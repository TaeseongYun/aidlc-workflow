<!-- workflow-step: STEP-1 | gate: none | producer: ctx-aidlc-run, ctx-aidlc-roadmap | updated-by: all steps -->
# AI-DLC State Tracking

Update rules:
- **On completion of every STEP**, update the corresponding checkbox to `[x]`.
- **When a conditional STEP is skipped**, mark it `[-]` and record the reason in parentheses.
- **On passing a GATE**, update the corresponding checkbox to `[x]`.
- Always update Current Stage to the STEP currently in progress.
- Always keep Feature Status up to date.

## Project Information
- Project Type:
- Start Date:
- Current Stage:
- Current Feature:

## Workspace State
- Existing Code:
- Reverse Engineering Needed:
- Workspace Root:

## Roadmap State
- Roadmap Path: `aidlc-docs/_roadmap.md` (none / in progress / approved)
- Multi-Feature Mode: yes / no
- GATE-0 Decision: pending / approved / not-applicable
- Last Roadmap Update:

## Feature Index

| Slug | Status | Roadmap Source | Owner |
|------|--------|----------------|-------|
|      |        |                |       |

Status values: active / completed / parked
Roadmap Source values: `_roadmap.md` item ID or `standalone` (a single feature outside the roadmap)

## Cross-Feature Dependencies

| Source Feature | Depends On | Shared Resource | Resolution |
|----------------|------------|-----------------|------------|
|                |            |                 |            |

Resolution values: `foundation-extracted` / `serialized` / `parallel-safe` / `unresolved`
If the table is empty, write "Not applicable".

## Current Feature Summary
- Feature Slug:
- Request Type:
- Feature Status:
- Feature Folder:
- Depth Level: minimal / standard / comprehensive
- Current Phase: A (Discovery) / B (Definition) / C (Design)
- Input Validation Result: passed / issues-found / skipped
- Readiness Score:
- Last Updated:

## Confidence Summary
- Confirmed: 0
- Estimated: 0
- AI-recommended: 0
- Undecided: 0

## Extension Configuration
- security-baseline: disabled / enabled
- performance-baseline: disabled / enabled
- api-contract: disabled / enabled

## Roadmap Phase Progress (multi-feature only)
- [ ] STEP R1: Input Validation (prepared-requirement only)
- [ ] STEP R2: Feature Decomposition
- [ ] STEP R3: Resource Matrix
- [ ] STEP R4: Dependency Graph
- [ ] STEP R5: Allocation Recommendation
- [ ] STEP R6: Roadmap File Output
  - [ ] GATE-0: Roadmap Review

For a single feature, mark the whole section `[-]` and record "single-feature" as the reason.

## Current Feature Stage Progress
- [ ] STEP 1: Project Detection & Classification
- [ ] STEP 1-A: Discovery (raw-request only)
- [ ] STEP 1-B: Depth Level Assessment
- [ ] STEP 1-C: Input Validation (prepared-requirement only)
- [ ] STEP 1.5: Reverse Engineering (brownfield only)
- [ ] STEP 2: Request Capture
- [ ] STEP 3: Request Analysis / Planning Draft
  - [ ] GATE-1: Planning Draft Review (raw-request only)
- [ ] STEP 4: Requirement Gap Extraction
- [ ] STEP 5: Requirements Writing
  - [ ] GATE-2: Requirements Review
- [ ] STEP 5.5: User Stories (conditional)
  - [ ] GATE-2.5: User Stories Review (conditional)
- [ ] STEP 5.7: Application Design (conditional)
  - [ ] GATE-2.7: Application Design Review (conditional)
- [ ] STEP 6: Unit-of-Work Decomposition
  - [ ] GATE-3: Unit-of-Work Review
- [ ] STEP 6.5: Technical Design (M/L only)
  - [ ] GATE-3.5: Technical Design Review (M/L only)
- [ ] STEP 6.7: Infrastructure Design (conditional)
  - [ ] GATE-4: Infrastructure Design Review (conditional)
- [ ] STEP 7: Readiness Score Calculation
- [ ] STEP 8: Stop or Proceed Decision
- [ ] STEP 9: Build & Test Instructions (conditional)
  - [ ] GATE-5: Build & Test Review (conditional)

Checkbox legend:
- `[x]` completed
- `[-]` skipped (reason in parentheses)
- `[ ]` not started
