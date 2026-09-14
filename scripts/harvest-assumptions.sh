#!/usr/bin/env bash
# Harvest unverified AI assumptions from aidlc-docs artifacts.
# Every hit is a claim the AI made under uncertainty -> raw input for /ctx-hallucination-audit.
# Recall over precision: over-harvests on purpose; the audit's VERIFY step filters.
#
# Usage: scripts/harvest-assumptions.sh [scope]   (default scope: aidlc-docs)
set -euo pipefail

SCOPE="${1:-aidlc-docs}"

if [[ ! -e "$SCOPE" ]]; then
  echo "scope not found: $SCOPE (nothing to harvest yet)"
  exit 0
fi

# The workflow's own uncertainty markers + generic hedging words.
PATTERN='UNCERTAIN|RISK:|TODO:|Confidence: Estimated|Confidence: AI-Recommended|확신: 추정|확신: AI추천|ASSUME|추정|가정|probably|likely|should be|I think|by convention|typically'

echo "# Harvested assumptions (scope: $SCOPE)"
echo "# Each line 'file:line: text' is a claim to VERIFY against graphify/code/ctx/docs."
echo

# --no-ignore/--hidden: match grep's behavior so the harvest is identical
# whichever tool is installed (rg would otherwise honor .gitignore and skip
# hidden files, giving a different audit input on different machines).
if command -v rg >/dev/null 2>&1; then
  rg -n --no-heading --no-ignore --hidden -g '!.git' -e "$PATTERN" -- "$SCOPE" || echo "(none found — clean)"
else
  grep -rnE --exclude-dir=.git -- "$PATTERN" "$SCOPE" || echo "(none found — clean)"
fi
