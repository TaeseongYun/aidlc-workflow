<!-- workflow-step: STEP-1 | gate: none | producer: ctx-aidlc-run, ctx-aidlc-roadmap | updated-by: all steps -->
# AI-DLC State Tracking

갱신 규칙:
- **모든 STEP 완료 시** 해당 체크박스를 `[x]`로 갱신한다.
- **조건부 STEP이 스킵되면** `[-]`로 표기하고 사유를 괄호에 기록한다.
- **GATE 통과 시** 해당 체크박스를 `[x]`로 갱신한다.
- Current Stage를 항상 현재 진행 중인 STEP으로 갱신한다.
- Feature Status를 항상 최신 상태로 갱신한다.

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
- Roadmap Path: `aidlc-docs/_roadmap.md` (없음 / 작성 중 / 승인 완료)
- Multi-Feature Mode: yes / no
- GATE-0 Decision: pending / approved / not-applicable
- Last Roadmap Update:

## Feature Index

| Slug | Status | Roadmap Source | Owner |
|------|--------|----------------|-------|
|      |        |                |       |

상태 값: active / completed / parked
Roadmap Source 값: `_roadmap.md` 항목 ID 또는 `standalone` (로드맵 외 단일 피처)

## Cross-Feature Dependencies

| Source Feature | Depends On | Shared Resource | Resolution |
|----------------|------------|-----------------|------------|
|                |            |                 |            |

Resolution 값: `foundation-extracted` / `serialized` / `parallel-safe` / `unresolved`
표가 비어 있으면 "해당 없음"으로 기재한다.

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
- 확실: 0개
- 추정: 0개
- AI추천: 0개
- 미정: 0개

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

단일 피처일 때는 전체를 `[-]`로 마킹하고 사유에 "single-feature"를 기록한다.

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
- [ ] STEP 5.5: User Stories (조건부)
  - [ ] GATE-2.5: User Stories Review (조건부)
- [ ] STEP 5.7: Application Design (조건부)
  - [ ] GATE-2.7: Application Design Review (조건부)
- [ ] STEP 6: Unit-of-Work Decomposition
  - [ ] GATE-3: Unit-of-Work Review
- [ ] STEP 6.5: Technical Design (M/L only)
  - [ ] GATE-3.5: Technical Design Review (M/L only)
- [ ] STEP 6.7: Infrastructure Design (조건부)
  - [ ] GATE-4: Infrastructure Design Review (조건부)
- [ ] STEP 7: Readiness Score Calculation
- [ ] STEP 8: Stop or Proceed Decision
- [ ] STEP 9: Build & Test Instructions (조건부)
  - [ ] GATE-5: Build & Test Review (조건부)

체크박스 범례:
- `[x]` 완료
- `[-]` 스킵 (사유 괄호 표기)
- `[ ]` 미진행
