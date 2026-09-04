#!/usr/bin/env bash
# aidlc-log.sh — one call per workflow event: append the audit.md block (the
# templates/audit.md "Logging Triggers" format) and update aidlc-state.md in the
# same call. Replaces the Read+Edit round-trips the skills spent on bookkeeping.
#
# Usage (run from the project root; override the docs dir with AIDLC_DOCS=<dir>):
#   aidlc-log.sh step    <feature> <STEP-ID> "<name>" started|completed|skipped ["reason"] ["outputs"]
#   aidlc-log.sh gate    <feature> <GATE-ID> "<name>" approved|change-requested|skipped "<user text>" ["notes"]
#   aidlc-log.sh answer  <feature> "<question>" "<user text>" "<impact>"
#   aidlc-log.sh status  <feature> "<previous>" "<current>" "<trigger>"
#   aidlc-log.sh handoff <feature> <from-skill> <to-skill> "<reason>" "<resume hint>"
#   aidlc-log.sh set     "<Field>" "<value>"     # replace the first "- <Field>:" line in aidlc-state.md
# IDs: STEP-4 / "STEP 4" / STEP-1-C / STEP-R2 / GATE-3.5 (audit writes STEP-4, state matches "STEP 4:").
# Exit: 0 ok (silent) · 1 usage · 2 aidlc-docs files missing (fall back to manual Edit).
set -euo pipefail

DOCS="${AIDLC_DOCS:-aidlc-docs}"
AUDIT="${DOCS}/audit.md"
STATE="${DOCS}/aidlc-state.md"

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- aidlc-state.md edits go through awk -> tmp -> mv (same on BSD and GNU) ---
state_edit() { # state_edit <awk-program> [-v var=value ...]
  local prog=$1; shift
  awk "$@" "$prog" "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
}
set_field() { # set_field "Field" "value" -> first line starting with "- Field:"
  state_edit '
    !done && index($0, "- " key ":") == 1 { print "- " key ": " val; done = 1; next }
    { print }' -v key="$1" -v val="$2"
}
mark_box() { # mark_box "<STATE LABEL>" x|- ["reason"] -> "- [ ] LABEL:" becomes "- [x] LABEL:" / "- [-] LABEL: ... (reason)"
  state_edit '
    !done {
      i = index($0, "- [ ] " lbl ":")
      if (!i) i = index($0, "- [x] " lbl ":")
      if (!i) i = index($0, "- [-] " lbl ":")
      if (i) {
        line = substr($0, 1, i - 1) "- [" mark "] " substr($0, i + 6)
        if (mark == "-" && reason != "" && index(line, "(" reason ")") == 0) line = line " (" reason ")"
        print line; done = 1; next
      }
    }
    { print }' -v lbl="$1" -v mark="$2" -v reason="${3:-}"
}
audit_append() { printf '\n%s\n' "$1" >> "$AUDIT"; }
norm_ids() { # sets AID (audit form STEP-4) and SLBL (state form "STEP 4") from "$1"
  case "$1" in
    STEP-*)  AID=$1; SLBL="STEP ${1#STEP-}" ;;
    STEP\ *) SLBL=$1; AID="STEP-${1#STEP }" ;;
    *)       AID=$1; SLBL=$1 ;;
  esac
}

[[ $# -ge 1 ]] || usage
cmd=$1; shift
case "$cmd" in -h|--help|help) usage ;; esac
if [[ ! -f "$AUDIT" || ! -f "$STATE" ]]; then
  echo "aidlc-log: ${AUDIT} or ${STATE} missing — run scripts/init-project.sh, or update the files by hand" >&2
  exit 2
fi
now=$(ts)

case "$cmd" in
  step)
    [[ $# -ge 4 ]] || usage
    feature=$1; norm_ids "$2"; name=$3; action=$4; reason=${5:-}; outputs=${6:-}
    case "$action" in started|completed|skipped) ;; *) usage ;; esac
    block="## [${AID}] ${name} — ${action}
- Timestamp: ${now}
- Feature: ${feature}
- Step: ${AID}
- Action: ${action}"
    if [[ -n "$reason" ]]; then block="${block}
- Reason: ${reason}"; fi
    if [[ -n "$outputs" ]]; then block="${block}
- Outputs: ${outputs}"; fi
    audit_append "$block"
    case "$action" in
      started)   set_field "Current Stage" "${SLBL}: ${name}" ;;
      completed) mark_box "$SLBL" x ;;
      skipped)   mark_box "$SLBL" - "$reason" ;;
    esac ;;
  gate)
    [[ $# -ge 5 ]] || usage
    feature=$1; norm_ids "$2"; name=$3; decision=$4; user_input=$5; notes=${6:-}
    case "$decision" in approved|change-requested|skipped) ;; *) usage ;; esac
    audit_append "## [${AID}] ${name}
- Timestamp: ${now}
- Feature: ${feature}
- Gate: ${AID}
- Decision: ${decision}
- User Input: \"${user_input}\"
- Notes: ${notes}"
    case "$decision" in
      approved) mark_box "$SLBL" x ;;
      skipped)  mark_box "$SLBL" - "$notes" ;;
    esac ;;
  answer)
    [[ $# -ge 4 ]] || usage
    audit_append "## [ANSWER] question answer
- Timestamp: ${now}
- Feature: $1
- Question: $2
- User Input: \"$3\"
- Impact: $4" ;;
  status)
    [[ $# -ge 4 ]] || usage
    audit_append "## [STATUS] status change
- Timestamp: ${now}
- Feature: $1
- Previous: $2
- Current: $3
- Trigger: $4"
    set_field "Feature Status" "$3" ;;
  handoff)
    [[ $# -ge 5 ]] || usage
    audit_append "## [HANDOFF] $2 → $3
- Timestamp: ${now}
- Feature: $1
- From: $2
- To: $3
- Reason: $4
- Resume Hint: $5" ;;
  set)
    [[ $# -eq 2 ]] || usage
    set_field "$1" "$2" ;;
  *) usage ;;
esac
set_field "Last Updated" "$now"
