#!/usr/bin/env bash
#
# deploy-rancid.sh - RANCID Deployment Script for RHEL 10
#
# Description:
#   This script automates the installation and configuration of RANCID (Really
#   Awesome New Cisco confIg Differ) on RHEL 10 systems. It handles package
#   installation, user/group creation, directory structure setup, Git repository
#   initialization, and cron job configuration.
#
# Features:
#   - Idempotent: Safe to run multiple times
#   - Configurable via .env file or /etc/rancid/rancid.env
#   - Preserves existing files unless --force is used
#   - Comprehensive error checking and validation
#
# Usage:
#   sudo ./deploy-rancid.sh [--force] [--help]
#
# Options:
#   --force    Overwrite existing configuration files (default: preserve)
#   --help     Display this help message and exit
#
# Configuration:
#   The script looks for a .env file in the script directory with the following
#   variables (all optional, defaults provided):
#     - RANCID_GROUPS: Array of group names, e.g., ("routers" "switches")
#     - GIT_NAME: Git user name for commits
#     - GIT_EMAIL: Git email for commits
#     - BASEDIR: Base directory for RANCID data (default: /var/lib/rancid)
#     - ETCDIR: Configuration directory (default: /etc/rancid)
#     - CRON_FILE: Cron file path (default: /etc/cron.d/rancid)
#     - CRON_LINE: Cron schedule line (default: "0 0 * * * rancid /usr/bin/rancid-run")
#
# Exit Codes:
#   0  Success
#   1  General error
#   2  Invalid usage or input
#   3  Missing dependency
#
# Author: RANCID Deployment Automation
# License: See LICENSE file
#

set -euo pipefail

#############################################
# Global Variables and Configuration
#############################################

# Script metadata
SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="1.0.0"
readonly FORCE_OVERWRITE="${FORCE_OVERWRITE:-false}"

# RANCID user and group
readonly RANCID_USER="rancid"
readonly RANCID_GROUP="rancid"

# Default paths (can be overridden via .env file)
ENV_FILE_DEFAULT="/etc/rancid/rancid.env"
BASEDIR_DEFAULT="/var/lib/rancid"
ETCDIR_DEFAULT="/etc/rancid"
CRON_FILE_DEFAULT="/etc/cron.d/rancid"
CRON_LINE_DEFAULT="0 0 * * * rancid /usr/bin/rancid-run"

# Default values for env file creation (if not already set)
RANCID_GROUPS_DEFAULT=("routers" "switches")
GIT_NAME_DEFAULT="RANCID Automation"
GIT_EMAIL_DEFAULT="rancid@$(hostname -f 2> /dev/null || hostname)"

#############################################
# Utility Functions
#############################################

# Logging functions
log() {
  echo "[rancid-setup] $*"
}

log_warn() {
  echo "[rancid-setup] WARNING: $*" >&2
}

log_error() {
  echo "[rancid-setup] ERROR: $*" >&2
}

die() {
  log_error "$*"
  exit 1
}

# Display usage information
usage() {
  cat << EOF
${SCRIPT_NAME} - RANCID Deployment Script for RHEL 10

Usage:
  sudo ${SCRIPT_NAME} [OPTIONS]

Options:
  --force     Overwrite existing configuration files (default: preserve)
  --help      Display this help message and exit
  --version   Display version information and exit

Description:
  Installs and configures RANCID on RHEL 10 systems. The script is idempotent
  and safe to run multiple times. Existing files are preserved unless --force
  is specified.

Configuration:
  The script reads configuration from:
  1. .env file in the script directory (if present)
  2. /etc/rancid/rancid.env (created if missing)

Examples:
  # Standard installation (preserves existing files)
  sudo ${SCRIPT_NAME}

  # Force overwrite of existing configuration
  sudo ${SCRIPT_NAME} --force

Exit Codes:
  0  Success
  1  General error
  2  Invalid usage or input
  3  Missing dependency

For more information, see the script header comments.
EOF
}

# Display version information
version() {
  echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --force)
        FORCE_OVERWRITE=true
        shift
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      --version | -v)
        version
        exit 0
        ;;
      *)
        log_error "Unknown option: ${1}"
        usage
        exit 2
        ;;
    esac
  done
}

# Verify script is running as root
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "This script must be run as root (use sudo)."
  fi
}

# Check if a command exists
command_exists() {
  command -v "${1}" > /dev/null 2>&1
}

# Validate required commands are available
check_dependencies() {
  local missing_deps=()
  local required_commands=("dnf" "getent" "useradd" "groupadd" "chown" "chmod" "mkdir")

  for cmd in "${required_commands[@]}"; do
    if ! command_exists "${cmd}"; then
      missing_deps+=("${cmd}")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    die "Missing required commands: ${missing_deps[*]}. Please install required packages."
  fi
}

# Safely create directory with proper permissions
safe_mkdir() {
  local dir="${1}"
  local owner="${2:-root}"
  local group="${3:-root}"
  local mode="${4:-755}"

  if [[ ! -d "${dir}" ]]; then
    log "Creating directory: ${dir}"
    mkdir -p "${dir}" || die "Failed to create directory: ${dir}"
  else
    log "Directory exists: ${dir}"
  fi

  chown "${owner}:${group}" "${dir}" || die "Failed to set ownership on ${dir}"
  chmod "${mode}" "${dir}" || die "Failed to set permissions on ${dir}"
}

# Safely create file with backup if it exists
safe_create_file() {
  local file="${1}"
  local content="${2}"
  local owner="${3:-root}"
  local group="${4:-root}"
  local mode="${5:-644}"
  local force="${6:-false}"

  if [[ -f "${file}" ]] && [[ "${force}" != "true" ]]; then
    log "File exists: ${file} (skipping, use --force to overwrite)"
    return 0
  fi

  if [[ -f "${file}" ]] && [[ "${force}" == "true" ]]; then
    local backup_file
    backup_file="${file}.bak.$(date +%Y%m%d%H%M%S)"
    log "Backing up existing file to: ${backup_file}"
    cp -a "${file}" "${backup_file}" || die "Failed to backup ${file}"
  fi

  log "Creating file: ${file}"
  cat > "${file}" << EOF
${content}
EOF

  chown "${owner}:${group}" "${file}" || die "Failed to set ownership on ${file}"
  chmod "${mode}" "${file}" || die "Failed to set permissions on ${file}"
}

#############################################
# Configuration Loading Functions
#############################################

# Load configuration from .env file in script directory
load_local_env() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local env_file="${script_dir}/.env"

  if [[ ! -f "${env_file}" ]]; then
    log "No .env file found at ${env_file}, using hardcoded defaults"
    return 0
  fi

  log "Loading defaults from: ${env_file}"

  # Temporarily disable strict mode to allow sourcing (variables may be unset)
  set +u
  # shellcheck source=/dev/null
  if ! source "${env_file}"; then
    set -u
    die "Failed to source ${env_file}"
  fi
  set -u

  # Map variables from .env to _DEFAULT variables (support multiple naming conventions)
  # Priority: LIST_OF_GROUPS > RANCID_GROUPS > RANCID_GROUPS_DEFAULT
  # LIST_OF_GROUPS is the preferred name per requirements.md
  if [[ -v LIST_OF_GROUPS ]]; then
    # Check if it's an array (has multiple elements or is declared as array)
    if [[ "${#LIST_OF_GROUPS[@]}" -gt 1 ]]; then
      # It's an array, use as-is
      RANCID_GROUPS_DEFAULT=("${LIST_OF_GROUPS[@]}")
    elif [[ "${#LIST_OF_GROUPS[@]}" -eq 1 ]] && [[ "${LIST_OF_GROUPS[0]}" =~ [[:space:]] ]]; then
      # Single element with spaces, convert to array
      read -ra RANCID_GROUPS_DEFAULT <<< "${LIST_OF_GROUPS[0]}"
    else
      # Single element, treat as array with one element
      RANCID_GROUPS_DEFAULT=("${LIST_OF_GROUPS[@]}")
    fi
  elif [[ -v RANCID_GROUPS ]]; then
    RANCID_GROUPS_DEFAULT=("${RANCID_GROUPS[@]}")
  elif [[ -v RANCID_GROUPS_DEFAULT ]]; then
    # Already in _DEFAULT format, check if string needs conversion
    if [[ "${#RANCID_GROUPS_DEFAULT[@]}" -eq 1 ]] && [[ "${RANCID_GROUPS_DEFAULT[0]}" =~ [[:space:]] ]]; then
      read -ra RANCID_GROUPS_DEFAULT <<< "${RANCID_GROUPS_DEFAULT[0]}"
    fi
  else
    RANCID_GROUPS_DEFAULT=("routers" "switches")
  fi

  # Validate RANCID_GROUPS_DEFAULT is not empty
  if [[ "${#RANCID_GROUPS_DEFAULT[@]}" -eq 0 ]]; then
    log_warn "RANCID_GROUPS_DEFAULT is empty, using default"
    RANCID_GROUPS_DEFAULT=("routers" "switches")
  fi

  # GIT_NAME -> GIT_NAME_DEFAULT
  if [[ -n "${GIT_NAME:-}" ]]; then
    GIT_NAME_DEFAULT="${GIT_NAME}"
  elif [[ -z "${GIT_NAME_DEFAULT:-}" ]]; then
    GIT_NAME_DEFAULT="RANCID Automation"
  fi

  # GIT_EMAIL -> GIT_EMAIL_DEFAULT
  if [[ -n "${GIT_EMAIL:-}" ]]; then
    GIT_EMAIL_DEFAULT="${GIT_EMAIL}"
  elif [[ -z "${GIT_EMAIL_DEFAULT:-}" ]]; then
    GIT_EMAIL_DEFAULT="rancid@$(hostname -f 2> /dev/null || hostname)"
  fi

  # BASEDIR -> BASEDIR_DEFAULT
  if [[ -n "${BASEDIR:-}" ]]; then
    BASEDIR_DEFAULT="${BASEDIR}"
  fi

  # ETCDIR -> ETCDIR_DEFAULT
  if [[ -n "${ETCDIR:-}" ]]; then
    ETCDIR_DEFAULT="${ETCDIR}"
  fi

  # CRON_FILE -> CRON_FILE_DEFAULT
  if [[ -n "${CRON_FILE:-}" ]]; then
    CRON_FILE_DEFAULT="${CRON_FILE}"
  fi

  # CRON_LINE -> CRON_LINE_DEFAULT
  if [[ -n "${CRON_LINE:-}" ]]; then
    CRON_LINE_DEFAULT="${CRON_LINE}"
  fi

  log "Configuration loaded from .env file"
}

# Ensure /etc/rancid/rancid.env exists, create if missing
ensure_env_file() {
  log "Ensuring environment file exists: ${ENV_FILE_DEFAULT}"

  # Create ETCDIR first so we can place env file
  safe_mkdir "${ETCDIR_DEFAULT}" "root" "root" "755"

  if [[ -f "${ENV_FILE_DEFAULT}" ]] && [[ "${FORCE_OVERWRITE}" != "true" ]]; then
    log "Using existing env file: ${ENV_FILE_DEFAULT}"
    return 0
  fi

  if [[ -f "${ENV_FILE_DEFAULT}" ]] && [[ "${FORCE_OVERWRITE}" == "true" ]]; then
    log "Overwriting existing env file (--force specified)"
  else
    log "Creating ${ENV_FILE_DEFAULT} (was missing)..."
  fi

  # Format array as space-separated string for easier sourcing
  local groups_str
  groups_str="$(printf "%s " "${RANCID_GROUPS_DEFAULT[@]}")"
  groups_str="${groups_str%% }"

  local env_content
  env_content="# /etc/rancid/rancid.env
# RANCID environment configuration (sourced by installer)
# IMPORTANT: This file is shell-sourced. Keep it trusted and root-writable only.

# RANCID_GROUPS: Space-separated list of group names
RANCID_GROUPS=(${groups_str})

GIT_NAME=\"${GIT_NAME_DEFAULT}\"
GIT_EMAIL=\"${GIT_EMAIL_DEFAULT}\"

BASEDIR=\"${BASEDIR_DEFAULT}\"
ETCDIR=\"${ETCDIR_DEFAULT}\"

CRON_FILE=\"${CRON_FILE_DEFAULT}\"
CRON_LINE=\"${CRON_LINE_DEFAULT}\""

  safe_create_file "${ENV_FILE_DEFAULT}" "${env_content}" "root" "root" "640" "${FORCE_OVERWRITE}"
}

# Load environment from /etc/rancid/rancid.env and validate
load_env() {
  log "Loading environment from: ${ENV_FILE_DEFAULT}"

  if [[ ! -f "${ENV_FILE_DEFAULT}" ]]; then
    die "Environment file not found: ${ENV_FILE_DEFAULT}"
  fi

  if [[ ! -r "${ENV_FILE_DEFAULT}" ]]; then
    die "Environment file is not readable: ${ENV_FILE_DEFAULT}"
  fi

  # Temporarily disable strict mode for sourcing
  set +u
  # shellcheck source=/dev/null
  if ! source "${ENV_FILE_DEFAULT}"; then
    set -u
    die "Failed to source ${ENV_FILE_DEFAULT}"
  fi
  set -u

  # Validate required variables are set
  [[ -n "${GIT_NAME:-}" ]] || die "GIT_NAME is not set in ${ENV_FILE_DEFAULT}"
  [[ -n "${GIT_EMAIL:-}" ]] || die "GIT_EMAIL is not set in ${ENV_FILE_DEFAULT}"
  [[ -n "${BASEDIR:-}" ]] || die "BASEDIR is not set in ${ENV_FILE_DEFAULT}"
  [[ -n "${ETCDIR:-}" ]] || die "ETCDIR is not set in ${ENV_FILE_DEFAULT}"
  [[ -n "${CRON_FILE:-}" ]] || die "CRON_FILE is not set in ${ENV_FILE_DEFAULT}"
  [[ -n "${CRON_LINE:-}" ]] || die "CRON_LINE is not set in ${ENV_FILE_DEFAULT}"
  [[ "${#RANCID_GROUPS[@]}" -gt 0 ]] || die "RANCID_GROUPS is empty in ${ENV_FILE_DEFAULT}"

  # Validate paths are absolute
  [[ "${BASEDIR}" =~ ^/ ]] || die "BASEDIR must be an absolute path: ${BASEDIR}"
  [[ "${ETCDIR}" =~ ^/ ]] || die "ETCDIR must be an absolute path: ${ETCDIR}"
  [[ "${CRON_FILE}" =~ ^/ ]] || die "CRON_FILE must be an absolute path: ${CRON_FILE}"

  log "Environment loaded and validated successfully"
}

#############################################
# Installation Functions
#############################################

# Install required packages via dnf
install_packages() {
  log "Installing required packages..."

  if ! command_exists dnf; then
    die "dnf package manager not found. This script requires RHEL 10 or compatible."
  fi

  log "Updating OS packages..."
  if ! dnf -y update; then
    die "Failed to update OS packages"
  fi

  log "Installing EPEL repository..."
  if ! dnf -y install epel-release; then
    die "Failed to install EPEL repository"
  fi

  log "Installing RANCID and dependencies..."
  local packages=(
    "rancid"
    "git"
    "perl-Expect"
    "perl-TermReadKey"
    "net-snmp-utils"
    "openssh-clients"
  )

  if ! dnf -y install "${packages[@]}"; then
    die "Failed to install RANCID packages"
  fi

  log "Package installation completed successfully"
}

# Create RANCID user and group
create_user_group() {
  log "Setting up RANCID user and group..."

  # Create group if it doesn't exist
  if ! getent group "${RANCID_GROUP}" > /dev/null 2>&1; then
    log "Creating group: ${RANCID_GROUP}"
    if ! groupadd "${RANCID_GROUP}"; then
      die "Failed to create group: ${RANCID_GROUP}"
    fi
  else
    log "Group exists: ${RANCID_GROUP}"
  fi

  # Create user if it doesn't exist
  if ! id -u "${RANCID_USER}" > /dev/null 2>&1; then
    log "Creating user: ${RANCID_USER} (home=${BASEDIR})"
    if ! useradd -m -d "${BASEDIR}" -s /bin/bash -g "${RANCID_GROUP}" "${RANCID_USER}"; then
      die "Failed to create user: ${RANCID_USER}"
    fi
    log "NOTE: User created without a password. Set one if interactive login is required: passwd ${RANCID_USER}"
  else
    log "User exists: ${RANCID_USER}"
    # Verify home directory matches expected value
    local current_home
    current_home="$(getent passwd "${RANCID_USER}" | cut -d: -f6 || true)"
    if [[ "${current_home}" != "${BASEDIR}" ]]; then
      log_warn "RANCID user's home is '${current_home}', expected '${BASEDIR}'."
    fi
  fi
}

# Create base directory structure
create_base_dirs() {
  log "Creating base directory structure..."

  # Create base directory and subdirectories
  safe_mkdir "${BASEDIR}" "${RANCID_USER}" "${RANCID_GROUP}" "750"
  safe_mkdir "${BASEDIR}/logs" "${RANCID_USER}" "${RANCID_GROUP}" "750"
  safe_mkdir "${BASEDIR}/tmp" "${RANCID_USER}" "${RANCID_GROUP}" "750"

  # Ensure config directory exists (root-owned)
  safe_mkdir "${ETCDIR}" "root" "root" "755"

  log "Base directory structure created"
}

# Write RANCID main configuration file
write_rancid_conf() {
  local rancid_conf="${ETCDIR}/rancid.conf"
  local global_logfile="${BASEDIR}/logs/rancid.log"
  local group_list
  group_list="$(printf "%s " "${RANCID_GROUPS[@]}")"
  group_list="${group_list%% }"

  log "Writing RANCID configuration: ${rancid_conf}"

  local conf_content="
BASEDIR=${BASEDIR}
RCSSYS=git
LIST_OF_GROUPS=\"${group_list}\"
LOGFILE=${global_logfile}"

  safe_create_file "${rancid_conf}" "${conf_content}" "root" "root" "644" "${FORCE_OVERWRITE}"
}

# Ensure correct ownership and permissions for a file or directory
ensure_permissions() {
  local target="${1}"
  local owner="${2}"
  local group="${3}"
  local mode="${4}"

  if [[ ! -e "${target}" ]]; then
    return 0 # File doesn't exist, nothing to fix
  fi

  # Check and fix ownership
  local current_owner
  current_owner="$(stat -c "%U:%G" "${target}" 2> /dev/null || echo "")"
  if [[ "${current_owner}" != "${owner}:${group}" ]]; then
    log "  Correcting ownership: ${target} (${current_owner} -> ${owner}:${group})"
    chown "${owner}:${group}" "${target}" || die "Failed to set ownership on ${target}"
  fi

  # Check and fix permissions
  local current_mode
  current_mode="$(stat -c "%a" "${target}" 2> /dev/null || echo "")"
  if [[ "${current_mode}" != "${mode}" ]]; then
    log "  Correcting permissions: ${target} (${current_mode} -> ${mode})"
    chmod "${mode}" "${target}" || die "Failed to set permissions on ${target}"
  fi
}

# Create directory structure for each RANCID group
create_groups_layout() {
  log "Creating group directory structure for RANCID groups..."

  # Get script directory to locate example files
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local example_router_db="${script_dir}/example-router.db"

  if [[ ! -f "${example_router_db}" ]]; then
    die "Required template file not found: ${example_router_db}"
  fi

  for g in "${RANCID_GROUPS[@]}"; do
    # Validate group name (basic sanity check)
    if [[ ! "${g}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      log_warn "Invalid group name format: ${g} (skipping)"
      continue
    fi

    local group_dir="${BASEDIR}/${g}"
    log "  Setting up group: ${g}"

    # Create group directory with proper permissions (idempotent)
    safe_mkdir "${group_dir}" "${RANCID_USER}" "${RANCID_GROUP}" "750"

    # Create subdirectories: configs/, logs/, status/
    safe_mkdir "${group_dir}/configs" "${RANCID_USER}" "${RANCID_GROUP}" "750"
    safe_mkdir "${group_dir}/logs" "${RANCID_USER}" "${RANCID_GROUP}" "750"
    safe_mkdir "${group_dir}/status" "${RANCID_USER}" "${RANCID_GROUP}" "750"

    # Ensure correct permissions on existing directories (idempotent correction)
    ensure_permissions "${group_dir}" "${RANCID_USER}" "${RANCID_GROUP}" "750"
    ensure_permissions "${group_dir}/configs" "${RANCID_USER}" "${RANCID_GROUP}" "750"
    ensure_permissions "${group_dir}/logs" "${RANCID_USER}" "${RANCID_GROUP}" "750"
    ensure_permissions "${group_dir}/status" "${RANCID_USER}" "${RANCID_GROUP}" "750"

    # Create router.db from example-router.db template (never overwrite existing)
    local router_db="${group_dir}/router.db"
    if [[ ! -f "${router_db}" ]]; then
      log "  Creating router.db from template: ${router_db}"
      if ! cp "${example_router_db}" "${router_db}"; then
        die "Failed to copy ${example_router_db} to ${router_db}"
      fi
      chown "${RANCID_USER}:${RANCID_GROUP}" "${router_db}" || die "Failed to set ownership on ${router_db}"
      chmod 640 "${router_db}" || die "Failed to set permissions on ${router_db}"
    else
      log "  router.db exists: ${router_db} (preserving, correcting permissions if needed)"
      # Correct ownership/permissions if incorrect (idempotent)
      ensure_permissions "${router_db}" "${RANCID_USER}" "${RANCID_GROUP}" "640"
    fi
  done

  log "Group directory structure created and validated"
}

# Setup .cloginrc credentials file from example-cloginrc template
setup_cloginrc_placeholder() {
  local cloginrc="${BASEDIR}/.cloginrc"

  log "Setting up credentials file: ${cloginrc}"

  # Get script directory to locate example file
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local example_cloginrc="${script_dir}/example-cloginrc"

  if [[ ! -f "${example_cloginrc}" ]]; then
    die "Required template file not found: ${example_cloginrc}"
  fi

  # Per requirements.md: Never overwrite existing .cloginrc
  if [[ -f "${cloginrc}" ]]; then
    log "${cloginrc} already exists; preserving contents (correcting permissions if needed)"
    # Correct ownership/permissions if incorrect (idempotent)
    ensure_permissions "${cloginrc}" "${RANCID_USER}" "${RANCID_GROUP}" "600"
  else
    log "Creating ${cloginrc} from template: ${example_cloginrc}"
    if ! cp "${example_cloginrc}" "${cloginrc}"; then
      die "Failed to copy ${example_cloginrc} to ${cloginrc}"
    fi
    chown "${RANCID_USER}:${RANCID_GROUP}" "${cloginrc}" || die "Failed to set ownership on ${cloginrc}"
    chmod 600 "${cloginrc}" || die "Failed to set permissions on ${cloginrc}"
    log "NOTE: Populate credentials in ${cloginrc} before running RANCID collection"
  fi
}

# Setup SSH key for RANCID user
setup_ssh_key() {
  local ssh_dir="${BASEDIR}/.ssh"
  local ssh_key="${ssh_dir}/id_rancid"

  log "Setting up SSH directory and key..."

  # Create SSH directory
  safe_mkdir "${ssh_dir}" "${RANCID_USER}" "${RANCID_GROUP}" "700"

  # Generate SSH key if it doesn't exist
  if [[ ! -f "${ssh_key}" ]]; then
    log "Generating SSH keypair for ${RANCID_USER}: ${ssh_key}"
    if ! sudo -u "${RANCID_USER}" ssh-keygen -t ed25519 -f "${ssh_key}" -N "" -C "rancid@$(hostname -f 2> /dev/null || hostname)" 2> /dev/null; then
      die "Failed to generate SSH key: ${ssh_key}"
    fi
  else
    log "SSH key exists: ${ssh_key}"
  fi

  # Ensure correct permissions
  if [[ -f "${ssh_key}" ]]; then
    chown "${RANCID_USER}:${RANCID_GROUP}" "${ssh_key}" || die "Failed to set ownership on ${ssh_key}"
    chmod 600 "${ssh_key}" || die "Failed to set permissions on ${ssh_key}"
  fi

  if [[ -f "${ssh_key}.pub" ]]; then
    chown "${RANCID_USER}:${RANCID_GROUP}" "${ssh_key}.pub" || die "Failed to set ownership on ${ssh_key}.pub"
    chmod 644 "${ssh_key}.pub" || die "Failed to set permissions on ${ssh_key}.pub"
  fi
}

# Initialize Git repositories for each group
init_git_repos() {
  log "Initializing Git repositories per group..."

  if ! command_exists git; then
    die "git command not found. Please install git package."
  fi

  for g in "${RANCID_GROUPS[@]}"; do
    local dir="${BASEDIR}/${g}"

    if [[ ! -d "${dir}" ]]; then
      log_warn "Group directory does not exist: ${dir} (skipping)"
      continue
    fi

    if [[ ! -d "${dir}/.git" ]]; then
      log "  Initializing Git repository: ${dir}"
      if ! sudo -u "${RANCID_USER}" git -C "${dir}" init; then
        log_warn "Failed to initialize Git repository in ${dir}"
        continue
      fi

      if ! sudo -u "${RANCID_USER}" git -C "${dir}" config user.name "${GIT_NAME}"; then
        log_warn "Failed to set git user.name in ${dir}"
      fi

      if ! sudo -u "${RANCID_USER}" git -C "${dir}" config user.email "${GIT_EMAIL}"; then
        log_warn "Failed to set git user.email in ${dir}"
      fi

      if ! sudo -u "${RANCID_USER}" git -C "${dir}" commit --allow-empty -m "Initial RANCID repository" 2> /dev/null; then
        log_warn "Failed to create initial commit in ${dir}"
      fi
    else
      log "  Git already initialized: ${dir}"
      # Update git config (non-fatal)
      sudo -u "${RANCID_USER}" git -C "${dir}" config user.name "${GIT_NAME}" 2> /dev/null || true
      sudo -u "${RANCID_USER}" git -C "${dir}" config user.email "${GIT_EMAIL}" 2> /dev/null || true
    fi
  done

  log "Git repository initialization completed"
}

# Install cron job for RANCID
install_cron() {
  log "Installing cron job: ${CRON_FILE}"

  local cron_content="# RANCID nightly configuration backup
${CRON_LINE}"

  safe_create_file "${CRON_FILE}" "${cron_content}" "root" "root" "644" "${FORCE_OVERWRITE}"
}

#############################################
# Validation and Post-Installation
#############################################

# Perform post-installation validation checks
post_checks() {
  log "Performing post-installation validation..."

  # Verify RANCID commands are available
  if ! command_exists rancid-run; then
    die "rancid-run not found on PATH after installation"
  fi

  if ! command_exists rancid; then
    die "rancid not found on PATH after installation"
  fi

  log "Verifying ownership and permissions..."
  local files_to_check=(
    "${BASEDIR}"
    "${BASEDIR}/.cloginrc"
    "${BASEDIR}/.ssh"
    "${ETCDIR}/rancid.conf"
    "${CRON_FILE}"
    "${ENV_FILE_DEFAULT}"
  )

  for item in "${files_to_check[@]}"; do
    if [[ -e "${item}" ]]; then
      stat -c "%U:%G %a %n" "${item}" || true
    else
      log_warn "Expected file/directory missing: ${item}"
    fi
  done

  log "Post-installation validation completed successfully"
}

# Display next steps to the user
show_next_steps() {
  cat << EOF

==================== NEXT STEPS ====================
1) Populate device credentials in: ${BASEDIR}/.cloginrc
   - Prefer read-only credentials where possible.
   - This file contains sensitive information and must remain mode 600.

2) Populate each group inventory in: ${BASEDIR}/<group>/router.db
   - Format: hostname:vendor
   - Example: jun-core-01:juniper

3) Distribute SSH public key to devices (as appropriate):
   ${BASEDIR}/.ssh/id_rancid.pub

4) Run a manual test collection:
   sudo -u ${RANCID_USER} rancid-run

5) Review logs:
   ls -ltr ${BASEDIR}/*/logs/
   journalctl -u crond | grep rancid

6) Verify cron job is active:
   systemctl status crond
   cat ${CRON_FILE}

====================================================
EOF
}

#############################################
# Main Function
#############################################

main() {
  # Parse command line arguments
  parse_args "$@"

  # Verify prerequisites
  require_root
  check_dependencies

  # Load configuration
  load_local_env
  ensure_env_file
  load_env

  # Perform installation steps
  install_packages
  create_user_group
  create_base_dirs
  write_rancid_conf
  create_groups_layout
  setup_cloginrc_placeholder
  setup_ssh_key
  init_git_repos
  install_cron

  # Validation and completion
  post_checks
  show_next_steps

  log "RANCID deployment completed successfully!"
}

# Execute main function
main "$@"
