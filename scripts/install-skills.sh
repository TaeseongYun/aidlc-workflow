#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/skills"
PLATFORMS_DIR="${ROOT_DIR}/platforms"

# Override target homes via env vars to support multi-account setups.
# Examples:
#   CLAUDE_HOME=$HOME/.claude-personal bash scripts/install-skills.sh
#   CODEX_HOME=$HOME/.codex-work bash scripts/install-skills.sh
#
# Platform skills (platforms/<p>/skills/*) are opt-in:
#   bash scripts/install-skills.sh --platforms=android,ios
#   bash scripts/install-skills.sh --platforms=all
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
CODEX_TARGET_DIR="${CODEX_HOME}/skills"
CLAUDE_COMMANDS_TARGET_DIR="${CLAUDE_HOME}/commands"

# team-ai-workflow root path to inject into skill files.
# Escaped for use in the sed replacement below — a checkout path containing
# '|', '&', or '\' would otherwise silently corrupt every installed skill.
WORKFLOW_DIR="${ROOT_DIR}"
WORKFLOW_DIR_SED=$(printf '%s' "${WORKFLOW_DIR}" | sed 's/[&|\\]/\\&/g')

PLATFORMS=""
PLATFORMS_GIVEN=0
for arg in "$@"; do
  case "$arg" in
    --platforms=) echo "Empty --platforms= is ambiguous: pass a platform list, 'all', or 'none'." >&2; exit 2 ;;
    --platforms=*) PLATFORMS="${arg#--platforms=}"; PLATFORMS_GIVEN=1 ;;
    *) echo "Unknown argument: $arg" >&2; echo "Usage: install-skills.sh [--platforms=android,ios|all|none]" >&2; exit 2 ;;
  esac
done

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

install_skill_dir() {
  # $1 = source skill directory (must contain SKILL.md)
  local src="$1"
  local skill
  skill="$(basename "$src")"
  local codex_dst="${CODEX_TARGET_DIR}/${skill}"
  local claude_command_dst="${CLAUDE_COMMANDS_TARGET_DIR}/${skill}.md"

  if [[ ! -f "${src}/SKILL.md" ]]; then
    echo "Skipping ${skill}: no SKILL.md" >&2
    return 0
  fi

  rm -rf "${codex_dst}"
  cp -R "${src}" "${codex_dst}"
  find "${codex_dst}" -name ".DS_Store" -delete

  # Replace placeholder with actual workflow path in installed copies
  find "${codex_dst}" -name "*.md" -exec "${SED_INPLACE[@]}" "s|{{TEAM_AI_WORKFLOW_DIR}}|${WORKFLOW_DIR_SED}|g" {} +

  # SKILL.md is the single entrypoint for both Codex and Claude.
  cp "${src}/SKILL.md" "${claude_command_dst}"
  "${SED_INPLACE[@]}" "s|{{TEAM_AI_WORKFLOW_DIR}}|${WORKFLOW_DIR_SED}|g" "${claude_command_dst}"

  INSTALLED_NAMES+=("$skill")
  echo "Installed ${skill} -> Codex skills, Claude commands"
}

# Shared protocol referenced by installed skills — keep a copy next to them so
# Codex-side relative reads also work even without the workflow repo path.
rm -rf "${CODEX_TARGET_DIR}/_shared"
cp -R "${SOURCE_DIR}/_shared" "${CODEX_TARGET_DIR}/_shared"
echo "Installed _shared (skill protocol)"

# Track what THIS installer owns so removed skills get pruned on the next run.
# Pruning only ever touches names recorded in the manifest (or the known legacy
# list below) — user-authored commands/skills in the same directories are never removed.
MANIFEST="${CODEX_TARGET_DIR}/.aidlc-manifest"
# Platform opt-in persists across runs: a plain re-run keeps the previous
# --platforms selection instead of silently pruning it. --platforms=none clears.
PLATFORMS_FILE="${CODEX_TARGET_DIR}/.aidlc-platforms"
LEGACY_REMOVED=("ctx-run")
INSTALLED_NAMES=()

if [[ $PLATFORMS_GIVEN -eq 0 && -f "$PLATFORMS_FILE" ]]; then
  PLATFORMS="$(paste -sd, "$PLATFORMS_FILE" 2>/dev/null || true)"
  [[ -n "$PLATFORMS" ]] && echo "Keeping previously selected platforms: ${PLATFORMS} (pass --platforms=none to remove)"
fi
if [[ "$PLATFORMS" == "none" ]]; then
  PLATFORMS=""
  rm -f "$PLATFORMS_FILE"
fi

prune_stale() {
  # Seed with the legacy list so prev is never an empty array
  # (bash 3.2 + set -u treats expanding an empty array as unbound).
  local prev=("${LEGACY_REMOVED[@]}")
  [[ -f "$MANIFEST" ]] && while IFS= read -r n; do [[ -n "$n" ]] && prev+=("$n"); done < "$MANIFEST"
  local name keep
  for name in "${prev[@]}"; do
    keep=0
    for cur in ${INSTALLED_NAMES[@]+"${INSTALLED_NAMES[@]}"}; do [[ "$cur" == "$name" ]] && keep=1 && break; done
    if [[ $keep -eq 0 ]]; then
      if [[ -d "${CODEX_TARGET_DIR}/${name}" || -f "${CLAUDE_COMMANDS_TARGET_DIR}/${name}.md" ]]; then
        rm -rf "${CODEX_TARGET_DIR:?}/${name}"
        rm -f "${CLAUDE_COMMANDS_TARGET_DIR}/${name}.md"
        echo "Pruned removed skill: ${name}"
      fi
    fi
  done
  printf '%s\n' ${INSTALLED_NAMES[@]+"${INSTALLED_NAMES[@]}"} > "$MANIFEST"
}

# Workflow skills: every directory under skills/ with a SKILL.md.
# Derived from the filesystem so a new or removed skill cannot drift from this list.
for src in "${SOURCE_DIR}"/*/; do
  skill="$(basename "$src")"
  [[ "$skill" == "_shared" ]] && continue
  install_skill_dir "$src"
done

# Platform skills (opt-in via --platforms=)
if [[ -n "$PLATFORMS" ]]; then
  if [[ "$PLATFORMS" == "all" ]]; then
    platform_list=()
    for d in "${PLATFORMS_DIR}"/*/; do
      [[ -d "${d}skills" ]] && platform_list+=("$(basename "$d")")
    done
  else
    IFS=',' read -r -a platform_list <<< "$PLATFORMS"
  fi

  # ${arr[@]+...} guard: bash 3.2 + set -u treats expanding an empty array as unbound.
  if [[ ${#platform_list[@]} -eq 0 ]]; then
    echo "No platforms found for --platforms=${PLATFORMS}" >&2
    exit 2
  fi
  # Validate every platform name BEFORE installing anything, so an unknown
  # platform cannot leave a partially-updated target behind.
  for p in ${platform_list[@]+"${platform_list[@]}"}; do
    [[ -n "$p" ]] || continue
    if [[ ! -d "${PLATFORMS_DIR}/${p}/skills" ]]; then
      echo "Unknown platform: ${p} (no ${PLATFORMS_DIR}/${p}/skills)" >&2
      exit 2
    fi
  done
  for p in ${platform_list[@]+"${platform_list[@]}"}; do
    [[ -n "$p" ]] || continue
    pdir="${PLATFORMS_DIR}/${p}/skills"
    count=0
    for src in "$pdir"/*/; do
      [[ -d "$src" ]] || continue
      install_skill_dir "$src"
      count=$((count+1))
    done
    echo "Platform ${p}: ${count} skill(s) installed"
  done
  printf '%s\n' ${platform_list[@]+"${platform_list[@]}"} | grep -v '^$' > "$PLATFORMS_FILE" || true
fi

prune_stale

echo
echo "Skill installation complete."
echo "Workflow root: ${WORKFLOW_DIR}"
echo "Codex target: ${CODEX_TARGET_DIR}"
echo "Claude commands target: ${CLAUDE_COMMANDS_TARGET_DIR}"
if [[ -z "$PLATFORMS" ]]; then
  echo "Platform skills not installed (opt-in): rerun with --platforms=android,ios,... or --platforms=all"
fi
echo
echo "Tip: set TEAM_AI_WORKFLOW_DIR in your shell rc so other tools can locate the workflow:"
echo "  export TEAM_AI_WORKFLOW_DIR=\"${WORKFLOW_DIR}\""
