#!/usr/bin/env bash
#
# compare-device-versions.sh - Compare two specific git commits for a device
#
# Usage: ./compare-device-versions.sh <group-name> <device-name> <commit1> <commit2>
#   Or:   ./compare-device-versions.sh <group-name> <device-name> <commit1>  (compare to HEAD)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ $# -lt 3 ]]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo "Usage: $0 <group-name> <device-name> <commit1> [commit2]"
  echo ""
  echo "Examples:"
  echo "  $0 core-switches switch-1 HEAD~1 HEAD"
  echo "  $0 core-switches switch-1 abc123 def456"
  echo "  $0 core-switches switch-1 HEAD~5  (compare HEAD~5 to HEAD)"
  exit 1
fi

GROUP_NAME="$1"
DEVICE_NAME="$2"
COMMIT1="$3"
COMMIT2="${4:-HEAD}"

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

# Validate commits exist
if ! sudo -u rancid git rev-parse --verify "$COMMIT1" > /dev/null 2>&1; then
  echo -e "${RED}Error: Invalid commit: ${COMMIT1}${NC}"
  exit 1
fi

if ! sudo -u rancid git rev-parse --verify "$COMMIT2" > /dev/null 2>&1; then
  echo -e "${RED}Error: Invalid commit: ${COMMIT2}${NC}"
  exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Device: ${GREEN}${DEVICE_NAME}${NC} | Group: ${GREEN}${GROUP_NAME}${NC}"
echo -e "${BLUE}Comparing: ${COMMIT1} vs ${COMMIT2}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

sudo -u rancid git log -1 --format="%C(yellow)${COMMIT1}:%Creset %s%n%an <%ae> - %ar" "$COMMIT1" -- "$RELATIVE_CONFIG" 2> /dev/null || true
echo ""
sudo -u rancid git log -1 --format="%C(yellow)${COMMIT2}:%Creset %s%n%an <%ae> - %ar" "$COMMIT2" -- "$RELATIVE_CONFIG" 2> /dev/null || true
echo ""
echo -e "${YELLOW}Diff:${NC}"
echo ""
sudo -u rancid git diff "$COMMIT1" "$COMMIT2" -- "$RELATIVE_CONFIG"
