<!-- workflow-step: STEP-1 | gate: none | producer: ctx-aidlc-run | updated-by: all steps -->
# Feature Status

## Identity
- Feature Slug:
- Title:
- Request Type:
  - raw-request / prepared-requirement / change-on-existing-feature
- Status:
  - intake / planning-draft / questions-open / approved / implementing / completed / parked

## Readiness Score

| Area | Points | Score | Status |
|------|------|------|------|
| Functional scope definition | 15 | | |
| Policy/exception finalization | 20 | | |
| User scenarios | 15 | | |
| NFR confirmation | 15 | | |
| Approval item resolution | 20 | | |
| Risk assessment | 15 | | |
| User story quality (conditional) | 10 | | Not applicable / scored |
| System structure design (conditional) | 10 | | Not applicable / scored |
| **Total** | **100 (+bonus)** | | |

Judgment criteria:
- Base full score is 100. When conditional areas are activated, the full score increases.
- Judgment thresholds are converted to 80%/60% ratios of the actual full score.
- Below 60%: implementation forbidden (high likelihood of remaining BLOCK questions)
- 60~79%: conditional proceed (ASSUME assumptions must be stated)
- 80% or above: implementation allowed

## Post-Implementation Score (after implementation — ctx-score-loop)

Mirrors the latest score produced by the dependency-awareness score loop (`/ctx-score-loop`) **after** implementation.
Its timing and purpose differ from the Readiness Score (before implementation). For detailed history, see the Score History in the feature/module directory's `dependency-check.md`.

| Item | Value |
|------|-----|
| Latest total | (0~100) |
| Latest round | |
| Per axis (dep/build/test/AC) | / / / |
| Verdict | COMPLETE(>85) / INCOMPLETE / STALLED / EXHAUSTED / REGRESSED |
| Last updated | (ISO 8601 UTC) |

Scoring criteria: `core/dependency-score.md`. Completion threshold: over 85 points (`> 85`) AND build axis ≠ 0 (GR-1).

## Scope
- Goal:
- In-Scope Summary:
- Out-of-Scope Summary:

## Gate Approval History

| Gate | Decision | Timestamp | Notes |
|------|----------|-----------|-------|
| GATE-1 (Planning Draft) | - | - | raw-request only |
| GATE-2 (Requirements) | - | - | |
| GATE-2.5 (User Stories) | - | - | conditional |
| GATE-2.7 (Application Design) | - | - | conditional |
| GATE-3 (Unit-of-Work) | - | - | |
| GATE-3.5 (Technical Design) | - | - | M/L only |
| GATE-4 (Infrastructure Design) | - | - | conditional |
| GATE-5 (Build & Test) | - | - | conditional |

## Approval
- Requirement Status:
- Design Status:
- Last Approved At:
- Approved By:

## Implementation
- Code Started:
- Current Owner:
- Related Branch:

## Related Files
- Request Intake:
- Planning Draft:
- Requirements:
- Questions:
- Personas:
- Stories:
- Components:
- Services:
- Component Dependency:
- Unit of Work:
- Dependency Map:
- Story Map:
- Technical Design:
- Infrastructure Design:
- Deployment Architecture:
- Build Instructions:
- Test Instructions:
- Security Baseline:

## Notes
-
