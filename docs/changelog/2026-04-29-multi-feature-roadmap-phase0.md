# 2026-04-29: Phase 0 Roadmapping and Multi-Feature Coordination Workflow

## Background

When a large prepared planning document naturally decomposes into several features, the following problems were repeatedly reported when a team divides the work:

1. **Cross-feature resource duplication** — different features try to build the same component/table/shared module
2. **Invisible upstream dependencies** — feature B needs feature A's output, but this is not stated anywhere
3. **No basis for dividing work** — there is no reference material to decide who handles what

The first round of the existing `ctx-aidlc-run` STEP 1-A only advised "if there are multiple features, decompose them," with no blocking, roadmap output, or handoff. As a result, users could only respond by either (a) forcibly bundling all work into a single feature folder, or (b) running ctx-aidlc-run separately per feature and discovering merge conflicts and policy mismatches after the fact.

This change fills that gap by formally incorporating a **Phase 0 — Roadmapping** stage into the workflow.

## Changes

### 1. New skill — `ctx-aidlc-roadmap`

**Files**: `skills/ctx-aidlc-roadmap/SKILL.md`, `skills/ctx-aidlc-roadmap/CLAUDE_COMMAND.md` (new)

- A standalone Phase 0 skill. Composed of STEP R1 ~ R6 + GATE-0.
- Input: the original prepared-requirement planning document. raw-request / change-on-existing-feature / single-feature are rejected and routed to the appropriate skill.
- Output: a single project-level file, `aidlc-docs/_roadmap.md`.
- BOOTSTRAP / Lazy Loading / real-time audit·state updates are unified to the same pattern as ctx-aidlc-run.
- Does not create per-feature `requirements.md` or `unit-of-work.md` (that is ctx-aidlc-run's responsibility).

Skill steps:
- **STEP R1** Input Validation — confirm classification, judge multi-feature signal. If single, skip all R-steps as `[-]`.
- **STEP R2** Feature Decomposition — feature slug (kebab-case) + one-line responsibility. Apply the Single Domain Principle.
- **STEP R3** Resource Matrix — a per-feature occupancy table of components/tables/APIs/events. If the same resource appears in 2+ features, mark ⚠.
- **STEP R4** Dependency Graph — inter-feature dependencies, cycle check, ⚠ resource handling (foundation extraction or single-owner assignment).
- **STEP R5** Allocation Recommendation — serial/parallel grouping, role-based work-split recommendation, merge-conflict risk annotation.
- **STEP R6** Roadmap File Output — write `_roadmap.md`, sync `aidlc-state.md`.
- **GATE-0** — after user approval, print per-feature handoff messages.

### 2. ctx-aidlc-run extension — bidirectional entry support

**Files**: `skills/ctx-aidlc-run/SKILL.md`, `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

- Added immediate reading of `aidlc-docs/_roadmap.md` to BOOTSTRAP.
- Added one line to CORE RULES: "if a roadmap exists, do not ignore its dependency and shared-resource information."
- Added Roadmap awareness to STEP 1 — when a roadmap exists, verify the working feature-slug is in its items, and cite the outputs of upstream features it depends on in the "Roadmap Context" section of `status.md`. On a slug mismatch, ask the user to choose one of (a) add / (b) standalone / (c) abort and record it in the audit.
- Added a multi-feature handoff branch to the first round of STEP 1-A — "multiple" AND `_roadmap.md` missing → STOP, record `[HANDOFF] ctx-aidlc-run → ctx-aidlc-roadmap` in audit.md, and advise running `/ctx-aidlc-roadmap`.

### 3. Gate — new GATE-0

**File**: `common/stage-gate-rules.md`

- Added GATE-0 (Roadmap Review) at the top of the gate list table.
- Whitelist-style skip rule: GATE-0 can only be skipped when single-feature.
- Added GATE-0 to the gates that cannot be explicitly skipped — once triggered, it cannot be skipped even by a bulk user approval.
- New review items: appropriateness of feature decomposition, resolution of ⚠ resources, absence of cyclic dependencies, serial/parallel distinction in the work-split recommendation, slug naming rules, aidlc-state sync.

### 4. Outputs / state / audit — settling multi-feature metadata

**Files**: `templates/feature-roadmap.md` (new), `templates/aidlc-state.md`, `templates/audit.md`, `core/core-workflow.md`

- `templates/feature-roadmap.md` new — the 8 sections of `_roadmap.md` (Source / Feature List / Resource Matrix / Dependency Graph / Allocation / Handoff Plan / Open Items / GATE-0 Pointers).
- `templates/aidlc-state.md`:
  - New `Roadmap State` section (Roadmap Path, Multi-Feature Mode, GATE-0 Decision, Last Update)
  - Changed `Feature Index` to table format + added a Roadmap Source column
  - New `Cross-Feature Dependencies` section (Source/Depends On/Shared Resource/Resolution)
  - New `Roadmap Phase Progress` checklist (R1~R6 + GATE-0)
- `templates/audit.md`:
  - Specified the rule that the Feature field of Phase 0 STEP / GATE-0 is written as `roadmap`
  - New `[HANDOFF]` event format (from-skill / to-skill / Reason / Resume Hint)
- `core/core-workflow.md`:
  - Added the Phase 0 entry condition to step 0 of the common execution order
  - Added GATE-0 to the approval gate list
  - Registered `aidlc-docs/_roadmap.md` in the output list (a project-level output exclusively for multi-feature prepared-requirement)

### 5. Operations guide / quick start / workflow guide

**Files**: `docs/multi-feature-coordination.md` (new), `docs/workflow-guide.md`, `README.md`, `QUICKSTART.md`, `skills/README.md`

- `docs/multi-feature-coordination.md` new — 7 sections (Applicability / Bidirectional Entry / Interpreting Outputs / 3 Work-Split Patterns / Conflict Resolution / Per-Feature Execution / FAQ).
- `docs/workflow-guide.md` — added a "Phase 0: Roadmapping" section before Phase A, added a Phase 0 row to the session-separation table.
- `README.md` — a Phase 0 block in the workflow flow diagram, `_roadmap.md` in the directory structure, `/ctx-aidlc-roadmap` registered in the skills table.
- `QUICKSTART.md` — added a multi-feature scenario paragraph (after the single-feature flow).
- `skills/README.md` — registered the new skill, separated single/multi flows into distinct recommended flows.

### 6. Install / init script sync

**Files**: `scripts/install-skills.sh`, `scripts/init-project.sh`

- Registered `ctx-aidlc-roadmap` in the `install-skills.sh` SKILLS array — the new skill is also deployed to the global paths (`~/.codex/skills/`, `~/.claude/commands/`).
- Switched the inline heredoc creation of `aidlc-state.md` / `audit.md` in `init-project.sh` to a `cp templates/*.md` basis:
  - `aidlc-state.md` — copy the template, then fill in only Start Date via sed. Roadmap State and Cross-Feature Dependencies are immediately usable even in a new project.
  - `audit.md` — copy only up to the first separator with `sed '/^---$/q'` (porting the rules, triggers, and HANDOFF format, while removing the sample Feature Start entry).
- Subsequent template changes are then reflected automatically without editing the init script.

## User question — "If we make a separate skill, at what point should it run?"

Conclusion for the user question that prompted this change:

| Entry path | Timing | Trigger condition |
|----------|------|-----------|
| 1. Direct call | Immediately after receiving the prepared planning document | The user knows it is a large planning document and runs `/ctx-aidlc-roadmap` first |
| 2. Handoff | First round of `/ctx-aidlc-run` STEP 1-A | "multiple independent features" answer AND `_roadmap.md` missing → ctx-aidlc-run blocks and advises |
| Exit | After GATE-0 approval | `_roadmap.md` finalized → each teammate runs `/ctx-aidlc-run` with their own feature slug as an argument (prepared-requirement, with the relevant feature excerpt as input) |

## Full list of modified/new files

| File | Change type |
|------|----------|
| `skills/ctx-aidlc-roadmap/SKILL.md` | New |
| `skills/ctx-aidlc-roadmap/CLAUDE_COMMAND.md` | New |
| `templates/feature-roadmap.md` | New |
| `docs/multi-feature-coordination.md` | New |
| `docs/changelog/2026-04-29-multi-feature-roadmap-phase0.md` | New |
| `skills/ctx-aidlc-run/SKILL.md` | BOOTSTRAP / CORE RULES / STEP 1 / STEP 1-A updates |
| `skills/ctx-aidlc-run/CLAUDE_COMMAND.md` | Required Reading / Behavior Rules sync |
| `common/stage-gate-rules.md` | Added GATE-0 item·skip rule·review items |
| `core/core-workflow.md` | Phase 0 entry condition / gate list / output registration |
| `templates/aidlc-state.md` | Roadmap State / Cross-Feature Deps / Roadmap Phase Progress |
| `templates/audit.md` | Phase 0 Feature notation / [HANDOFF] format |
| `docs/workflow-guide.md` | Phase 0 section + session-separation table |
| `README.md` | Flow diagram / directory / skills / changelog |
| `QUICKSTART.md` | Multi-feature scenario |
| `skills/README.md` | New skill registration + flow branching |
| `scripts/install-skills.sh` | Registered the new skill in the SKILLS array |
| `scripts/init-project.sh` | Inline heredoc → template-cp based switch |

## Validation

- `tools/validate-skills.sh`: 38 PASS / 0 FAIL (all 5 check items for the new skill pass)
- Ran `init-project.sh` in a temporary directory and confirmed that `aidlc-state.md` Start Date is auto-filled, and `audit.md` ports the rules, triggers, and HANDOFF format while the sample entry is removed.

## Expected effect

- Because it forces the output of **feature decomposition·resource matrix·dependency graph** before dividing a large prepared planning document, after-the-fact merge conflicts and policy mismatches are reduced.
- Because ctx-aidlc-run's STEP 1-A automatically blocks when multi-feature is detected, the pattern of bundling heterogeneous domains into a single feature folder is blocked.
- The Cross-Feature Dependencies table in `aidlc-state.md` becomes the single source of truth, making it visible which teammate is handling which feature and what they are waiting on.
- No impact on single-feature projects (skipped as `[-]` at STEP R1).

## Follow-up tasks (out of scope for this work)

- A Golden Baseline example for Phase 0 outputs (`examples/golden-baselines/multi-feature/_roadmap.md`)
- Adding GATE-0 pass-condition validation rules to `tools/evaluator/` (feature slug naming, ⚠ resource resolution, absence of cyclic dependencies)
