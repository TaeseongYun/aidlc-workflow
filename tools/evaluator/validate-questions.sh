#!/usr/bin/env bash
# 질문 거버넌스 태그 검증
# 사용법: bash validate-questions.sh <feature-dir>

set -uo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

FEATURE_DIR="${1:?Usage: validate-questions.sh <feature-dir>}"
QFILE="$FEATURE_DIR/requirement-verification-questions.md"
ERRORS=0
WARNINGS=0

error() { echo -e "${RED}[ERROR]${NC} $1"; ((ERRORS++)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)); }
pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }

echo "=== 질문 거버넌스 태그 검증 ==="

if [[ ! -f "$QFILE" ]]; then
  error "requirement-verification-questions.md 파일 없음"
  exit 1
fi

echo "대상: $QFILE"
echo ""

# --- 1. Request Anchor 존재 ---
echo "--- 1. Request Anchor ---"
if grep -q 'Request Anchor' "$QFILE" 2>/dev/null; then
  pass "Request Anchor 존재"
else
  error "Request Anchor 누락 (question-governance.md 규칙 위반)"
fi

# --- 2. Summary 테이블 존재 ---
echo ""
echo "--- 2. Summary 테이블 ---"
if grep -q '## Summary' "$QFILE" 2>/dev/null; then
  pass "Summary 섹션 존재"
else
  error "Summary 섹션 누락"
fi

# --- 3. 각 질문의 필수 필드 검증 ---
echo ""
echo "--- 3. 질문별 필수 필드 ---"

question_ids=$(grep -oE 'Q[0-9]+\.' "$QFILE" 2>/dev/null | sort -u)
question_count=$(echo "$question_ids" | grep -c 'Q' || true)
echo "발견된 질문: ${question_count}개"

# 필수 필드: 분류, 영향도, 미응답 시
for qid in $question_ids; do
  qnum="${qid%.}"

  # 해당 질문 블록 추출 (다음 Q 또는 ## 까지)
  block=$(sed -n "/### ${qid}/,/^### Q\|^## /p" "$QFILE" | head -30)

  # 분류 (유형) 필드
  if echo "$block" | grep -qi '분류:\|유형:' 2>/dev/null; then
    type_val=$(echo "$block" | grep -oi '분류: *\(policy\|domain\|scope\)\|유형: *\(policy\|domain\|scope\)' | head -1)
    if [[ -n "$type_val" ]]; then
      pass "$qnum: 분류 필드 있음 ($type_val)"
    else
      warn "$qnum: 분류 값이 policy/domain/scope 중 하나가 아님"
    fi
  else
    error "$qnum: 분류(유형) 필드 누락"
  fi

  # 영향도 필드
  if echo "$block" | grep -qi '영향도:' 2>/dev/null; then
    pass "$qnum: 영향도 필드 있음"
  else
    warn "$qnum: 영향도 필드 누락"
  fi

  # 미응답 시 필드
  if echo "$block" | grep -qi '미응답 시:' 2>/dev/null; then
    fallback=$(echo "$block" | grep -oi '미응답 시: *\(BLOCK\|ASSUME\|AI-RECOMMEND\|DEFER\)' | head -1)
    pass "$qnum: 미응답 시 필드 있음 ($fallback)"
  else
    error "$qnum: 미응답 시 필드 누락"
  fi

  # 범위(Scope Tag) 필드
  if echo "$block" | grep -qi '범위:' 2>/dev/null; then
    pass "$qnum: 범위 필드 있음"
  else
    warn "$qnum: 범위(Scope Tag) 필드 누락"
  fi

  # 우선순위 필드
  if echo "$block" | grep -qi '우선순위:' 2>/dev/null; then
    priority_val=$(echo "$block" | grep -oi '우선순위: *P[0-2]' | head -1)
    if [[ -n "$priority_val" ]]; then
      pass "$qnum: 우선순위 필드 있음 ($priority_val)"
    else
      warn "$qnum: 우선순위 값이 P0/P1/P2 형식이 아님"
    fi
  else
    warn "$qnum: 우선순위 필드 누락"
  fi
done

# --- 4. policy 질문에 AI 추천이 없는지 ---
echo ""
echo "--- 4. policy 질문 AI 추천 금지 ---"

# policy 질문 블록에서 AI 추천 필드가 있으면 위반
policy_questions=$(grep -B1 '분류: *policy' "$QFILE" 2>/dev/null | grep -oE 'Q[0-9]+' || true)
for qnum in $policy_questions; do
  block=$(sed -n "/### ${qnum}\./,/^### Q\|^## /p" "$QFILE" | head -30)
  if echo "$block" | grep -qi 'AI 추천:\|AI-RECOMMEND' 2>/dev/null; then
    error "$qnum: policy 질문에 AI 추천이 포함됨 (governance 위반)"
  else
    pass "$qnum: policy 질문 — AI 추천 없음"
  fi
done

# --- 5. BLOCK 질문 현황 ---
echo ""
echo "--- 5. BLOCK 질문 현황 ---"
block_open=$(grep -ci 'BLOCK' "$QFILE" 2>/dev/null || true)
answered=$(grep -c '\[답변\]:.\+' "$QFILE" 2>/dev/null || true)
unanswered=$(grep -c '\[답변\]: *$' "$QFILE" 2>/dev/null || true)

echo "BLOCK 언급: ${block_open}회"
echo "답변 완료: ${answered}건"
echo "미답변: ${unanswered}건"

if (( unanswered > 0 )); then
  warn "미답변 질문 ${unanswered}건 존재 — GATE-2 통과 조건 확인 필요"
fi

# --- 6. 확신도 태그 통계 ---
echo ""
echo "--- 6. 확신도 태그 통계 ---"
certain=$(grep -c '\[확신: 확실\]' "$QFILE" 2>/dev/null || true)
estimated=$(grep -c '\[확신: 추정\]' "$QFILE" 2>/dev/null || true)
ai_rec=$(grep -c '\[확신: AI추천\]' "$QFILE" 2>/dev/null || true)
deferred=$(grep -c '\[확신: 미정\]' "$QFILE" 2>/dev/null || true)

echo "확실: ${certain}, 추정: ${estimated}, AI추천: ${ai_rec}, 미정: ${deferred}"

if (( deferred > 0 )); then
  warn "미정 답변 ${deferred}건 — Readiness Score 차감 대상"
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
