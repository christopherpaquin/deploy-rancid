#!/usr/bin/env bash
#
# view-device-changes.sh - View recent git changes for a specific device
#
# Usage: ./view-device-changes.sh <group-name> <device-name> [--count N]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMMIT_COUNT=10

if [[ $# -lt 2 ]]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo "Usage: $0 <group-name> <device-name> [--count N]"
  exit 1
fi

GROUP_NAME="$1"
DEVICE_NAME="$2"
shift 2

while [[ $# -gt 0 ]]; do
  case $1 in
    --count)
      COMMIT_COUNT="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Error: Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

BASEDIR="${BASEDIR:-/var/lib/rancid}"
GROUP_DIR="${BASEDIR}/${GROUP_NAME}"
CONFIG_FILE="${GROUP_DIR}/configs/${DEVICE_NAME}"

if [[ ! -d "$GROUP_DIR" ]]; then
  echo -e "${RED}Error: Group directory not found: ${GROUP_DIR}${NC}"
  exit 1
fi

cd "$GROUP_DIR" || exit 1
if ! sudo -u rancid git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${RED}Error: Not a git repository: ${GROUP_DIR}${NC}"
  exit 2
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}Error: Device config not found: ${CONFIG_FILE}${NC}"
  echo "Available devices:"
  ls -1 "${GROUP_DIR}/configs/" 2> /dev/null || echo "  (none)"
  exit 1
fi

RELATIVE_CONFIG="configs/${DEVICE_NAME}"

if ! sudo -u rancid git log --oneline -- "$RELATIVE_CONFIG" > /dev/null 2>&1; then
  echo -e "${YELLOW}Warning: No git history found for ${DEVICE_NAME}${NC}"
  exit 0
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Device: ${GREEN}${DEVICE_NAME}${NC} | Group: ${GREEN}${GROUP_NAME}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Recent Changes (last ${COMMIT_COUNT} commits):${NC}"
echo ""
sudo -u rancid git log --oneline --decorate -n "$COMMIT_COUNT" -- "$RELATIVE_CONFIG"

echo ""
echo -e "${YELLOW}Detailed Changes:${NC}"
echo ""
sudo -u rancid git log -p -n "$COMMIT_COUNT" -- "$RELATIVE_CONFIG"
