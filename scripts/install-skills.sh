#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/skills"

# Override target homes via env vars to support multi-account setups.
# Examples:
#   CLAUDE_HOME=$HOME/.claude-personal bash scripts/install-skills.sh
#   CODEX_HOME=$HOME/.codex-work bash scripts/install-skills.sh
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
CODEX_TARGET_DIR="${CODEX_HOME}/skills"
CLAUDE_COMMANDS_TARGET_DIR="${CLAUDE_HOME}/commands"

# team-ai-workflow root path to inject into skill files
WORKFLOW_DIR="${ROOT_DIR}"

# Detect sed in-place flavor (BSD on macOS, GNU on Linux)
case "$(uname -s)" in
  Darwin*) SED_INPLACE=(sed -i '') ;;
  *)       SED_INPLACE=(sed -i)    ;;
esac

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Source skills directory not found: ${SOURCE_DIR}" >&2
  exit 1
fi

mkdir -p "${CODEX_TARGET_DIR}"
mkdir -p "${CLAUDE_COMMANDS_TARGET_DIR}"

SKILLS=(
  "team-ai-workflow-start"
  "ctx-aidlc-roadmap"
  "ctx-aidlc-run"
  "ctx-run"
  "ctx-architect-judge"
  "ctx-commit-planner"
  "ctx-domain-exec"
  "ctx-refiner"
  "ctx-reviewer"
  "ctx-updater"
)

for skill in "${SKILLS[@]}"; do
  src="${SOURCE_DIR}/${skill}"
  codex_dst="${CODEX_TARGET_DIR}/${skill}"
  claude_command_dst="${CLAUDE_COMMANDS_TARGET_DIR}/${skill}.md"

  if [[ ! -d "${src}" ]]; then
    echo "Skipping missing skill: ${skill}"
    continue
  fi

  rm -rf "${codex_dst}"
  cp -R "${src}" "${codex_dst}"
  find "${codex_dst}" -name ".DS_Store" -delete

  # Replace placeholder with actual workflow path in installed copies
  find "${codex_dst}" -name "*.md" -exec "${SED_INPLACE[@]}" "s|{{TEAM_AI_WORKFLOW_DIR}}|${WORKFLOW_DIR}|g" {} +

  if [[ -f "${src}/CLAUDE_COMMAND.md" ]]; then
    cp "${src}/CLAUDE_COMMAND.md" "${claude_command_dst}"
  elif [[ -f "${src}/SKILL.md" ]]; then
    cp "${src}/SKILL.md" "${claude_command_dst}"
  fi

  # Replace placeholder in Claude command file
  if [[ -f "${claude_command_dst}" ]]; then
    "${SED_INPLACE[@]}" "s|{{TEAM_AI_WORKFLOW_DIR}}|${WORKFLOW_DIR}|g" "${claude_command_dst}"
  fi

  echo "Installed ${skill} -> Codex skills, Claude commands"
done

echo
echo "Skill installation complete."
echo "Workflow root: ${WORKFLOW_DIR}"
echo "Codex target: ${CODEX_TARGET_DIR}"
echo "Claude commands target: ${CLAUDE_COMMANDS_TARGET_DIR}"
echo
echo "Tip: set TEAM_AI_WORKFLOW_DIR in your shell rc so other tools can locate the workflow:"
echo "  export TEAM_AI_WORKFLOW_DIR=\"${WORKFLOW_DIR}\""
