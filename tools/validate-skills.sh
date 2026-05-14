#!/usr/bin/env bash
# Skill Validator - Deterministic checks for team-ai-workflow skills
# Usage: bash tools/validate-skills.sh
# Rules reference: tools/skill-validator.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/skills"

PASS=0
FAIL=0
SKIP=0
TOTAL=0

pass() {
  echo "[PASS] $1"
  ((PASS++))
  ((TOTAL++))
}

fail() {
  echo "[FAIL] $1"
  ((FAIL++))
  ((TOTAL++))
}

skip() {
  echo "[SKIP] $1"
  ((SKIP++))
  ((TOTAL++))
}

echo "=== team-ai-workflow Skill Validator ==="
echo "Root: $ROOT_DIR"
echo ""

# Find all skill directories (exclude _shared, common)
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")

  # Skip non-skill directories
  if [[ "$skill_name" == "_shared" || "$skill_name" == "common" ]]; then
    continue
  fi

  echo "--- $skill_name ---"

  # SKILL-01: Entrypoint exists
  if [[ -f "$skill_dir/SKILL.md" || -f "$skill_dir/CLAUDE_COMMAND.md" ]]; then
    entrypoint=""
    [[ -f "$skill_dir/SKILL.md" ]] && entrypoint="SKILL.md"
    [[ -f "$skill_dir/CLAUDE_COMMAND.md" ]] && entrypoint="${entrypoint:+$entrypoint + }CLAUDE_COMMAND.md"
    pass "SKILL-01: $skill_name — entrypoint exists ($entrypoint)"
  else
    fail "SKILL-01: $skill_name — no SKILL.md or CLAUDE_COMMAND.md found"
    continue  # Skip remaining checks if no entrypoint
  fi

  # SKILL-02: Frontmatter description field
  for entry_file in "$skill_dir/SKILL.md" "$skill_dir/CLAUDE_COMMAND.md"; do
    if [[ -f "$entry_file" ]]; then
      entry_name=$(basename "$entry_file")
      # Check for YAML frontmatter with description
      if head -20 "$entry_file" | grep -q "^description:"; then
        pass "SKILL-02: $skill_name/$entry_name — description field exists"
      elif head -5 "$entry_file" | grep -q "^---"; then
        # Has frontmatter but maybe no description
        if sed -n '/^---$/,/^---$/p' "$entry_file" | grep -q "description:"; then
          pass "SKILL-02: $skill_name/$entry_name — description field exists"
        else
          fail "SKILL-02: $skill_name/$entry_name — missing description in frontmatter"
        fi
      else
        skip "SKILL-02: $skill_name/$entry_name — no frontmatter found (inference check needed)"
      fi
    fi
  done

  # SCOPE-01: No cross-skill references
  cross_refs=$(grep -rn "skills/[a-z]" "$skill_dir" --include="*.md" 2>/dev/null | grep -v "_shared" | grep -v "common" || true)
  if [[ -z "$cross_refs" ]]; then
    pass "SCOPE-01: $skill_name — no cross-skill references"
  else
    fail "SCOPE-01: $skill_name — cross-skill reference found:"
    echo "         $cross_refs" | head -3
  fi

  # PATH-02: No hardcoded absolute paths to team-ai-workflow
  hardcoded=$(grep -rn "/Users/\|/home/" "$skill_dir" --include="*.md" 2>/dev/null || true)
  if [[ -z "$hardcoded" ]]; then
    pass "PATH-02: $skill_name — no hardcoded absolute paths"
  else
    fail "PATH-02: $skill_name — hardcoded path found:"
    echo "         $hardcoded" | head -3
  fi

  # REF-01: Referenced files exist (check common references)
  ref_failures=0
  while IFS= read -r ref_line; do
    # Extract relative path references like ./file.md or ../file.md
    ref_path=$(echo "$ref_line" | grep -oE '\./[a-zA-Z0-9_./-]+\.md' || true)
    if [[ -n "$ref_path" ]]; then
      full_path="$skill_dir/$ref_path"
      if [[ ! -f "$full_path" ]]; then
        if [[ $ref_failures -eq 0 ]]; then
          fail "REF-01: $skill_name — missing referenced file: $ref_path"
        fi
        ((ref_failures++))
      fi
    fi
  done < <(grep -rn '\./.*\.md' "$skill_dir" --include="*.md" 2>/dev/null || true)

  if [[ $ref_failures -eq 0 ]]; then
    # Only count as pass if there were references to check
    ref_count=$(grep -rc '\./.*\.md' "$skill_dir" --include="*.md" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
    if [[ $ref_count -gt 0 ]]; then
      pass "REF-01: $skill_name — all $ref_count internal references valid"
    else
      skip "REF-01: $skill_name — no internal file references to check"
    fi
  fi

  echo ""
done

# Inference checks reminder
echo "--- Inference Checks (AI Review Required) ---"
skip "SKILL-03: Protocol reference — requires AI review"
skip "SKILL-04: Guardrail section — requires AI review"
skip "SKILL-05: Output format section — requires AI review"
skip "PROTO-01: Protocol compliance — requires AI review"

echo ""
echo "=== Summary ==="
echo "Total: $TOTAL | PASS: $PASS | FAIL: $FAIL | SKIP: $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "❌ Validation failed with $FAIL error(s)"
  exit 1
else
  echo ""
  echo "✅ All deterministic checks passed"
  exit 0
fi
