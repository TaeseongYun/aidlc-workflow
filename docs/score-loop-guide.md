# Score Loop Guide — Dependency-Aware Score Loop

`/ctx-score-loop` is a loop-engineering feature that, **after** implementation, automatically and repeatedly scores dependencies and 4-axis verification, and judges completion **only when the score exceeds 85 (`> 85`)**. From a "single request to implement the code," it iterates autonomously without further user intervention.

> Key point: you do not need to repeatedly ask "please verify" every round. Once started, it runs on its own until the score exceeds 85 (or until stall/cap).

---

## 1. When to use

- When implementing a feature that has passed GATE-3 (implementation approval), and you want to auto-judge completion by objective scores across dependencies·build·test·AC.
- When multiple kinds of dependencies (functional ordering / build·library / inter-module) are entangled and you need to trace "where it is stuck."

Do not confuse this with readiness-score (readiness **before** implementation). This loop is an output score **after** implementation.

---

## 2. 4-axis score (25 each · 100 total)

| Axis | Meaning | Scoring basis |
|----|------|----------|
| Dependency resolution | Are all 3 kinds of dependencies satisfied | `dependency-check.md` checklist |
| Build/compile | Does it actually build with no compile errors | **build command execution result** (0 if not run) |
| Test/coverage | Do tests pass and is coverage at or above the bar | **test command execution result** (0 if not run) |
| Requirements/AC satisfaction | Are the intended Acceptance Criteria met | UOW acceptance criteria + requirements FR |

Detailed criteria: `core/dependency-score.md` / schema: `core/dependency-score.schema.yaml`

### Gating (preventing false completion)
- **If the build axis is 0, it is not complete even if it exceeds 85** (GR-1).
- If there is even 1 unresolved BLOCK dependency, the dependency axis is capped at 12 points (GR-2).
- The build·test axes **forbid estimated scoring** — only evidence of actually running the command is accepted.

---

## 3. Creating the dependency verification md

Place a `dependency-check.md` **inside each feature/module directory** that needs dependencies (distributed placement). Template: `templates/dependency-check.md`.

Classify the 3 kinds of dependencies as a checklist:
1. **Functional ordering** — e.g., "the login feature must be completed"
2. **Build/library** — e.g., "retrofit, hilt version config + build passing"
3. **Inter-module** — e.g., "feature-A calls/implements core-network API X"

The loop auto-generates/updates this file, but **preserves human-written items (`<!-- src: human -->`)**.

---

## 4. Execution

```text
/ctx-score-loop <feature-slug>
```

Optional arguments:
- `engine=ralph|evolve|native` (default ralph)
- `max_rounds=N`, `max_minutes=M` (default 10 / 30 — can also be overridden by the Loop Config in `dependency-check.md`)

### One-round flow
```
sync dependency md → actually run build·test → score 4 axes (evidence required)
  → verdict judgment → record Score History + report
```

### Termination/stop conditions

| verdict | Condition | Action |
|---------|------|------|
| COMPLETE | total > 85 AND build axis ≠ 0 | Report "complete (over 85)" then **terminate** |
| CONTINUE | above not met, not stall/cap/regression | Improve deficient axes, then next round |
| STALLED | 2 consecutive rounds with no score improvement | **Stop immediately**, report stuck axis·reason |
| EXHAUSTED | reached 10 rounds or 30 minutes | **Stop immediately**, report reason |
| REGRESSED | score dropped vs. previous | **Stop immediately**, report warning (no auto-rollback in v1) |

On stop, the loop **does not auto-restart** and waits for a human decision.

---

## 5. Examples

### To completion (S1)
```
[ctx-score-loop] coupon-feature — round 1
  dependency 18/25 · build 25/25 · test 12/25 · AC 20/25 = 75/100  (CONTINUE)
[ctx-score-loop] coupon-feature — round 2
  dependency 25/25 · build 25/25 · test 22/25 · AC 23/25 = 95/100  (COMPLETE)
  → complete (over 85). Loop terminated.
```

### Stopped by stall (S2)
```
[ctx-score-loop] coupon-feature — round 3 (STALLED)
  final 82/100. Stuck axis: inter-module dependency (core-network API not deployed)
  → Stopped. Waiting for human decision.
```

---

## 6. Relationship to other engines

- The default engine is OMC `ralph`. The termination condition "4-axis score > 85 & build axis ≠ 0" is injected into ralph (`docs/omc-ouroboros-integration.md` §2-2-S).
- If the measurable goal is strong, it can be replaced with Ouroboros `evolve`. The protocol (scoring criteria·termination judgment) is engine-independent.

---

## 7. Cautions

- This loop **does not auto-pass GATEs (human approval).** It operates only in the implementation section after GATE-3.
- Unsettled business policy (refund/settlement/permissions) is still a STOP condition.
- Completion is reported only when verification passes. On test failure/skip, state that fact explicitly.

---

## 8. Full example (walkthrough)

A walkthrough example that carries one feature all the way from `/ctx-aidlc-run` to `/ctx-score-loop`:

- `examples/score-loop-walkthrough/book-borrowing/` — the "book borrowing" feature
  - `README.md` — step-by-step flow
  - `requirements.md` / `requirement-verification-questions.md` / `unit-of-work.md` / `status.md` — `/ctx-aidlc-run` outputs
  - `dependency-check.md` — score-loop scoring input + Score History (75→82→92)
  - `LOOP-RUN.md` — per-round progress + stall/false-completion counterexamples
