# Requirements

## Purpose

 - This document defines the authoritative requirements for a deployment script (deploy-rancid.sh)
 - The script should install and configures RANCID in a safe, idempotent, production-ready manner
 - The script must not overwrite existing files
 - The script must enforce correct ownership and permissions
 - The script must align with a usage-based RANCID group model.

## Assumptions & Scope

 - Target OS: RHEL-family Linux (RHEL 9/10 compatible)
 - Rancid will be installed and configured by the install script
 - A Rancid user (service account) will be created as part of the deploy
 - The rancid user does not need a login password
 - The rancid user does not need a login shell
 - The rancid user does not need ssh access to the target host
 - The userid will be rancid
 - The group will be rancid
 - The deploy/install script is run with sufficient privileges (root or sudo)
 - The script is idempotent and safe to re-run multiple times
 - The script must not destroy or overwrite existing configuration or data
 - The install/deployment script should be well commented and have clear print statements advising user of its actions and logic

## RANCID Groups

 - Rancid groups are usage-based, not vendor-based
 - Rancid groups will be sourced from the .env file in the top level of the repo
 - The script must iterate over every group in RANCID_GROUPS (from .env file)
 - The variable name in .env file is: RANCID_GROUPS=

## Required Directory Structure (Per Group)

 - For each RANCID group listed in RANCID_GROUPS, the script must explicitly create the following directory structure if it does not already exist:

```bash
/var/lib/rancid/<RANCID_GROUP>/
├── router.db
├── configs/
├── logs/
└── status/

```

 - Example path is /var/lib/rancid/<RANCID_GROUP>/
 - Subdirectories are below
   - /var/lib/rancid/<RANCID_GROUP>/configs
   - /var/lib/rancid/<RANCID_GROUP>/logs
   - /var/lib/rancid/<RANCID_GROUP>/status
 - Permissions on the above directories should be 750 and owned by rancid:rancid
 - RANCID does not create these directories automatically
 - The deployment script is responsible for creating them
 - Existing directories and files must be preserved

## Ownership Requirements (Mandatory)

 - All operational RANCID files and directories must be owned by the rancid user and group.
 - Owner: rancid and Group: rancid
 - The group/owner applies to: Group directories and all subdirectories
 - Subdirectories are  (configs/, logs/, status/)

## Router.db
 - a router.db file should be created by the installer/deployment script in each RANCID_GROUP directory tree
 - the router.db file defines the device inventory for that group
 - the router.db file should never contain credentials
 - example location is /var/lib/rancid/<RANCID_GROUP>/router.db
 - the install/deployment script generated router.db should be copied from the template - example-router.db
 - router.db permissions should be 640 and owned by rancid:rancid

## .cloginrc

 - Location /var/lib/rancid/.cloginrc
 - Created from template file example-cloginrc
 - It's purpose is global authentication and login behavior for all RANCID groups
 - single source of truth for credentials
 - Not group-specific
 - Permissions (Strict) Mode: 600, Owner: rancid Group: rancid
 - Reference Commands
  - chmod 600 /var/lib/rancid/.cloginrc
  - chown rancid:rancid /var/lib/rancid/.cloginrc

## Creation Rules for .cloginrc
 - If .cloginrc does not exist:
 - Create it using example-cloginrc
 - If it already exists do not overwrite and do not modify contents

##  Idempotency Requirements (Critical)

 - The deployment script must be idempotent.
 - Explicitly Required Behavior must not overwrite existing router.db 
 - Explicitly Required Behavior must not overwrite existing .cloginrc
 - Explicitly Required Behavior must not overwrite existing group directories
 - Must be safe to re-run multiple times
 - Must only: Create missing directories and Create missing files
 - Correct ownership and permissions if incorrect


## Explicitly Forbidden Behavior
 
 - No destructive operations (rm, forced overwrite, truncation)
 - No credential regeneration
 - No modification of existing inventories
 - No assumptions about empty directories

## Naming & File References

 - The deployment script is expected to reference: example-router.db as a template when creating new router.db files
 - The deployment script is expected to reference: example-cloginrc  Used only as a template when creating .cloginrc
 - The deployment script must copy, not inline, these examples when creating files.

##  Non-Goals (policy violations)
 - The deployment script must not: Populate real credentials or Populate device inventories
 - Modify rancid.conf beyond required group awareness


##  Design Intent (For the AI Agent)

 - RANCID is explicit by design
 - If something exists, it is intentional
 - The deployment script must respect that
 - The script should favor safety over convenience and explicit creation over assumptions
 - Clear logging over silent behavior
 - Each acceptance criterion must be testable

## Git Requirements

- The installer script should create local Git repositories per group for revision history
- Use Git only locally - never push backups/configs to public repos
- The installer/deployment script MUST NOT:
  - Configure Git remotes
  - Run git remote add, git remote set-url, etc.
  - Push rancid configs/backups (git push)
  - Pull/fetch rancid configs/backups from any remote (git pull, git fetch)
  - Include any remote URL in any config file

## .gitignore
 - git must ignore any .env files (other than example)
 - git must ignore any router.db files (other than example)

## Failure Modes

 - Missing dependency:
 - Permission denied:
 - Network failure:
 - Partial execution:
 - Re-run behavior:

## Test Plan

### Automated

 - Unit tests:
 - Integration tests:

### Manual

 - Step-by-step validation procedure
