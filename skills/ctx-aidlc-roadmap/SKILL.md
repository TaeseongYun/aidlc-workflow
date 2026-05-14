---
description: Multi-feature roadmapping (Phase 0) for prepared planning documents. Decomposes a large prepared requirement into feature slugs, resource matrix, dependency graph, and allocation plan, then stops at GATE-0.
model: opus
allowed-tools: Read, Write, Edit, Bash
---

ROLE: ROADMAP_COORDINATOR
MODE: MULTI_FEATURE_ROADMAPPING
EXECUTION_MODEL: SEQUENTIAL

────────────────────────────────────
PURPOSE
────────────────────────────────────

Run **Phase 0 — Roadmapping** before any feature-level analysis when a prepared planning document decomposes into multiple features.

This skill produces a single project-level artifact `aidlc-docs/_roadmap.md` and gates approval at GATE-0. After approval, each team member runs `/ctx-aidlc-run` per feature using the roadmap as input.

This skill does NOT:
- Run STEP 4 question generation
- Write `requirements.md` or `unit-of-work.md`
- Make implementation decisions
- Replace `ctx-aidlc-run` for individual features

────────────────────────────────────
ENTRY CONDITIONS
────────────────────────────────────

Direct entry: User invokes `/ctx-aidlc-roadmap` with a prepared planning document path or content.

Handoff entry: `ctx-aidlc-run` STEP 1-A round 1 detects "multiple independent features" AND `aidlc-docs/_roadmap.md` does not exist. The handoff message must include the original request reference.

Reject and exit if:
- Request classification is `raw-request` → instruct user to run `/ctx-aidlc-run` first to produce `planning-draft.md`, then re-run this skill.
- Request classification is `change-on-existing-feature` → instruct user to run `/ctx-aidlc-run` directly on the affected feature folder.
- Single-feature prepared-requirement → instruct user to run `/ctx-aidlc-run` directly. GATE-0 is skipped (`[-]` with reason "single-feature").

────────────────────────────────────
INPUT LOADING STRATEGY
────────────────────────────────────

Lazy Loading. Read the minimum at start, load per-step files only when entering that step.

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
10. `aidlc-docs/_roadmap.md` (if exists — for resume)

If `ctx/INDEX.md` or `ctx/project-profile.ctx.md` is missing, infer from `README.md`, `AGENTS.md`, repository layout, and existing CTX files.

PER-STEP LOADING:

| Step Entry | Files |
|------------|-------|
| STEP R1 | `core/input-validation.md` |
| STEP R2 | `core/units-generation.md` (single-domain principle), `templates/feature-roadmap.md` |
| STEP R3 | (brownfield) `aidlc-docs/reverse-engineering/component-inventory.md` |
| STEP R4 | `common/diagram-standards.md` (for dependency graph rendering) |
| GATE-0 | `common/stage-gate-rules.md` |

Skipped steps do not load their files.

────────────────────────────────────
CORE RULES
────────────────────────────────────

- `team-ai-workflow/` defines HOW to think.
- Project `ctx/` defines WHAT is already true.
- `aidlc-docs/_roadmap.md` is the **single source of truth** for cross-feature coordination. Per-feature `ctx-aidlc-run` runs MUST read it.
- Never make implicit business or product decisions during roadmapping. Defer all policy questions to per-feature `ctx-aidlc-run` STEP 4.
- Roadmap-time decisions are limited to: feature decomposition, slug naming, resource ownership assignment, dependency ordering, parallelization safety.
- Apply `units-generation.md` Single Domain Principle at the **feature level** (not UOW level): one feature should not bundle two independent domains.
- A resource appearing in 2+ features (⚠) MUST be resolved before GATE-0: extract to `foundation-*` feature OR assign single owner explicitly.
- Audit log (`audit.md`) is append-only.
- **Real-time update rule**: After EVERY STEP start/complete/skip, GATE-0 decision, and HANDOFF event, IMMEDIATELY:
  1. Append to `audit.md` per `templates/audit.md` triggers.
  2. Update `aidlc-state.md` Roadmap Phase Progress checkboxes, Roadmap State, Feature Index, and Cross-Feature Dependencies.
  3. Do NOT batch updates.
- Phase 0 audit/state entries use `Feature: roadmap` (not a per-feature slug).

────────────────────────────────────
OUTPUT CONTRACT
────────────────────────────────────

Project-level files:
- `aidlc-docs/_roadmap.md` (mandatory)
- `aidlc-docs/aidlc-state.md` (update Roadmap State, Feature Index, Cross-Feature Dependencies)
- `aidlc-docs/audit.md` (append Phase 0 events)

No feature folders are created during this skill. Per-feature folders are created later by `ctx-aidlc-run` invocations.

────────────────────────────────────
EXECUTION FLOW
────────────────────────────────────

STEP LIFECYCLE (all steps):
- On entry: `[STEP-RN] {Name} — started` → audit.md append (Feature: roadmap)
- On conditional skip: `[STEP-RN] {Name} — skipped ({reason})` → audit.md append, aidlc-state.md `[-]`
- On completion: `[STEP-RN] {Name} — completed` → audit.md append, aidlc-state.md `[x]`
- On user input (GATE-0 answer or scope decisions): `[ANSWER]` entry to audit.md verbatim

STEP R1. Input Validation
- Confirm classification is `prepared-requirement`. If not, reject per ENTRY CONDITIONS and exit.
- Run `core/input-validation.md` workflow (completeness, contradictions, undefined terms, `⚠️ RISK:` tags) on the planning document.
- Determine multi-feature signal:
  - If document explicitly enumerates 2+ features OR independent flows OR ≥3 distinct domains, treat as multi-feature.
  - If signal is ambiguous, ask the user a single binary question: "Is this a single feature or multiple features?" Record the answer in audit.md.
  - If single-feature, mark all R-steps as skipped (`[-]` reason: "single-feature"), instruct the user to run `/ctx-aidlc-run` directly, exit.
- Output: validation summary in scratch (not yet written to `_roadmap.md`).

STEP R2. Feature Decomposition
- Propose feature slugs from the planning document. AI proposes; user reviews at GATE-0.
- Each feature gets:
  - Feature ID (`F-1`, `F-2`, …)
  - Slug (kebab-case, ≤4 words)
  - 1-line responsibility
  - Type (`domain-feature` / `foundation-*` / `integration` / `ops/admin`)
- Apply Single Domain Principle. If a feature bundles 2+ independent domains, split.
- foundation-* features (shared models, common modules, base infra) are placed first.
- Write decomposition into the in-memory roadmap draft (do not write file yet — write at STEP R6).

STEP R3. Resource Matrix
- For each feature, enumerate resources it CREATES or MODIFIES:
  - components, tables, APIs, events, modules, infra elements
- Build the matrix per `templates/feature-roadmap.md` Section 3.
- Mark ⚠ on any resource appearing in 2+ features.
- For brownfield, cross-reference `aidlc-docs/reverse-engineering/component-inventory.md` to label resources as new vs. modified.

STEP R4. Dependency Graph
- For each feature, list:
  - Source feature (this feature)
  - Depends on (feature IDs)
  - Reason (resource/data/api dependency)
  - Resolution (`foundation-extracted` / `serialized` / `parallel-safe`)
- Resolve every ⚠ from STEP R3:
  - If resource is shared infra/model → extract into `foundation-*` feature, all consumers depend on it.
  - If resource is genuinely owned by one feature → assign single owner, others must wait or read-only.
- Detect cycles. If cycle exists, propose a break (split feature, invert dependency, or extract foundation). Do not proceed to R5 with unresolved cycles.
- Optionally render Mermaid graph per `common/diagram-standards.md` when feature count ≥ 5 or dependencies are non-trivial.

STEP R5. Allocation Recommendation
- Group features by execution phase:
  - Phase 1: serial (foundation, blocking)
  - Phase 2+: parallel-safe groups
  - Phase N: serial tail (depends on earlier phase outputs)
- Recommend per-feature ownership by role/skill (NOT by individual person — user fills names).
- Note parallel-safety: highlight features that touch the same module and would cause merge conflicts; recommend serialization.
- Build the Handoff Plan: for each feature, identify the planning-document section that will be excerpted as input when the team member runs `/ctx-aidlc-run`.

STEP R6. Roadmap File Output
- Write `aidlc-docs/_roadmap.md` using `templates/feature-roadmap.md` structure.
- Synchronize `aidlc-docs/aidlc-state.md`:
  - Roadmap State: Multi-Feature Mode = yes, Roadmap Path = active, Last Roadmap Update = now
  - Feature Index: one row per feature with Roadmap Source = `F-N`
  - Cross-Feature Dependencies: replicate from roadmap section 4 with Resolution values
- Append audit entry: `[STEP-R6] Roadmap File Output — completed` with output paths.
- Present the file to the user and proceed to GATE-0.

GATE-0. Roadmap Review
- Use approval message format from `common/stage-gate-rules.md`. Required content:
  - Summary: feature count, foundation count, ⚠ count resolved, cycle status
  - Review file paths: `aidlc-docs/_roadmap.md`, `aidlc-docs/aidlc-state.md`
  - Two choices only: revise / approve-and-continue
- Do NOT proceed without explicit approval.
- On approval:
  - Append `[GATE-0] Roadmap — approved` to audit.md (Feature: roadmap)
  - Mark GATE-0 `[x]` in aidlc-state.md
  - Output the next-step instruction: list each feature's slug and the corresponding `/ctx-aidlc-run` invocation hint
- On revision:
  - Capture user input verbatim in audit.md
  - Re-run from the appropriate STEP (R2/R3/R4/R5) and re-present GATE-0
- On user-requested skip (single-feature override):
  - Allowed only if user explicitly states "single-feature, skip roadmap"
  - Mark `[-]` with reason "user-requested single-feature"
  - Cannot be triggered by user inactivity or batch approval

────────────────────────────────────
HANDOFF MESSAGES
────────────────────────────────────

After GATE-0 approval, output exactly this structure (one block per feature):

```markdown
### Phase 0 완료 — 피처별 진행 안내

다음 명령으로 각 피처를 진행하세요:

#### F-1: <slug>
\`\`\`
/ctx-aidlc-run

Phase 0 로드맵 기준으로 F-1(<slug>) 작업을 시작한다.
- 입력: prepared-requirement (원본 §<범위>)
- 의존: <선행 피처 산출물 경로 또는 "없음">
- aidlc-docs/_roadmap.md를 먼저 읽어라.
\`\`\`

#### F-2: <slug>
…
```

Features in different phases (R5 결과)는 Phase 1 → Phase 2 순서로 그룹화하여 표시한다.

────────────────────────────────────
WHEN TO STOP
────────────────────────────────────

Stop and wait when any of the following:
- STEP R1 detects raw-request or change-on-existing-feature → reject with ENTRY CONDITIONS message
- STEP R1 ambiguous multi-feature signal → ask user
- STEP R4 unresolved cycle → ask user for resolution preference
- STEP R3 ⚠ resource cannot be auto-resolved (no clear single owner, no foundation candidate) → ask user
- GATE-0 not approved

────────────────────────────────────
FINAL RESPONSE RULE
────────────────────────────────────

Your final response must contain only:
1. What was created or updated (paths)
2. Feature count and ⚠ resource count (resolved/unresolved)
3. GATE-0 decision (approved / pending / revised)
4. Next-step handoff messages (one per feature) when GATE-0 is approved

Do NOT include feature-level requirements, UOW decomposition, design decisions, or implementation guidance. Those belong to per-feature `/ctx-aidlc-run` runs.
