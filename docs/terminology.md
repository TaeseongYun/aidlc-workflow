# Terminology

These are the definitions of the core terms used in this project.

## Request classification

| Term | Definition |
|------|------------|
| `raw-request` | A request at the level of raw wording from marketing/operations/business. It has a goal but its scope, policy, and success criteria are not organized. Write `request-intake.md` and `planning-draft.md` first. |
| `prepared-requirement` | An already-structured requirement. Proceed directly, centered on `requirements.md`. |
| `change-on-existing-feature` | An additional change or follow-up requirement for an existing feature. Prefer updating the existing feature folder over creating a new one. |

## Project type

| Term | Definition |
|------|------------|
| `greenfield` | A brand-new project. No existing code/DB/API/operational flows. Start from requirements and domain definition. |
| `brownfield` | An existing project. You must read the existing code/DB/API/operational/deployment constraints. New features are also fitted into the existing structure. |

## Question/approval status

| Term | Definition |
|------|------------|
| `BLOCK` | Implementation cannot proceed without an answer. The default for high-impact questions. |
| `ASSUME-{X}` | Can proceed on an assumption. Used for medium/low-impact questions. `{X}` is the chosen assumption option. The basis for the assumption must always be stated. |
| `OPEN` | The question has not yet been answered. |
| `ANSWERED` | The question has been answered. |
| `implementation-ready` | State with 0 BLOCK questions and confirmed requirements. Implementation can proceed. |

## Deliverable/structure

| Term | Definition |
|------|------------|
| `CTX` (Context) | The `ctx/` directory holding project-local facts. Defines existing structure, prohibition rules, reusable components, etc. |
| `aidlc-docs` | The feature-work deliverable directory. Holds requirements, questions, unit-of-work, and status-tracking documents. |
| `feature-slug` | The per-feature deliverable folder name. Use lowercase kebab-case. e.g., `coupon-feature`, `b2b-approval-flow` |
| `UOW` (Unit of Work) | An independently verifiable unit of work. Decomposed by domain responsibility, deployment unit, failure impact, etc. |
| `ADR` (Architecture Decision Record) | A record of a technical decision. Captures context/options/decision/impact structurally. |

## Approval gates

| Term | Definition |
|------|------------|
| `GATE-0` | _roadmap review. Triggered only for a multi-feature `prepared-requirement` (Phase 0). |
| `GATE-1` | planning-draft review. Triggered only for a `raw-request`. |
| `GATE-2` | requirements + questions review. Always triggered. |
| `GATE-2.5` | personas + stories review. Triggered when User Scenarios >= 3 or a new user type exists. |
| `GATE-2.7` | application-design review. Triggered when UOW >= 3 is expected or new components are created. |
| `GATE-3` | unit-of-work review. Always triggered. |
| `GATE-3.5` | technical-design review. Triggered only when M/L-sized units exist. |
| `GATE-4` | infrastructure-design review. Triggered when infrastructure changes are needed. |
| `GATE-5` | build/test-instructions review. Triggered when M/L-sized units exist. |

Full trigger/pass conditions: `common/stage-gate-rules.md` (single source of truth).

## Readiness Score

| Term | Definition |
|------|------------|
| `READY` (80+) | Ready to implement. |
| `CONDITIONAL` (60-79) | Can proceed conditionally under ASSUME. Rework risk exists. |
| `NOT_READY` (below 60) | Cannot implement. Questions must be resolved. |

## Other scores

| Term | Definition |
|------|------------|
| Dependency Score | Post-implementation 4-axis quality score iterated by `/ctx-score-loop`; complete when it exceeds 85 (`core/dependency-score.md`). |
| Hallucination-Free Score | `/ctx-hallucination-audit` loop score; the loop repeats until it reaches at least 87 (`docs/hallucination-guard.md`). |
| Sync Score | Upstream sync quality in `/ctx-aidlc-sync`; a PR opens only above 90. |

## Size

| Term | Definition |
|------|------------|
| `S` | Single-file/function-level change. Within half a day. |
| `M` | Multiple file changes, including tests. 1–2 days. |
| `L` | Module-level change, including external integration/migration. 3 days or more. |
