#!/usr/bin/env bash
# 전체 검증 실행기
# 사용법: bash validate-all.sh <feature-dir>
# 모든 검증 스크립트를 순차 실행하고 종합 결과를 출력한다.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

FEATURE_DIR="${1:?Usage: validate-all.sh <feature-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} Team AI Workflow — 산출물 검증${NC}"
echo -e "${BOLD}======================================${NC}"
echo "대상: $FEATURE_DIR"
echo "시각: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
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

run_validator "1/3 산출물 완성도" "validate-artifacts.sh"
run_validator "2/3 질문 거버넌스" "validate-questions.sh"
run_validator "3/3 Readiness Score" "validate-readiness-score.sh"

# --- 종합 결과 ---
echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD} 종합 결과${NC}"
echo -e "${BOLD}======================================${NC}"
echo -e "통과: ${GREEN}${TOTAL_PASS}${NC}개, 실패: ${RED}${TOTAL_FAIL}${NC}개"

if (( TOTAL_FAIL > 0 )); then
  echo -e "${RED}FAIL${NC} — ${TOTAL_FAIL}개 검증에서 오류가 발생했습니다."
  exit 1
else
  echo -e "${GREEN}ALL PASS${NC}"
  exit 0
fi
