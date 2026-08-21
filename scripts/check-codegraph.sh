#!/usr/bin/env bash
# Precondition gate for the Hallucination Guard: verify the code-graph substrate.
#
# The guard's core rule is "verify every dev fact against a concrete source; never verify a
# guess with another guess." The highest-quality concrete source is a code graph. So codegraph
# + graphify + a built index are MANDATORY preconditions of project setup.
#
# Consumed by:
#   - scripts/init-project.sh  (hard-fails on a missing tool; auto-builds a missing index)
#   - /team-ai-workflow-start skill (on a missing tool it must open an AskUserQuestion dialog,
#     never a free-text "continue anyway" prompt)
#
# Usage: scripts/check-codegraph.sh [project-root]   (default: current directory)
#
# Exit codes (granular, so callers can distinguish block-vs-autofix):
#   0  all present (both tools on PATH + index built)
#   2  a TOOL is missing (codegraph and/or graphify)  -> HARD BLOCK, needs install
#   3  tools present but INDEX missing                -> auto-fixable via `codegraph init`
#
# Output: one machine-readable line per check, plus a final `RESULT: <code> <summary>` line.
set -uo pipefail

# ── TOOL REGISTRY ──────────────────────────────────────────────────────────────
# Single place that names the tools and how to install them. Edit here only.
CODEGRAPH_BIN="codegraph"
CODEGRAPH_INSTALL="npm i -g @colbymchenry/codegraph"

GRAPHIFY_BIN="graphify"
# graphify is a scoped npm package installed like codegraph; its bin is `graphify`
# (verified: `npm view @sentropic/graphify bin`), so `command -v graphify` detects it.
# code/docs -> queryable knowledge graph — the VERIFY grounding source the guard relies on.
GRAPHIFY_PKG="@sentropic/graphify"
GRAPHIFY_INSTALL="npm i -g ${GRAPHIFY_PKG}"
# ───────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT="${1:-.}"

tool_missing=0
index_missing=0

check_tool() {
  local bin="$1" install="$2" path
  if path="$(command -v "$bin" 2>/dev/null)"; then
    echo "OK: ${bin} (${path})"
  else
    echo "MISSING: ${bin} — install: ${install}"
    tool_missing=1
  fi
}

check_tool "$CODEGRAPH_BIN" "$CODEGRAPH_INSTALL"
check_tool "$GRAPHIFY_BIN" "$GRAPHIFY_INSTALL"

# Index check only makes sense if codegraph itself is present.
if command -v "$CODEGRAPH_BIN" >/dev/null 2>&1; then
  if [[ -d "${PROJECT_ROOT}/.codegraph" ]] && \
     "$CODEGRAPH_BIN" status "${PROJECT_ROOT}" >/dev/null 2>&1; then
    echo "OK: index (.codegraph built)"
  else
    echo "MISSING: index — run: ${CODEGRAPH_BIN} init ${PROJECT_ROOT}"
    index_missing=1
  fi
else
  echo "SKIP: index (codegraph not installed)"
fi

if [[ "$tool_missing" -eq 1 ]]; then
  echo "RESULT: 2 tool(s) missing — setup blocked; install required"
  exit 2
elif [[ "$index_missing" -eq 1 ]]; then
  echo "RESULT: 3 index missing — build with '${CODEGRAPH_BIN} init'"
  exit 3
else
  echo "RESULT: 0 code-graph substrate ready"
  exit 0
fi
