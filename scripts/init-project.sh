#!/usr/bin/env bash
set -euo pipefail

# Usage: bash <path-to-team-ai-workflow>/scripts/init-project.sh [project-root]
# If project-root is omitted, uses current directory.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GUARD_DOC="${WORKFLOW_DIR}/extensions/hallucination-guard/hallucination-guard.md"

# Detect sed in-place flavor (BSD on macOS, GNU on Linux)
case "$(uname -s)" in
  Darwin*) SED_INPLACE=(sed -i '') ;;
  *)       SED_INPLACE=(sed -i)    ;;
esac

PROJECT_ROOT="${1:-.}"
mkdir -p "${PROJECT_ROOT}"
PROJECT_ROOT="$(cd "${PROJECT_ROOT}" && pwd)"
PROJECT_NAME="$(basename "${PROJECT_ROOT}")"

echo "Initializing team-ai-workflow structure in: ${PROJECT_ROOT}"
echo "Project name: ${PROJECT_NAME}"
echo

# ── Hallucination Guard precondition: code-graph substrate is STRONGLY RECOMMENDED ──
# The guard verifies dev facts against a code graph. graphify is the primary substrate;
# codegraph (if present) is a fallback. When neither is available the guard degrades to
# grep/Read verification (see common/graph-grounding.md) — setup still proceeds.
# --mode is auto-detected by the gate (brownfield if source files exist, else greenfield).
echo "Checking code-graph preconditions (graphify)…"
if GATE_OUT="$(bash "${SCRIPT_DIR}/check-graphify.sh" "${PROJECT_ROOT}")"; then
  GATE_RC=0
else
  GATE_RC=$?
fi
echo "${GATE_OUT}"

if [[ "${GATE_RC}" -eq 2 ]]; then
  # The graphify tool is missing. Warn and continue in DEGRADED mode — do NOT abort setup.
  # /team-ai-workflow-start surfaces an install / degraded / cancel dialog on first run.
  echo
  echo "WARN: graphify not found — continuing in DEGRADED mode (VERIFY falls back to grep/Read)." >&2
  echo "Install later to enable graph-backed verification: uv tool install \"graphifyy[mcp]\"" >&2
  echo
elif [[ "${GATE_RC}" -eq 3 ]]; then
  # Tool present, brownfield, but the graph isn't built yet — try to build it.
  echo "Building graph (graphify .)…"
  ( cd "${PROJECT_ROOT}" && graphify . ) || {
    echo "WARN: 'graphify .' failed — continuing in DEGRADED mode. Retry manually later:" >&2
    echo "  (cd ${PROJECT_ROOT} && graphify .)" >&2
    GATE_RC=2
  }
fi
# ────────────────────────────────────────────────────────────────────────────────

# ctx/
mkdir -p "${PROJECT_ROOT}/ctx"
mkdir -p "${PROJECT_ROOT}/ctx/workflow"

if [[ ! -f "${PROJECT_ROOT}/ctx/INDEX.md" ]]; then
  cat > "${PROJECT_ROOT}/ctx/INDEX.md" << EOF
# CTX Index

## Project
- name: ${PROJECT_NAME}
- type: (TODO: e.g. Spring Boot API, Next.js, Python CLI)
- language: (TODO: e.g. Kotlin, TypeScript, Python)

## Key Modules
- (TODO: list primary modules/packages)

## Constraints
- (TODO: list key constraints, conventions, or rules)
EOF
  echo "Created ctx/INDEX.md"
else
  echo "Skipped ctx/INDEX.md (already exists)"
fi

if [[ ! -f "${PROJECT_ROOT}/ctx/project-profile.ctx.md" ]]; then
  cat > "${PROJECT_ROOT}/ctx/project-profile.ctx.md" << EOF
# Project Profile

- name: ${PROJECT_NAME}
- type: (TODO)
- platform: (TODO: android | ios | backend | frontend | flutter | rn)
- language: (TODO)
- test-strategy: test-after
EOF
  echo "Created ctx/project-profile.ctx.md"
else
  echo "Skipped ctx/project-profile.ctx.md (already exists)"
fi

if [[ ! -f "${PROJECT_ROOT}/ctx/workflow/commit-workflow.ctx.md" ]]; then
  cp "${TEMPLATE_DIR}/commit-workflow.ctx.md" "${PROJECT_ROOT}/ctx/workflow/commit-workflow.ctx.md"
  echo "Created ctx/workflow/commit-workflow.ctx.md"
else
  echo "Skipped ctx/workflow/commit-workflow.ctx.md (already exists)"
fi

# CLAUDE.md
if [[ ! -f "${PROJECT_ROOT}/CLAUDE.md" ]] && [[ ! -f "${PROJECT_ROOT}/AGENTS.md" ]]; then
  cat > "${PROJECT_ROOT}/CLAUDE.md" << EOF
# ${PROJECT_NAME}

## Project Overview
(TODO: brief description of this project)

## Tech Stack
- (TODO)

## Development Rules
- (TODO: coding conventions, naming rules, etc.)
EOF
  echo "Created CLAUDE.md"
else
  echo "Skipped CLAUDE.md (CLAUDE.md or AGENTS.md already exists)"
fi

# Hallucination Guard pointer (idempotent): ensure the always-on guard is referenced from
# whichever agent file exists, so every ctx-* run bootstraps it.
AGENT_FILE="${PROJECT_ROOT}/CLAUDE.md"
[[ -f "${PROJECT_ROOT}/AGENTS.md" ]] && AGENT_FILE="${PROJECT_ROOT}/AGENTS.md"
if [[ -f "${AGENT_FILE}" ]] && ! grep -q "Hallucination Guard" "${AGENT_FILE}"; then
  cat >> "${AGENT_FILE}" << EOF

## Hallucination Guard (ALWAYS ON)
Verify every dev fact (paths, symbols, API sigs, config keys, versions) against a concrete
source before stating it — prefer graphify (\`graphify query\`/\`graphify explain\`/\`graphify path\`,
or the MCP tools) over memory; codegraph/grep/Read as fallback. Never verify a guess with another guess. Read
\`aidlc-docs/hallucination-ledger.md\` first; never reuse a quarantined claim.
Full rules: ${GUARD_DOC}
Audit loop: /ctx-hallucination-audit (run until Hallucination-Free Score ≥ 87).
EOF
  echo "Wired Hallucination Guard pointer into $(basename "${AGENT_FILE}")"
fi

# .gitignore: keep the per-worktree graph out of version control (idempotent).
GITIGNORE="${PROJECT_ROOT}/.gitignore"
if [[ ! -f "${GITIGNORE}" ]] || ! grep -qx "graphify-out/" "${GITIGNORE}"; then
  printf '\n# graphify code-graph output (per-worktree, not shared)\ngraphify-out/\n' >> "${GITIGNORE}"
  echo "Ignored graphify-out/ in ${PROJECT_NAME}/.gitignore"
fi

# aidlc-docs/
mkdir -p "${PROJECT_ROOT}/aidlc-docs/features"

if [[ ! -f "${PROJECT_ROOT}/aidlc-docs/aidlc-state.md" ]]; then
  cp "${TEMPLATE_DIR}/aidlc-state.md" "${PROJECT_ROOT}/aidlc-docs/aidlc-state.md"
  "${SED_INPLACE[@]}" "s|^- Start Date:.*|- Start Date: $(date +%Y-%m-%d)|" "${PROJECT_ROOT}/aidlc-docs/aidlc-state.md"
  echo "Created aidlc-docs/aidlc-state.md"
else
  echo "Skipped aidlc-docs/aidlc-state.md (already exists)"
fi

if [[ ! -f "${PROJECT_ROOT}/aidlc-docs/audit.md" ]]; then
  # Copy template up to (and including) the first '---' separator so the rules
  # and trigger definitions ship to the project, but the sample feature entry
  # at the tail of the template is stripped.
  sed '/^---$/q' "${TEMPLATE_DIR}/audit.md" > "${PROJECT_ROOT}/aidlc-docs/audit.md"
  echo "Created aidlc-docs/audit.md"
else
  echo "Skipped aidlc-docs/audit.md (already exists)"
fi

# Hallucination Guard state files (append-only ledgers)
for guard_doc in hallucination-ledger.md knowledge-log.md; do
  if [[ ! -f "${PROJECT_ROOT}/aidlc-docs/${guard_doc}" ]]; then
    cp "${TEMPLATE_DIR}/${guard_doc}" "${PROJECT_ROOT}/aidlc-docs/${guard_doc}"
    echo "Created aidlc-docs/${guard_doc}"
  else
    echo "Skipped aidlc-docs/${guard_doc} (already exists)"
  fi
done

# Run log: structured result log (NDJSON source of truth) + graphify-ingestible
# Markdown mirror. See common/run-logging.md. The mirror is regenerated by
# scripts/run-logger.ts on every append; the NDJSON starts empty.
if [[ ! -f "${PROJECT_ROOT}/aidlc-docs/run-log.md" ]]; then
  cp "${TEMPLATE_DIR}/run-log.md" "${PROJECT_ROOT}/aidlc-docs/run-log.md"
  echo "Created aidlc-docs/run-log.md"
else
  echo "Skipped aidlc-docs/run-log.md (already exists)"
fi
if [[ ! -f "${PROJECT_ROOT}/aidlc-docs/run-log.ndjson" ]]; then
  : > "${PROJECT_ROOT}/aidlc-docs/run-log.ndjson"
  echo "Created aidlc-docs/run-log.ndjson"
else
  echo "Skipped aidlc-docs/run-log.ndjson (already exists)"
fi

echo
echo "Done. Project structure:"
echo "  ${PROJECT_ROOT}/"
echo "  ├── CLAUDE.md (or AGENTS.md)"
echo "  ├── ctx/"
echo "  │   ├── INDEX.md"
echo "  │   ├── project-profile.ctx.md"
echo "  │   └── workflow/"
echo "  │       └── commit-workflow.ctx.md"
echo "  └── aidlc-docs/"
echo "      ├── aidlc-state.md"
echo "      ├── audit.md"
echo "      ├── hallucination-ledger.md"
echo "      ├── knowledge-log.md"
echo "      ├── run-log.ndjson"
echo "      ├── run-log.md"
echo "      └── features/"
echo
if [[ "${GATE_RC}" -eq 2 ]]; then
  echo "Hallucination Guard active in DEGRADED mode (no graph; VERIFY uses grep/Read)."
  echo "Install graphify to enable graph-backed verification: uv tool install \"graphifyy[mcp]\""
  echo "Audit loop: /ctx-hallucination-audit"
elif [[ "${GATE_RC}" -eq 3 ]]; then
  echo "Hallucination Guard active (graphify installed; graph deferred — run 'graphify .' to build it)."
  echo "Audit loop: /ctx-hallucination-audit"
else
  echo "Hallucination Guard active (graphify verified). Audit loop: /ctx-hallucination-audit"
fi
echo "Next: fill in the (TODO) placeholders, then run /ctx-aidlc-run"
