#!/usr/bin/env bash
# Readiness Score 검증
# 사용법: bash validate-readiness-score.sh <feature-dir>
# status.md의 Readiness Score 테이블을 검증한다.

set -uo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

FEATURE_DIR="${1:?Usage: validate-readiness-score.sh <feature-dir>}"
STATUS_FILE="$FEATURE_DIR/status.md"
QFILE="$FEATURE_DIR/requirement-verification-questions.md"
ERRORS=0
WARNINGS=0

error() { echo -e "${RED}[ERROR]${NC} $1"; ((ERRORS++)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)); }
pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }

echo "=== Readiness Score 검증 ==="

if [[ ! -f "$STATUS_FILE" ]]; then
  error "status.md 파일 없음"
  exit 1
fi

echo "대상: $STATUS_FILE"
echo ""

# --- 1. Readiness Score 섹션 존재 ---
echo "--- 1. Readiness Score 테이블 ---"
if grep -q '## Readiness Score' "$STATUS_FILE" 2>/dev/null; then
  pass "Readiness Score 섹션 존재"
else
  error "Readiness Score 섹션 누락"
  exit 1
fi

# --- 2. 합계 행 존재 및 점수 추출 ---
echo ""
echo "--- 2. 합계 점수 ---"
total_line=$(grep -i '합계\|total' "$STATUS_FILE" 2>/dev/null | head -1)
if [[ -n "$total_line" ]]; then
  # 테이블 행에서 숫자 추출: | 합계 | 배점 | 점수 | 판정 |
  # bold(**) 제거 후 파이프 구분으로 파싱
  clean_line=$(echo "$total_line" | sed 's/\*\*//g')
  total_max=$(echo "$clean_line" | awk -F'|' '{gsub(/[^0-9]/,"",$3); print $3}')
  total_score=$(echo "$clean_line" | awk -F'|' '{gsub(/[^0-9]/,"",$4); print $4}')

  if [[ -n "$total_score" && -n "$total_max" ]]; then
    pass "합계: ${total_score}/${total_max}"

    # 판정 일관성 확인 (bold 제거 후 추출)
    verdict=$(echo "$clean_line" | grep -oE 'READY|CONDITIONAL|NOT_READY' | head -1)

    if [[ -n "$total_max" && "$total_max" -gt 0 ]]; then
      threshold_ready=$(( total_max * 80 / 100 ))
      threshold_conditional=$(( total_max * 60 / 100 ))

      if [[ "$total_score" -ge "$threshold_ready" ]]; then
        expected="READY"
      elif [[ "$total_score" -ge "$threshold_conditional" ]]; then
        expected="CONDITIONAL"
      else
        expected="NOT_READY"
      fi

      if [[ -n "$verdict" ]]; then
        if [[ "$verdict" == "$expected" ]]; then
          pass "판정 일관성: $verdict (점수 ${total_score}/${total_max}, 기대값 $expected)"
        else
          error "판정 불일치: 표기=$verdict, 점수 기준 기대값=$expected (${total_score}/${total_max})"
        fi
      else
        warn "판정(READY/CONDITIONAL/NOT_READY) 표기가 합계 행에 없음"
      fi
    fi
  else
    warn "합계 행에서 점수를 추출할 수 없음"
  fi
else
  error "합계(Total) 행 누락"
fi

# --- 3. BLOCK 질문과 판정 교차 검증 ---
echo ""
echo "--- 3. BLOCK 질문 교차 검증 ---"

if [[ -f "$QFILE" ]]; then
  # OPEN 상태인 BLOCK 질문 수 (Summary 테이블에서)
  block_open=$(grep -ci 'OPEN.*BLOCK\|BLOCK.*OPEN' "$QFILE" 2>/dev/null || echo "0")

  if (( block_open > 0 )); then
    echo "OPEN BLOCK 질문: ${block_open}건"

    # status.md에서 BLOCK 수 확인 (e.g. "BLOCK Questions: 2")
    status_block=$(grep -i 'BLOCK Questions' "$STATUS_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "")
    if [[ -n "$status_block" ]]; then
      if [[ "$status_block" -ne "$block_open" ]]; then
        warn "BLOCK 수 불일치: status.md=${status_block}, questions.md=${block_open}"
      else
        pass "BLOCK 수 일치: ${block_open}건"
      fi
    fi

    # READY 판정인데 BLOCK이 있으면 오류
    if [[ -n "${verdict:-}" && "$verdict" == "READY" ]]; then
      error "READY 판정이지만 OPEN BLOCK 질문 ${block_open}건 존재"
    fi
  else
    pass "OPEN BLOCK 질문 없음"
  fi
else
  warn "requirement-verification-questions.md 없어 BLOCK 교차 검증 생략"
fi

# --- 4. 배점 합산 검증 ---
echo ""
echo "--- 4. 배점 합산 ---"

# Readiness Score 테이블에서 배점 열의 숫자 합산
score_section=$(sed -n '/## Readiness Score/,/^## /p' "$STATUS_FILE")
point_values=$(echo "$score_section" | grep -E '^\|' | grep -v '합계\|total\|영역\|--' | grep -oE '\| *[0-9]+ *\|' | head -20)

if [[ -n "$point_values" ]]; then
  # 개별 행의 배점(3번째 열) 추출 — bold(**) 제거 후 파싱
  row_maxes=$(echo "$score_section" | sed 's/\*\*//g' | grep -E '^\|' | grep -v '합계\|total\|영역\|--' | awk -F'|' '{gsub(/[^0-9]/,"",$3); if($3!="") print $3}')

  calc_total=0
  for val in $row_maxes; do
    if [[ "$val" =~ ^[0-9]+$ ]]; then
      calc_total=$((calc_total + val))
    fi
  done

  if [[ -n "${total_max:-}" && "$calc_total" -gt 0 ]]; then
    if [[ "$calc_total" -eq "$total_max" ]]; then
      pass "배점 합산 일치: ${calc_total}"
    else
      warn "배점 합산 불일치: 개별 합=${calc_total}, 합계 행=${total_max}"
    fi
  fi
fi

# --- 5. UNCERTAIN 마커 교차 검증 ---
echo ""
echo "--- 5. UNCERTAIN 마커 ---"

uncertain_count=0
for file in "$FEATURE_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  count=$(grep -c '⚠️ UNCERTAIN' "$file" 2>/dev/null || true)
  if (( count > 0 )); then
    uncertain_count=$((uncertain_count + count))
    fname=$(basename "$file")
    warn "$fname: ⚠️ UNCERTAIN 마커 ${count}건 — Readiness Score 상한 적용 대상"
  fi
done

if (( uncertain_count == 0 )); then
  pass "UNCERTAIN 마커 없음"
fi

# --- 결과 요약 ---
echo ""
echo "=== 결과 ==="
echo -e "오류: ${RED}${ERRORS}${NC}건, 경고: ${YELLOW}${WARNINGS}${NC}건"

if (( ERRORS > 0 )); then
  echo -e "${RED}FAIL${NC}"
  exit 1
elif (( WARNINGS > 0 )); then
  echo -e "${YELLOW}PASS (경고 있음)${NC}"
  exit 0
else
  echo -e "${GREEN}PASS${NC}"
  exit 0
fi
