# Change: Structural Refactoring (P0~P3)

## Change Date
2026-03-24

## Background

Analyzing the overall project structure identified the following problems:
- The same rule was described redundantly in 3~4 places → risk of inconsistency on change
- Absence of definitions for core terms → higher onboarding cost
- Absence of linking information between templates and workflow steps
- Common boilerplate repeated across skills
- Absence of examples showing the expected level of artifacts
- Rate limit problems caused by specifying the Sonnet model

---

## P0: Deduplication (Critical)

### P0-1: Deduplicate the question format
- **Problem**: the question format was repeated in 3 places: `common/question-rules.md`, `templates/requirement-verification-questions.md`, `skills/ctx-aidlc-run/SKILL.md`
- **Solution**: keep `question-rules.md` as the single source of truth. Leave only 1 example in the template and reduce the remaining sections to references
- **Modified file**: `templates/requirement-verification-questions.md`

### P0-2: Merge approval-rules → stage-gate-rules
- **Problem**: the contents of `approval-rules.md` were a subset of `stage-gate-rules.md` yet existed as a separate file
- **Solution**: delete `approval-rules.md`. Absorb its unique content into the "items requiring approval" section of `stage-gate-rules.md`
- **Deleted file**: `common/approval-rules.md`
- **Modified files**: `common/stage-gate-rules.md`, `skills/ctx-aidlc-run/SKILL.md`, `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

### P0-3: Extract the size definitions
- **Problem**: the S/M/L size definitions were repeated in 3 places: `templates/unit-of-work.md`, `skills/ctx-aidlc-run/SKILL.md`, `docs/changelog/`
- **Solution**: create `core/unit-sizing.md`. Replace the inline definitions in the 3 places with references
- **New file**: `core/unit-sizing.md`
- **Modified files**: `templates/unit-of-work.md`, `skills/ctx-aidlc-run/SKILL.md`, `docs/changelog/2026-03-23-technical-design.md`

---

## P1: Filling Gaps (High Priority)

### P1-1: Glossary
- **Problem**: core terms such as `raw-request`, `brownfield`, `BLOCK`, `UOW`, `ADR` were used without definition
- **Solution**: create `docs/terminology.md` (7 categories, 25 terms)
- **New file**: `docs/terminology.md`
- **Modified file**: `README.md` (added link)

### P1-2: Template workflow metadata
- **Problem**: looking at a template file alone, you cannot tell at which STEP it is produced or which GATE it connects to
- **Solution**: add a `<!-- workflow-step / gate / producer -->` HTML comment to the top of 9 templates
- **Modified files**: 9 files under `templates/`

### P1-3: Merge project-profile
- **Problem**: `project-profile.md` and `project-profile.ctx.md` were nearly identical
- **Solution**: delete `project-profile.md`. Consolidate into `project-profile.ctx.md` (making Related CTX Files an optional section)
- **Deleted file**: `templates/project-profile.md`
- **Modified files**: `templates/project-profile.ctx.md`, `core/core-workflow.md`

---

## P2: Structural Improvement (Medium Priority)

### P2-1: Extract a common skill protocol
- **Problem**: input validation rules, execution guidelines, and output constraints were repeated identically across 6 skills
- **Solution**: create `skills/_shared/skill-protocol.md`. Replace the boilerplate in the 6 skills with references
- **New file**: `skills/_shared/skill-protocol.md`
- **Modified files**: 6 skill SKILL.md files, `skills/README.md`

### P2-2: Consolidated STOP conditions document
- **Problem**: "when should we stop?" was scattered across 8+ files
- **Solution**: create `docs/stop-conditions.md`. Consolidate a Mermaid decision tree + policy/gate/score-based STOP conditions
- **New file**: `docs/stop-conditions.md`
- **Modified file**: `README.md`

### P2-3: Filled-in example artifacts
- **Problem**: `examples/` had only a directory structure and no actual content examples
- **Solution**: create 5 examples — status, requirements, questions, unit-of-work, technical-design — with a "repurchase discount coupon" scenario
- **New files**: `examples/filled-outputs/` (README.md, status.md, requirements.md, requirement-verification-questions.md, unit-of-work.md, technical-design.md)
- **Modified file**: `examples/project-layout-example.md`

---

## P3: Adding Guides (Polish)

### P3-1: Korean-English mixed style guide
- **Problem**: template headings are English, question labels must be Korean, body text is mixed → no consistency
- **Solution**: create `docs/style-guide.md`. Define the language rules for section headings/field labels/body text/commit messages respectively
- **New file**: `docs/style-guide.md`
- **Modified file**: `README.md`

### P3-2: Schematize the Readiness Score
- **Problem**: the scoring criteria existed only as Markdown prose, making automatic scoring difficult
- **Solution**: create `core/readiness-score.schema.yaml`. Define the 15 criteria across 6 areas as structured YAML
- **New file**: `core/readiness-score.schema.yaml`
- **Modified file**: `core/readiness-score.md`

### P3-3: Brownfield hands-on guide
- **Problem**: absence of a concrete guide for exploring brownfield projects
- **Solution**: create `docs/brownfield-guide.md`. A 5-step exploration order + a hands-on coupon system example
- **New file**: `docs/brownfield-guide.md`
- **Modified file**: `README.md`

---

## Skill Model Setting Changes

### Fix missing Technical Design in CLAUDE_COMMAND.md
- **Problem**: on 2026-03-23, STEP 6.5 (Technical Design) + GATE-3.5 were added to `SKILL.md`, but the `CLAUDE_COMMAND.md` sync was missed. When Claude Code references `CLAUDE_COMMAND.md` while running `/ctx-aidlc-run`, a bug occurred where `technical-design.md` was not generated even at M/L sizes
- **Solution**: add the following to `CLAUDE_COMMAND.md`
  - Add `core/unit-sizing.md`, `templates/technical-design.md` to the Required Reading Order
  - Add `technical-design.md` (required at M/L size) to the Required Outputs
  - Add a Technical Design (STEP 6.5 + GATE-3.5) section
- **Modified file**: `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

### Resolve Sonnet rate limit
- **Problem**: `ctx-reviewer`, `ctx-updater` specified `model: sonnet` → the Sonnet rate limit was hit on model switching during a ctx-run execution
- **Solution**: remove `model: sonnet` from both skills. Inherit the parent skill's (ctx-run) `model: opus`
- **Modified files**: `skills/ctx-reviewer/SKILL.md`, `skills/ctx-updater/SKILL.md`

---

## Change Statistics

| Category | Count |
|------|---|
| New files | 14 |
| Modified files | 31 |
| Deleted files | 2 |

## Compatibility

- Backward compatible: no change to the existing skill execution flow
- No impact on existing artifacts
- Skill redeployment required: `bash scripts/install-skills.sh`
