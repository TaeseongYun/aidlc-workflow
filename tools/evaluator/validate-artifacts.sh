#!/usr/bin/env bash
# Artifact completeness validation
# Usage: bash validate-artifacts.sh <feature-dir>
# Example: bash validate-artifacts.sh ./aidlc-docs/features/repurchase-coupon

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

echo "=== Artifact Completeness Validation ==="
echo "Target: $FEATURE_DIR"
echo ""

# --- 1. Required files ---
echo "--- 1. Required files ---"
REQUIRED_FILES=(
  "status.md"
  "requirements.md"
  "requirement-verification-questions.md"
  "unit-of-work.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$FEATURE_DIR/$file" ]]; then
    pass "$file present"
  else
    error "$file missing"
  fi
done

# --- 2. Required sections ---
echo ""
echo "--- 2. Required sections ---"

check_sections() {
  local file="$1"
  shift
  local sections=("$@")

  if [[ ! -f "$FEATURE_DIR/$file" ]]; then
    return
  fi

  for section in "${sections[@]}"; do
    if grep -qi "^##.*${section}" "$FEATURE_DIR/$file" 2>/dev/null; then
      pass "$file: '$section' section present"
    else
      error "$file: '$section' section missing"
    fi
  done
}

check_sections "requirements.md" "Goal" "In-Scope" "Out-of-Scope" "Functional Requirements"
check_sections "status.md" "Readiness Score" "Scope" "Approval"
check_sections "unit-of-work.md" "Summary"
check_sections "requirement-verification-questions.md" "Summary"

# --- 3. Empty section detection ---
echo ""
echo "--- 3. Empty section detection ---"

check_empty_sections() {
  local file="$1"
  if [[ ! -f "$FEATURE_DIR/$file" ]]; then
    return
  fi

  local prev_heading=""
  local prev_line=0
  local current_line=0
  local content_since=0

  # A section is empty when no non-blank body line appears between one heading
  # and the next (blank lines between headings are the normal markdown layout,
  # so a line-distance check can never fire).
  while IFS= read -r line; do
    ((current_line++))
    if [[ "$line" =~ ^##+ ]]; then
      if [[ -n "$prev_heading" && $content_since -eq 0 ]]; then
        warn "$file: '$prev_heading' section is empty (line ${prev_line})"
      fi
      prev_heading="$line"
      prev_line=$current_line
      content_since=0
    elif [[ -n "${line// /}" ]]; then
      content_since=1
    fi
  done < "$FEATURE_DIR/$file"
  if [[ -n "$prev_heading" && $content_since -eq 0 ]]; then
    warn "$file: '$prev_heading' section is empty (line ${prev_line})"
  fi
}

for file in "requirements.md" "status.md" "unit-of-work.md"; do
  check_empty_sections "$file"
done

# --- 4. Reference integrity (UOW IDs) ---
echo ""
echo "--- 4. Reference integrity ---"

if [[ -f "$FEATURE_DIR/unit-of-work.md" ]]; then
  uow_ids=$(grep -oE 'UOW-[0-9]+' "$FEATURE_DIR/unit-of-work.md" | sort -u)
  if [[ -z "$uow_ids" ]]; then
    # echo "" | wc -l prints 1, so count only when the list is non-empty
    error "unit-of-work.md: no UOW IDs found"
  else
    uow_count=$(echo "$uow_ids" | wc -l | tr -d ' ')
    pass "unit-of-work.md: ${uow_count} UOW ID(s) found"
  fi

  # Compare UOWs in the Summary table against body headings
  summary_ids=$(grep -E '^\|.*UOW-[0-9]+' "$FEATURE_DIR/unit-of-work.md" 2>/dev/null | grep -oE 'UOW-[0-9]+' | sort -u)
  heading_ids=$(grep -E '^## UOW-[0-9]+' "$FEATURE_DIR/unit-of-work.md" 2>/dev/null | grep -oE 'UOW-[0-9]+' | sort -u)

  if [[ -n "$summary_ids" && -n "$heading_ids" ]]; then
    missing_headings=$(comm -23 <(echo "$summary_ids") <(echo "$heading_ids"))
    if [[ -n "$missing_headings" ]]; then
      error "unit-of-work.md: UOWs in Summary without a body heading: $missing_headings"
    else
      pass "unit-of-work.md: Summary and body UOW IDs match"
    fi
  fi
fi

# --- 5. feature-slug consistency ---
echo ""
echo "--- 5. feature-slug consistency ---"

if [[ -f "$FEATURE_DIR/status.md" ]]; then
  slug_in_status=$(grep -i "Feature Slug:" "$FEATURE_DIR/status.md" 2>/dev/null | head -1 | sed 's/.*: *//')
  dir_name=$(basename "$FEATURE_DIR")
  if [[ -n "$slug_in_status" && "$slug_in_status" != "$dir_name" ]]; then
    warn "feature-slug mismatch: status.md='$slug_in_status' vs directory='$dir_name'"
  elif [[ -n "$slug_in_status" ]]; then
    pass "feature-slug matches: $slug_in_status"
  fi
fi

# --- 6. Basic diagram validation ---
echo ""
echo "--- 6. Diagram validation ---"

for file in "$FEATURE_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  fname=$(basename "$file")

  # Mermaid block without a text alternative
  if grep -q '```mermaid' "$file" 2>/dev/null; then
    if ! grep -qi '텍스트 대안\|text alternative\|fallback' "$file" 2>/dev/null; then
      warn "$fname: Mermaid diagram has no text alternative"
    else
      pass "$fname: Mermaid text alternative present"
    fi
  fi

  # Detect Unicode box-drawing characters (-P is missing from BSD grep and dies silently on macOS — use ERE)
  if grep -qE '┌|─|│|└|┐|┘|├|┤|┬|┴|┼' "$file" 2>/dev/null; then
    error "$fname: Unicode box-drawing characters detected (ASCII only)"
  fi
done

# --- Result summary ---
echo ""
echo "=== Result ==="
echo -e "Errors: ${RED}${ERRORS}${NC}, Warnings: ${YELLOW}${WARNINGS}${NC}"

if (( ERRORS > 0 )); then
  echo -e "${RED}FAIL${NC} — errors must be resolved."
  exit 1
elif (( WARNINGS > 0 )); then
  echo -e "${YELLOW}PASS (with warnings)${NC}"
  exit 0
else
  echo -e "${GREEN}PASS${NC}"
  exit 0
fi
