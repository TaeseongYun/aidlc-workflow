#!/usr/bin/env bash
# Precondition gate for the Hallucination Guard: verify the code-graph substrate.
#
# The guard's core rule is "verify every dev fact against a concrete source; never verify a
# guess with another guess." The highest-quality concrete source is a code graph. So graphify
# + a built graph are the PRIMARY preconditions of project setup. codegraph, if present, is only
# a fallback grounding source — it is NOT required.
#
# Consumed by:
#   - scripts/init-project.sh  (hard-fails on a missing tool; auto-builds a missing graph on
#     brownfield; passes --mode)
#   - /team-ai-workflow-start skill (on a missing tool it must open an AskUserQuestion dialog,
#     never a free-text "continue anyway" prompt)
#
# Usage: scripts/check-graphify.sh [project-root] [--mode=brownfield|greenfield]
#   project-root  default: current directory
#   --mode        default: auto (brownfield if the project already contains source files)
#
# Exit codes (granular, so callers can distinguish block-vs-autofix-vs-defer):
#   0  ready (graphify present + graph built)  — OR greenfield with no graph yet (graph deferred)
#   2  the graphify TOOL is missing              -> HARD BLOCK, needs install
#   3  brownfield but the GRAPH is missing       -> auto-fixable via `graphify .`
#
# Output: one machine-readable line per check, plus a final `RESULT: <code> <summary>` line.
set -uo pipefail

# ── TOOL REGISTRY ──────────────────────────────────────────────────────────────
# Single place that names the tools and how to install them. Edit here only.
# graphify is the PyPI package `graphifyy` (double-y); its console script is `graphify`.
# The `[mcp]` extra also installs the MCP server used by the guard's structured VERIFY path.
GRAPHIFY_BIN="graphify"
GRAPHIFY_PKG="graphifyy[mcp]"
GRAPHIFY_INSTALL="uv tool install \"${GRAPHIFY_PKG}\""   # or: pipx install "${GRAPHIFY_PKG}"
# graphify writes its queryable knowledge graph here — the VERIFY grounding source the guard relies on.
GRAPH_FILE="graphify-out/graph.json"

# codegraph is an OPTIONAL fallback grounding source. Absence is fine (informational only).
CODEGRAPH_BIN="codegraph"
CODEGRAPH_INSTALL="npm i -g @colbymchenry/codegraph"
# ───────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT="."
MODE="auto"
for arg in "$@"; do
  case "$arg" in
    --mode=*) MODE="${arg#--mode=}" ;;
    -*)       echo "WARN: unknown flag '${arg}' ignored" ;;
    *)        PROJECT_ROOT="$arg" ;;
  esac
done

# Resolve auto mode: brownfield if the project already has non-scaffold source files.
resolve_mode() {
  [[ "$MODE" != "auto" ]] && return
  local n
  n="$(find "${PROJECT_ROOT}" \
        \( -name .git -o -name node_modules -o -name .venv -o -name aidlc-docs \
           -o -name graphify-out -o -name .codegraph \) -prune -o \
        -type f \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' \
           -o -name '*.jsx' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \
           -o -name '*.kt' -o -name '*.rb' -o -name '*.swift' -o -name '*.c' \
           -o -name '*.cc' -o -name '*.cpp' -o -name '*.cs' \) -print 2>/dev/null | head -1)"
  if [[ -n "$n" ]]; then MODE="brownfield"; else MODE="greenfield"; fi
}
resolve_mode

tool_missing=0
graph_missing=0

# ── TOOL: graphify (required) ────────────────────────────────────────────────
if path="$(command -v "$GRAPHIFY_BIN" 2>/dev/null)"; then
  echo "OK: ${GRAPHIFY_BIN} (${path})"
else
  echo "MISSING: ${GRAPHIFY_BIN} — install: ${GRAPHIFY_INSTALL}"
  tool_missing=1
fi

# ── TOOL: codegraph (optional fallback) ──────────────────────────────────────
if path="$(command -v "$CODEGRAPH_BIN" 2>/dev/null)"; then
  echo "OK: ${CODEGRAPH_BIN} fallback (${path})"
else
  echo "INFO: ${CODEGRAPH_BIN} fallback not installed (optional) — ${CODEGRAPH_INSTALL}"
fi

# ── SUBSTRATE: graphify-out/graph.json exists AND parses ─────────────────────
graph_path="${PROJECT_ROOT%/}/${GRAPH_FILE}"
graph_ok=0
if [[ -f "$graph_path" ]]; then
  # Parse-check with whatever JSON reader is available; fall back to a non-empty check.
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$graph_path" 2>/dev/null && graph_ok=1
  elif command -v jq >/dev/null 2>&1; then
    jq -e . "$graph_path" >/dev/null 2>&1 && graph_ok=1
  elif command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$graph_path" 2>/dev/null && graph_ok=1
  else
    [[ -s "$graph_path" ]] && graph_ok=1   # last resort: non-empty
  fi
fi

if [[ "$graph_ok" -eq 1 ]]; then
  echo "OK: graph (${GRAPH_FILE} present & parses)"
else
  graph_missing=1
  echo "MISSING: graph (${GRAPH_FILE}) — build: ${GRAPHIFY_BIN} ."
fi

# ── VERDICT ──────────────────────────────────────────────────────────────────
if [[ "$tool_missing" -eq 1 ]]; then
  echo "RESULT: 2 tool missing — setup blocked; install required (${GRAPHIFY_INSTALL})"
  exit 2
elif [[ "$graph_missing" -eq 1 ]]; then
  if [[ "$MODE" == "greenfield" ]]; then
    echo "WARN: greenfield (mode=${MODE}) — graph deferred until first implementation; VERIFY uses grep/Read until then"
    echo "RESULT: 0 greenfield — graph not required yet"
    exit 0
  else
    echo "RESULT: 3 graph missing (mode=${MODE}) — build with '${GRAPHIFY_BIN} .'"
    exit 3
  fi
else
  echo "RESULT: 0 code-graph substrate ready (mode=${MODE})"
  exit 0
fi
