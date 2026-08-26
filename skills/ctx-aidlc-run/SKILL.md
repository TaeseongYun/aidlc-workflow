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

Lazy Loading: At start, read only the minimum files, and read the files needed when entering each STEP at that time.
Do not re-read files that have already been read.

BOOTSTRAP (read immediately on skill start):
1. `{{TEAM_AI_WORKFLOW_DIR}}/core/core-workflow.md`
2. `{{TEAM_AI_WORKFLOW_DIR}}/common/no-implicit-decisions.md`
3. `{{TEAM_AI_WORKFLOW_DIR}}/common/depth-levels.md`
4. `{{TEAM_AI_WORKFLOW_DIR}}/common/error-recovery.md`
5. Project `AGENTS.md` (or `CLAUDE.md`)
6. Project `ctx/INDEX.md`
7. Project `ctx/project-profile.ctx.md`
8. `aidlc-docs/aidlc-state.md` (if exists)
9. `aidlc-docs/audit.md` (if exists)
10. `aidlc-docs/_roadmap.md` (if exists — read immediately to be aware of multi-feature mode)

If `ctx/INDEX.md` or `ctx/project-profile.ctx.md` do not exist, infer from `README.md`, `AGENTS.md`, repository layout, and existing CTX files.

PER-STEP LOADING (read only when entering the corresponding STEP):

| Timing | Files to read |
|------|----------|
| STEP 1-C entry | `core/input-validation.md` |
| STEP 1.5 entry | `core/reverse-engineering.md`, `templates/reverse-engineering/*`, `common/graph-grounding.md` |
| STEP 1.5 Extension Scan | `common/extension-rules.md`, `extensions/*.opt-in.md` |
| After STEP 3 completion | `common/overconfidence-prevention.md` (perform question-omission detection) |
| STEP 3 entry | `templates/planning-draft.md` (raw-request only), `common/diagram-standards.md`, `common/graph-grounding.md`, `templates/graph-evidence.md` |
| Reaching the first GATE | `common/stage-gate-rules.md` (reused for all subsequent GATEs) |
| STEP 4 entry | `common/question-rules.md`, `common/question-governance.md`, `common/graph-grounding.md` |
| STEP 5 entry | `core/requirements-analysis.md` |
| STEP 5-V entry | `common/content-validation.md` |
| STEP 5.5 entry | `templates/personas.md`, `templates/stories.md` |
| STEP 5.7 entry | `templates/components.md`, `templates/services.md`, `templates/component-dependency.md` |
| STEP 6 entry | `core/units-generation.md`, `core/unit-sizing.md`, `common/graph-grounding.md`, `common/overconfidence-prevention.md` (perform self-verification) |
| STEP 6.5 entry | `templates/technical-design.md`, `templates/graph-evidence.md`, `core/nfr-checklist.md`, `common/graph-grounding.md`, `common/overconfidence-prevention.md` (perform self-verification) |
| STEP 6.7 entry | `templates/infrastructure-design.md`, `templates/deployment-architecture.md`, `common/overconfidence-prevention.md` (perform self-verification) |
| STEP 7 entry | `core/readiness-score.md` |
| STEP 9 entry | `templates/build-instructions.md`, `templates/test-instructions.md` |

If a conditional STEP is skipped, its files are not read.
Additional Project `ctx/*` files are read selectively, only those related to the feature.

GRAPH GROUNDING (graphify) — per-step usage (protocol: `common/graph-grounding.md`):

| STEP | Graphify usage |
|------|----------------|
| 1 / 1.5 | graph stats · god-nodes · communities → grasp brownfield structure |
| 3 | query requirement keywords → related modules & call paths |
| 4 | turn `INFERRED`/`AMBIGUOUS` graph results into requirement (BLOCK) questions |
| 6 | decompose UOW using connected communities & paths |
| 6.5 | `graphify path`/`explain` → design impact & reuse; fill technical-design §6 Graph-backed Impact Analysis + snapshot `graph-evidence.md` |

Skip when no graph is available (greenfield before first implementation); VERIFY falls back to grep/Read.

────────────────────────────────────
CORE RULES
────────────────────────────────────

- `team-ai-workflow/` defines HOW to think.
- Project `ctx/` defines WHAT is already true in this project.
- `aidlc-docs/aidlc-state.md` and `aidlc-docs/audit.md` are shared project-level files.
- If `aidlc-docs/_roadmap.md` exists, do not ignore its dependency/shared-resource information. Verify which roadmap entry the currently working feature-slug corresponds to, and cite the depended-on predecessor feature outputs in status.md.
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

Per-Phase session separation is the default execution model. Details: `docs/workflow-guide.md`

| Phase | Scope | Session end point |
|-------|------|--------------|
| A. Discovery | STEP 1 ~ GATE-1 | After passing GATE-1 |
| B. Definition | STEP 4 ~ GATE-3 | After passing GATE-3 |
| C. Design | STEP 6.5 ~ GATE-5 | After passing GATE-5 |

Application criteria: minimal=optional, standard=recommended, comprehensive=**mandatory**

On Phase transition:
- After passing a GATE, output the session-separation notice message below after the GATE approval message.
- The new session reads aidlc-state.md first, and references only the previous Phase's outputs.
- Do not reference the previous session's conversation content.

Session-separation notice message format (appended after the GATE approval message):

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

- comprehensive depth: after the notice, **stop responding and wait for the user's next session**.
- standard depth: after the notice, if the user says "continue", work may proceed in the same session.
- minimal depth: output only the notice and automatically continue with the next Phase.

────────────────────────────────────
EXECUTION FLOW
────────────────────────────────────

STEP LIFECYCLE (common to all STEPs):
- On start: `[STEP-{ID}] {Name} — started` → audit.md append
- On conditional skip: `[STEP-{ID}] {Name} — skipped ({reason})` → audit.md append, mark aidlc-state.md `[-]`. Also record the skip reason in status.md.
- On completion: `[STEP-{ID}] {Name} — completed` → audit.md append, check aidlc-state.md `[x]` + update Current Stage
- On receiving a user answer: record the `[ANSWER]` entry in audit.md verbatim
- This pattern is applied automatically to all STEPs. Do not repeat it in individual STEPs.

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
    - Warn the user: "This feature is not in `_roadmap.md`. (a) add to the roadmap then proceed (b) proceed as a standalone feature (c) abort" — ask for explicit choice and log to audit.md.
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
- Enter discovery mode when: `raw-request` or `ctx/project-profile.ctx.md` does not exist
- Ask the user up to 4 clarifying rounds to narrow scope:
  1. Scope check: "Is this a single feature or multiple independent features?"
     - If "multiple" AND `aidlc-docs/_roadmap.md` does not exist → **HANDOFF to ctx-aidlc-roadmap**:
       - Append `[HANDOFF] ctx-aidlc-run → ctx-aidlc-roadmap` to audit.md (Reason: "multi-feature detected, _roadmap.md absent", Resume Hint: command guidance to display to the user)
       - Guide the user: "Since this work decomposes into multiple features, please run `/ctx-aidlc-roadmap` first. After GATE-0 approval, invoke this command again per feature."
       - Stop without proceeding beyond this STEP.
     - If "multiple" AND `_roadmap.md` exists → confirm with the user which feature among the roadmap entries to proceed with, then continue to STEP 1-B.
     - If "single" → proceed with the existing flow.
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
- Evaluate 5 factors (request clarity, impact scope, design decisions, risk level, CTX coverage) per `depth-levels.md`.
- When 3+ factors match, apply that level. On a boundary, take the higher level. When the user specifies, apply as stated.
- depth level → controls question budget (`question-governance.md`), template detail, and gate message length.

STEP 1-C. Input Validation (prepared-requirement only)
- Condition: run only when `prepared-requirement`. Otherwise skip.
- Perform the `core/input-validation.md` workflow: collect completeness, contradictions, undefined terms, `⚠️ RISK:` tags.
- `⚠️ RISK:` tags are used for P0 promotion in STEP 4.
- Present 3 options for the validation result: fix then re-validate / proceed as-is (gaps→BLOCK) / reduce scope.

STEP 1.5. Reverse Engineering (brownfield only)
- Condition: brownfield AND `aidlc-docs/reverse-engineering/` does not exist. Otherwise skip.
- Perform the `core/reverse-engineering.md` workflow.
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
  1. Executive Summary — write so a non-developer can grasp the whole context in 1-2 paragraphs
  2. Problem Statement — who, what, and why it is a problem, with evidence
  3. Target Users & Personas — primary/secondary users, JTBD, operator role
  4. Strategic Context — OKR linkage, competitive landscape, why now (only when applicable)
  5. Solution Overview — core features, user flow, brownfield connection points
  6. Scope Draft — included/excluded scope
  7. Policy Draft — related business policies
  8. Success Metrics — primary/secondary/guardrail metrics, judgment method
  9. Dependencies & Risks — technical/external dependencies, risk table
  10. Assumptions
  11. Open Decisions
  12. Recommendation
  - Include flow diagrams per `diagram-standards.md` when helpful.
  - Strategic Context (item 4) may be marked "not applicable" for internal-tool/operations improvements.

GATE-1. Planning Draft Review (raw-request only)
- Triggered when `raw-request` and `planning-draft.md` is generated. Use the `stage-gate-rules.md` approval message format.
- Do not proceed to STEP 4 before user approval. On a change request, fix and re-present.
- Skipped for `prepared-requirement` or `change-on-existing-feature`.
- **Phase A end point**: for comprehensive depth, notify the user about session separation.

STEP 4. Extract requirement gaps
- Apply `question-rules.md` format + full `question-governance.md` rules + `no-implicit-decisions.md`.
- Convert missing decisions into answerable questions.

STEP 4 core rules:
- Pin the Request Anchor (captured in STEP 2) at the top of `requirement-verification-questions.md`.
- Every question MUST be assigned a P0/P1/P2 priority, type (policy/domain/scope), and scope tag.
- `⚠️ RISK:` tags collected in STEP 1-C auto-promote related questions to P0. External integrations are minimum P1.
- Question budget: comply with the per-depth-level cap. P2 is not counted in the budget; record it in the "AI 자동 결정 (P2)" section.
- When over budget, sort by importance (P0+policy → P0+domain → P1+policy → P1+domain → P1+scope). The overflow goes to the "추가 질문 (다음 라운드)" section.
- Scope Drift Detection: do not generate questions outside the Request Anchor scope.
- Include a summary table at the top of the question file.
- Extension opt-in questions are handled separately, outside the budget.

STEP 4 per-classification mandatory rules:
- Even for `prepared-requirement` or `change-on-existing-feature`, STEP 4 MUST be run. Do not skip question generation even if the input document appears sufficient.
- Empty areas (missing items) identified in STEP 1-C are converted into BLOCK questions in STEP 4.
- If STEP 4 yields 0 P0/P1 questions, do not pass STEP 5/GATE-2 on that alone. Only one of the following is allowed:
  1. Re-run question-omission detection from `overconfidence-prevention.md`, and add any omissions found.
  2. If it is still 0, get explicit confirmation from the user "no verification questions — whether GATE-2 may proceed as-is", record the answer in audit.md, then proceed.

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
- Use the `stage-gate-rules.md` approval message format. Include the Progress Line.
- Specify unanswered BLOCK questions and `[확신: 추정/AI추천]` items in the gate message.
- Do not proceed before user approval. On a change request, fix and re-present.
- GATE-2 cannot be skipped regardless of request classification (`raw-request`/`prepared-requirement`/`change-on-existing-feature`). Direct entry into STEP 6 (UOW) is not allowed.
- Do not pass if even 1 unanswered BLOCK question remains.
- After GATE-2 approval:
  - If security-baseline extension is enabled, create `extensions/security-baseline.md` using the extension template.
  - Evaluate STEP 5.5 condition before proceeding to STEP 6.

STEP 5.5. User Stories (conditional)
- Condition: User Scenarios ≥ 3 or new user type. Otherwise skip.
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
- Use the `stage-gate-rules.md` approval message format. Do not proceed before user approval.

STEP 5.7. Application Design (conditional)
- Condition: UOW ≥ 3 expected or new component creation. Otherwise skip.
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
- Use the `stage-gate-rules.md` approval message format. Do not proceed before user approval.

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
- Use the `stage-gate-rules.md` approval message format. Do not proceed before user approval.
- **Phase B end point**: for standard/comprehensive depth, notify the user about session separation.

STEP 6.5. Technical Design
- Condition: 1 or more M or L sized units. Skip if all are S.
- Use the template from `{{TEAM_AI_WORKFLOW_DIR}}/templates/technical-design.md`.
- Write output to `aidlc-docs/features/<feature-slug>/technical-design.md`.

STEP 6.5 Inputs:
- `requirements.md` — functional requirements, user scenarios, derived requirements
- `unit-of-work.md` — decomposed units with responsibilities and locations
- Project `ctx/` — existing code patterns, domain rules, API conventions
- `nfr-checklist.md` — non-functional requirements to address in design
- `{{TEAM_AI_WORKFLOW_DIR}}/platforms/<platform>/guidance.md` — platform
  architecture baseline. Resolve the platform from `ctx/project-profile.ctx.md`
  (`## Platform`) or infer per `{{TEAM_AI_WORKFLOW_DIR}}/platforms/README.md`.
  Precedence: project `ctx/` > platform guidance. Flag conflicts, do not
  silently pick one.

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
- Use the `stage-gate-rules.md` approval message format. Do not proceed before user approval.
- Review focus: refer to the `stage-gate-rules.md` GATE-3.5 review items.

STEP 6.7. Infrastructure Design (conditional)
- Condition: when a new infrastructure resource, infrastructure configuration change, or deployment topology change is needed. Otherwise skip.
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
- Use the `stage-gate-rules.md` approval message format. Do not proceed before user approval.

STEP 7. Calculate Readiness Score
- Calculate the score per `core/readiness-score.md`.
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
- Condition: implementation complete AND 1 or more M/L sized units. Skip if all are S.
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
- Use the `stage-gate-rules.md` approval message format. Do not proceed before user approval.

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
