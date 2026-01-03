#!/usr/bin/env bash
#
# install-helper-scripts.sh - Install RANCID helper scripts for viewing Git changes
#
# Description:
#   This script installs helper scripts from the repository's helper-scripts directory
#   to /var/lib/rancid/helper-scripts. These scripts help operators view and compare
#   device configuration changes stored in Git repositories.
#
# Usage:
#   sudo ./install-helper-scripts.sh [--force]
#
# Options:
#   --force    Overwrite existing helper scripts (default: preserve)
#   --help     Display this help message and exit
#
# Exit Codes:
#   0  Success
#   1  General error
#   2  Invalid usage or input
#

set -euo pipefail

#############################################
# Global Variables and Configuration
#############################################

SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="1.0.0"

# RANCID user and group
readonly RANCID_USER="rancid"
readonly RANCID_GROUP="rancid"

# Default paths
BASEDIR="${BASEDIR:-/var/lib/rancid}"
FORCE_OVERWRITE="${FORCE_OVERWRITE:-false}"

#############################################
# Utility Functions
#############################################

log() {
  echo "[helper-scripts-install] $*"
}

log_warn() {
  echo "[helper-scripts-install] WARNING: $*" >&2
}

log_error() {
  echo "[helper-scripts-install] ERROR: $*" >&2
}

die() {
  log_error "$*"
  exit 1
}

usage() {
  cat << EOF
${SCRIPT_NAME} - Install RANCID Helper Scripts

Usage:
  sudo ${SCRIPT_NAME} [OPTIONS]

Options:
  --force     Overwrite existing helper scripts (default: preserve)
  --help      Display this help message and exit
  --version   Display version information and exit

Description:
  Installs helper scripts from the repository's helper-scripts directory to
  /var/lib/rancid/helper-scripts. These scripts help operators view and compare
  device configuration changes stored in Git repositories.

Examples:
  # Standard installation (preserves existing scripts)
  sudo ${SCRIPT_NAME}

  # Force overwrite of existing scripts
  sudo ${SCRIPT_NAME} --force

Exit Codes:
  0  Success
  1  General error
  2  Invalid usage or input
EOF
}

version() {
  echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
}

# Verify script is running as root
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "This script must be run as root (use sudo)."
  fi
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

# Install helper scripts
install_helper_scripts() {
  log "Installing helper scripts..."

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local helper_scripts_source="${script_dir}/helper-scripts"
  local helper_scripts_dest="${BASEDIR}/helper-scripts"

  # Create destination directory
  safe_mkdir "${helper_scripts_dest}" "${RANCID_USER}" "${RANCID_GROUP}" "755"

  # Check if source directory exists
  if [[ ! -d "${helper_scripts_source}" ]]; then
    die "Helper scripts source directory not found: ${helper_scripts_source}"
  fi

  # Copy helper scripts
  local scripts=(
    "view-device-changes.sh"
    "list-recent-changes.sh"
    "compare-device-versions.sh"
    "view-device-history.sh"
  )

  local installed_count=0
  local skipped_count=0

  for script in "${scripts[@]}"; do
    local source_file="${helper_scripts_source}/${script}"
    local dest_file="${helper_scripts_dest}/${script}"

    if [[ ! -f "${source_file}" ]]; then
      log_warn "Helper script not found: ${source_file} (skipping)"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    if [[ -f "${dest_file}" ]] && [[ "${FORCE_OVERWRITE}" != "true" ]]; then
      log "Helper script exists: ${dest_file} (skipping, use --force to overwrite)"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    log "Installing helper script: ${script}"
    cp "${source_file}" "${dest_file}" || die "Failed to copy ${source_file} to ${dest_file}"
    chown "${RANCID_USER}:${RANCID_GROUP}" "${dest_file}" || die "Failed to set ownership on ${dest_file}"
    chmod 755 "${dest_file}" || die "Failed to set permissions on ${dest_file}"
    installed_count=$((installed_count + 1))
  done

  log "Helper scripts installation completed!"
  log "  Installed: ${installed_count}"
  log "  Skipped: ${skipped_count}"
  log "  Location: ${helper_scripts_dest}"
}

#############################################
# Main Function
#############################################

main() {
  parse_args "$@"
  require_root
  install_helper_scripts
  log "Installation completed successfully!"
}

# Execute main function
main "$@"
