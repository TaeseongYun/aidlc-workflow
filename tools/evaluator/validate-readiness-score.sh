#!/usr/bin/env bash
# Readiness Score validation
# Usage: bash validate-readiness-score.sh <feature-dir>
# Validates the Readiness Score table in status.md.

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

echo "=== Readiness Score Validation ==="

if [[ ! -f "$STATUS_FILE" ]]; then
  error "status.md missing"
  exit 1
fi

echo "Target: $STATUS_FILE"
echo ""

# --- 1. Readiness Score section present ---
echo "--- 1. Readiness Score table ---"
if grep -q '## Readiness Score' "$STATUS_FILE" 2>/dev/null; then
  pass "Readiness Score section present"
else
  error "Readiness Score section missing"
  exit 1
fi

# --- 2. Total row present and score extraction ---
echo ""
echo "--- 2. Total score ---"
total_line=$(grep -i '합계\|total' "$STATUS_FILE" 2>/dev/null | head -1)
if [[ -n "$total_line" ]]; then
  # Extract numbers from the table row: | Total | Max | Score | Verdict |
  # Strip bold (**), then parse pipe-separated.
  # Use only the first integer token even when a cell holds several numbers,
  # e.g. '120 (100 + bonus 20)' (stripping all non-digits would concatenate
  # 120,100,20 into 12010020).
  clean_line=$(echo "$total_line" | sed 's/\*\*//g')
  total_max=$(echo "$clean_line" | awk -F'|' '{print $3}' | grep -oE '[0-9]+' | head -1)
  total_score=$(echo "$clean_line" | awk -F'|' '{print $4}' | grep -oE '[0-9]+' | head -1)

  if [[ -n "$total_score" && -n "$total_max" ]]; then
    pass "Total: ${total_score}/${total_max}"

    # Verdict consistency check (extract after stripping bold)
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
          pass "Verdict consistent: $verdict (score ${total_score}/${total_max}, expected $expected)"
        else
          error "Verdict mismatch: stated=$verdict, expected from score=$expected (${total_score}/${total_max})"
        fi
      else
        warn "Verdict (READY/CONDITIONAL/NOT_READY) not stated in the total row"
      fi
    fi
  else
    warn "Cannot extract scores from the total row"
  fi
else
  error "Total row missing"
fi

# --- 3. Cross-check BLOCK questions against verdict ---
echo ""
echo "--- 3. BLOCK question cross-check ---"

if [[ -f "$QFILE" ]]; then
  # Count of BLOCK questions in OPEN state (from the Summary table).
  # grep -c prints "0" to stdout AND exits 1 on zero matches, so appending
  # "|| echo 0" would yield "0\n0" and break (( )) arithmetic.
  # Take only the last line and normalize to an integer.
  block_open=$(grep -ci 'OPEN.*BLOCK\|BLOCK.*OPEN' "$QFILE" 2>/dev/null | tail -1)
  block_open=${block_open:-0}

  if (( block_open > 0 )); then
    echo "OPEN BLOCK questions: ${block_open}"

    # Check the BLOCK count in status.md (e.g. "BLOCK Questions: 2")
    status_block=$(grep -i 'BLOCK Questions' "$STATUS_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "")
    if [[ -n "$status_block" ]]; then
      if [[ "$status_block" -ne "$block_open" ]]; then
        warn "BLOCK count mismatch: status.md=${status_block}, questions.md=${block_open}"
      else
        pass "BLOCK count matches: ${block_open}"
      fi
    fi

    # A READY verdict with open BLOCK questions is an error.
    # When verdict extraction failed (total-row parse failure) this key cross-check
    # would be silently skipped, so leave a warning.
    if [[ -z "${verdict:-}" ]]; then
      warn "Verdict not extracted — cannot perform READY x BLOCK cross-check"
    elif [[ "$verdict" == "READY" ]]; then
      error "Verdict is READY but ${block_open} OPEN BLOCK question(s) exist"
    fi
  else
    pass "No OPEN BLOCK questions"
  fi
else
  warn "requirement-verification-questions.md missing — skipping BLOCK cross-check"
fi

# --- 4. Max-points sum check ---
echo ""
echo "--- 4. Max-points sum ---"

# Sum the max-points column in the Readiness Score table
score_section=$(sed -n '/## Readiness Score/,/^## /p' "$STATUS_FILE")
point_values=$(echo "$score_section" | grep -E '^\|' | grep -vi '합계\|total\|영역\|area\|--' | grep -oE '\| *[0-9]+ *\|' | head -20)

if [[ -n "$point_values" ]]; then
  # Extract per-row max points (3rd column) — strip bold (**), use only the first integer token
  row_maxes=$(echo "$score_section" | sed 's/\*\*//g' | grep -E '^\|' | grep -vi '합계\|total\|영역\|area\|--' | awk -F'|' '{print $3}' | grep -oE '[0-9]+' )

  calc_total=0
  for val in $row_maxes; do
    if [[ "$val" =~ ^[0-9]+$ ]]; then
      calc_total=$((calc_total + val))
    fi
  done

  if [[ -n "${total_max:-}" && "$calc_total" -gt 0 ]]; then
    if [[ "$calc_total" -eq "$total_max" ]]; then
      pass "Max-points sum matches: ${calc_total}"
    else
      warn "Max-points sum mismatch: per-row sum=${calc_total}, total row=${total_max}"
    fi
  fi
fi

# --- 5. UNCERTAIN marker cross-check ---
echo ""
echo "--- 5. UNCERTAIN markers ---"

uncertain_count=0
for file in "$FEATURE_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  count=$(grep -c '⚠️ UNCERTAIN' "$file" 2>/dev/null || true)
  if (( count > 0 )); then
    uncertain_count=$((uncertain_count + count))
    fname=$(basename "$file")
    warn "$fname: ${count} UNCERTAIN marker(s) — subject to Readiness Score cap"
  fi
done

if (( uncertain_count == 0 )); then
  pass "No UNCERTAIN markers"
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
