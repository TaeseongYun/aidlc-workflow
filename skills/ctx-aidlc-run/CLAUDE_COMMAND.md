---
description: Requirements/design analysis only using team-ai-workflow and project CTX. Write outputs to aidlc-docs and stop before implementation.
model: opus
allowed-tools: Read, Write, Edit, Bash
---

# ctx-aidlc-run

Use `{{TEAM_AI_WORKFLOW_DIR}}/` as the shared decision framework.
Use project `ctx/`, `AGENTS.md`, `CLAUDE.md`, and `README.md` as local context.
Write outputs to `aidlc-docs/`.

## Mission
- Analyze the request as greenfield or brownfield.
- Assess depth level (minimal/standard/comprehensive) per `depth-levels.md`.
- For prepared-requirement, run Input Validation (STEP 1-C) per `input-validation.md`.
- For brownfield without existing RE artifacts, run Reverse Engineering (STEP 1.5).
- Scan and present extension opt-in questions per `extension-rules.md`.
- Classify the request as `raw-request`, `prepared-requirement`, or `change-on-existing-feature`.
- Extract requirement gaps with Question Governance (Focus Anchor, type classification, risk-based priority P0/P1/P2, AI recommendations, confidence tagging, question budget) per `question-governance.md`.
- Validate answers for contradictions per `content-validation.md`.
- Apply overconfidence prevention per `overconfidence-prevention.md` at STEP 3 completion and STEP 6/6.5/6.7.
- On session resumption, verify state consistency per `error-recovery.md`.
- Write/update `aidlc-docs`.
- Stop before any implementation.

## Required Reading Order
1. `ctx/INDEX.md` when present
2. `ctx/project-profile.ctx.md` when present
3. `AGENTS.md` when present
4. `CLAUDE.md` when present
5. `README.md` when present
5a. `aidlc-docs/_roadmap.md` when present (multi-feature mode awareness; never overwrite)
6. Relevant additional `ctx/*`
7. `{{TEAM_AI_WORKFLOW_DIR}}/README.md`
8. `{{TEAM_AI_WORKFLOW_DIR}}/core/core-workflow.md`
9. `{{TEAM_AI_WORKFLOW_DIR}}/core/requirements-analysis.md`
10. `{{TEAM_AI_WORKFLOW_DIR}}/core/units-generation.md`
11. `{{TEAM_AI_WORKFLOW_DIR}}/core/unit-sizing.md`
12. `{{TEAM_AI_WORKFLOW_DIR}}/core/nfr-checklist.md`
13. `{{TEAM_AI_WORKFLOW_DIR}}/core/readiness-score.md`
14. `{{TEAM_AI_WORKFLOW_DIR}}/core/input-validation.md`
15. `{{TEAM_AI_WORKFLOW_DIR}}/core/reverse-engineering.md`
15. `{{TEAM_AI_WORKFLOW_DIR}}/common/question-rules.md`
16. `{{TEAM_AI_WORKFLOW_DIR}}/common/question-governance.md`
17. `{{TEAM_AI_WORKFLOW_DIR}}/common/no-implicit-decisions.md`
18. `{{TEAM_AI_WORKFLOW_DIR}}/common/stage-gate-rules.md`
19. `{{TEAM_AI_WORKFLOW_DIR}}/common/depth-levels.md`
20. `{{TEAM_AI_WORKFLOW_DIR}}/common/content-validation.md`
21. `{{TEAM_AI_WORKFLOW_DIR}}/common/extension-rules.md`
22. `{{TEAM_AI_WORKFLOW_DIR}}/common/overconfidence-prevention.md`
23. `{{TEAM_AI_WORKFLOW_DIR}}/common/error-recovery.md`
24. `{{TEAM_AI_WORKFLOW_DIR}}/templates/technical-design.md`
25. `{{TEAM_AI_WORKFLOW_DIR}}/extensions/` — scan for `*.opt-in.md` files

## Required Outputs

Project-level (brownfield STEP 1.5 only):
- `aidlc-docs/reverse-engineering/business-overview.md`
- `aidlc-docs/reverse-engineering/architecture-overview.md`
- `aidlc-docs/reverse-engineering/component-inventory.md`

Shared:
- `aidlc-docs/aidlc-state.md` (includes Depth Level, Confidence Summary, Extension Configuration)
- `aidlc-docs/audit.md`
- `aidlc-docs/features/<feature-slug>/status.md`
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/technical-design.md` — mandatory when 1 or more M/L sized UOWs exist
- Optional:
  - `aidlc-docs/features/<feature-slug>/unit-of-work-dependency.md`
  - `aidlc-docs/features/<feature-slug>/unit-of-work-story-map.md`

Create these additional files only for `raw-request`:
- `aidlc-docs/features/<feature-slug>/request-intake.md`
- `aidlc-docs/features/<feature-slug>/planning-draft.md`

## Hard Stop Rules
- Do NOT modify production code.
- Do NOT modify tests.
- Do NOT modify infrastructure.
- Do NOT modify frontend/backend runtime files.
- Only edit `aidlc-docs/` during this command.
- Even if requirements are fully resolved, STOP after documentation.
- Implementation is allowed only in a separate `/ctx-run` command.

## Question Rules
- Use the structured format from `question-rules.md` and governance rules from `question-governance.md`.
- Add Request Anchor at the top of question files. Add Scope Tag to every question.
- Classify each question as `policy` (human-only, BLOCK), `domain` (AI recommendation possible, AI-RECOMMEND), or `scope` (DEFER-TO-FEATURE).
- For `domain` questions: provide `AI 추천` field with recommendation + rationale based on industry standards and project CTX.
- For `policy` questions: NEVER provide AI recommendations. Business policies are human-only decisions.
- Assign risk-based priority to every question: `P0-CRITICAL` (external integration, security, data integrity), `P1-IMPORTANT` (policy, exceptions, data model), `P2-DEFERRABLE` (defaults, formatting, retry counts).
- P2 questions: AI decides with a default value. Record in "AI 자동 결정 (P2)" section. Do NOT present as BLOCK to humans.
- P0 questions: always require human confirmation. External integrations are minimum P1 even without explicit risk tags.
- Collect `⚠️ RISK:` tags from input documents and auto-promote related questions to P0.
- Respect question budget per depth level (minimal: 3, standard: 7, comprehensive: 12 per round). P2 questions do not count toward the budget.
- Every P0/P1 question must specify `BLOCK`, `ASSUME-{X}`, `AI-RECOMMEND-{X}`, or `DEFER-TO-FEATURE` for if-unanswered.
- Every answer must include `[확신]` tag: 확실 / 추정 / AI추천 / 미정.
- Include a summary table at the top of `requirement-verification-questions.md`.
- Before GATE-2, run contradiction detection per `content-validation.md`. Do not proceed with contradictions.
- STEP 4 runs for every request classification, including `prepared-requirement` and `change-on-existing-feature`. Empty areas detected in STEP 1-C must be converted into BLOCK questions.
- If STEP 4 yields zero P0/P1 questions, do NOT pass STEP 5/GATE-2 silently. Re-run question-omission detection per `overconfidence-prevention.md`; if still zero, get explicit user confirmation that GATE-2 may proceed and log the answer in `audit.md`.
- GATE-2 cannot be skipped under any classification. Direct entry into STEP 6 (UOW) is forbidden. GATE-2 does not pass while any unanswered BLOCK question remains.

## Behavior Rules
- Never make implicit business decisions.
- If multiple valid policies or designs exist, create questions instead of deciding.
- **Roadmap awareness**: when `aidlc-docs/_roadmap.md` exists, verify the working `feature-slug` matches a roadmap entry. Cite the roadmap's depends-on features and shared resources in `status.md` under a "Roadmap Context" section. If the slug is not in the roadmap, ask the user to (a) add it to the roadmap, (b) proceed as standalone, or (c) abort.
- **Multi-feature handoff**: in STEP 1-A round 1, if the user answers "multiple independent features" AND `_roadmap.md` does not exist, append a `[HANDOFF] ctx-aidlc-run → ctx-aidlc-roadmap` event to `audit.md` and stop. Instruct the user to run `/ctx-aidlc-roadmap` first, then invoke this command per feature after GATE-0 approval.
- For raw stakeholder requests, preserve the original wording in `request-intake.md` and create `planning-draft.md` before treating the request as implementation-ready.
- For prepared requirements, the only artifacts skipped are `request-intake.md`, `planning-draft.md`, and GATE-1. STEP 4 question generation and GATE-2 still run.
- For changes on an existing feature, prefer updating the existing feature folder instead of creating a new one.
- For brownfield, map the request to existing modules/components.
- For greenfield, define the minimum project/document structure needed before implementation.
- Reuse existing feature folders only if the user is clearly continuing the same feature.

## Technical Design (STEP 6.5 + GATE-3.5)
- After writing unit-of-work, verify the size (S/M/L) of every UOW.
- If 1 or more M or L sizes exist, `technical-design.md` MUST be written.
- If everything is S size, skip technical design and record "technical design skipped — all S size" in `status.md`.
- Template: `{{TEAM_AI_WORKFLOW_DIR}}/templates/technical-design.md`
- After writing, present GATE-3.5. Do not proceed to the next step without user approval.
- GATE-3.5 review items:
  - Is the ADR decision a well-grounded choice
  - Is the API response shape explicit and complete
  - Is the data model change compatible with the existing schema
  - Does the module structure match the unit-of-work decomposition

## Readiness Score
- After writing requirements, calculate a Readiness Score (0-100) using `core/readiness-score.md`.
- Record the score and per-area breakdown in `status.md`.
- 80+: `approved`. 60-79: `questions-open` with ASSUME conditions. Below 60: `questions-open`, implementation blocked.
- If BLOCK questions remain, "승인 항목 해결" area is capped at 5 points.

## Feature Discovery
- Before creating a new feature folder, scan `aidlc-docs/features/` for existing features.
- If a related feature exists, present the user with options:
  - A) Update existing feature folder
  - B) Create new feature folder
- Only auto-reuse when the user explicitly says this is a follow-up on an existing feature.

## Final Response Rule
Your final response must contain only:
1. What documents were created or updated
2. Readiness Score and judgment (READY / CONDITIONAL / NOT_READY)
3. Whether unresolved BLOCK questions remain (count)
4. A short statement that implementation has NOT been started

Do not include implementation steps, code patches, or commit plans.
