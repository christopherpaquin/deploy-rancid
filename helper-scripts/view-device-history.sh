#!/usr/bin/env bash
#
# view-device-history.sh - Show full git log/history for a device
#
# Usage: ./view-device-history.sh <group-name> <device-name> [--all]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SHOW_ALL=false

if [[ $# -lt 2 ]]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo "Usage: $0 <group-name> <device-name> [--all]"
  exit 1
fi

GROUP_NAME="$1"
DEVICE_NAME="$2"
shift 2

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      SHOW_ALL=true
      shift
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
  exit 1
fi

RELATIVE_CONFIG="configs/${DEVICE_NAME}"

COMMIT_COUNT=$(sudo -u rancid git rev-list --count HEAD -- "$RELATIVE_CONFIG" 2> /dev/null || echo "0")
if [[ "$COMMIT_COUNT" -eq 0 ]]; then
  echo -e "${YELLOW}Warning: No git history found for ${DEVICE_NAME}${NC}"
  exit 0
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Device: ${GREEN}${DEVICE_NAME}${NC} | Group: ${GREEN}${GROUP_NAME}${NC}"
echo -e "${BLUE}Total commits: ${COMMIT_COUNT}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [[ "$SHOW_ALL" == true ]]; then
  sudo -u rancid git log --pretty=format:"%C(yellow)%h%Creset - %s (%an, %ar)" -- "$RELATIVE_CONFIG"
else
  sudo -u rancid git log --pretty=format:"%C(yellow)%h%Creset - %s (%an, %ar)" -n 20 -- "$RELATIVE_CONFIG"
  if [[ "$COMMIT_COUNT" -gt 20 ]]; then
    echo ""
    echo -e "${YELLOW}... (showing last 20 of ${COMMIT_COUNT} commits, use --all to see all)${NC}"
  fi
fi
