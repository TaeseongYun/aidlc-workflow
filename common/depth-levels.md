# Adaptive Depth

Adjusts the level of detail of the workflow to match the complexity of the work.
Whether a STEP runs is decided by the conditional rules in `core-workflow.md`,
and this document defines **how deeply it is treated** within an executed step.

## Core Principle

> As detailed as the problem needs, no more and no less.

- Do not artificially inflate a simple problem.
- Do not under-treat a complex problem.
- All required artifacts are generated regardless of depth. Depth only adjusts the level of detail of the content.

## Depth Level Definitions

### minimal
- **Target**: Simple bug fixes, text changes, reuse of existing patterns, clear 1-2 file changes
- **Characteristics**: Write only the core sections, skip most conditional STEPs
- **Question budget**: 3 per round

### standard
- **Target**: Medium-complexity feature additions, some design judgment needed, affecting 2-5 files
- **Characteristics**: Standard level of detail, execute/skip STEPs based on conditions
- **Question budget**: 7 per round

### comprehensive
- **Target**: Large-scale features, multi-domain impact, new design, migration, external integration
- **Characteristics**: Write all sections in detail, execute most conditional STEPs
- **Question budget**: 12 per round

## Depth Level Determination

### Determination Timing
Immediately after STEP 1-A Discovery completes (STEP 1-B).

### Determination Factors

| Factor | minimal | standard | comprehensive |
|------|---------|----------|---------------|
| Request clarity | Concrete, complete in 1-2 lines | Intent clear but detail needed | Ambiguous or multiple meanings |
| Impact scope | Single file/component | 2-5 files/components | Multiple domains, system-wide |
| Design decisions | None (existing patterns) | 1-3 | 4 or more |
| Risk | Existing patterns, easy rollback | Some new, limited impact | New design, data changes, external integration |
| Existing CTX coverage | Relevant rules exist | Partial | No or insufficient relevant rules |

### Determination Rules
- If 3 or more of the 5 factors match a given depth, decide on that level.
- In borderline cases, choose the **depth one level higher**.
- If the user explicitly specifies a depth, follow it.

### Recording
- Record it in the `Depth Level` field of `aidlc-state.md`.
- Record the reason for the determination in `audit.md`.

## Artifact Detail by Depth

### requirements.md

| Section | minimal | standard | comprehensive |
|------|---------|----------|---------------|
| Goal | 1-2 lines | 3-5 lines + background | Detailed background + constraints + success metrics |
| In-Scope | Core items only | Items + brief description | Items + detailed description + boundary conditions |
| Out-of-Scope | 1-2 | 3-5 | Detailed + reasons |
| Functional requirements | Core only | Standard | Full + edge cases |
| Derived requirements | None or 1-2 | Write if present | Mandatory |

### unit-of-work.md

| Item | minimal | standard | comprehensive |
|------|---------|----------|---------------|
| Number of UOWs | 1-2 | 3-5 | No limit |
| Acceptance criteria | 1-2 per UOW | 2-3 per UOW | 3 or more per UOW + Gherkin |
| Dependencies | Brief | Explicit | Detailed + cycle verification |

### Gate Messages

| Item | minimal | standard | comprehensive |
|------|---------|----------|---------------|
| Artifact summary | 2 items | 3-4 items | 5 items |
| File list | Core only | All relevant | All relevant + references |
