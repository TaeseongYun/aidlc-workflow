<!-- ctx-aidlc-run Phase B body (STEP 4 ~ GATE-3). Loaded by the SKILL.md PHASE ROUTER; the STEP LIFECYCLE,
CORE RULES, INPUT LOADING STRATEGY and OUTPUT CONTRACT of SKILL.md apply to every STEP below. -->

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
