# Dependency Score — Evaluation Procedure

This is the protocol for how the loop executes **one round** of 4-axis scoring.
The scoring criteria follow `core/dependency-score.md`, and the schema follows `core/dependency-score.schema.yaml`.

## Input
- The dependency verification md of the target feature/module (`templates/dependency-check.md` structure)
- `unit-of-work.md` (AC scoring criteria)
- `requirements.md` Functional Requirements (AC scoring criteria)
- Build/test commands (source: `build-instructions.md`, `test-instructions.md`, or the UOW Verification section)

## One-round scoring procedure

### STEP A. Sync the dependency md (S-1)
1. If the dependency md does not exist, create it from `templates/dependency-check.md`.
2. Detect and update dependencies, but follow the **source-marker merge rule**:
   - `<!-- src: human -->` items: read-only. No editing/deleting.
   - `<!-- src: auto -->` items and newly auto-detected items: update.
   - Items with no marker: treat as human, preserve.

### STEP B. Actually run build/test (S-3)
1. **Actually run** the build command and collect the exit code/log.
2. **Actually run** the test command and collect the report.
3. If a command was not run or could not be found, treat that axis as **0 points** (FR-4). No estimated scoring.

### STEP C. 4-axis scoring (S-2)
Score each axis by the `core/dependency-score.md` criteria and **record a rationale sentence as mandatory**.

1. **Dependency resolution (25)**: proportional scoring by the resolution ratio of the md checklist. If there is one or more unresolved BLOCK, at most 12 points (GR-2).
2. **Build/compile (25)**: rationale from STEP B's build result. 0 points if not run.
3. **Test/coverage (25)**: rationale from STEP B's test result. 0 points if not run. If the coverage target is undefined, mark that 5 points as "not applicable" and exclude from the maximum.
4. **Requirements/AC (25)**: score by UOW acceptance criteria + requirements FR (FR-5).

Round the score to an integer.

### STEP D. Termination/halt judgment (S-4)
Determine the verdict from the total and the Score History:

```
if build_axis == 0:                        verdict = INCOMPLETE  (GR-1: cannot complete)
elif total > 85:                           verdict = COMPLETE
elif round_count >= max_rounds
     or elapsed_time >= max_minutes:       verdict = EXHAUSTED
elif total < prev_total:                   verdict = REGRESSED
elif improvement over last stall_rounds == 0: verdict = STALLED
else:                                      verdict = CONTINUE
```

- Improvement judgment: if the total gained less than +1 versus the previous round, treat it as "no improvement".
- Default parameters: complete_threshold=85 (exceed), stall_rounds=2, max_rounds=10, max_minutes=30. Overridable via the dependency md's Loop Config (ADR-5).

### STEP E. Record/report (S-5)
1. Append one row `round | total | per_axis | verdict | ts(UTC)` to the Score History.
2. Mirror the Post-Implementation Score (latest total) in status.md.
3. Behavior per verdict:
   - `COMPLETE`: report "complete (exceeds 85)" and terminate the loop.
   - `CONTINUE`: supplement-implement the lacking axes and go to the next round (STEP A).
   - `STALLED` / `EXHAUSTED` / `REGRESSED`: **halt immediately**, report the blocked axis/item, current score, and reason, **no automatic restart** (FR-13). Wait for a human decision.
4. When recording to audit, use the `[LOOP]` prefix.

## Prohibitions
- Do not score the build/test axes by estimation without running commands (treated as 0 points).
- Do not arbitrarily release a BLOCK dependency in order to raise the score.
- Do not record the number alone without rationale.
- Do not declare COMPLETE while the build is 0 points (GR-1).
- Do not automatically restart after a halt without human approval.
- Do not auto-pass a GATE (human approval). The loop operates only in the range after GATE-3.
