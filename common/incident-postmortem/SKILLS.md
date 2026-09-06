# Incident Response & Postmortem — Skills

Actionable procedure an agent (or engineer) runs to handle a production incident and review it
afterward. This is the *how*; the *what/why* reference is [`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-hallucination-audit` (captures durable lessons to
  `aidlc-docs/knowledge-log.md` — the knowledge-capture parallel to postmortem action items).
- **Cross-links**: [`../code-review/reference/guide.md`](../code-review/reference/guide.md)
  (a bad change is the most common incident cause),
  [`../ci-cd-automation/reference/guide.md`](../ci-cd-automation/reference/guide.md)
  (rollback, canary, and deploy gates are your fastest mitigations).
- **Platform-agnostic**: applies on any stack. Platform-specific runbooks live under `platforms/<platform>/`.

## When to use

Any time a service is disrupted or degraded in a way that matters to users, or when reviewing
such an event afterward. Also for near-misses caught before impact — they teach cheaply.

## Inputs

- The signal — an alert, monitor, or user report. If severity is unclear, over-declare.
- System access — logs, metrics, deploy history, and the ability to roll back / fail over.
- Recent changes — the last deploys, config edits, and traffic shifts (the usual suspects).

## Outputs

- **During**: a declared severity, named roles, status updates on cadence, and a mitigation applied.
- **After**: a blameless postmortem with a timeline, contributing factors, and owned action items.

## Procedure — during the incident

1. **Detect and own it.** Acknowledge the signal. One person owns the incident until handed off.
2. **Declare severity** (see guide's table). When torn between two levels, pick the higher.
3. **Assign roles** for SEV2+ : Incident Commander, Comms/Scribe, Ops. Open a channel/bridge.
4. **Mitigate first.** Stop the harm with the fastest reversible move — roll back, fail over,
   flag off, scale up — *before* diagnosing. Do not debug in prod while users are down.
5. **Communicate on cadence.** Post what's affected, what you're doing, and the next-update
   time. Keep posting, even "no change yet," until resolved.
6. **Scribe the timeline live.** Timestamp (UTC) each change, action, and effect as it happens —
   memory is worse and the logs may rotate.
7. **Resolve.** Confirm metrics are healthy and stable for a defined window, then declare the
   incident over. Mitigated is not resolved.

## Procedure — the postmortem

8. **Build the timeline** from evidence: change → impact start → detection → actions →
   mitigation → resolution. Mark the gaps.
9. **Find contributing factors,** not a single cause. Run 5 Whys past "human error" to the
   systemic condition. Test each candidate: *if we fix only this, does this class stop recurring?*
10. **Write action items,** each with a named owner and a real due date, categorized
    prevent / detect / mitigate. "Be more careful" is not an action item.
11. **Capture the lesson.** File action items in the tracker; record any durable wrong-assumption
    lesson to `aidlc-docs/knowledge-log.md` (as `/ctx-hallucination-audit` does).
12. **Publish blamelessly** and track every action item to done.

## Decision rules

- Impact unclear or growing → **declare higher severity**; de-escalate later if wrong.
- User impact ongoing → **mitigate before diagnosing**; reversible fix beats correct-but-slow fix.
- Root cause reads "human error" or "be more careful" → **not done**; find the systemic gap.
- Action item has no owner or no date → **not an action item**; assign both or drop it.
- Incident felt "too small for a postmortem" → **still do a lightweight one**; near-misses teach.

## Stop / escalate

- Suspected security breach or data loss/corruption → treat as SEV1, engage security/privacy
  owners; preserve evidence before any cleanup.
- Blast radius or blame is a policy/people decision → escalate to a human owner; an agent must
  not assign fault or make retention/customer-impact calls.
- Mitigation requires irreversible action (data deletion, destructive migration) → get a human
  to confirm; prefer any reversible path first.

## Output format

```markdown
## Incident: <title>  —  SEV<n>  —  status: <mitigating | resolved>

Impact: <who/what, when it started>
IC: <name>  Comms: <name>  Ops: <name>

### Timeline (UTC)
- HH:MM  change:     <deploy/config/traffic event>
- HH:MM  impact:     <users first affected>
- HH:MM  detected:   <how>
- HH:MM  mitigated:  <action → effect>
- HH:MM  resolved:   <stable>

### Contributing factors
- <systemic condition that had to hold>  (not "person X did Y")

### Action items
- [prevent] <fix> — owner: <name> — due: <date>
- [detect]  <alert/monitor> — owner: <name> — due: <date>
- [mitigate]<guardrail> — owner: <name> — due: <date>
```

## Quick checklist

- [ ] Severity declared (higher when in doubt); roles named for SEV2+
- [ ] Harm mitigated before diagnosing; reversible move preferred
- [ ] Status updates posted on cadence
- [ ] Timeline built from evidence with UTC timestamps
- [ ] Contributing factors found; no stopping at "human error"
- [ ] Every action item has an owner and a due date, tracked to done
- [ ] Postmortem is blameless; durable lesson logged to knowledge-log
