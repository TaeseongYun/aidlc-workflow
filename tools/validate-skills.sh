#!/usr/bin/env bash
# Skill Validator - Deterministic checks for team-ai-workflow skills
# Usage: bash tools/validate-skills.sh
# Rules reference: tools/skill-validator.md
#
# Covers two skill families:
#   - workflow skills:  skills/*/            (must follow skills/_shared/skill-protocol.md)
#   - platform skills:  platforms/*/skills/*/ (structural checks + token budget)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
SKIP=0
TOTAL=0

# Note: use VAR=$((VAR+1)), never ((VAR++)) — the latter returns exit 1 when the
# pre-increment value is 0, which kills the script under `set -e`.
pass() {
  echo "[PASS] $1"
  PASS=$((PASS+1))
  TOTAL=$((TOTAL+1))
}

fail() {
  echo "[FAIL] $1"
  FAIL=$((FAIL+1))
  TOTAL=$((TOTAL+1))
}

skip() {
  echo "[SKIP] $1"
  SKIP=$((SKIP+1))
  TOTAL=$((TOTAL+1))
}

echo "=== team-ai-workflow Skill Validator ==="
echo "Root: $ROOT_DIR"
echo ""

# $1 = skill dir, $2 = family (workflow|platform)
check_skill_dir() {
  local skill_dir="$1"
  local family="$2"
  local skill_name
  skill_name=$(basename "$skill_dir")

  echo "--- $skill_name ($family) ---"

  # SKILL-01: SKILL.md is the single entrypoint. CLAUDE_COMMAND.md is forbidden:
  # dual entrypoints drifted apart twice (2026-03-24, 2026-09 audit) and were removed.
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    fail "SKILL-01: $skill_name — no SKILL.md found"
    return
  fi
  if [[ -f "$skill_dir/CLAUDE_COMMAND.md" ]]; then
    fail "SKILL-01: $skill_name — CLAUDE_COMMAND.md present (dual entrypoint forbidden; merge into SKILL.md)"
  else
    pass "SKILL-01: $skill_name — single SKILL.md entrypoint"
  fi

  local entry_file="$skill_dir/SKILL.md"

  # SKILL-02: Frontmatter description field
  if sed -n '/^---$/,/^---$/p' "$entry_file" | grep -q "^description:"; then
    pass "SKILL-02: $skill_name — description field exists"
  else
    fail "SKILL-02: $skill_name — missing description in frontmatter"
  fi

  if [[ "$family" == "workflow" ]]; then
    # FRONT-01: one frontmatter convention — name+description+allowed-tools required,
    # model optional, and no dead legacy keys (version:/command:).
    local fm
    fm=$(sed -n '/^---$/,/^---$/p' "$entry_file")
    local front_missing=""
    echo "$fm" | grep -q "^name:" || front_missing="$front_missing name"
    echo "$fm" | grep -q "^allowed-tools:" || front_missing="$front_missing allowed-tools"
    local front_dead=""
    echo "$fm" | grep -qE "^(version|command):" && front_dead=" (drop legacy version:/command:)"
    if [[ -z "$front_missing" && -z "$front_dead" ]]; then
      pass "FRONT-01: $skill_name — frontmatter convention (name/description/allowed-tools)"
    else
      fail "FRONT-01: $skill_name — missing:${front_missing:- none}${front_dead}"
    fi
  fi

  if [[ "$family" == "workflow" ]]; then
    # SKILL-03: references the shared skill protocol
    if grep -q "skill-protocol" "$entry_file"; then
      pass "SKILL-03: $skill_name — references skill-protocol"
    else
      fail "SKILL-03: $skill_name — SKILL.md never references skills/_shared/skill-protocol.md"
    fi

    # SKILL-04: has a guardrail / prohibition / halt section
    if grep -qiE '^(#+ .*)?(prohibition|guardrail|hard (stop|rules|preconditions)|halt conditions|stop conditions)|^(HARD RULES|CORE RULES|WHEN TO STOP)' "$entry_file"; then
      pass "SKILL-04: $skill_name — guardrail/halt section present"
    else
      fail "SKILL-04: $skill_name — no guardrail/prohibition/halt section found"
    fi

    # SKILL-05: has an output contract / format section
    if grep -qiE '^#+ .*(output|report format|required outputs)|^(OUTPUT CONTRACT|OUTPUT FORMAT|REPORT FORMAT|FINAL RESPONSE RULE)' "$entry_file"; then
      pass "SKILL-05: $skill_name — output format section present"
    else
      fail "SKILL-05: $skill_name — no output format section found"
    fi
  fi

  # USAGE-01: USAGE.md examples must carry the labels their SKILL.md enforces —
  # every real contract defect found in audits lived in a USAGE example that
  # modeled a pre-migration output shape.
  if [[ "$family" == "workflow" && -f "$skill_dir/USAGE.md" ]]; then
    local usage_required=""
    case "$skill_name" in
      ctx-reviewer)       usage_required="### Proposal 1|Target file path:|## 1b" ;;
      ctx-updater)        usage_required="Target file path:|Reflection Success" ;;
      ctx-commit-planner) usage_required="Order rationale:|- message:|\[Background\]" ;;
      ctx-architect-judge) usage_required="## 5" ;;
      ctx-domain-exec)    usage_required="Guarantee" ;;
    esac
    if [[ -n "$usage_required" ]]; then
      local usage_missing=""
      IFS='|' read -r -a req_arr <<< "$usage_required"
      for req in "${req_arr[@]}"; do
        grep -q -- "$req" "$skill_dir/USAGE.md" || usage_missing="$usage_missing '$req'"
      done
      if [[ -z "$usage_missing" ]]; then
        pass "USAGE-01: $skill_name — USAGE examples carry the enforced labels"
      else
        fail "USAGE-01: $skill_name — USAGE.md missing enforced label(s):$usage_missing"
      fi
    fi
  fi

  # SCOPE-01: No cross-skill references.
  # Workflow family: no reference to another workflow skill's sources.
  # Platform family: no reference to ANOTHER platform's skills (same-platform links allowed).
  local cross_refs=""
  if [[ "$family" == "workflow" ]]; then
    cross_refs=$(grep -rn "skills/[a-z]" "$skill_dir" --include="*.md" 2>/dev/null \
      | grep -v "_shared" | grep -v "common" | grep -v "skills/${skill_name}/" \
      | grep -v "platforms/" \
      | grep -vE '~?/?\.(claude|codex)[^ ]*skills/' \
      | grep -vE '\.claude/|\.codex/' || true)
  else
    local platform_name
    platform_name=$(basename "$(cd "$skill_dir/../.." && pwd)")
    cross_refs=$(grep -rn "platforms/[a-z]*/skills/" "$skill_dir" --include="*.md" 2>/dev/null \
      | grep -v "platforms/${platform_name}/skills/" || true)
  fi
  if [[ -z "$cross_refs" ]]; then
    pass "SCOPE-01: $skill_name — no cross-skill references"
  else
    fail "SCOPE-01: $skill_name — cross-skill reference found:"
    echo "         $cross_refs" | head -3
  fi

  # PATH-02: No hardcoded absolute paths to team-ai-workflow
  local hardcoded
  # Only flag /Users/ or /home/ as a filesystem root (not e.g. feature/home/ module paths).
  hardcoded=$(grep -rnE '(^|[^A-Za-z0-9_./-])/(Users|home)/' "$skill_dir" --include="*.md" 2>/dev/null || true)
  if [[ -z "$hardcoded" ]]; then
    pass "PATH-02: $skill_name — no hardcoded absolute paths"
  else
    fail "PATH-02: $skill_name — hardcoded path found:"
    echo "         $hardcoded" | head -3
  fi

  # REF-01: Relative .md references (./x.md, ../x.md, ../../x.md ...) resolve,
  # relative to the directory of the file that contains the reference.
  local ref_failures=0 ref_count=0
  while IFS=: read -r src_file ref_path; do
    [[ -n "$ref_path" ]] || continue
    ref_count=$((ref_count+1))
    if [[ ! -f "$(dirname "$src_file")/$ref_path" ]]; then
      if [[ $ref_failures -eq 0 ]]; then
        fail "REF-01: $skill_name — missing referenced file: $ref_path (from $(basename "$src_file"))"
      fi
      ref_failures=$((ref_failures+1))
    fi
  done < <(grep -roE '\.\.?(/[A-Za-z0-9_.-]+)+\.md' "$skill_dir" --include="*.md" 2>/dev/null || true)

  if [[ $ref_failures -eq 0 ]]; then
    if [[ $ref_count -gt 0 ]]; then
      pass "REF-01: $skill_name — all $ref_count internal references valid"
    else
      skip "REF-01: $skill_name — no internal file references to check"
    fi
  fi

  # REF-02: {{TEAM_AI_WORKFLOW_DIR}}/<path> references resolve inside this repo
  local ref2_missing
  ref2_missing=$(grep -rhoE '\{\{TEAM_AI_WORKFLOW_DIR\}\}/[A-Za-z0-9_./-]+' "$skill_dir" --include="*.md" 2>/dev/null \
    | sort -u | sed -e 's#{{TEAM_AI_WORKFLOW_DIR}}/##' -e 's#[.,)]*$##' \
    | while IFS= read -r p; do [[ -e "$ROOT_DIR/$p" ]] || echo "$p"; done || true)
  if [[ -z "$ref2_missing" ]]; then
    pass "REF-02: $skill_name — all workflow-dir references resolve"
  else
    fail "REF-02: $skill_name — unresolved workflow-dir reference: $(echo "$ref2_missing" | head -3 | tr '\n' ' ')"
  fi

  # TOKEN-01: prompt-weight budget. Rough estimate: printable-ASCII bytes / 3.3 + other bytes / 3.
  # reference.md is tier-2 (loaded on demand, one platform at a time) and carries no budget.
  local f est budget
  for f in "$skill_dir/SKILL.md" "$skill_dir"/phases/*.md; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in SKILL.md) budget=5000 ;; *) budget=3000 ;; esac
    est=$(LC_ALL=C awk '{ n = length($0); for (i = 1; i <= n; i++) { if (substr($0, i, 1) ~ /[ -~]/) a++; else o++ } } END { printf "%d", a / 3.3 + o / 3 }' "$f")
    if (( est <= budget )); then
      pass "TOKEN-01: $skill_name/$(basename "$f") — ~${est} tokens (budget ${budget})"
    else
      fail "TOKEN-01: $skill_name/$(basename "$f") — ~${est} tokens exceeds budget ${budget}"
    fi
  done

  echo ""
}

# Workflow skills
for skill_dir in "$ROOT_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  [[ "$skill_name" == "_shared" || "$skill_name" == "common" ]] && continue
  check_skill_dir "$skill_dir" "workflow"
done

# Platform skills
for skill_dir in "$ROOT_DIR/platforms"/*/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  check_skill_dir "$skill_dir" "platform"
done

# DUP-01: skill names must be globally unique across families — workflow and
# platform skills all install into the same flat commands/skills namespaces,
# and the installer's rm -rf + cp means a collision silently clobbers.
echo "--- Cross-family checks ---"
dups=$( { for d in "$ROOT_DIR/skills"/*/; do n=$(basename "$d"); [[ "$n" == "_shared" ]] || echo "$n"; done
          for d in "$ROOT_DIR/platforms"/*/skills/*/; do [[ -d "$d" ]] && basename "$d"; done; } | sort | uniq -d)
if [[ -z "$dups" ]]; then
  pass "DUP-01: all skill names unique across workflow + platform families"
else
  fail "DUP-01: duplicate skill name(s) would clobber on install: $(echo "$dups" | tr '\n' ' ')"
fi

# Inference checks reminder
echo "--- Inference Checks (AI Review Required) ---"
skip "PROTO-01: Full 8-section protocol compliance — requires AI review"

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
