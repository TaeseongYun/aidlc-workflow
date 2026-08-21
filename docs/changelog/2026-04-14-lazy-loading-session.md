# 2026-04-14: Lazy Loading + Session-Separation Default Execution Model

## Background

When `/ctx-aidlc-run` was invoked, it bulk-loaded 31 files and consumed excessive tokens. Even for minimal-depth work, the structure read all the comprehensive-only templates (infrastructure-design, deployment-architecture, etc.).

In addition, session separation existed only at the level of "optional guidance," so in practice, comprehensive work repeatedly suffered answer inconsistencies from context collapse.

## Changes

### 1. Lazy Loading (INPUT LOADING STRATEGY)

**File**: `skills/ctx-aidlc-run/SKILL.md`

Converted the existing PRIMARY INPUTS (bulk-loading 31 files) into an INPUT LOADING STRATEGY.

#### Bootstrap (read immediately when the skill starts — 8 files)
1. `core/core-workflow.md`
2. `common/no-implicit-decisions.md`
3. `common/depth-levels.md`
4. Project `AGENTS.md` (or `CLAUDE.md`)
5. Project `ctx/INDEX.md`
6. Project `ctx/project-profile.ctx.md`
7. `aidlc-docs/aidlc-state.md`
8. `aidlc-docs/audit.md`

#### Per-STEP Loading (read only when entering that STEP)
- STEP 1-C: `input-validation.md`
- STEP 1.5: `reverse-engineering.md`, RE templates
- STEP 1.5 Extension Scan: `extension-rules.md`, `extensions/*.opt-in.md`
- STEP 3: `planning-draft.md` template, `diagram-standards.md`
- First GATE: `stage-gate-rules.md`
- STEP 4: `question-rules.md`, `question-governance.md`
- STEP 5: `requirements-analysis.md`
- STEP 5-V: `content-validation.md`
- STEP 5.5: `personas.md`, `stories.md` templates
- STEP 5.7: `components.md`, `services.md`, `component-dependency.md` templates
- STEP 6: `units-generation.md`, `unit-sizing.md`
- STEP 6.5: `technical-design.md` template, `nfr-checklist.md`
- STEP 6.7: `infrastructure-design.md`, `deployment-architecture.md` templates
- STEP 7: `readiness-score.md`
- STEP 9: `build-instructions.md`, `test-instructions.md` templates

#### Expected effect

| Depth Level | Files before | After Lazy Loading | Reduction |
|-------------|------------|----------------|------|
| minimal | 31 | ~12 | -61% |
| standard | 31 | ~18 | -42% |
| comprehensive | 31 | ~25 | -19% |

### 2. Promotion of the session-separation default execution model

**Files**: `docs/workflow-guide.md`, `skills/ctx-aidlc-run/SKILL.md`

#### workflow-guide.md changes
- Moved session separation to the very top of the document, stated as the "default execution model"
- Changed the application criteria:
  - comprehensive: "strongly recommended" → **required**
  - standard: "optional" → **recommended**
  - minimal: "unnecessary" → **optional**
- Added the Phase C session-resume pattern
- Replaced the previous duplicate session-separation section at the bottom with a reference to the top

#### ctx-aidlc-run/SKILL.md changes
- Added a new SESSION MANAGEMENT section (just before EXECUTION FLOW)
- Specified the Phase table, application criteria, and transition rules
- Added a "Phase A end point" notice to GATE-1 (recommends session separation for comprehensive)
- Added a "Phase B end point" notice to GATE-3 (recommends session separation for standard/comprehensive)

## Full list of modified files

| File | Change type |
|------|------------|
| `skills/ctx-aidlc-run/SKILL.md` | PRIMARY INPUTS → INPUT LOADING STRATEGY, added SESSION MANAGEMENT, GATE Phase notices |
| `docs/workflow-guide.md` | Promoted session separation to the top-level default execution model, removed duplication |
| `README.md` | Updated documentation links, added changelog entry |

## Reference sources

| Source | Pattern borrowed |
|------|-----------|
| BMAD-METHOD | Per-phase document-based context handoff (basis for session separation) |
| AIDLC workshop retrospective | Answer inconsistency due to context collapse (need for session separation) |
| Token diet analysis | Identified the inefficiency of bulk-loading 31 files (basis for Lazy Loading) |
