# Dependency Score

This is the standard for quantitatively evaluating whether the code, **after** implementation, satisfies the dependency and multi-axis verification criteria.

> This is the sibling document to `core/readiness-score.md` (pre-**implementation** requirements readiness). The timing and purpose differ.
> - readiness-score: before entering implementation, whether the requirements are implementable (once, right before the human GATE)
> - dependency-score: after implementation, whether the artifact is complete (the loop produces it repeatedly)

## Scoring areas (4 axes · 25 points each · 100 points total)

### 1. Dependency resolution (25 points)
Whether the items listed in the target feature/module's dependency verification md (`templates/dependency-check.md` structure) are resolved.

- All ordering dependencies between features are satisfied (8)
- All build/library dependencies are set up and resolved (8)
- All inter-module dependencies (API call/implementation) are satisfied (9)

Rules:
- Deduct proportionally to the ratio of unresolved items.
- If there is even one unresolved dependency marked as BLOCK, this area is capped at **12 points at most** (GR-2).

### 2. Build/compile pass (25 points)
Whether the code actually builds with no compile errors.

- The build command completes successfully (15)
- Warnings are below the threshold (5)
- Lint/static analysis passes (5)

Rules:
- **Only the result of actually running the build command (exit code/log) is accepted as evidence.** If the command was not run, this area is **0 points** (FR-4).
- Build command source: `build-instructions.md` or the UOW Verification section.

### 3. Test pass / coverage (25 points)
Whether the relevant tests pass and coverage is at or above the threshold.

- All relevant tests pass (15)
- Coverage is at or above the target threshold (5)
- Exception/edge-case tests exist (5)

Rules:
- **Only the result of actually running the test command (report) is accepted as evidence.** If the command was not run, this area is **0 points** (FR-4).
- If the coverage target is not defined, mark that 5 points as "not applicable" and exclude it from the maximum.

### 4. Requirements / AC fulfillment (25 points)
Whether the originally intended Acceptance Criteria are met.

- Each UOW's acceptance criteria in `unit-of-work.md` are met (15)
- The Functional Requirements in `requirements.md` are reflected (10)

Rules:
- The scoring criteria source is **UOW acceptance criteria + requirements Functional Requirements** (FR-5). Do not create other arbitrary criteria.

## Verdict criteria

| Score | Verdict | Meaning |
|------|------|------|
| 86~100 | COMPLETE | Fully closed (complete). But only when the gating rules pass. |
| 0~85 | INCOMPLETE | Not complete. Supplement the lacking axes and re-score. |

- The completion threshold is **greater than 85 (`score > 85`)**. Exactly 85 is incomplete.

## Gating rules (mandatory)

- **GR-1**: Even if the total exceeds 85, **do not judge COMPLETE if the build axis is 0 points.** Do not call code that fails to build "complete" (consistent with the project rule "no committing with a broken build").
- **GR-2**: If there is even one unresolved dependency classified as BLOCK, the dependency axis (area 1) is capped at 12 points.

## Score computation and iteration (loop)

- Compute the score every round and compare it with the previous round.
- Append the score history to the **Score History** table in the dependency verification md (`templates/dependency-check.md`).
- The termination/halt judgment follows the loop rules in `core/dependency-score-eval.md`.

## Rules

- Do not arbitrarily release a BLOCK dependency in order to raise the score.
- Record the score **together with rationale**. Do not write the number alone (inheriting the readiness-score rule).
- Do not score the build/test axes by estimation. Without execution evidence, it is 0 points.
- Mark undefined detail items such as the coverage target as "not applicable" rather than 0 points, and exclude them from the maximum calculation.

## Structured schema
For automated scoring and programmatic reference: `core/dependency-score.schema.yaml`
