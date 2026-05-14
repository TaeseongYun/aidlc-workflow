#!/usr/bin/env bash
# 산출물 완성도 검증
# 사용법: bash validate-artifacts.sh <feature-dir>
# 예: bash validate-artifacts.sh ./aidlc-docs/features/repurchase-coupon

set -uo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

FEATURE_DIR="${1:?Usage: validate-artifacts.sh <feature-dir>}"
ERRORS=0
WARNINGS=0

error() { echo -e "${RED}[ERROR]${NC} $1"; ((ERRORS++)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)); }
pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }

echo "=== 산출물 완성도 검증 ==="
echo "대상: $FEATURE_DIR"
echo ""

# --- 1. 필수 파일 존재 확인 ---
echo "--- 1. 필수 파일 존재 확인 ---"
REQUIRED_FILES=(
  "status.md"
  "requirements.md"
  "requirement-verification-questions.md"
  "unit-of-work.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$FEATURE_DIR/$file" ]]; then
    pass "$file 존재"
  else
    error "$file 누락"
  fi
done

# --- 2. 필수 섹션 확인 ---
echo ""
echo "--- 2. 필수 섹션 확인 ---"

check_sections() {
  local file="$1"
  shift
  local sections=("$@")

  if [[ ! -f "$FEATURE_DIR/$file" ]]; then
    return
  fi

  for section in "${sections[@]}"; do
    if grep -qi "^##.*${section}" "$FEATURE_DIR/$file" 2>/dev/null; then
      pass "$file: '$section' 섹션 존재"
    else
      error "$file: '$section' 섹션 누락"
    fi
  done
}

check_sections "requirements.md" "Goal" "In-Scope" "Out-of-Scope" "Functional Requirements"
check_sections "status.md" "Readiness Score" "Scope" "Approval"
check_sections "unit-of-work.md" "Summary"
check_sections "requirement-verification-questions.md" "Summary"

# --- 3. 빈 섹션 감지 ---
echo ""
echo "--- 3. 빈 섹션 감지 ---"

check_empty_sections() {
  local file="$1"
  if [[ ! -f "$FEATURE_DIR/$file" ]]; then
    return
  fi

  local prev_heading=""
  local prev_line=0
  local current_line=0

  while IFS= read -r line; do
    ((current_line++))
    if [[ "$line" =~ ^##+ ]]; then
      if [[ -n "$prev_heading" ]] && (( current_line - prev_line <= 1 )); then
        warn "$file: '$prev_heading' 섹션이 비어 있음 (${prev_line}줄)"
      fi
      prev_heading="$line"
      prev_line=$current_line
    fi
  done < "$FEATURE_DIR/$file"
}

for file in "requirements.md" "status.md" "unit-of-work.md"; do
  check_empty_sections "$file"
done

# --- 4. 참조 무결성 (UOW ID) ---
echo ""
echo "--- 4. 참조 무결성 ---"

if [[ -f "$FEATURE_DIR/unit-of-work.md" ]]; then
  uow_ids=$(grep -oE 'UOW-[0-9]+' "$FEATURE_DIR/unit-of-work.md" | sort -u)
  uow_count=$(echo "$uow_ids" | wc -l | tr -d ' ')
  pass "unit-of-work.md: UOW ID ${uow_count}개 발견"

  # Summary 테이블의 UOW와 본문 헤딩의 UOW 비교
  summary_ids=$(grep -E '^\|.*UOW-[0-9]+' "$FEATURE_DIR/unit-of-work.md" 2>/dev/null | grep -oE 'UOW-[0-9]+' | sort -u)
  heading_ids=$(grep -E '^## UOW-[0-9]+' "$FEATURE_DIR/unit-of-work.md" 2>/dev/null | grep -oE 'UOW-[0-9]+' | sort -u)

  if [[ -n "$summary_ids" && -n "$heading_ids" ]]; then
    missing_headings=$(comm -23 <(echo "$summary_ids") <(echo "$heading_ids"))
    if [[ -n "$missing_headings" ]]; then
      error "unit-of-work.md: Summary에 있지만 본문 헤딩이 없는 UOW: $missing_headings"
    else
      pass "unit-of-work.md: Summary와 본문 UOW ID 일치"
    fi
  fi
fi

# --- 5. feature-slug 일관성 ---
echo ""
echo "--- 5. feature-slug 일관성 ---"

if [[ -f "$FEATURE_DIR/status.md" ]]; then
  slug_in_status=$(grep -i "Feature Slug:" "$FEATURE_DIR/status.md" 2>/dev/null | head -1 | sed 's/.*: *//')
  dir_name=$(basename "$FEATURE_DIR")
  if [[ -n "$slug_in_status" && "$slug_in_status" != "$dir_name" ]]; then
    warn "feature-slug 불일치: status.md='$slug_in_status' vs 디렉토리='$dir_name'"
  elif [[ -n "$slug_in_status" ]]; then
    pass "feature-slug 일치: $slug_in_status"
  fi
fi

# --- 6. 다이어그램 기본 검증 ---
echo ""
echo "--- 6. 다이어그램 검증 ---"

for file in "$FEATURE_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  fname=$(basename "$file")

  # Mermaid 블록이 있는데 텍스트 대안이 없는 경우
  if grep -q '```mermaid' "$file" 2>/dev/null; then
    if ! grep -qi '텍스트 대안\|text alternative\|fallback' "$file" 2>/dev/null; then
      warn "$fname: Mermaid 다이어그램에 텍스트 대안이 없음"
    else
      pass "$fname: Mermaid 텍스트 대안 존재"
    fi
  fi

  # 유니코드 박스 문자 사용 감지
  if grep -P '[┌─│└┐┘├┤┬┴┼]' "$file" 2>/dev/null; then
    error "$fname: 유니코드 박스 문자 사용 감지 (ASCII만 허용)"
  fi
done

# --- 결과 요약 ---
echo ""
echo "=== 결과 ==="
echo -e "오류: ${RED}${ERRORS}${NC}건, 경고: ${YELLOW}${WARNINGS}${NC}건"

if (( ERRORS > 0 )); then
  echo -e "${RED}FAIL${NC} — 오류를 해결해야 합니다."
  exit 1
elif (( WARNINGS > 0 )); then
  echo -e "${YELLOW}PASS (경고 있음)${NC}"
  exit 0
else
  echo -e "${GREEN}PASS${NC}"
  exit 0
fi
