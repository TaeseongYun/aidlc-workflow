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

# ── Hallucination Guard precondition: code-graph substrate is MANDATORY ──────────
# The guard verifies dev facts against a code graph; without it, setup must not proceed.
echo "Checking code-graph preconditions (codegraph + graphify)…"
if GATE_OUT="$(bash "${SCRIPT_DIR}/check-codegraph.sh" "${PROJECT_ROOT}")"; then
  GATE_RC=0
else
  GATE_RC=$?
fi
echo "${GATE_OUT}"

if [[ "${GATE_RC}" -eq 2 ]]; then
  # A required tool is missing. Bash cannot show a dialog, so fail loudly and defer the
  # install dialog to the /team-ai-workflow-start skill (per the plan's gate design).
  echo
  echo "초기 세팅 불가 — codegraph/graphify 전제조건 미충족." >&2
  echo "설치는 자동으로 진행하지 않습니다. Claude에서 /team-ai-workflow-start 를 실행하면" >&2
  echo "설치 여부를 대화 상자로 처리합니다 (또는 위 install 명령을 직접 실행하세요)." >&2
  exit 1
elif [[ "${GATE_RC}" -eq 3 ]]; then
  # Tools present but the index isn't built yet — build it (greenfield-safe).
  echo "Building codegraph index…"
  codegraph init "${PROJECT_ROOT}" || {
    echo "codegraph init 실패 — 수동으로 'codegraph init ${PROJECT_ROOT}' 실행 후 재시도하세요." >&2
    exit 1
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
source before stating it — prefer codegraph (\`codegraph explore\`/\`codegraph node\`) over memory,
grep/Read as fallback. Never verify a guess with another guess. Read
\`aidlc-docs/hallucination-ledger.md\` first; never reuse a quarantined claim.
Full rules: ${GUARD_DOC}
Audit loop: /ctx-hallucination-audit (run until Hallucination-Free Score ≥ 87).
EOF
  echo "Wired Hallucination Guard pointer into $(basename "${AGENT_FILE}")"
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
echo "      └── features/"
echo
echo "Hallucination Guard active (codegraph + graphify verified). Audit loop: /ctx-hallucination-audit"
echo "Next: fill in the (TODO) placeholders, then run /ctx-aidlc-run"
