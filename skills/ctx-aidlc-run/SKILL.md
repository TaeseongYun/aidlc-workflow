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
4. On resume only (aidlc-state.md already shows progress): `bash {{TEAM_AI_WORKFLOW_DIR}}/scripts/md-section.sh {{TEAM_AI_WORKFLOW_DIR}}/common/error-recovery.md "## 2. Session Resumption Procedure"`. Load the full file only when an error or inconsistency is actually found.
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
| STEP 1.5 entry | `core/reverse-engineering.md`, `templates/reverse-engineering/*`, `common/graph-grounding.md`; with a graph: `scripts/graph_inventory.py` + GRAPH_REPORT.md sections instead of source exploration (see STEP 1.5) |
| STEP 1.5 Extension Scan | `common/extension-rules.md`, `extensions/*.opt-in.md` |
| After STEP 3 completion | `common/overconfidence-prevention.md` (perform question-omission detection) |
| STEP 3 entry | `templates/planning-draft.md` (raw-request only), `common/diagram-standards.md`, `common/graph-grounding.md`, `templates/graph-evidence.md` |
| Reaching the first GATE | `bash {{TEAM_AI_WORKFLOW_DIR}}/scripts/md-section.sh {{TEAM_AI_WORKFLOW_DIR}}/common/stage-gate-rules.md "## Gate List" "## Gate Rules" "## Standard Approval Message Format" "## Audit Log Integration"` once (reused for all GATEs); at each GATE-N add `"### GATE-N:"` (its Per-Gate Review Items). Never load the whole file |
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

- Shared execution protocol: `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md` (halt format, execution boundary).
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
  1. Run `bash {{TEAM_AI_WORKFLOW_DIR}}/scripts/aidlc-log.sh <step|gate|answer|status|handoff|set> ...` once for the event (`--help` lists the arguments). It appends the `templates/audit.md` block and updates the `aidlc-state.md` checkboxes (`[x]` completed, `[-]` skipped with reason), Current Stage, Feature Status, and Last Updated in one call.
  2. Do not Read or Edit `audit.md` / `aidlc-state.md` for these events. Only if the script exits non-zero, fall back to a manual append in the `templates/audit.md` format plus a manual checkbox update.
  3. Do NOT batch these updates. Each event triggers its own call (several calls may share one turn with the step's other tool calls).

────────────────────────────────────
OUTPUT CONTRACT
────────────────────────────────────

Generate or update, under the project root, the artifacts listed in `core/core-workflow.md` §8 (loaded at BOOTSTRAP): the project-level RE files (brownfield, STEP 1.5), the shared `aidlc-docs/aidlc-state.md` / `aidlc-docs/audit.md`, the mandatory feature files, and the conditional INCEPTION / CONSTRUCTION / extension files under their stated conditions. Each STEP names the files it writes under `aidlc-docs/features/<feature-slug>/`.
- `aidlc-docs/_roadmap.md` is consumed, never produced, by this skill (producer: `ctx-aidlc-roadmap`). Read it in BOOTSTRAP, cite it in `status.md`, never overwrite it.
- `unit-of-work-dependency.md` / `unit-of-work-story-map.md` are added when they clarify the plan (STEP 6).
- Use the templates and structure from `{{TEAM_AI_WORKFLOW_DIR}}/templates/` unless the project already has a stronger established structure.

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

STEP LIFECYCLE (common to all STEPs) — each line is one `aidlc-log.sh` call (see Real-time update rule):
- On start: `aidlc-log.sh step <slug> STEP-{ID} "{Name}" started` (audit `[STEP-{ID}] … — started`, sets Current Stage)
- On conditional skip: `aidlc-log.sh step <slug> STEP-{ID} "{Name}" skipped "{reason}"` (audit + aidlc-state.md `[-]`). Also record the skip reason in status.md.
- On completion: `aidlc-log.sh step <slug> STEP-{ID} "{Name}" completed "" "{outputs}"` (audit + aidlc-state.md `[x]`)
- On a GATE decision: `aidlc-log.sh gate <slug> GATE-{N} "{Name}" approved|change-requested|skipped "{user text verbatim}"`
- On receiving a user answer: `aidlc-log.sh answer <slug> "{question id}" "{user text verbatim}" "{impact}"`
- On a GATE decision or a unit-of-work completion → also append a **result** entry to the structured run
  log (protocol: `{{TEAM_AI_WORKFLOW_DIR}}/common/run-logging.md`), so later runs and graphify can retrieve
  outcomes: `npx tsx {{TEAM_AI_WORKFLOW_DIR}}/scripts/run-logger.ts append --project . --feature <slug>
  --skill ctx-aidlc-run --phase <GATE-N|unit:<id>> --kind <gate|unit> --result "<outcome>"`. Result-level
  only — the per-event audit trail stays in `aidlc-log.sh`.
- This pattern is applied automatically to all STEPs. Do not repeat it in individual STEPs.

PHASE ROUTER (load only the current Phase's STEP text):
- Determine the Phase: the user prompt first ("Phase B를 시작한다"), else `aidlc-state.md` (Current Phase / first unchecked STEP), else Phase A.
- Read exactly one file, then execute its STEPs in order:
  - Phase A (STEP 1 ~ GATE-1): `{{TEAM_AI_WORKFLOW_DIR}}/skills/ctx-aidlc-run/phases/phase-a.md`
  - Phase B (STEP 4 ~ GATE-3): `{{TEAM_AI_WORKFLOW_DIR}}/skills/ctx-aidlc-run/phases/phase-b.md`
  - Phase C (STEP 6.5 ~ GATE-5): `{{TEAM_AI_WORKFLOW_DIR}}/skills/ctx-aidlc-run/phases/phase-c.md`
- When a Phase continues in the same session (minimal depth, or the user says "continue"), read the next Phase file at that point. Never read a Phase file ahead of time.
- On entering a Phase: `aidlc-log.sh set "Current Phase" "B (Definition)"` (A (Discovery) / B (Definition) / C (Design)).

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
