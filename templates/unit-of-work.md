<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/unit-of-work.md`.

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

Decomposition criteria:
- Follows `core/units-generation.md`.
- Payment/refund/settlement are always reviewed as separate units.

## Summary

| ID | Responsibility | Scale | Dependencies | Status |
|----|------|------|--------|------|
| UOW-1 | | S/M/L | none | TODO |
| UOW-2 | | S/M/L | UOW-1 | TODO |

## UOW-1. {unit title}
- Responsibility: {what this unit is in charge of}
- Expected location: {code/document path}
- Dependencies: none / UOW-{N}
- Scale: S / M / L
- Acceptance criteria: {definition of the completed state of this unit}
- Verification method: unit test / integration test / manual check / code review

## UOW-2. {unit title}
- Responsibility: {what this unit is in charge of}
- Expected location: {code/document path}
- Dependencies: UOW-1
- Scale: S / M / L
- Acceptance criteria: {definition of the completed state of this unit}
- Verification method: unit test / integration test / manual check / code review

## Recommended Delivery Order
1. UOW-1 — {reason}
2. UOW-2 — {reason}

## Scale Criteria
Follows `core/unit-sizing.md`.
