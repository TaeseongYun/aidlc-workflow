#!/usr/bin/env bash
# Full validation runner
# Usage: bash validate-all.sh <feature-dir>
# Runs every validation script in order and prints the combined result.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

FEATURE_DIR="${1:?Usage: validate-all.sh <feature-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} Team AI Workflow — Artifact Validation${NC}"
echo -e "${BOLD}======================================${NC}"
echo "Target: $FEATURE_DIR"
echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0

run_validator() {
  local name="$1"
  local script="$2"

  echo -e "${BOLD}>>> $name${NC}"
  echo ""

  if bash "$SCRIPT_DIR/$script" "$FEATURE_DIR"; then
    ((TOTAL_PASS++))
  else
    ((TOTAL_FAIL++))
  fi

  echo ""
  echo "---"
  echo ""
}

run_validator "1/3 Artifact completeness" "validate-artifacts.sh"
run_validator "2/3 Question governance" "validate-questions.sh"
run_validator "3/3 Readiness Score" "validate-readiness-score.sh"

# --- Combined result ---
echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} Combined Result${NC}"
echo -e "${BOLD}======================================${NC}"
echo -e "Passed: ${GREEN}${TOTAL_PASS}${NC}, Failed: ${RED}${TOTAL_FAIL}${NC}"

if (( TOTAL_FAIL > 0 )); then
  echo -e "${RED}FAIL${NC} — ${TOTAL_FAIL} validation(s) reported errors."
  exit 1
else
  echo -e "${GREEN}ALL PASS${NC}"
  exit 0
fi
