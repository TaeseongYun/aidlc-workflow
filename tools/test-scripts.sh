#!/usr/bin/env bash
# Self-checks for scripts/aidlc-log.sh, scripts/md-section.sh and scripts/graph_inventory.py.
# Usage: bash tools/test-scripts.sh   (exit 1 when any assertion fails)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fails=0
check()  { if grep -q -- "$2" "$3"; then echo "[PASS] $1"; else echo "[FAIL] $1 — expected '$2' in $3"; fails=$((fails+1)); fi; }
absent() { if grep -q -- "$2" "$3"; then echo "[FAIL] $1 — did not expect '$2' in $3"; fails=$((fails+1)); else echo "[PASS] $1"; fi; }
expect_rc() { local want=$1 name=$2; shift 2; local rc=0; "$@" >/dev/null 2>&1 || rc=$?
  if [[ $rc -eq $want ]]; then echo "[PASS] $name (exit $want)"; else echo "[FAIL] $name — expected exit $want, got $rc"; fails=$((fails+1)); fi; }

echo "--- aidlc-log.sh ---"
LOG="$ROOT/scripts/aidlc-log.sh"
mkdir -p "$TMP/aidlc-docs"
cp "$ROOT/templates/aidlc-state.md" "$TMP/aidlc-docs/aidlc-state.md"
sed '/^---$/q' "$ROOT/templates/audit.md" > "$TMP/aidlc-docs/audit.md"
export AIDLC_DOCS="$TMP/aidlc-docs"
bash "$LOG" step demo STEP-4 "Requirement Gap Extraction" started
bash "$LOG" step demo STEP-4 "Requirement Gap Extraction" completed "" "requirement-verification-questions.md"
bash "$LOG" step demo STEP-1-C "Input Validation" skipped "raw-request"
bash "$LOG" gate demo GATE-2 "Requirements Review" approved "승인합니다"
bash "$LOG" answer demo Q1 "14일 환불" "BLOCK released"
bash "$LOG" status demo questions-open approved "GATE-2 approved"
bash "$LOG" set "Current Phase" "B (Definition)"
bash "$LOG" step demo STEP-R2 "Feature Decomposition" completed
bash "$LOG" handoff demo ctx-aidlc-run ctx-aidlc-roadmap "multi-feature detected" "run /ctx-aidlc-roadmap"
S="$TMP/aidlc-docs/aidlc-state.md"; A="$TMP/aidlc-docs/audit.md"
check  "state: STEP 4 checked"          "- \[x\] STEP 4:" "$S"
absent "state: STEP 4 not left unchecked" "- \[ \] STEP 4:" "$S"
check  "state: STEP 1-C skipped + reason" "- \[-\] STEP 1-C: Input Validation (prepared-requirement only) (raw-request)" "$S"
check  "state: GATE-2 checked"          "- \[x\] GATE-2:" "$S"
check  "state: STEP R2 checked"         "- \[x\] STEP R2:" "$S"
check  "state: Current Stage"           "^- Current Stage: STEP 4: Requirement Gap Extraction" "$S"
check  "state: Feature Status"          "^- Feature Status: approved" "$S"
check  "state: Current Phase"           "^- Current Phase: B (Definition)" "$S"
check  "state: Last Updated stamped"    "^- Last Updated: 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T" "$S"
check  "audit: step block"              "^## \[STEP-4\] Requirement Gap Extraction — completed" "$A"
check  "audit: outputs line"            "^- Outputs: requirement-verification-questions.md" "$A"
check  "audit: skip reason"             "^- Reason: raw-request" "$A"
check  "audit: gate block"              "^## \[GATE-2\] Requirements Review" "$A"
check  "audit: verbatim user input"     '^- User Input: "승인합니다"' "$A"
check  "audit: answer block"            "^## \[ANSWER\] question answer" "$A"
check  "audit: status block"            "^## \[STATUS\] status change" "$A"
check  "audit: handoff block"           "^## \[HANDOFF\] ctx-aidlc-run → ctx-aidlc-roadmap" "$A"
AIDLC_DOCS="$TMP/nowhere" expect_rc 2 "log: missing docs" bash "$LOG" step demo STEP-1 "x" started
expect_rc 1 "log: bad action" bash "$LOG" step demo STEP-1 "x" done
unset AIDLC_DOCS

echo "--- md-section.sh ---"
SEC="$ROOT/scripts/md-section.sh"; SG="$ROOT/common/stage-gate-rules.md"; out="$TMP/sec.txt"
bash "$SEC" "$SG" "## Standard Approval Message Format" > "$out"
check  "section: keeps fenced pseudo-heading" "^## \[Stage Name\] Complete" "$out"
check  "section: includes H3 subsection"      "^### Format Rules" "$out"
absent "section: stops at next H2"            "^## Audit Log Integration" "$out"
bash "$SEC" "$SG" "### GATE-2:" > "$out"
check  "section: single gate"                 "^### GATE-2: Requirements" "$out"
absent "section: excludes GATE-2.5"           "^### GATE-2.5" "$out"
bash "$SEC" "$SG" "## Gate List" "## Gate Rules" > "$out"
check  "section: multi heading 1"             "^## Gate List" "$out"
check  "section: multi heading 2 (with H3s)"  "^### Gate Skipping" "$out"
expect_rc 1 "section: missing heading" bash "$SEC" "$SG" "## Nope"

echo "--- graph_inventory.py ---"
GI="$ROOT/scripts/graph_inventory.py"
mkdir -p "$TMP/proj/graphify-out"; cp "$ROOT/tools/fixtures/graph.sample.json" "$TMP/proj/graphify-out/graph.json"
python3 "$GI" "$TMP/proj" > "$TMP/inv.out"
INV="$TMP/proj/aidlc-docs/reverse-engineering/component-inventory.md"
check "inventory: written"          "^# Component Inventory" "$INV"
check "inventory: domain package"   "^| orders | \`orders/\`" "$INV"
check "inventory: infra package"    "^| infra |" "$INV"
check "inventory: common package"   "^| common |" "$INV"
check "inventory: dependency row"   "^| orders → payments | calls (1 edge)" "$INV"
check "inventory: inferred flagged" "only 0% EXTRACTED" "$INV"
check "inventory: cycle detected"   "^Circular dependency present: yes — orders ↔ payments" "$INV"
check "inventory: god node row"     "^| \`OrderService\` |" "$INV"
check "inventory: stdout summary"   "^cycles: orders ↔ payments" "$TMP/inv.out"
expect_rc 4 "inventory: refuses overwrite" python3 "$GI" "$TMP/proj"
expect_rc 3 "inventory: no graph"          python3 "$GI" "$TMP"

echo ""
if (( fails > 0 )); then echo "❌ $fails script check(s) failed"; exit 1; else echo "✅ all script checks passed"; fi
