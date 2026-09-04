#!/usr/bin/env bash
# md-section.sh FILE "HEADING" [HEADING...] — print only the requested section(s) of a
# markdown file instead of loading the whole document into context.
# A section runs from the heading line whose text starts with HEADING (e.g. "## Gate List",
# "### GATE-2:") to the line before the next heading of the same or a higher level.
# Lines inside ``` fences are never treated as headings. Exit 1 if any heading is missing.
set -euo pipefail
[[ $# -ge 2 ]] || { echo "usage: md-section.sh FILE HEADING [HEADING...]" >&2; exit 1; }
file=$1; shift
[[ -f "$file" ]] || { echo "md-section: no such file: $file" >&2; exit 1; }
rc=0
for want in "$@"; do
  out=$(awk -v want="$want" '
    /^```/ { fence = !fence }
    !fence && /^#+ / {
      lvl = length($1)
      if (on && lvl <= wlvl) exit
      if (!on && index($0, want) == 1) { on = 1; wlvl = lvl }
    }
    on { print }
  ' "$file")
  if [[ -z "$out" ]]; then
    echo "md-section: heading not found in $file: $want" >&2; rc=1
  else
    printf '%s\n\n' "$out"
  fi
done
exit $rc
