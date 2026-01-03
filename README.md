# RANCID Deployment Automation

![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-RHEL%2010-red.svg)
![Shell](https://img.shields.io/badge/shell-Bash-green.svg)
![Status](https://img.shields.io/badge/status-production%20ready-success.svg)

Automated deployment script for RANCID (Really Awesome New Cisco confIg Differ) on RHEL 10 systems. This script provides a complete, idempotent solution for installing and configuring RANCID with Git-based configuration versioning.

---

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [🏗️ Architecture](#️-architecture)
- [✅ Requirements](#-requirements)
- [🚀 Installation](#-installation)
- [⚙️ Configuration](#️-configuration)
- [📝 Usage](#-usage)
- [🔧 How It Works](#-how-it-works)
- [🔒 Security Notes](#-security-notes)
- [🗑️ Uninstallation](#️-uninstallation)
- [🐛 Troubleshooting](#-troubleshooting)
- [📚 Additional Resources](#-additional-resources)
- [📄 License](#-license)

---

## 🎯 Overview

**RANCID** (Really Awesome New Cisco confIg Differ) is a network configuration management tool that automatically collects, stores, and tracks changes to network device configurations. This deployment script automates the entire setup process on RHEL 10 systems.

### Key Features

- ✅ **Idempotent**: Safe to run multiple times without side effects
- ✅ **Configurable**: Supports `.env` file for custom configuration
- ✅ **Preserves Data**: Existing files are protected unless `--force` is used
- ✅ **Dry-Run Mode**: Preview changes with `--dryrun` before execution
- ✅ **Comprehensive**: Handles packages, users, directories, Git repos, and cron jobs
- ✅ **Validated**: Extensive error checking and validation throughout
- ✅ **Documented**: Clear logging and helpful error messages

### What Gets Installed

- RANCID package and dependencies
- RANCID user and group
- Directory structure for device groups
- Git repositories for configuration versioning
- SSH keys for device access
- Cron job for automated collection
- Configuration files with proper permissions

---

## 🏗️ Architecture

The deployment script follows a modular architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                    deploy-rancid.sh                      │
│                                                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────┐  │
│  │ Configuration │───▶│ Installation │───▶│ Validation│  │
│  │   Loading     │    │   Functions   │    │   Checks  │  │
│  └──────────────┘    └──────────────┘    └──────────┘  │
│         │                     │                  │        │
│         ▼                     ▼                  ▼        │
│  ┌──────────────────────────────────────────────────┐   │
│  │         System Configuration Files                │   │
│  │  • /etc/rancid/rancid.conf                       │   │
│  │  • /etc/cron.d/rancid                            │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │         RANCID Data Directory                      │   │
│  │  /var/lib/rancid/                                  │   │
│  │  ├── .cloginrc (credentials)                      │   │
│  │  ├── .ssh/id_rancid (SSH key)                     │   │
│  │  └── <group>/                                      │   │
│  │      ├── router.db                                 │   │
│  │      ├── configs/                                  │   │
│  │      ├── logs/                                     │   │
│  │      └── .git/ (version control)                   │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Configuration Flow

```
.env file (optional)
    │
    ▼
deploy-rancid.sh
    │
    ├─▶ Load .env variables
    │
    ├─▶ Validate configuration
    │
    └─▶ Execute installation steps
        ├─▶ Create group directories
        ├─▶ Copy router.db from template
        ├─▶ Copy .cloginrc from template
        └─▶ Initialize Git repositories
```

---

## ✅ Requirements

### System Requirements

- **Operating System**: RHEL 10 (or compatible)
- **Architecture**: x86_64
- **Privileges**: Root access (via `sudo` or direct root login)
- **Network**: Internet access for package installation

### Software Dependencies

The script automatically installs these packages:

| Package | Purpose | Status |
|---------|---------|--------|
| `rancid` | Main RANCID application | ✅ Required |
| `git` | Version control for configs | ✅ Required |
| `perl-Expect` | Device interaction | ✅ Required |
| `perl-TermReadKey` | Terminal input handling | ✅ Required |
| `net-snmp-utils` | SNMP utilities | ✅ Required |
| `openssh-clients` | SSH client tools | ✅ Required |
| `epel-release` | EPEL repository | ✅ Required |

### Pre-Installation Checklist

- [ ] System is running RHEL 10
- [ ] Root or sudo access is available
- [ ] Internet connectivity is working
- [ ] `.env` file is configured (optional, see [Configuration](#️-configuration))
- [ ] Sufficient disk space available (minimum 1GB recommended)

---

## 🚀 Installation

### Quick Start

1. **Clone or download the repository**:
   ```bash
   git clone <repository-url>
   cd deploy-rancid
   ```

2. **Configure your environment** (optional):
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Run the deployment script**:
   ```bash
   sudo ./deploy-rancid.sh
   ```

### Step-by-Step Installation

#### Step 1: Prepare Configuration

Copy the example environment file and customize it:

```bash
cp .env.example .env
nano .env  # or use your preferred editor
```

See the [Configuration](#️-configuration) section for details on available options.

#### Step 2: Preview Changes (Recommended)

Before executing, preview what the script will do:

```bash
sudo ./deploy-rancid.sh --dryrun
```

This shows all changes without modifying the system.

#### Step 3: Execute Deployment

Run the script with appropriate privileges:

```bash
sudo ./deploy-rancid.sh
```

#### Step 4: Verify Installation

The script performs automatic validation, but you can manually verify:

```bash
# Check RANCID commands are available
which rancid-run
which rancid

# Verify directory structure
ls -la /var/lib/rancid/

# Check cron job
cat /etc/cron.d/rancid

# Verify Git repositories
ls -la /var/lib/rancid/*/.git
```

#### Step 5: Post-Installation Configuration

After successful installation, complete these steps:

- [ ] Populate device credentials in `/var/lib/rancid/.cloginrc`
- [ ] Add devices to group `router.db` files
- [ ] Distribute SSH public key to network devices
- [ ] Test manual collection: `sudo -u rancid rancid-run`
- [ ] Review logs: `ls -ltr /var/lib/rancid/*/logs/`

---

## ⚙️ Configuration

### Environment File (`.env`)

The script supports configuration via a `.env` file in the script directory. This file is **optional** - if not present, sensible defaults are used.

#### Creating Your `.env` File

1. **Copy the example file**:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your values**:
   ```bash
   nano .env  # or vim, emacs, etc.
   ```

3. **Important**: Never commit `.env` to version control (it's in `.gitignore`)

#### Available Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `RANCID_GROUPS` | Array of group names | `("routers" "switches")` | ❌ |
| `GIT_NAME` | Git commit author name | `"RANCID Automation"` | ❌ |
| `GIT_EMAIL` | Git commit author email | `rancid@$(hostname)` | ❌ |
| `BASEDIR` | Base directory for RANCID data | `"/var/lib/rancid"` | ❌ |
| `ETCDIR` | Configuration directory | `"/etc/rancid"` | ❌ |
| `CRON_FILE` | Cron job file path | `"/etc/cron.d/rancid"` | ❌ |
| `CRON_LINE` | Cron schedule | `"0 0 * * * rancid /usr/bin/rancid-run"` | ❌ |

#### Variable Naming Conventions

The script supports **two naming conventions** for flexibility:

1. **Standard format** (recommended):
   ```bash
   RANCID_GROUPS=("core-switches" "tor-switches" "firewalls")
   GIT_NAME="RANCID"
   GIT_EMAIL="rancid@example.com"
   ```

2. **DEFAULT suffix format** (also supported):
   ```bash
   RANCID_GROUPS_DEFAULT=("core-switches" "tor-switches" "firewalls")
   GIT_NAME_DEFAULT="RANCID"
   GIT_EMAIL_DEFAULT="rancid@example.com"
   ```

#### Example `.env` File

```bash
# RANCID Deployment Configuration
# Copy this file to .env and customize for your environment

# RANCID Groups - Array of group names
# Supports bash array syntax: ("group1" "group2")
# Or space-separated string: "group1 group2"
RANCID_GROUPS=("core-switches" "tor-switches" "ASAv" "firewalls")

# Git configuration for RANCID repositories
GIT_NAME="RANCID Automation"
GIT_EMAIL="rancid@example.local"

# Optional: Override system paths (usually not needed)
# BASEDIR="/var/lib/rancid"
# ETCDIR="/etc/rancid"
# CRON_FILE="/etc/cron.d/rancid"
# CRON_LINE="0 0 * * * rancid /usr/bin/rancid-run"
```

### `.env.example` File

The `.env.example` file serves as a **template** and **documentation** for configuration options:

- ✅ **Safe to commit**: Contains no sensitive information
- ✅ **Well-documented**: Includes comments explaining each variable
- ✅ **Example values**: Shows expected format and syntax
- ✅ **Reference guide**: Documents all available options

**Usage**:
1. Copy `.env.example` to `.env`
2. Customize values for your environment
3. Never commit `.env` (it's gitignored)

### Template Files

The script uses template files to create initial configuration files. These templates are **copied** (not inlined) to ensure consistency:

#### `example-router.db`

- **Purpose**: Template for device inventory files
- **Location**: Script directory
- **Usage**: Copied to `/var/lib/rancid/<group>/router.db` for each group
- **Behavior**: Never overwrites existing `router.db` files (idempotent)
- **Permissions**: 640, owner rancid:rancid

#### `example-cloginrc`

- **Purpose**: Template for credentials file
- **Location**: Script directory
- **Usage**: Copied to `/var/lib/rancid/.cloginrc`
- **Behavior**: Never overwrites existing `.cloginrc` file (idempotent, per requirements)
- **Permissions**: 600, owner rancid:rancid

**Important**: Both template files are copied as-is. The script does not modify their contents during deployment.

### Dry-Run Mode

The script supports a `--dryrun` (or `--dry-run`) option that allows you to preview all changes without actually modifying the system:

```bash
sudo ./deploy-rancid.sh --dryrun
```

**What dry-run shows:**
- ✅ Directories that would be created
- ✅ Files that would be created or modified
- ✅ Ownership and permission changes
- ✅ Package installation commands
- ✅ User/group creation operations
- ✅ Git repository initialization steps

**What dry-run does NOT do:**
- ❌ Make any actual changes to the system
- ❌ Install packages
- ❌ Create files or directories
- ❌ Modify permissions or ownership

This is useful for:
- Understanding what the script will do before execution
- Validating configuration without risk
- Troubleshooting configuration issues
- Documentation and planning

---

## 📝 Usage

### Basic Usage

```bash
# Standard installation (preserves existing files)
sudo ./deploy-rancid.sh

# Preview changes without executing (dry-run)
sudo ./deploy-rancid.sh --dryrun

# Force overwrite of existing configuration
sudo ./deploy-rancid.sh --force

# Display help information
./deploy-rancid.sh --help

# Display version
./deploy-rancid.sh --version
```

### Command-Line Options

| Option | Description | Default Behavior |
|--------|-------------|------------------|
| `--force` | Overwrite existing configuration files | Preserves existing files |
| `--dryrun` / `--dry-run` | Preview changes without executing | Executes changes |
| `--help` / `-h` | Display help message and exit | N/A |
| `--version` / `-v` | Display version information and exit | N/A |

### Idempotent Behavior

The script is designed to be **idempotent**, meaning:

- ✅ Safe to run multiple times
- ✅ Existing files are preserved (unless `--force`)
- ✅ Existing users/groups are detected and skipped
- ✅ Git repositories are not re-initialized if they exist
- ✅ Configuration files are backed up before overwrite (with `--force`)

### Example Workflows

#### Initial Installation

```bash
# 1. Configure environment
cp .env.example .env
nano .env

# 2. Run deployment
sudo ./deploy-rancid.sh

# 3. Verify installation
sudo -u rancid rancid-run
```

#### Updating Configuration

```bash
# 1. Update .env file
nano .env

# 2. Preview changes with dry-run
sudo ./deploy-rancid.sh --dryrun

# 3. Apply changes
sudo ./deploy-rancid.sh

# 4. Verify configuration
cat /etc/rancid/rancid.conf
```

#### Adding New Groups

```bash
# 1. Edit .env to add new group
nano .env
# Add: RANCID_GROUPS=("existing" "new-group")

# 2. Re-run script (idempotent, only adds new group)
sudo ./deploy-rancid.sh
```

---

## 🔧 How It Works

### Execution Flow

The script follows this execution sequence:

```
1. Parse Arguments
   ├─▶ Validate command-line options
   └─▶ Set FORCE_OVERWRITE flag

2. Prerequisites Check
   ├─▶ Verify root privileges
   └─▶ Check required commands exist

3. Configuration Loading
   ├─▶ Load .env file (if present)
   ├─▶ Map variables to internal format
   └─▶ Validate configuration

4. Package Installation
   ├─▶ Update system packages
   ├─▶ Install EPEL repository
   └─▶ Install RANCID and dependencies

5. User/Group Setup
   ├─▶ Create rancid group (if needed)
   └─▶ Create rancid user (if needed)

6. Directory Structure
   ├─▶ Create base directories
   ├─▶ Create group directories (configs/, logs/, status/)
   ├─▶ Copy router.db from template for each group
   └─▶ Set proper permissions

7. Configuration Files
   ├─▶ Write rancid.conf
   ├─▶ Copy .cloginrc from template
   └─▶ Install cron job

8. SSH Key Setup
   └─▶ Generate SSH keypair (if needed)

9. Git Initialization
   ├─▶ Initialize Git repos per group
   └─▶ Configure Git user/email

10. Validation
    ├─▶ Verify commands exist
    ├─▶ Check file permissions
    └─▶ Display next steps
```

### Key Functions

#### Configuration Loading

1. **`load_local_env()`**: Sources `.env` file and maps variables to internal format
2. **`validate_and_set_env()`**: Validates configuration and sets final variables

#### Installation Functions

- **`install_packages()`**: Installs RANCID and dependencies via dnf
- **`create_user_group()`**: Creates rancid user and group
- **`create_base_dirs()`**: Sets up directory structure
- **`write_rancid_conf()`**: Writes main RANCID configuration
- **`create_groups_layout()`**: Creates directories for each group and copies router.db from template
- **`setup_cloginrc_placeholder()`**: Copies credentials file from example-cloginrc template
- **`setup_ssh_key()`**: Generates SSH keypair for device access
- **`init_git_repos()`**: Initializes Git repositories per group
- **`install_cron()`**: Sets up automated collection schedule

#### Safety Features

- **`safe_mkdir()`**: Creates directories with proper permissions (supports dry-run)
- **`safe_create_file()`**: Creates files with backup on overwrite (supports dry-run)
- **`ensure_permissions()`**: Corrects ownership/permissions if incorrect (idempotent, supports dry-run)
- **`check_dependencies()`**: Validates required commands exist
- **`post_checks()`**: Verifies installation success

### File Preservation Logic

The script implements intelligent file preservation:

| File Type | Default Behavior | With `--force` |
|-----------|-----------------|----------------|
| `/etc/rancid/rancid.conf` | Preserve if exists | Backup and overwrite |
| `/etc/cron.d/rancid` | Preserve if exists | Backup and overwrite |
| `/var/lib/rancid/.cloginrc` | Preserve if exists | Never overwrite (per requirements) |
| `router.db` files | Preserve if exists | Never overwrite (per requirements) |
| SSH keys | Preserve if exists | Preserve (never overwrite) |
| Git repositories | Preserve if exists | Preserve (never overwrite) |

**Backup naming**: `filename.bak.YYYYMMDDHHMMSS`

---

## 🔒 Security Notes

### File Permissions

The script sets appropriate permissions for security:

| File/Directory | Permissions | Owner | Purpose |
|---------------|-------------|-------|---------|
| `/etc/rancid/rancid.conf` | 644 | root:root | Main configuration |
| `/etc/cron.d/rancid` | 644 | root:root | Cron job configuration |
| `/var/lib/rancid/.cloginrc` | 600 | rancid:rancid | Credentials (must remain 600) |
| `/var/lib/rancid/.ssh/id_rancid` | 600 | rancid:rancid | SSH private key |
| `/var/lib/rancid/.ssh/id_rancid.pub` | 644 | rancid:rancid | SSH public key |
| `/var/lib/rancid/` | 750 | rancid:rancid | Base directory |
| `/var/lib/rancid/<group>/` | 750 | rancid:rancid | Group directories |
| `/var/lib/rancid/<group>/router.db` | 640 | rancid:rancid | Device inventory |
| `/var/lib/rancid/<group>/configs/` | 750 | rancid:rancid | Configuration storage |
| `/var/lib/rancid/<group>/logs/` | 750 | rancid:rancid | Log files |
| `/var/lib/rancid/<group>/status/` | 750 | rancid:rancid | Status files |

### Credential Management

⚠️ **Important Security Considerations**:

1. **`.cloginrc` file**:
   - Contains device credentials
   - **MUST** remain mode 600
   - Should use read-only credentials where possible
   - Never commit to version control

2. **SSH Keys**:
   - Private key is mode 600 (rancid user only)
   - Public key should be distributed to devices
   - Keys are never overwritten by the script

3. **Environment Files**:
   - `.env` file should not be committed (in `.gitignore`)
   - `.env` file contains configuration but no credentials

### Best Practices

- ✅ Use read-only credentials for device access
- ✅ Restrict `.cloginrc` file permissions (600)
- ✅ Regularly rotate SSH keys
- ✅ Monitor RANCID logs for unauthorized access attempts
- ✅ Keep RANCID packages updated
- ✅ Review cron job permissions regularly

---

## 🗑️ Uninstallation

### Manual Uninstallation Steps

To remove RANCID deployment:

1. **Stop cron job**:
   ```bash
   rm /etc/cron.d/rancid
   ```

2. **Remove configuration files**:
   ```bash
   rm -rf /etc/rancid/
   ```

3. **Remove RANCID data** (⚠️ **WARNING**: This deletes all collected configs):
   ```bash
   rm -rf /var/lib/rancid/
   ```

4. **Remove RANCID user and group**:
   ```bash
   userdel rancid
   groupdel rancid
   ```

5. **Uninstall packages** (optional):
   ```bash
   dnf remove rancid perl-Expect perl-TermReadKey net-snmp-utils
   ```

### Backup Before Uninstallation

Before removing RANCID, consider backing up:

- Configuration files: `/etc/rancid/`
- Collected configurations: `/var/lib/rancid/<group>/configs/`
- Device inventory: `/var/lib/rancid/<group>/router.db`
- Credentials: `/var/lib/rancid/.cloginrc` (if you have backups elsewhere)

---

## 🐛 Troubleshooting

### Common Issues

#### Issue: "This script must be run as root"

**Solution**: Run with sudo:
```bash
sudo ./deploy-rancid.sh
```

#### Issue: "Missing required commands"

**Solution**: Ensure you're on RHEL 10 with dnf available:
```bash
which dnf
# If missing, you may not be on RHEL 10
```

#### Issue: "Failed to install EPEL repository"

**Solution**: Check network connectivity and repository access:
```bash
ping 8.8.8.8
dnf repolist
```

#### Issue: "GIT_NAME is not set (check .env file or defaults)"

**Solution**: Ensure `.env` file has GIT_NAME set, or the script will use defaults:
```bash
# Check .env file
cat .env | grep GIT_NAME

# If missing, add to .env file:
echo 'GIT_NAME="RANCID Automation"' >> .env
echo 'GIT_EMAIL="rancid@example.com"' >> .env

# Re-run script
sudo ./deploy-rancid.sh
```

#### Issue: "File exists: ... (skipping, use --force to overwrite)"

**Solution**: This is expected behavior. Use `--force` if you want to overwrite:
```bash
sudo ./deploy-rancid.sh --force
```

#### Issue: RANCID collection fails

**Solution**: Check common causes:

1. **Credentials not configured**:
   ```bash
   cat /var/lib/rancid/.cloginrc
   # Ensure credentials are populated
   ```

2. **Devices not in router.db**:
   ```bash
   cat /var/lib/rancid/<group>/router.db
   # Ensure devices are listed
   ```

3. **SSH key not distributed**:
   ```bash
   cat /var/lib/rancid/.ssh/id_rancid.pub
   # Distribute to devices
   ```

4. **Check logs**:
   ```bash
   ls -ltr /var/lib/rancid/*/logs/
   tail -f /var/lib/rancid/logs/rancid.log
   ```

### Debugging Tips

1. **Enable verbose output**: The script logs all operations with `[rancid-setup]` prefix

2. **Check file permissions**:
   ```bash
   ls -la /var/lib/rancid/
   ls -la /etc/rancid/
   ```

3. **Verify Git repositories**:
   ```bash
   sudo -u rancid git -C /var/lib/rancid/<group> status
   ```

4. **Test manual collection**:
   ```bash
   sudo -u rancid rancid-run
   ```

5. **Review cron logs**:
   ```bash
   journalctl -u crond | grep rancid
   ```

### Getting Help

If issues persist:

1. Review the script logs (all output is prefixed with `[rancid-setup]`)
2. Check RANCID documentation: `man rancid`
3. Review RANCID logs in `/var/lib/rancid/*/logs/`
4. Verify configuration files are correct

---

## 📚 Additional Resources

### RANCID Documentation

- **Official RANCID Website**: http://www.shrubbery.net/rancid/
- **RANCID Manual**: `man rancid` (after installation)
- **RANCID Configuration Guide**: `/usr/share/doc/rancid/` (after installation)

### Related Files

- **Script**: `deploy-rancid.sh` - Main deployment script
- **Configuration Template**: `.env.example` - Example environment file
- **Configuration**: `.env` - Your environment configuration (not in git)
- **Main Config**: `/etc/rancid/rancid.conf` - RANCID main configuration
- **Template Files**:
  - `example-router.db` - Template for device inventory files
  - `example-cloginrc` - Template for credentials file

### Project Documentation

- **Context Standards**: `docs/ai/CONTEXT.md` - Development standards
- **Requirements**: `docs/requirements.md` - Project requirements
- **Security Review**: `docs/security-ci-review.md` - Security guidelines

---

## 📄 License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

---

**Last Updated**: 2025-01-02

