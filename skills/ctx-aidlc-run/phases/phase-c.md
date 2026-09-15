<!-- ctx-aidlc-run Phase C body (STEP 6.5 ~ GATE-5). Loaded by the SKILL.md PHASE ROUTER; the STEP LIFECYCLE,
CORE RULES, INPUT LOADING STRATEGY and OUTPUT CONTRACT of SKILL.md apply to every STEP below. -->

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
- Open Items section lists anything that cannot be resolved without additional information. If none, write "None".
- Do NOT generate implementation code. This step produces design artifacts only.
- For brownfield projects, reference existing code patterns from `ctx/` and align new design with established conventions.

STEP 6.5 Section Skip Rules:
- API Specification: skip if no API changes. Write "Not applicable".
- Data Model: skip if no DB changes. Write "Not applicable".
- Interaction Flow: skip if flow is self-evident from the module structure. Write "Not applicable".
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
- If GATE-2.5 was activated, add a "User Story Quality" area (max 10 bonus points).
- If GATE-2.7 was activated, add a "System Structure Design" area (max 10 bonus points).
- Record the score and per-area breakdown in `status.md` Readiness Score table.
- If BLOCK questions remain, the "Resolution of approval items" area is capped at 5 points.
- **Confidence warning marks**: For each scoring area, if answers with `[Confidence: Estimated]` or `[Confidence: AI-Recommended]` affect that area, add a warning mark (⚠) next to the area score. List affected questions in the "Uncertain Areas" section of `status.md`.
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
