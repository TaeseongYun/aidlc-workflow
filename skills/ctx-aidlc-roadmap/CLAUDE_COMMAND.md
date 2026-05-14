---
description: Phase 0 multi-feature roadmapping. Decompose a large prepared planning document into feature slugs, resource matrix, dependency graph, and allocation plan. Stop at GATE-0.
model: opus
allowed-tools: Read, Write, Edit, Bash
---

# ctx-aidlc-roadmap

Use `{{TEAM_AI_WORKFLOW_DIR}}/` as the shared decision framework.
Use project `ctx/`, `AGENTS.md`, `CLAUDE.md`, and `README.md` as local context.
Write outputs to `aidlc-docs/_roadmap.md` (project-level, single file).

## Mission
- Validate that the request is a multi-feature `prepared-requirement`.
- Decompose into feature slugs (kebab-case, single-domain) per `units-generation.md` Single Domain Principle.
- Build a Resource Matrix and flag any resource appearing in 2+ features.
- Build a Dependency Graph and resolve every shared resource (extract foundation OR assign single owner).
- Recommend execution phases and parallel-safe groups.
- Stop at GATE-0. Do not run feature-level analysis (that belongs to `/ctx-aidlc-run`).

## Required Reading Order
1. `ctx/INDEX.md` when present
2. `ctx/project-profile.ctx.md` when present
3. `AGENTS.md` when present
4. `CLAUDE.md` when present
5. `README.md` when present
6. `aidlc-docs/aidlc-state.md` when present
7. `aidlc-docs/audit.md` when present
8. `aidlc-docs/_roadmap.md` when present (resume mode)
9. `{{TEAM_AI_WORKFLOW_DIR}}/core/core-workflow.md`
10. `{{TEAM_AI_WORKFLOW_DIR}}/core/input-validation.md`
11. `{{TEAM_AI_WORKFLOW_DIR}}/core/units-generation.md`
12. `{{TEAM_AI_WORKFLOW_DIR}}/common/no-implicit-decisions.md`
13. `{{TEAM_AI_WORKFLOW_DIR}}/common/depth-levels.md`
14. `{{TEAM_AI_WORKFLOW_DIR}}/common/error-recovery.md`
15. `{{TEAM_AI_WORKFLOW_DIR}}/common/stage-gate-rules.md`
16. `{{TEAM_AI_WORKFLOW_DIR}}/common/diagram-standards.md` (when ≥5 features)
17. `{{TEAM_AI_WORKFLOW_DIR}}/templates/feature-roadmap.md`
18. (brownfield) `aidlc-docs/reverse-engineering/component-inventory.md`

## Required Outputs

Project-level (always):
- `aidlc-docs/_roadmap.md`
- `aidlc-docs/aidlc-state.md` (Roadmap State, Feature Index, Cross-Feature Dependencies updated)
- `aidlc-docs/audit.md` (Phase 0 STEP and GATE-0 events appended)

Do NOT create any `aidlc-docs/features/<slug>/` folders. Per-feature folders are created later by `/ctx-aidlc-run` invocations.

## Hard Stop Rules
- Do NOT modify production code, tests, infra, or runtime files.
- Do NOT write `requirements.md`, `unit-of-work.md`, or any per-feature documents.
- Do NOT make business policy or design decisions. Defer to per-feature `/ctx-aidlc-run` STEP 4.
- Stop at GATE-0. Do not proceed to per-feature analysis even if user says "continue".
- Implementation is allowed only via separate `/ctx-run` after each feature's GATE-3.5 / GATE-5.

## Entry Conditions
- `prepared-requirement` AND multi-feature signal (≥2 features OR ≥3 distinct domains).
- Reject and exit if `raw-request` (instruct: run `/ctx-aidlc-run` first to produce planning-draft.md).
- Reject and exit if `change-on-existing-feature` (instruct: run `/ctx-aidlc-run` directly on the affected feature folder).
- Skip all R-steps if single-feature (instruct: run `/ctx-aidlc-run` directly).

## Behavior Rules
- AI proposes feature decomposition; user reviews and approves at GATE-0.
- Apply Single Domain Principle at the feature level.
- Every ⚠ shared resource MUST be resolved before GATE-0.
- No cycles in the dependency graph. If detected, propose a break and ask the user to choose.
- Audit/state entries during Phase 0 use `Feature: roadmap`.
- After GATE-0 approval, output one handoff block per feature with `/ctx-aidlc-run` invocation hint, grouped by execution phase.

## Final Response Rule
Your final response must contain only:
1. Files created or updated (paths)
2. Feature count, ⚠ resource count (resolved/unresolved), cycle status
3. GATE-0 decision (approved / pending / revised)
4. Next-step handoff messages (one per feature) when GATE-0 is approved

Do NOT include feature-level requirements, UOW, design, or implementation guidance.
