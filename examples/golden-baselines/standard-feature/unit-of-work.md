<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

Decomposition criteria:
- Follows `core/units-generation.md`.
- Sizing criteria: follows `core/unit-sizing.md`.

## Summary

| ID | Responsibility | Size | Dependencies | Status |
|----|------|------|--------|------|
| UOW-1 | Campaign domain model and repository | S | None | TODO |
| UOW-2 | Repeat-purchase determination query | S | UOW-1 | TODO |
| UOW-3 | Coupon auto-issuance batch | M | UOW-1, UOW-2 | TODO |
| UOW-4 | Administrator campaign API | S | UOW-1 | TODO |
| UOW-5 | Coupon usage validation and payment integration | M | UOW-1 | TODO |
| UOW-6 | Issuance/usage status query API | S | UOW-1, UOW-3 | TODO |

## UOW-1. Campaign domain model and repository
- Responsibility: create the campaign table, coupon_issue table, JPA Entity, and Repository
- Expected location: domains/domain-rds/src/.../campaign/
- Dependencies: None
- Size: S
- Acceptance criteria: the Entity and Repository exist and basic CRUD tests pass
- Verification method: unit tests

## UOW-2. Repeat-purchase determination query
- Responsibility: query the list of customer IDs with completed-payment history within the last N days
- Expected location: domains/domain-rds/src/.../order/repository/
- Dependencies: UOW-1
- Size: S
- Acceptance criteria: accurately returns the list of repeat-purchase target customers for the period condition
- Verification method: unit tests (based on test data)

## UOW-3. Coupon auto-issuance batch
- Responsibility: query repeat-purchase targets via scheduler → issue coupons to un-issued customers → record issuance history
- Expected location: center/back-end/src/.../campaign/batch/
- Dependencies: UOW-1, UOW-2
- Size: M
- Acceptance criteria: on batch execution, coupons are issued to target customers with no duplicate issuance, completing within 5 minutes for 100,000 records
- Verification method: integration tests

## UOW-4. Administrator campaign API
- Responsibility: campaign CRUD + ON/OFF API
- Expected location: center/back-end/src/.../campaign/controller/
- Dependencies: UOW-1
- Size: S
- Acceptance criteria: campaign creation/modification/query/ON/OFF work via API
- Verification method: integration tests

## UOW-5. Coupon usage validation and payment integration
- Responsibility: coupon-apply request at order time → validity check → apply discount → mark as used
- Expected location: center/back-end/src/.../payment/service/, .../coupon/service/
- Dependencies: UOW-1
- Size: M
- Acceptance criteria: discount reflected when a valid coupon is applied; expired/already-used coupons blocked; orders below the minimum amount blocked
- Verification method: integration tests

## UOW-6. Issuance/usage status query API
- Responsibility: administrator issuance-status and usage-rate statistics API
- Expected location: center/back-end/src/.../campaign/controller/
- Dependencies: UOW-1, UOW-3
- Size: S
- Acceptance criteria: returns issuance count, usage count, and usage rate per campaign
- Verification method: integration tests

## Recommended Delivery Order
1. UOW-1 — the foundation for all other units
2. UOW-2 — a precondition for the batch (UOW-3)
3. UOW-4 — the administrator must create a campaign first for the batch to be meaningful
4. UOW-3 — the actual issuance operation
5. UOW-5 — the flow that uses issued coupons
6. UOW-6 — status queries are meaningful only after data has accumulated

## Sizing Criteria
Follows `core/unit-sizing.md`.
