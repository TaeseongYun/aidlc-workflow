# 2026-04-29: Blocking STEP 4/GATE-2 Skips on prepared-requirement

## Background

During hands-on use, a problem was reported where, on `prepared-requirement` input, the AI passed STEP 1-C (input validation) and then jumped straight to STEP 6 (UOW), implicitly passing through GATE-2 without receiving STEP 4 question answers.

Cause analysis:
1. The `SKILL.md` phrasing "Prepared requirements should skip raw-request artifacts" was ambiguous, so the model over-interpreted it as "if prepared, skip the pre-stages entirely"
2. STEP 1-A's "skip rounds 1-3" (Discovery-only) could be generalized as skipping all the way to STEP 4 (verification questions)
3. The "gate skipping" in `stage-gate-rules.md` was a blacklist-style enumeration, so it could not enforce that GATE-2 is explicitly non-skippable
4. The validation-pass message in `input-validation.md` ("Proceeding to STEP 2") encouraged auto-jumping and did not indicate that STEP 4/GATE-2 proceed separately
5. Absence of a guardrail for the case of passing STEP 4 with 0 questions

## Changes

### 1. SKILL.md / CLAUDE_COMMAND.md — limit prepared skip scope + enforce STEP 4

**Files**: `skills/ctx-aidlc-run/SKILL.md`, `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

- "Prepared requirements should skip raw-request artifacts." → limit the skip target to `request-intake.md`, `planning-draft.md`, and GATE-1. State that STEP 4 and GATE-2 are still performed.
- Added a "per-classification enforcement rule" block to STEP 4 (SKILL.md / CLAUDE_COMMAND.md in sync):
  - STEP 4 is mandatory even for `prepared-requirement` / `change-on-existing-feature`
  - Empty areas identified in STEP 1-C are converted into BLOCK questions in STEP 4
  - If 0 P0/P1 questions are produced, no standalone pass — re-run omission detection or record in audit.md after explicit user confirmation
- Added an explicit non-skippable line to GATE-2 (SKILL.md / CLAUDE_COMMAND.md in sync):
  - Non-skippable in any request classification; direct entry to STEP 6 prohibited
  - No pass if even one unanswered BLOCK question exists

> The two files have different surfaces (skill harness vs. Claude slash command), so they must always be updated together. If only one is modified, the old rule remains exposed on one surface even after `scripts/install-skills.sh` reinstall.

### 2. stage-gate-rules.md — whitelist gate skipping

**File**: `common/stage-gate-rules.md`

- Converted the "gate skipping" section into a whitelist table. Any gate not listed in the table is non-skippable under any classification or condition.
- Skippable gates: GATE-1 / GATE-2.5 / GATE-2.7 / GATE-4 / GATE-5
- New "explicitly non-skippable gates" item: GATE-2 / GATE-3 / GATE-3.5
- Reinforced the "user bulk approval" rule: even when "skip gate" or "approve all" is stated, non-skippable gates are excluded from bulk skipping.

### 3. input-validation.md — add follow-up-stage guidance

**File**: `core/input-validation.md`

- Changed the validation-pass message to "Validation passed. Proceeding to STEP 2. However, STEP 4 question generation and GATE-2 are performed separately."
- New "Follow-up-stage guidance (required)" section:
  - Regardless of the validation result, the STEP 2 → 3 → 4 → 5 → GATE-2 flow is all performed
  - Even if the input document looks sufficient, do not skip STEP 4 question generation
  - GATE-2 is non-skippable even for prepared-requirement; entering STEP 6 without user approval is prohibited
  - "Validation passed = decision complete" is false; validation is only a form check, not a policy/design agreement

## Full list of modified files

| File | Change type |
|------|------------|
| `skills/ctx-aidlc-run/SKILL.md` | Limit skip scope + STEP 4 per-classification enforcement rule + GATE-2 non-skippable |
| `skills/ctx-aidlc-run/CLAUDE_COMMAND.md` | Same rules updated in parallel (Claude slash-command surface) |
| `common/stage-gate-rules.md` | Whitelist gate skipping |
| `core/input-validation.md` | Fixed validation-pass message + added follow-up-stage guidance |
| `README.md` | Updated changelog |

## Expected effect

- The path where the AI jumps straight to STEP 6 after passing STEP 1-C on prepared input is blocked on both the SKILL.md and stage-gate-rules.md sides.
- The scope of "skip" is fixed by whitelist, reducing the room for the model to arbitrarily over-interpret it.
- Since passing STEP 4 with 0 questions requires explicit user confirmation, a missing pre-review becomes visible in audit.md.
