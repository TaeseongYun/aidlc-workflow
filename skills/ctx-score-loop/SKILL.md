---
description: Dependency-aware score loop — implement once, then auto-iterate 4-axis scoring until >85 or stalled
model: opus
allowed-tools: Read, Write, Edit, Bash, Skill
---

# ctx-score-loop

A loop that, **after** implementation, automatically and repeatedly scores dependencies and the 4-axis verification, and judges as **complete only when the score exceeds 85**.
With "a single request to implement the code," it iterates autonomously without additional user intervention.

Framework root: `{{TEAM_AI_WORKFLOW_DIR}}`

## Input
- `<feature-slug>` or the target feature/module path (required)
- `engine`: `ralph` (default) / `evolve` / `native` (optional)
- Cap overrides: `max_rounds`, `max_minutes` (optional, default 10/30)

## Hard Preconditions
- Shared execution protocol: `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md` (halt format, execution boundary).
- Run only on features that have passed GATE-3 (implementation approval). This loop **does NOT auto-pass GATEs.**
- Scoring criteria: `{{TEAM_AI_WORKFLOW_DIR}}/core/dependency-score.md`
- Scoring procedure: `{{TEAM_AI_WORKFLOW_DIR}}/core/dependency-score-eval.md`
- Dependency md structure: `{{TEAM_AI_WORKFLOW_DIR}}/templates/dependency-check.md`

## Execution Flow (one request → autonomous iteration)

```
[1 request] → loop starts
  repeat {
    STEP A: Sync dependency md (merge preserving human items)
    STEP B: Actually run build/test commands (unrun axis = 0 points)
    STEP C: 4-axis scoring (25 points each, rationale required)
    STEP D: verdict judgment
    STEP E: Append Score History + mirror to status.md + run log + report
  } until verdict != CONTINUE
```

Judgment rules (`dependency-score-eval.md` STEP D):
- `COMPLETE` (total > 85 AND build axis ≠ 0): report "complete (over 85)" then **terminate**.
- `CONTINUE`: implement to fill the lacking axis, then next round.
- `STALLED` (2 consecutive rounds without improvement) / `EXHAUSTED` (10 rounds or 30 minutes) / `REGRESSED` (score dropped): **halt immediately**, report the blocked axis, score, and reason, **no auto-restart**, wait for human decision.

## Gating (required)
- **GR-1**: If the build axis is 0, do NOT mark COMPLETE even when total > 85.
- **GR-2**: If there is 1 or more unresolved BLOCK dependency, cap the dependency axis at 12 points.

## Engine Delegation
- Default `ralph`: use the handoff path in `docs/omc-ouroboros-integration.md` §2-2. Inject the termination condition "dependency md 4-axis score > 85 & build axis ≠ 0".
- `evolve` / `native`: pass the same termination condition to that engine. The protocol is engine-independent.

## Report Format
```
[ctx-score-loop] <feature-slug> — round N
  Dependency 22/25 · Build 25/25 · Test 20/25 · AC 23/25 = 90/100
  verdict: COMPLETE (over 85)
  → Complete. Loop terminated.
```
On halt:
```
[ctx-score-loop] <feature-slug> — STALLED at round N
  Final 82/100. Blocked axis: Test (15/25 — 2 CouponTest failures)
  → Halted. Waiting for human decision.
```

## Prohibitions
- Do NOT estimate-score the build/test axes without running the commands (0 points).
- Do NOT arbitrarily release BLOCK dependencies to raise the score.
- Do NOT record numbers only, without rationale.
- Do NOT auto-restart after a halt without human approval.
- Do NOT auto-pass GATEs.
- Do NOT modify/delete human-authored dependency md items (`<!-- src: human -->`).

## Run Log (result capture)
On each round's STEP E, also append the verdict to the structured run log so later runs (and graphify)
can retrieve it. Protocol: `{{TEAM_AI_WORKFLOW_DIR}}/common/run-logging.md`.
```bash
npx tsx {{TEAM_AI_WORKFLOW_DIR}}/scripts/run-logger.ts append --project . \
  --feature <feature-slug> --skill ctx-score-loop --phase score-round-<N> --kind score \
  --result "<verdict> <total>/100" --refs "dependency-check.md,status.md"
```
When a round closes `COMPLETE`, append a second `--kind unit` entry marking the unit finished.

## Detailed Guide
`{{TEAM_AI_WORKFLOW_DIR}}/docs/score-loop-guide.md`
