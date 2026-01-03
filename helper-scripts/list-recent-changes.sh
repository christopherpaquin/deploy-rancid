#!/usr/bin/env bash
#
# list-recent-changes.sh - Show recent changes across all devices in a group
#
# Usage: ./list-recent-changes.sh <group-name> [--count N] [--device DEVICE]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMMIT_COUNT=10
DEVICE_FILTER=""

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo "Usage: $0 <group-name> [--count N] [--device DEVICE]"
  exit 1
fi

GROUP_NAME="$1"
shift

while [[ $# -gt 0 ]]; do
  case $1 in
    --count)
      COMMIT_COUNT="$2"
      shift 2
      ;;
    --device)
      DEVICE_FILTER="$2"
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

if [[ ! -d "$GROUP_DIR" ]]; then
  echo -e "${RED}Error: Group directory not found: ${GROUP_DIR}${NC}"
  exit 1
fi

cd "$GROUP_DIR" || exit 1
if ! sudo -u rancid git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${RED}Error: Not a git repository: ${GROUP_DIR}${NC}"
  exit 2
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Group: ${GREEN}${GROUP_NAME}${NC}"
if [[ -n "$DEVICE_FILTER" ]]; then
  echo -e "${BLUE}Filter: ${GREEN}${DEVICE_FILTER}${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [[ -n "$DEVICE_FILTER" ]]; then
  sudo -u rancid git log --oneline --decorate -n "$COMMIT_COUNT" -- "configs/${DEVICE_FILTER}"
else
  sudo -u rancid git log --oneline --decorate -n "$COMMIT_COUNT" -- configs/
fi

echo ""
echo -e "${YELLOW}Summary by device:${NC}"
echo ""

if [[ -n "$DEVICE_FILTER" ]]; then
  sudo -u rancid git log --format="%h %s" -n "$COMMIT_COUNT" -- "configs/${DEVICE_FILTER}" |
    awk '{print "  " $0}'
else
  sudo -u rancid git log --format="%h %s" -n "$COMMIT_COUNT" -- configs/ |
    awk '{print "  " $0}'
fi
