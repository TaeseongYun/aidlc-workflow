#!/usr/bin/env bash
set -euo pipefail

# Usage: bash <path-to-team-ai-workflow>/scripts/init-project.sh [project-root]
# If project-root is omitted, uses current directory.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates"

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
echo "      └── features/"
echo
echo "Next: fill in the (TODO) placeholders, then run /ctx-aidlc-run"
