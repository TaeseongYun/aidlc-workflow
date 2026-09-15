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

  # Type field — labels are bilingual (KR: 분류/유형, EN: Type/Category)
  if echo "$block" | grep -qi '분류:\|유형:\|Type:\|Category:' 2>/dev/null; then
    type_val=$(echo "$block" | grep -oiE '(분류|유형|Type|Category): *(policy|domain|scope)' | head -1)
    if [[ -n "$type_val" ]]; then
      pass "$qnum: type field present ($type_val)"
    else
      warn "$qnum: type value is not one of policy/domain/scope"
    fi
  else
    error "$qnum: type field missing"
  fi

  # Impact field (KR: 영향도, EN: Impact)
  if echo "$block" | grep -qi '영향도:\|Impact:' 2>/dev/null; then
    pass "$qnum: impact field present"
  else
    warn "$qnum: impact field missing"
  fi

  # If-unanswered field (KR: 미응답 시, EN: If unanswered)
  if echo "$block" | grep -qi '미응답 시:\|If unanswered:' 2>/dev/null; then
    fallback=$(echo "$block" | grep -oiE '(미응답 시|If unanswered): *(BLOCK|ASSUME|AI-RECOMMEND|DEFER)' | head -1)
    pass "$qnum: if-unanswered field present ($fallback)"
  else
    error "$qnum: if-unanswered field missing"
  fi

  # Scope Tag field (KR: 범위, EN: Scope)
  if echo "$block" | grep -qi '범위:\|Scope:' 2>/dev/null; then
    pass "$qnum: scope field present"
  else
    warn "$qnum: scope (Scope Tag) field missing"
  fi

  # Priority field (KR: 우선순위, EN: Priority)
  if echo "$block" | grep -qi '우선순위:\|Priority:' 2>/dev/null; then
    priority_val=$(echo "$block" | grep -oiE '(우선순위|Priority): *P[0-2]' | head -1)
    if [[ -n "$priority_val" ]]; then
      pass "$qnum: priority field present ($priority_val)"
    else
      warn "$qnum: priority value is not in P0/P1/P2 format"
    fi
  else
    warn "$qnum: priority field missing"
  fi
done

# --- 4. No AI recommendation on policy questions ---
echo ""
echo "--- 4. No AI recommendation on policy questions ---"

# Identify policy questions → an AI recommendation inside such a block is a violation.
# Governance source of truth (question-governance.md): the '유형:' field carries the
# policy/domain/scope classification ('분류:' is an area tag like ops/scope — using it
# for policy detection yields false negatives).
# Extract each question block and decide 'policy' type inside the block.
policy_found=0
for qid in $question_ids; do
  qnum="${qid%.}"
  block=$(awk -v hdr="### ${qid}" '
    index($0, hdr) == 1 {grab=1; print; next}
    grab && (/^### Q[0-9]/ || /^## /) {exit}
    grab {print}
  ' "$QFILE" | head -30)

  # Only 'policy'-type questions (KR 유형/분류, EN Type/Category — value is policy)
  if echo "$block" | grep -qiE '(유형|분류|Type|Category): *policy' 2>/dev/null; then
    policy_found=$((policy_found + 1))
    if echo "$block" | grep -qi 'AI 추천:\|AI-RECOMMEND' 2>/dev/null; then
      error "$qnum: policy question contains an AI recommendation (governance violation)"
    else
      pass "$qnum: policy question — no AI recommendation"
    fi
  fi
done
if (( policy_found == 0 )); then
  echo "No policy-type questions (0 checked)"
fi

# --- 5. BLOCK question status ---
echo ""
echo "--- 5. BLOCK question status ---"
block_open=$(grep -ci 'BLOCK' "$QFILE" 2>/dev/null || true)
# Answer label is bilingual (KR: [답변], EN: [Answer])
answered=$(grep -cE '\[(답변|Answer)\]:.+' "$QFILE" 2>/dev/null || true)
unanswered=$(grep -cE '\[(답변|Answer)\]: *$' "$QFILE" 2>/dev/null || true)

echo "BLOCK mentions: ${block_open}"
echo "Answered: ${answered}"
echo "Unanswered: ${unanswered}"

if (( unanswered > 0 )); then
  warn "${unanswered} unanswered question(s) — check GATE-2 pass conditions"
fi

# --- 6. Confidence tag statistics ---
echo ""
echo "--- 6. Confidence tag statistics ---"
# Confidence tag is bilingual (KR: [확신: 확실/추정/AI추천/미정], EN: [Confidence: certain/estimated/ai-recommended/undecided])
certain=$(grep -ciE '\[(확신: 확실|Confidence: certain)\]' "$QFILE" 2>/dev/null || true)
estimated=$(grep -ciE '\[(확신: 추정|Confidence: estimated)\]' "$QFILE" 2>/dev/null || true)
ai_rec=$(grep -ciE '\[(확신: AI추천|Confidence: ai-recommended)\]' "$QFILE" 2>/dev/null || true)
deferred=$(grep -ciE '\[(확신: 미정|Confidence: undecided)\]' "$QFILE" 2>/dev/null || true)

echo "certain: ${certain}, estimated: ${estimated}, ai-recommended: ${ai_rec}, undecided: ${deferred}"

if (( deferred > 0 )); then
  warn "${deferred} undecided answer(s) — subject to Readiness Score deduction"
fi

# --- Result summary ---
echo ""
echo "=== Result ==="
echo -e "Errors: ${RED}${ERRORS}${NC}, Warnings: ${YELLOW}${WARNINGS}${NC}"

if (( ERRORS > 0 )); then
  echo -e "${RED}FAIL${NC}"
  exit 1
elif (( WARNINGS > 0 )); then
  echo -e "${YELLOW}PASS (with warnings)${NC}"
  exit 0
else
  echo -e "${GREEN}PASS${NC}"
  exit 0
fi
