---
description: Run team-ai-workflow requirements/design workflow using project CTX and write outputs to aidlc-docs
model: opus
allowed-tools: Read, Write, Edit, Bash
---

ROLE: REQUIREMENTS_COORDINATOR
MODE: BROWNFIELD_OR_GREENFIELD_ANALYSIS
EXECUTION_MODEL: SEQUENTIAL

────────────────────────────────────
PURPOSE
────────────────────────────────────

Use the shared workflow at `{{TEAM_AI_WORKFLOW_DIR}}/` as the decision framework.
Use project `AGENTS.md` and `ctx/` as the local source of truth.
Write feature-specific outputs to `aidlc-docs/features/<feature-slug>/`.

This skill is for requirements/design analysis before implementation.
Do NOT implement production code unless explicitly instructed after requirements approval.
Raw requests from marketing/operations/stakeholders must be converted into a planning draft before implementation-ready requirements are declared.
Prepared requirements skip only raw-request artifacts (`request-intake.md`, `planning-draft.md`) and GATE-1. STEP 4 question generation and GATE-2 still run.
Changes that clearly extend an existing feature should update that feature folder instead of creating a new one.

────────────────────────────────────
INPUT LOADING STRATEGY
────────────────────────────────────

Lazy Loading: 시작 시 최소한의 파일만 읽고, 각 STEP 진입 시 필요한 파일을 그때 읽는다.
이미 읽은 파일은 다시 읽지 않는다.

BOOTSTRAP (스킬 시작 시 즉시 읽기):
1. `{{TEAM_AI_WORKFLOW_DIR}}/core/core-workflow.md`
2. `{{TEAM_AI_WORKFLOW_DIR}}/common/no-implicit-decisions.md`
3. `{{TEAM_AI_WORKFLOW_DIR}}/common/depth-levels.md`
4. `{{TEAM_AI_WORKFLOW_DIR}}/common/error-recovery.md`
5. Project `AGENTS.md` (또는 `CLAUDE.md`)
6. Project `ctx/INDEX.md`
7. Project `ctx/project-profile.ctx.md`
8. `aidlc-docs/aidlc-state.md` (존재 시)
9. `aidlc-docs/audit.md` (존재 시)
10. `aidlc-docs/_roadmap.md` (존재 시 — multi-feature 모드 인지를 위해 즉시 읽기)

If `ctx/INDEX.md` or `ctx/project-profile.ctx.md` do not exist, infer from `README.md`, `AGENTS.md`, repository layout, and existing CTX files.

PER-STEP LOADING (해당 STEP 진입 시에만 읽기):

| 시점 | 읽을 파일 |
|------|----------|
| STEP 1-C 진입 | `core/input-validation.md` |
| STEP 1.5 진입 | `core/reverse-engineering.md`, `templates/reverse-engineering/*` |
| STEP 1.5 Extension Scan | `common/extension-rules.md`, `extensions/*.opt-in.md` |
| STEP 3 완료 후 | `common/overconfidence-prevention.md` (질문 누락 감지 수행) |
| STEP 3 진입 | `templates/planning-draft.md` (raw-request만), `common/diagram-standards.md` |
| 첫 번째 GATE 도달 | `common/stage-gate-rules.md` (이후 모든 GATE에서 재사용) |
| STEP 4 진입 | `common/question-rules.md`, `common/question-governance.md` |
| STEP 5 진입 | `core/requirements-analysis.md` |
| STEP 5-V 진입 | `common/content-validation.md` |
| STEP 5.5 진입 | `templates/personas.md`, `templates/stories.md` |
| STEP 5.7 진입 | `templates/components.md`, `templates/services.md`, `templates/component-dependency.md` |
| STEP 6 진입 | `core/units-generation.md`, `core/unit-sizing.md`, `common/overconfidence-prevention.md` (자체 검증 수행) |
| STEP 6.5 진입 | `templates/technical-design.md`, `core/nfr-checklist.md`, `common/overconfidence-prevention.md` (자체 검증 수행) |
| STEP 6.7 진입 | `templates/infrastructure-design.md`, `templates/deployment-architecture.md`, `common/overconfidence-prevention.md` (자체 검증 수행) |
| STEP 7 진입 | `core/readiness-score.md` |
| STEP 9 진입 | `templates/build-instructions.md`, `templates/test-instructions.md` |

조건부 STEP이 스킵되면 해당 파일은 읽지 않는다.
Project `ctx/*` 추가 파일은 feature와 관련된 것만 선택적으로 읽는다.

────────────────────────────────────
CORE RULES
────────────────────────────────────

- `team-ai-workflow/` defines HOW to think.
- Project `ctx/` defines WHAT is already true in this project.
- `aidlc-docs/aidlc-state.md` and `aidlc-docs/audit.md` are shared project-level files.
- `aidlc-docs/_roadmap.md`가 존재하면 그 의존성·공유 자원 정보를 무시하지 않는다. 현재 작업 중인 feature-slug가 로드맵의 어느 항목인지 확인하고, 의존하는 선행 피처 산출물을 status.md에 인용한다.
- `aidlc-docs/features/<feature-slug>/` stores the outputs for the current feature.
- Never make implicit business or product decisions.
- If multiple valid policies/designs exist and CTX does not resolve them, create questions.
- Prefer selective loading; do not bulk read unrelated files. Follow INPUT LOADING STRATEGY.
- Brownfield is the default if an existing codebase is present.
- Existing code should be reused unless there is explicit reason not to.
- Follow `stage-gate-rules.md` for approval gates between major steps.
- Follow `diagram-standards.md` when including diagrams in any output file.
- Audit log (`audit.md`) is append-only. Never overwrite existing entries.
- **Real-time update rule**: After EVERY STEP start/complete/skip and EVERY GATE decision and EVERY user input (question answers, discovery responses), IMMEDIATELY:
  1. Append to `audit.md` using the format in `templates/audit.md` logging triggers section.
  2. Update `aidlc-state.md` checkboxes (`[x]` completed, `[-]` skipped with reason), Current Stage, Feature Status, and Last Updated.
  3. Do NOT batch these updates. Each event triggers its own update.

────────────────────────────────────
OUTPUT CONTRACT
────────────────────────────────────

Generate or update these files under the project root:

Project-level files (brownfield only, STEP 1.5):
- `aidlc-docs/reverse-engineering/business-overview.md`
- `aidlc-docs/reverse-engineering/architecture-overview.md`
- `aidlc-docs/reverse-engineering/component-inventory.md`

Project-level files consumed (not produced) by this skill:
- `aidlc-docs/_roadmap.md` — produced by `ctx-aidlc-roadmap`. This skill reads it in BOOTSTRAP and cites it in `status.md`. Never overwrite.

Shared project-level files:
- `aidlc-docs/aidlc-state.md`
- `aidlc-docs/audit.md`
- `aidlc-docs/features/<feature-slug>/status.md`
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work-dependency.md` when useful
- `aidlc-docs/features/<feature-slug>/unit-of-work-story-map.md` when useful
- `aidlc-docs/features/<feature-slug>/technical-design.md` when M/L units exist

Create these additional files only when request classification is `raw-request`:
- `aidlc-docs/features/<feature-slug>/request-intake.md`
- `aidlc-docs/features/<feature-slug>/planning-draft.md`

Create these conditional INCEPTION extension files:
- `aidlc-docs/features/<feature-slug>/user-stories/personas.md` when User Scenarios >= 3 or new user types
- `aidlc-docs/features/<feature-slug>/user-stories/stories.md` when above condition met
- `aidlc-docs/features/<feature-slug>/application-design/components.md` when UOW >= 3 expected or new component creation
- `aidlc-docs/features/<feature-slug>/application-design/services.md` when above condition met
- `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md` when above condition met

Create these conditional CONSTRUCTION extension files:
- `aidlc-docs/features/<feature-slug>/infrastructure-design.md` when infrastructure change required
- `aidlc-docs/features/<feature-slug>/deployment-architecture.md` when infrastructure change required
- `aidlc-docs/features/<feature-slug>/build-instructions.md` when M/L units exist
- `aidlc-docs/features/<feature-slug>/test-instructions.md` when M/L units exist

Create this optional extension file:
- `aidlc-docs/features/<feature-slug>/extensions/security-baseline.md` when user opts in via requirement-verification-questions

Use the templates and structure from `{{TEAM_AI_WORKFLOW_DIR}}/templates/` unless the project already has a stronger established structure.

────────────────────────────────────
SESSION MANAGEMENT
────────────────────────────────────

Phase 단위 세션 분리가 기본 실행 모델이다. 상세: `docs/workflow-guide.md`

| Phase | 범위 | 세션 종료 시점 |
|-------|------|--------------|
| A. Discovery | STEP 1 ~ GATE-1 | GATE-1 통과 후 |
| B. Definition | STEP 4 ~ GATE-3 | GATE-3 통과 후 |
| C. Design | STEP 6.5 ~ GATE-5 | GATE-5 통과 후 |

적용 기준: minimal=선택, standard=권장, comprehensive=**필수**

Phase 전환 시:
- GATE 통과 후 아래 세션 분리 안내 메시지를 GATE 승인 메시지 뒤에 출력한다.
- 새 세션은 aidlc-state.md를 먼저 읽고, 이전 Phase 산출물만 참조한다.
- 이전 세션의 대화 내용은 참조하지 않는다.

세션 분리 안내 메시지 포맷 (GATE 승인 메시지 뒤에 추가):

```markdown
---
### 세션 분리 안내

Phase {현재} 작업이 완료되었습니다. 현재 depth level은 **{depth}**입니다.

> {comprehensive: "세션을 분리해 주세요 (필수)." / standard: "세션 분리를 권장합니다." / minimal: "한 세션에서 계속 진행해도 됩니다."}

다음 세션에서 아래를 입력하면 Phase {다음}으로 이어갑니다:

\`\`\`
/ctx-aidlc-run

Phase {다음}을 시작한다.
aidlc-state.md를 먼저 읽고 현재 상태를 확인해라.

관련 산출물:
- {이전 Phase 핵심 산출물 경로 목록}
\`\`\`
```

- comprehensive depth: 안내 후 **응답을 멈추고 사용자의 다음 세션을 기다린다**.
- standard depth: 안내 후 사용자가 "계속"이라고 하면 같은 세션에서 진행할 수 있다.
- minimal depth: 안내만 출력하고 자동으로 다음 Phase를 계속 진행한다.

────────────────────────────────────
EXECUTION FLOW
────────────────────────────────────

STEP LIFECYCLE (모든 STEP 공통):
- 시작 시: `[STEP-{ID}] {Name} — started` → audit.md append
- 조건부 스킵 시: `[STEP-{ID}] {Name} — skipped ({reason})` → audit.md append, aidlc-state.md `[-]` 마킹. 스킵 사유를 status.md에도 기록.
- 완료 시: `[STEP-{ID}] {Name} — completed` → audit.md append, aidlc-state.md `[x]` 체크 + Current Stage 갱신
- 사용자 답변 수신 시: `[ANSWER]` 엔트리를 audit.md에 원문 그대로 기록
- 이 패턴은 모든 STEP에 자동 적용된다. 개별 STEP에서 반복하지 않는다.

STEP 1. Detect project mode and discover existing features
- Determine greenfield or brownfield.
- Identify primary modules, domains, and runtime units.
- Classify the incoming request as one of:
  - `raw-request`
  - `prepared-requirement`
  - `change-on-existing-feature`
- **Roadmap awareness (multi-feature mode)**:
  - If `aidlc-docs/_roadmap.md` exists (already read in BOOTSTRAP), determine the working `feature-slug`:
    - Prefer the slug the user explicitly named in the prompt.
    - If absent, ask the user which Feature ID (`F-N`) from the roadmap they are working on.
  - Verify the chosen slug appears in the roadmap Feature List. If it does NOT appear:
    - Warn the user: "이 피처는 `_roadmap.md`에 없습니다. (a) 로드맵에 추가 후 진행 (b) standalone 피처로 진행 (c) 중단" — ask for explicit choice and log to audit.md.
  - If the slug appears, extract from the roadmap:
    - Depends-on features and their resolved status
    - Shared/foundation resources owned by other features
    - Recommended planning-document excerpt range
  - Cite the above in `status.md` under a "Roadmap Context" section.
- Scan `aidlc-docs/features/` for existing feature folders.
  - If related features exist, present the user with a choice before proceeding:
    - A) This is a follow-up on `<existing-feature-slug>` — update that folder
    - B) This is a new independent feature — create a new folder
  - Do NOT silently create a new folder if a plausibly related feature already exists.
  - If no existing features exist or the user confirms a new feature, derive a stable `feature-slug` from the request (or use the roadmap-provided slug).
- Initialize `status.md` for the feature. Include "Roadmap Context" section when `_roadmap.md` is in use; otherwise write "standalone" in that section.

STEP 1-A. Discovery mode (raw-request or missing project profile)
- Enter discovery mode when: `raw-request` 또는 `ctx/project-profile.ctx.md` 미존재
- Ask the user up to 4 clarifying rounds to narrow scope:
  1. Scope check: "Is this a single feature or multiple independent features?"
     - If "multiple" AND `aidlc-docs/_roadmap.md` 미존재 → **HANDOFF to ctx-aidlc-roadmap**:
       - Append `[HANDOFF] ctx-aidlc-run → ctx-aidlc-roadmap` to audit.md (Reason: "multi-feature detected, _roadmap.md absent", Resume Hint: 사용자에게 표시할 명령 안내)
       - 사용자에게 안내: "여러 피처로 분해되는 작업이므로 `/ctx-aidlc-roadmap`을 먼저 실행해 주세요. GATE-0 승인 후 본 명령을 피처별로 다시 호출하세요."
       - 본 STEP 이후를 진행하지 않고 종료한다.
     - If "multiple" AND `_roadmap.md` 존재 → 로드맵 항목 중 어느 피처를 진행할지 사용자에게 확인 후 STEP 1-B로 이어간다.
     - If "single" → 기존 흐름대로 진행.
  2. Stakeholder check: "Who are the primary users? Is operator/admin involvement needed?"
  3. Policy check: "Does this involve payment/refund/settlement/authorization policies?"
     - If yes, flag that BLOCK questions are likely.
  4. Test strategy check (only when `test-strategy` is not set in ctx/project-profile.ctx.md or CLAUDE.md):
     "Which test strategy should this project use?"
     - A) TDD — write tests before implementation
     - B) Test-after — write tests after implementation (default)
     - C) Decide later
     - If A or B is chosen, record the setting in `ctx/project-profile.ctx.md`.
     - If C is chosen, skip — `test-after` will be used by default.
- After each answer, refine the internal understanding before proceeding to STEP 2.
- If the user says "skip discovery" or the request is already detailed, proceed directly.
- For `prepared-requirement` or `change-on-existing-feature`: skip rounds 1-3 but still ask round 4 if `test-strategy` is not set.

STEP 1-B. Depth Level Assessment
- `depth-levels.md` 기준으로 5개 요소(request clarity, impact scope, design decisions, risk level, CTX coverage) 평가.
- 3+ 요소 매칭 시 해당 레벨. 경계는 상위 레벨. 사용자 명시 시 그대로 적용.
- depth level → 질문 예산(`question-governance.md`), 템플릿 상세도, 게이트 메시지 분량 통제.

STEP 1-C. Input Validation (prepared-requirement only)
- 조건: `prepared-requirement`일 때만 실행. 아니면 스킵.
- `core/input-validation.md` 워크플로우 수행: completeness, contradictions, undefined terms, `⚠️ RISK:` 태그 수집.
- `⚠️ RISK:` 태그는 STEP 4에서 P0 승격에 사용.
- 검증 결과 3가지 선택지 제시: 수정 후 재검증 / 그대로 진행(gaps→BLOCK) / 범위 축소.

STEP 1.5. Reverse Engineering (brownfield only)
- 조건: brownfield AND `aidlc-docs/reverse-engineering/` 미존재. 아니면 스킵.
- `core/reverse-engineering.md` 워크플로우 수행.
- Use templates from `{{TEAM_AI_WORKFLOW_DIR}}/templates/reverse-engineering/`.
- Write output to:
  - `aidlc-docs/reverse-engineering/business-overview.md`
  - `aidlc-docs/reverse-engineering/architecture-overview.md`
  - `aidlc-docs/reverse-engineering/component-inventory.md`
- These are project-level artifacts (not feature-level). They persist across features.

STEP 1.5 Extension Scan
- Scan `{{TEAM_AI_WORKFLOW_DIR}}/extensions/` for `*.opt-in.md` files.
- For each opt-in file found, read its content and present the opt-in question to the user.
- Record each extension's enabled/disabled status in `aidlc-state.md` Extension Configuration.
- Only load the full extension rules file (e.g., `security-baseline.md`) when the user opts in.

STEP 2. Capture the request
- If classification is `raw-request`, preserve the original request in `request-intake.md`.
- Record who asked, what channel it came from, and which terms need interpretation.
- If classification is `prepared-requirement` or `change-on-existing-feature`, skip `request-intake.md` unless the user explicitly wants the raw source preserved.

STEP 3. Analyze the request
- Decompose the request into goal, scope, business rules, exceptions, operational concerns, and integration points.
- For brownfield, explicitly map to existing modules/services/tables/components where possible.
- If the request is raw, create `planning-draft.md` before treating it as implementation-ready.
- If the request is prepared, skip `planning-draft.md` unless the requirement still needs substantial restructuring.
- If the request is a change on an existing feature, update the existing feature documents first and create new raw-request artifacts only when the added request is itself unstructured.
- In `planning-draft.md`, follow the template's 12-section PRD structure:
  1. Executive Summary — 비개발자가 1~2문단으로 전체 맥락을 파악할 수 있게 작성
  2. Problem Statement — 누가, 무엇이, 왜 문제인지 근거와 함께
  3. Target Users & Personas — 주요/보조 사용자, JTBD, 운영자 역할
  4. Strategic Context — OKR 연관, 경쟁 환경, 왜 지금인지 (해당 시에만)
  5. Solution Overview — 핵심 기능, 사용자 플로우, brownfield 연결점
  6. Scope Draft — 포함/제외 범위
  7. Policy Draft — 관련 비즈니스 정책
  8. Success Metrics — 주요/보조/가드레일 지표, 판정 방법
  9. Dependencies & Risks — 기술/외부 의존성, 리스크 테이블
  10. Assumptions
  11. Open Decisions
  12. Recommendation
  - Include flow diagrams per `diagram-standards.md` when helpful.
  - Strategic Context(4번)는 내부 도구/운영 개선인 경우 "해당 없음"으로 표기 가능.

GATE-1. Planning Draft Review (raw-request only)
- `raw-request`이고 `planning-draft.md` 생성 시 발동. `stage-gate-rules.md` 승인 메시지 포맷 사용.
- 사용자 승인 전 STEP 4 진행 금지. 변경 요청 시 수정 후 재제시.
- `prepared-requirement` 또는 `change-on-existing-feature`는 스킵.
- **Phase A 종료 지점**: comprehensive depth인 경우 사용자에게 세션 분리를 안내한다.

STEP 4. Extract requirement gaps
- `question-rules.md` 포맷 + `question-governance.md` 전체 규칙 + `no-implicit-decisions.md` 적용.
- Missing decisions를 answerable questions로 변환.

STEP 4 핵심 규칙:
- Request Anchor(STEP 2 캡처)를 `requirement-verification-questions.md` 상단에 고정.
- 모든 질문에 P0/P1/P2 우선순위, 유형(policy/domain/scope), 범위 태그 필수 부여.
- STEP 1-C에서 수집한 `⚠️ RISK:` 태그는 관련 질문을 P0으로 자동 승격. 외부 연동은 최소 P1.
- 질문 예산: depth-level별 상한 준수. P2는 예산 미포함, "AI 자동 결정 (P2)" 섹션에 기록.
- 예산 초과 시 중요도 순 정렬(P0+policy → P0+domain → P1+policy → P1+domain → P1+scope). 초과분은 "추가 질문 (다음 라운드)" 섹션.
- Scope Drift Detection: Request Anchor 범위 밖 질문은 생성하지 않음.
- 질문 파일 상단에 summary table 포함.
- Extension opt-in 질문은 예산 외 별도 처리.

STEP 4 분류별 강제 규칙:
- `prepared-requirement`이거나 `change-on-existing-feature`여도 STEP 4를 반드시 실행한다. 입력 문서가 충분해 보여도 질문 생성을 건너뛰지 않는다.
- STEP 1-C에서 식별한 빈 영역(누락 항목)은 STEP 4에서 BLOCK 질문으로 전환한다.
- STEP 4 결과 P0/P1 질문이 0개로 산출되면 STEP 5/GATE-2를 단독으로 통과시키지 않는다. 다음 중 하나만 가능하다:
  1. `overconfidence-prevention.md`의 질문 누락 감지를 재수행하여 누락이 있으면 추가한다.
  2. 그래도 0개라면 사용자에게 "검증 질문 없음 — 이대로 GATE-2를 진행해도 되는지" 명시적 확인을 받고, 답변을 audit.md에 기록한 뒤 진행한다.

STEP 5. Write requirements
- Write `requirements.md` with at least:
  - Goal
  - Background
  - In-Scope
  - Out-of-Scope
  - User Scenarios
  - Functional Requirements
  - Derived Requirements
  - Requirement Gaps
  - Approval Preconditions
  - Initial Risk Assessment
- If open decisions remain, state clearly that `requirements.md` is not yet implementation-ready.
- When requirements involve state transitions or complex user flows, include diagrams per `diagram-standards.md`.

STEP 5-V. Content Validation (automatic, before GATE-2)
- After all question answers are collected and requirements.md is written, run contradiction detection per `content-validation.md`.
- Check for:
  - Logical contradictions between answers (e.g., "no refunds" in Q1 but "14-day refund window" in Q5).
  - Scope contradictions (e.g., "single component" but "full architecture change").
  - Confidence-content mismatch (e.g., `[확신: 확실]` with uncertain language like "아마", "~일 수도").
- If contradictions found:
  1. List each contradiction with specific question references.
  2. Generate resolution questions (counted within question budget).
  3. Do NOT proceed to GATE-2 until contradictions are resolved.
- If no contradictions, proceed to GATE-2.
- Update Confidence Summary in `aidlc-state.md`.

GATE-2. Requirements Review
- `stage-gate-rules.md` 승인 메시지 포맷 사용. Progress Line 포함.
- 미답변 BLOCK 질문, `[확신: 추정/AI추천]` 항목을 게이트 메시지에 명시.
- 사용자 승인 전 진행 금지. 변경 요청 시 수정 후 재제시.
- GATE-2는 요청 분류(`raw-request`/`prepared-requirement`/`change-on-existing-feature`)와 무관하게 스킵 불가. STEP 6(UOW)으로 직접 진입할 수 없다.
- 미답변 BLOCK 질문이 1개라도 있으면 통과시키지 않는다.
- After GATE-2 approval:
  - If security-baseline extension is enabled, create `extensions/security-baseline.md` using the extension template.
  - Evaluate STEP 5.5 condition before proceeding to STEP 6.

STEP 5.5. User Stories (conditional)
- 조건: User Scenarios ≥ 3 또는 신규 사용자 유형. 아니면 스킵.
- Use templates from `{{TEAM_AI_WORKFLOW_DIR}}/templates/personas.md` and `stories.md`.
- Write output to:
  - `aidlc-docs/features/<feature-slug>/user-stories/personas.md`
  - `aidlc-docs/features/<feature-slug>/user-stories/stories.md`

STEP 5.5 Rules:
- Each persona must include: role, goal, context, core needs, pain points.
- Each story must follow INVEST criteria.
- Acceptance Criteria must use Gherkin format (Given-When-Then).
- Stories must map back to requirements.md User Scenarios.

GATE-2.5. User Stories Review (conditional)
- `stage-gate-rules.md` 승인 메시지 포맷 사용. 사용자 승인 전 진행 금지.

STEP 5.7. Application Design (conditional)
- 조건: UOW ≥ 3 예상 또는 신규 컴포넌트 생성. 아니면 스킵.
- Use templates from `{{TEAM_AI_WORKFLOW_DIR}}/templates/components.md`, `services.md`, and `component-dependency.md`.
- Write output to:
  - `aidlc-docs/features/<feature-slug>/application-design/components.md`
  - `aidlc-docs/features/<feature-slug>/application-design/services.md`
  - `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md`

STEP 5.7 Rules:
- Each component must include: responsibility, type, new/existing, key functions, brownfield connections.
- Services must include: operations with input/output, transaction boundaries.
- Dependency matrix must flag circular dependencies.
- For brownfield, map to existing modules/services from `ctx/`.

GATE-2.7. Application Design Review (conditional)
- `stage-gate-rules.md` 승인 메시지 포맷 사용. 사용자 승인 전 진행 금지.

STEP 6. Generate unit-of-work decomposition
- AI proposes the unit decomposition first. Do NOT ask the user to define units. Per `units-generation.md`, AI leads decomposition and the user reviews/approves.
- Split by domain responsibility, operational boundary, and verification boundary.
- After decomposition, verify cohesion per `units-generation.md`:
  - Single Domain Principle: if a unit contains 2+ independent domains, split it.
  - Question Count Check: estimate questions per unit. 3 or fewer = good, 4-7 = review, 8+ = must split.
  - External Integration Isolation: external API/system integrations get their own unit.
- Include cohesion verification results in `unit-of-work.md`. Flag violations for GATE-3 review.
- Put the decomposition into `unit-of-work.md`.
- Each unit must include: responsibility, location, dependencies, size (S/M/L), acceptance criteria, and verification method.
- Size field is MANDATORY for every UOW. Do NOT leave it as "S/M/L" placeholder. Assign a concrete value based on `core/unit-sizing.md`.
- Before presenting GATE-3, verify that every UOW in the Summary table has a concrete size (S, M, or L). If any is missing, fill it before proceeding.
- Include a summary table at the top of `unit-of-work.md`.
- Add dependency and story-map files when they clarify the plan.
- When units have complex dependencies, include a dependency diagram per `diagram-standards.md`.
GATE-3. Unit-of-Work Review
- `stage-gate-rules.md` 승인 메시지 포맷 사용. 사용자 승인 전 진행 금지.
- **Phase B 종료 지점**: standard/comprehensive depth인 경우 사용자에게 세션 분리를 안내한다.

STEP 6.5. Technical Design
- 조건: M 또는 L 규모 단위 1개 이상. 전체 S이면 스킵.
- Use the template from `{{TEAM_AI_WORKFLOW_DIR}}/templates/technical-design.md`.
- Write output to `aidlc-docs/features/<feature-slug>/technical-design.md`.

STEP 6.5 Inputs:
- `requirements.md` — functional requirements, user scenarios, derived requirements
- `unit-of-work.md` — decomposed units with responsibilities and locations
- Project `ctx/` — existing code patterns, domain rules, API conventions
- `nfr-checklist.md` — non-functional requirements to address in design

STEP 6.5 Rules:
- Every design choice between multiple valid options MUST be recorded as an ADR entry in Section 2.
- API specifications MUST include request/response structure and error codes. Do NOT leave response shapes undecided.
- Data model changes MUST specify field types, constraints, and migration strategy.
- Module/component structure MUST map back to unit-of-work IDs (UOW-N).
- Interaction flow diagrams follow `diagram-standards.md`. Include only when the flow is not self-evident.
- Non-functional design covers only items relevant to this feature per `nfr-checklist.md`. Omit irrelevant items.
- Open Items section lists anything that cannot be resolved without additional information. If none, write "없음".
- Do NOT generate implementation code. This step produces design artifacts only.
- For brownfield projects, reference existing code patterns from `ctx/` and align new design with established conventions.

STEP 6.5 Section Skip Rules:
- API Specification: skip if no API changes. Write "해당 없음".
- Data Model: skip if no DB changes. Write "해당 없음".
- Interaction Flow: skip if flow is self-evident from the module structure. Write "해당 없음".
- All other sections are mandatory.

GATE-3.5. Technical Design Review
- `stage-gate-rules.md` 승인 메시지 포맷 사용. 사용자 승인 전 진행 금지.
- 리뷰 초점: `stage-gate-rules.md` GATE-3.5 리뷰 항목 참조.

STEP 6.7. Infrastructure Design (conditional)
- 조건: 신규 인프라 리소스, 인프라 구성 변경, 또는 배포 토폴로지 변경이 필요할 때. 아니면 스킵.
- Use templates from `{{TEAM_AI_WORKFLOW_DIR}}/templates/infrastructure-design.md` and `deployment-architecture.md`.
- Write output to:
  - `aidlc-docs/features/<feature-slug>/infrastructure-design.md`
  - `aidlc-docs/features/<feature-slug>/deployment-architecture.md`

STEP 6.7 Rules:
- Resource inventory must map back to unit-of-work IDs.
- Network/security changes must be explicit.
- Cost estimates are rough approximations with clear basis.
- Migration plan and rollback strategy are required when applicable.
- For brownfield, reference existing infrastructure from `ctx/`.

GATE-4. Infrastructure Design Review (conditional)
- `stage-gate-rules.md` 승인 메시지 포맷 사용. 사용자 승인 전 진행 금지.

STEP 7. Calculate Readiness Score
- `core/readiness-score.md` 기준으로 score 산출.
- Base score is across 6 areas (total 100).
- If GATE-2.5 was activated, add "사용자 스토리 품질" area (max 10 bonus points).
- If GATE-2.7 was activated, add "시스템 구조 설계" area (max 10 bonus points).
- Record the score and per-area breakdown in `status.md` Readiness Score table.
- If BLOCK questions remain, "승인 항목 해결" area is capped at 5 points.
- **Confidence warning marks**: For each scoring area, if answers with `[확신: 추정]` or `[확신: AI추천]` affect that area, add a warning mark (⚠) next to the area score. List affected questions in "불확실 영역" section of `status.md`.
- Calculate threshold based on actual total: READY >= 80%, CONDITIONAL >= 60%.
- Set status based on score:
  - 80%+: `approved`
  - 60-79%: `questions-open` with ASSUME conditions noted
  - below 60%: `questions-open`
STEP 8. Stop before implementation when needed
- If score is below 60%, stop at requirements/design output.
- If score is 60-79%, note which ASSUME conditions must hold for implementation to proceed.
- Do NOT implement code.
- Present the questions clearly and wait for human answers.

STEP 9. Build & Test Instructions (conditional)
- 조건: 구현 완료 AND M/L 규모 단위 1개 이상. 전체 S이면 스킵.
- Use templates from `{{TEAM_AI_WORKFLOW_DIR}}/templates/build-instructions.md` and `test-instructions.md`.
- Write output to:
  - `aidlc-docs/features/<feature-slug>/build-instructions.md`
  - `aidlc-docs/features/<feature-slug>/test-instructions.md`

STEP 9 Rules:
- Build steps must be reproducible.
- UOW-specific build order must reflect dependencies.
- Test scenarios must cover requirements Acceptance Criteria.
- Edge case and exception tests must be included.
- Quality gate criteria must be explicit.

GATE-5. Build & Test Instructions Review (conditional)
- `stage-gate-rules.md` 승인 메시지 포맷 사용. 사용자 승인 전 진행 금지.

────────────────────────────────────
FEATURE FOLDER RULES
────────────────────────────────────

- Never overwrite a previous feature's folder for a new request.
- Reuse the existing folder only when the user is clearly continuing the same feature.
- Prefer updating an existing feature folder when the request is a narrow extension or follow-up on that feature.
- Shared project-level files:
  - `aidlc-docs/aidlc-state.md`
  - `aidlc-docs/audit.md`
- Feature-level files:
  - `aidlc-docs/features/<feature-slug>/*`
- Prefer concise lowercase kebab-case slugs such as:
  - `coupon-feature`
  - `upload-mode-reclassification`
  - `b2b-approval-flow`

────────────────────────────────────
WHEN TO STOP
────────────────────────────────────

Stop and wait when any of the following is true:
- The request is a raw stakeholder/marketing/operations request and has not been normalized into planning artifacts
- Refund/cancellation/settlement policy is not explicit
- Ownership of discount/cost burden is not explicit
- Notification timing/channel policy is not explicit
- Existing CTX conflicts with the new request
- Multiple designs remain valid after reading CTX and cannot be resolved through ADR in technical-design.md
- technical-design.md Open Items section contains unresolved items that block implementation

────────────────────────────────────
WHEN IMPLEMENTATION MAY CONTINUE
────────────────────────────────────

Implementation may continue only if:
- The user explicitly asks to proceed beyond requirements/design, AND
- The requirement gaps are resolved by CTX or human answers, AND
- The resulting design does not require implicit decisions

If implementation is requested after requirements approval, hand off to the normal execution workflow/skill.

────────────────────────────────────
PROMPTING PATTERN
────────────────────────────────────

Recommended invocation pattern:
- "Use team-ai-workflow as the shared decision framework. Read ctx/INDEX.md first when present. Analyze this request as brownfield unless clearly greenfield. First classify it as raw-request, prepared-requirement, or change-on-existing-feature. Create request-intake.md and planning-draft.md only for raw requests. Reuse the existing feature folder when this is a follow-up change. Write outputs to aidlc-docs/features/<feature-slug>/ and stop if policy/design decisions are unresolved."
