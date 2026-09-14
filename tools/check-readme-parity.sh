#!/usr/bin/env bash
# Translation parity: every skill listed in README.md's skill table must also
# appear in README.ko.md and README.zh.md, so translations cannot silently lag.
# Usage: bash tools/check-readme-parity.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0

skills=$(grep -oE '^\| `/[a-z-]+`' "$ROOT_DIR/README.md" | grep -oE '/[a-z-]+' | sort -u)
count=$(echo "$skills" | wc -l | tr -d ' ')
if [[ -z "$skills" || "$count" -lt 10 ]]; then
  echo "ERROR: could not extract a plausible skill table from README.md (got $count rows)" >&2
  exit 1
fi

for translation in README.ko.md README.zh.md; do
  missing=""
  while IFS= read -r s; do
    grep -q -- "$s" "$ROOT_DIR/$translation" || missing="$missing $s"
  done <<< "$skills"
  if [[ -n "$missing" ]]; then
    echo "[FAIL] $translation is missing skill(s):$missing"
    fails=$((fails+1))
  else
    echo "[PASS] $translation lists all $count skills"
  fi
done

# The skill table must also match the actual skills/ directory.
dir_skills=$(cd "$ROOT_DIR/skills" && ls -d */ | tr -d '/' | grep -v '^_shared$' | sed 's#^#/#' | sort)
table_vs_dir=$(comm -3 <(echo "$skills") <(echo "$dir_skills") || true)
if [[ -n "$table_vs_dir" ]]; then
  echo "[FAIL] README.md skill table != skills/ directory:"
  echo "$table_vs_dir" | sed 's/^/    /'
  fails=$((fails+1))
else
  echo "[PASS] README.md skill table matches skills/ directory ($count)"
fi

if [[ $fails -gt 0 ]]; then exit 1; fi
