# Core Workflow

This document is the AI judgment flow common to all projects.

## 1. Determine project state
- First determine whether the current work is `greenfield` or `brownfield`.
- If there is existing code, DB, operational flow, or external integration, treat it as `brownfield`.

## 2. Conditions to start requirements analysis
- New feature request
- Policy change request
- Existing feature extension request
- Bug fix with structural impact

## 3. Common order of execution
0. (For a multi-feature prepared-requirement) Perform Phase 0 — Roadmapping first (`ctx-aidlc-roadmap`). Produce feature decomposition, resource matrix, dependency graph, and division-of-work recommendation, and after passing GATE-0, enter the per-feature flow.
1. Explore the current project structure and related domains.
1-A. (For a raw-request) Clarify the request via Discovery questions. If the answer is multi-feature and there is no `_roadmap.md`, hand off to Phase 0.
1-B. Determine the Depth Level (`common/depth-levels.md`). minimal / standard / comprehensive.
1-C. (For a prepared-requirement) Perform input document validation (`core/input-validation.md`).
1.5. (For brownfield with no existing RE artifacts) Perform Reverse Engineering (`core/reverse-engineering.md`).
2. Decompose the requirements into functional/policy/operational perspectives.
3. Convert blanks that require assumptions into questions. Question governance follows `common/question-governance.md`.
4. Do not finalize design decisions before questions are answered. Contradictions in answers are verified via `common/content-validation.md`.
5. After the answers, fix the requirements document.
5.5. (Conditional) Define user stories.
5.7. (Conditional) Design the system structure.
6. Proceed with unit decomposition and design.
6.5. (Conditional) Proceed with technical design.
6.7. (Conditional) Proceed with infrastructure design.
7. Before implementation, check for missing tests/operations/NFR.
8. Compute the Readiness Score and judge whether implementation is possible.
9. (Conditional) Write the build and test guides.

## 4. Cases where a question MUST be generated
- When multiple designs are all possible
- When there is payment/refund/settlement/authorization/security/operational impact
- When the user screen flow is not decided
- When the external system integration method is not finalized
- When data model extension is required

## 5. Cases where you can proceed without questions
- A simple change that can be handled with the same pattern as existing project rules
- When the domain/state/policy decision is already specified in `ctx/`, `AGENTS.md`

## 6. Approval gates
After writing major artifacts, obtain user approval according to `common/stage-gate-rules.md`.
- GATE-0: roadmap review (for a multi-feature prepared-requirement)
- GATE-1: planning-draft review (for a raw-request)
- GATE-2: requirements + questions review
- GATE-2.5: user-stories review (when User Scenarios >= 3 or a new user type, conditional)
- GATE-2.7: application-design review (when UOW >= 3 expected or a new component is created, conditional)
- GATE-3: unit-of-work review
- GATE-3.5: technical-design review (when there are M/L sized units)
- GATE-4: infrastructure-design review (when an infrastructure change is required, conditional)
- GATE-5: build/test-instructions review (when there are M/L sized units, conditional)
If a gate is not passed, do not proceed to the next step.

## 7. Diagrams
If artifacts require visuals such as state transitions, dependencies, or flows, follow `common/diagram-standards.md`.
- Simple flow: ASCII
- Complex relationships: Mermaid (text alternative required)

## 8. Artifacts

### Project-level artifacts (brownfield only)
- `aidlc-docs/reverse-engineering/business-overview.md` (STEP 1.5)
- `aidlc-docs/reverse-engineering/architecture-overview.md` (STEP 1.5)
- `aidlc-docs/reverse-engineering/component-inventory.md` (STEP 1.5)

### Project-level artifacts (multi-feature prepared-requirement only)
- `aidlc-docs/_roadmap.md` (Phase 0 / GATE-0, producer: `ctx-aidlc-roadmap`)

### Mandatory artifacts
- `aidlc-docs/aidlc-state.md`
- `aidlc-docs/audit.md`
- `aidlc-docs/features/<feature-slug>/status.md`
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`

### Conditional artifacts — INCEPTION extension
- `aidlc-docs/features/<feature-slug>/user-stories/personas.md` (User Scenarios >= 3 or a new user type)
- `aidlc-docs/features/<feature-slug>/user-stories/stories.md` (same condition as above)
- `aidlc-docs/features/<feature-slug>/application-design/components.md` (UOW >= 3 expected or a new component)
- `aidlc-docs/features/<feature-slug>/application-design/services.md` (same condition as above)
- `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md` (same condition as above)

### Conditional artifacts — CONSTRUCTION
- `aidlc-docs/features/<feature-slug>/technical-design.md` (when there are M/L sized units)
- `aidlc-docs/features/<feature-slug>/infrastructure-design.md` (when an infrastructure change is required)
- `aidlc-docs/features/<feature-slug>/deployment-architecture.md` (when an infrastructure change is required)
- `aidlc-docs/features/<feature-slug>/build-instructions.md` (when there are M/L sized units)
- `aidlc-docs/features/<feature-slug>/test-instructions.md` (when there are M/L sized units)

### Conditional artifacts — Extension
- `aidlc-docs/features/<feature-slug>/extensions/security-baseline.md` (when the user opts in)

## 9. Document update after finalizing the commit plan (mandatory)
Once the commit plan is finalized, the documents below must be updated.
- `aidlc-docs/features/<feature-slug>/status.md`: reflect the current state
- `aidlc-docs/audit.md`: append the commit-plan-finalized event

## 10. Real-time update rules for audit.md / aidlc-state.md

### audit.md (append-only)
When the events below occur, **immediately** append to `aidlc-docs/audit.md`.
- **STEP start/complete**: record on every STEP entry and completion. Record the skip reason even when a conditional STEP is skipped.
- **GATE pass**: record on user approval/change request/skip.
- **User input**: record on BLOCK/ASSUME question answers and Discovery round responses.
- **State change**: record when the feature status changes.
The format follows the logging trigger section of `templates/audit.md`.

### aidlc-state.md
When the events below occur, **immediately** update `aidlc-docs/aidlc-state.md`.
- **STEP complete/skip**: update the corresponding checkbox to `[x]` or `[-]`.
- **GATE pass**: update the corresponding checkbox to `[x]`.
- **Current Stage**: always update to the STEP currently in progress.
- **Feature Status**: update to the latest value on state change.
- **Readiness Score**: update on computation/change.
- **Last Updated**: update the timestamp on every update.

## 11. Overconfidence prevention
In AI-led steps (STEP 6, 6.5, 6.7) and Readiness Score computation (STEP 7), apply the `common/overconfidence-prevention.md` rules.
- Attach a `⚠️ UNCERTAIN` marker to uncertain judgments.
- After writing an artifact, perform Self-Verification before presenting the gate.
- Perform missing-question detection on STEP 3 completion.

## 12. Error recovery
If an error, session interruption, or artifact corruption occurs during workflow execution, follow the `common/error-recovery.md` procedure.
- On session resume, verify consistency between aidlc-state.md and the actual artifacts.
- On finding an inconsistency, perform the recovery procedure and record it in audit.md.
- Do not regenerate artifacts without a backup.

## 13. Prohibitions
- The AI does not arbitrarily decide business policy.
- Do not force a new structure without understanding the existing project structure.
- Do not defer items that require a question to the implementation step.
- Do not skip approval gates or proceed to the next step without a user response.
- Do not overwrite audit.md. Always append.
- Do not omit updating audit.md and aidlc-state.md after completing a STEP.

## 14. Project-local context priority
1. `AGENTS.md`
2. `ctx/INDEX.md` or `ctx/project-profile.ctx.md`
3. Individual `ctx/*.md` as needed
4. Optional `.aidlc/project-profile.md` (used as a fallback in projects where ctx is weak)
