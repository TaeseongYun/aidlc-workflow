# Error Recovery

Defines the recovery procedures for when an error or interruption occurs during workflow execution.

## 1. Error Severity Classification

| Severity | Description | Workflow Impact |
|--------|------|----------------|
| **CRITICAL** | Workflow cannot proceed | Missing required artifact, corrupted aidlc-state.md, required input cannot be processed |
| **HIGH** | Current STEP cannot be completed | BLOCK question unanswered, previous STEP artifact incomplete, contradiction unresolved |
| **MEDIUM** | Can proceed via a workaround | Conditional artifact missing, non-core validation failure |
| **LOW** | No impact on progress | Format inconsistency, optional information missing |

## 2. Session Resumption Procedure

The procedure for resuming in a new session after session separation (see `docs/workflow-guide.md`).

### 2.1 State Check (Required)

1. Read `aidlc-docs/aidlc-state.md`.
2. Check the following items:
   - Current Stage: How far has progress gotten?
   - Current Phase: Which stage among A / B / C?
   - Stage Progress checkboxes: Completed/skipped/not-started status
   - Confidence Summary: Status of uncertain answers

3. Present a summary of the current state to the user:
```markdown
## Session Resumption

- Feature: {feature-slug}
- Last completed: {last [x] STEP}
- Next step: {next not-started STEP}
- Unresolved items: {number of BLOCK questions, number of UNCERTAIN markers}

> A) Continue — {description of next step}
> B) Review previous step — check parts that need fixing
```

### 2.2 Artifact Integrity Verification

Before proceeding to the next STEP, verify that the previous artifacts required for that STEP exist and are valid.

| STEP to proceed | Required artifacts |
|-------------|-------------|
| STEP 4-5 | requirements.md or planning-draft.md |
| STEP 5.5 | requirements.md, requirement-verification-questions.md |
| STEP 5.7 | requirements.md, (if present) stories.md |
| STEP 6 | requirements.md |
| STEP 6.5 | unit-of-work.md |
| STEP 6.7 | unit-of-work.md, (if present) technical-design.md |
| STEP 7-8 | unit-of-work.md, requirements.md |
| STEP 9 | unit-of-work.md, requirements.md, Readiness Score >= 80 |

### 2.3 When an Inconsistency Is Found

**When marked as complete in aidlc-state.md but the artifact does not exist**:
1. Revert the corresponding STEP in aidlc-state.md to `[ ]`.
2. Re-run from that STEP.
3. Record a `[RECOVERY] STEP {N} — re-run due to missing artifact` event in `audit.md`.

**When the artifact exists but is marked as incomplete in aidlc-state.md**:
1. Verify that the artifact content is complete (required sections, whether any section is empty).
2. If complete, update aidlc-state.md to `[x]`.
3. If incomplete, re-run from that STEP.

## 3. Per-STEP Error Handling

### STEP 1 (Project Detection) Errors

**Cannot identify the project root**:
- Request that the user confirm the project path and structure.
- If progress is possible with minimal information (language, framework), substitute with the user-provided information.

**greenfield/brownfield judgment is uncertain**:
- If **even one** of existing code, DB, or operating system is present, judge it as brownfield.
- Record the basis for the judgment in `audit.md`.

### STEP 3-5 (Analysis/Questions/Requirements) Errors

**User provides contradictory answers**:
- Handle according to the contradiction detection rules in `content-validation.md`.
- Do not proceed to GATE-2 until the contradiction is resolved.

**Question answers are incomplete (only partially responded)**:
1. State the list of unanswered questions.
2. If a BLOCK question is unanswered, re-present that question.
3. If an ASSUME/AI-RECOMMEND question is unanswered, apply the no-response handling rules in `question-governance.md`.

### STEP 6 (Unit Decomposition) Errors

**Circular dependency found**:
1. State the cyclic relationship: "UOW-A → UOW-B → UOW-A".
2. Readjust the boundaries according to the decomposition criteria (`core/units-generation.md`).
3. After readjustment, obtain user confirmation at GATE-3.

### STEP 7 (Readiness Score) Errors

**Insufficient data for score calculation**:
- Score the missing domain as 0 (no bonus points).
- State it as a "Not Evaluated Domains" section in `status.md`.
- If 2 or more domains are not evaluated, automatically render a NOT_READY verdict.

## 4. Artifact Recovery Procedure

### When Artifact Regeneration Is Needed

1. Back up the existing artifact: `{filename}` → `{filename}.backup.md`
2. Record a `[RECOVERY] {filename} — regeneration started. Reason: {reason}` event in `audit.md`.
3. Re-run the corresponding STEP from the beginning.
4. After regeneration completes, preserve the backup file until the user approves its deletion.

### When aidlc-state.md Is Corrupted

1. Create a backup: `aidlc-state.md.backup`
2. Confirm the current progress with the user.
3. Reconstruct the state based on the list of artifacts present under `aidlc-docs/features/<feature-slug>/`.
4. Present the reconstruction result to the user and apply it after obtaining approval.
5. Record a `[RECOVERY] aidlc-state.md — reconstructed due to corruption` event in `audit.md`.

## 5. Rollback by User Request

### STEP Re-run Request

When the user is dissatisfied with the result of a specific STEP and requests a re-run:

1. Back up the artifact of that STEP.
2. Check **whether STEPs that depend on this STEP have already been completed**.
3. If there are dependent STEPs, warn the user:
   ```
   Re-running STEP {N} will also affect the artifacts of STEP {M}, {L}.
   Do you want to regenerate those artifacts as well?
   ```
4. Re-run after user approval.
5. Record a `[REDO] STEP {N} — re-run by user request` event in `audit.md`.

### Change Request at a GATE

When the user selects "request change" at a GATE:

1. Record the change request content verbatim in `audit.md`.
2. Judge the scope of the change:
   - **Partial change**: Modify only the relevant artifact and present the GATE again.
   - **Full rework**: Re-run the corresponding STEP from the beginning.
3. If the change also affects a previous STEP's artifact, notify the user.

## 6. audit.md Logging Format

Record recovery/error events in the format below.

```markdown
## [RECOVERY] {target}
- Timestamp: {ISO 8601}
- Feature: {feature-slug}
- Error Type: CRITICAL / HIGH / MEDIUM / LOW
- Description: {the problem that occurred}
- Resolution: {the action taken}
- Artifacts Affected: {list of affected files}
```

## 7. Prohibitions

- Do not ignore artifact corruption/absence and proceed to the next STEP.
- Do not regenerate an artifact without a backup.
- Do not reconstruct aidlc-state.md without user confirmation.
- Do not move on without recording the recovery event in audit.md.
