<!-- ctx-aidlc-run Phase A body (STEP 1 ~ GATE-1). Loaded by the SKILL.md PHASE ROUTER; the STEP LIFECYCLE,
CORE RULES, INPUT LOADING STRATEGY and OUTPUT CONTRACT of SKILL.md apply to every STEP below. -->

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
- With a code graph (`graphify-out/graph.json`): run `python3 {{TEAM_AI_WORKFLOW_DIR}}/scripts/graph_inventory.py .` first — it writes the `component-inventory.md` draft from the graph. Then read only `bash {{TEAM_AI_WORKFLOW_DIR}}/scripts/md-section.sh graphify-out/GRAPH_REPORT.md "## God Nodes" "## Communities"` for `architecture-overview.md`. Verify every `⚠️ UNCERTAIN (auto)` row against `ctx/` or the source (`file:line`); do not explore the source tree wholesale. Without a graph, follow the manual workflow.
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
