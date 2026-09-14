#!/usr/bin/env bash
# Question governance tag validation
# Usage: bash validate-questions.sh <feature-dir>

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

echo "=== Question Governance Tag Validation ==="

if [[ ! -f "$QFILE" ]]; then
  error "requirement-verification-questions.md missing"
  exit 1
fi

echo "Target: $QFILE"
echo ""

# --- 1. Request Anchor 존재 ---
echo "--- 1. Request Anchor ---"
if grep -q 'Request Anchor' "$QFILE" 2>/dev/null; then
  pass "Request Anchor present"
else
  error "Request Anchor missing (violates question-governance.md rules)"
fi

# --- 2. Summary table ---
echo ""
echo "--- 2. Summary table ---"
if grep -q '## Summary' "$QFILE" 2>/dev/null; then
  pass "Summary section present"
else
  error "Summary section missing"
fi

# --- 3. Required fields per question ---
echo ""
echo "--- 3. Required fields per question ---"

question_ids=$(grep -oE 'Q[0-9]+\.' "$QFILE" 2>/dev/null | sort -u)
question_count=$(echo "$question_ids" | grep -c 'Q' || true)
echo "Questions found: ${question_count}"

# Required fields: type, impact, if-unanswered
for qid in $question_ids; do
  qnum="${qid%.}"

  # Extract the question block (from its header up to the next ### Q / ## header).
  # Note: in a sed address range '\|' is a literal, not alternation, so the end
  # pattern never matches and the block runs to EOF. Handle explicitly with awk.
  block=$(awk -v hdr="### ${qid}" '
    index($0, hdr) == 1 {grab=1; print; next}
    grab && (/^### Q[0-9]/ || /^## /) {exit}
    grab {print}
  ' "$QFILE" | head -30)

  # 분류 (유형) 필드 — labels are bilingual (KR: 분류/유형, EN: Type/Category)
  if echo "$block" | grep -qi '분류:\|유형:\|Type:\|Category:' 2>/dev/null; then
    type_val=$(echo "$block" | grep -oiE '(분류|유형|Type|Category): *(policy|domain|scope)' | head -1)
    if [[ -n "$type_val" ]]; then
      pass "$qnum: 분류 필드 있음 ($type_val)"
    else
      warn "$qnum: 분류 값이 policy/domain/scope 중 하나가 아님"
    fi
  else
    error "$qnum: 분류(유형) 필드 누락"
  fi

  # 영향도 필드 (KR: 영향도, EN: Impact)
  if echo "$block" | grep -qi '영향도:\|Impact:' 2>/dev/null; then
    pass "$qnum: 영향도 필드 있음"
  else
    warn "$qnum: 영향도 필드 누락"
  fi

  # 미응답 시 필드 (KR: 미응답 시, EN: If unanswered)
  if echo "$block" | grep -qi '미응답 시:\|If unanswered:' 2>/dev/null; then
    fallback=$(echo "$block" | grep -oiE '(미응답 시|If unanswered): *(BLOCK|ASSUME|AI-RECOMMEND|DEFER)' | head -1)
    pass "$qnum: 미응답 시 필드 있음 ($fallback)"
  else
    error "$qnum: 미응답 시 필드 누락"
  fi

  # 범위(Scope Tag) 필드 (KR: 범위, EN: Scope)
  if echo "$block" | grep -qi '범위:\|Scope:' 2>/dev/null; then
    pass "$qnum: 범위 필드 있음"
  else
    warn "$qnum: 범위(Scope Tag) 필드 누락"
  fi

  # 우선순위 필드 (KR: 우선순위, EN: Priority)
  if echo "$block" | grep -qi '우선순위:\|Priority:' 2>/dev/null; then
    priority_val=$(echo "$block" | grep -oiE '(우선순위|Priority): *P[0-2]' | head -1)
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

# policy 질문 식별 → 해당 블록에 AI 추천이 있으면 위반.
# 거버넌스 정본(question-governance.md): policy/domain/scope 분류는 '유형:' 필드가 담는다
# ('분류:'는 ops/scope 등 영역 태그라 policy 판정에 쓰면 false negative).
# 각 질문 블록을 추출해 블록 내부에서 'policy' 유형 여부를 판정한다.
policy_found=0
for qid in $question_ids; do
  qnum="${qid%.}"
  block=$(awk -v hdr="### ${qid}" '
    index($0, hdr) == 1 {grab=1; print; next}
    grab && (/^### Q[0-9]/ || /^## /) {exit}
    grab {print}
  ' "$QFILE" | head -30)

  # 'policy' 유형 질문만 대상 (KR 유형/분류, EN Type/Category — 값이 policy인 경우)
  if echo "$block" | grep -qiE '(유형|분류|Type|Category): *policy' 2>/dev/null; then
    policy_found=$((policy_found + 1))
    if echo "$block" | grep -qi 'AI 추천:\|AI-RECOMMEND' 2>/dev/null; then
      error "$qnum: policy 질문에 AI 추천이 포함됨 (governance 위반)"
    else
      pass "$qnum: policy 질문 — AI 추천 없음"
    fi
  fi
done
if (( policy_found == 0 )); then
  echo "policy 유형 질문 없음 (검사 대상 0건)"
fi

# --- 5. BLOCK 질문 현황 ---
echo ""
echo "--- 5. BLOCK 질문 현황 ---"
block_open=$(grep -ci 'BLOCK' "$QFILE" 2>/dev/null || true)
# Answer label is bilingual (KR: [답변], EN: [Answer])
answered=$(grep -cE '\[(답변|Answer)\]:.+' "$QFILE" 2>/dev/null || true)
unanswered=$(grep -cE '\[(답변|Answer)\]: *$' "$QFILE" 2>/dev/null || true)

echo "BLOCK 언급: ${block_open}회"
echo "답변 완료: ${answered}건"
echo "미답변: ${unanswered}건"

if (( unanswered > 0 )); then
  warn "미답변 질문 ${unanswered}건 존재 — GATE-2 통과 조건 확인 필요"
fi

# --- 6. 확신도 태그 통계 ---
echo ""
echo "--- 6. 확신도 태그 통계 ---"
# Confidence tag is bilingual (KR: [확신: 확실/추정/AI추천/미정], EN: [Confidence: certain/estimated/ai-recommended/undecided])
certain=$(grep -ciE '\[(확신: 확실|Confidence: certain)\]' "$QFILE" 2>/dev/null || true)
estimated=$(grep -ciE '\[(확신: 추정|Confidence: estimated)\]' "$QFILE" 2>/dev/null || true)
ai_rec=$(grep -ciE '\[(확신: AI추천|Confidence: ai-recommended)\]' "$QFILE" 2>/dev/null || true)
deferred=$(grep -ciE '\[(확신: 미정|Confidence: undecided)\]' "$QFILE" 2>/dev/null || true)

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
