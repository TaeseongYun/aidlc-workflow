<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

Decomposition criteria: `core/units-generation.md`

## Summary

| ID | Responsibility | Size | Dependencies | Status |
|----|------|------|--------|------|
| UOW-1 | Order list sorting fix | S | None | TODO |

## UOW-1. Order list sorting fix
- Responsibility: change the sort condition of OrderRepository.findByUserId() to DESC and update the unit tests
- Expected location: domains/domain-rds/src/.../order/repository/OrderRepository.java
- Dependencies: None
- Size: S
- Acceptance criteria: the GET /api/orders response is in created_at DESC order and the existing tests pass
- Verification method: unit tests + API integration tests

## Recommended Delivery Order
1. UOW-1 — a single task

## Sizing Criteria
`core/unit-sizing.md`
