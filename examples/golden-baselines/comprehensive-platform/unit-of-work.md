<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

Decomposition criteria: `core/units-generation.md`

## Summary

| ID | Responsibility | Size | Dependencies | Status |
|----|------|------|--------|------|
| UOW-1 | Settlement domain model and repository | M | None | TODO |
| UOW-2 | Vendor fee policy management | S | UOW-1 | TODO |
| UOW-3 | Sales aggregation and settlement calculation batch | L | UOW-1, UOW-2 | TODO |
| UOW-4 | PG-provider reconciliation integration | M | UOW-1 | TODO |
| UOW-5 | Settlement approval workflow API | M | UOW-1, UOW-3 | TODO |
| UOW-6 | Vendor settlement query API | S | UOW-1 | TODO |
| UOW-7 | Settlement audit log | S | UOW-1, UOW-5 | TODO |

## UOW-1. Settlement domain model and repository
- Responsibility: settlement, settlement_detail, vendor_fee_policy, reconciliation tables and Entity/Repository
- Expected location: domains/domain-rds/src/.../settlement/
- Dependencies: None
- Size: M
- Acceptance criteria: DDL for the 4 tables, Entity, and Repository created. Basic CRUD tests pass.
- Verification method: unit tests

## UOW-2. Vendor fee policy management
- Responsibility: per-vendor fee policy CRUD API, effective_from-based application logic
- Expected location: center/back-end/src/.../settlement/service/FeePolicy*
- Dependencies: UOW-1
- Size: S
- Acceptance criteria: percentage/fixed-amount/mixed policies can be configured, application after effective_from confirmed
- Verification method: unit tests

## UOW-3. Sales aggregation and settlement calculation batch
- Responsibility: aggregate completed orders per vendor → apply fees → calculate settlement amount → create settlement
- Expected location: center/back-end/src/.../settlement/batch/
- Dependencies: UOW-1, UOW-2
- Size: L
- Acceptance criteria: within 30 minutes for 200 vendors × 100,000 records, settlement amount = sales − fees, truncated to the won unit
- Verification method: integration tests + performance tests

## UOW-4. PG-provider reconciliation integration
- Responsibility: PG-provider API call → download transaction records → match order transactions → generate mismatch list
- Expected location: center/back-end/src/.../settlement/reconciliation/
- Dependencies: UOW-1
- Size: M
- Acceptance criteria: match success/failure/mismatch classification, rate-limit compliance, webhook + batch hybrid
- Verification method: integration tests (PG API mock)

## UOW-5. Settlement approval workflow API
- Responsibility: settlement status management (create → review → approve → pay), administrator API, payout retry
- Expected location: center/back-end/src/.../settlement/controller/, service/
- Dependencies: UOW-1, UOW-3
- Size: M
- Acceptance criteria: state transitions work per the rules, permission check (ROLE_SETTLEMENT_ADMIN), 3 retries
- Verification method: integration tests

## UOW-6. Vendor settlement query API
- Responsibility: settlement-history query API for the vendor portal (access to own settlements only)
- Expected location: center/back-end/src/.../settlement/controller/VendorSettlement*
- Dependencies: UOW-1
- Size: S
- Acceptance criteria: per-vendor settlement list/detail query, access to other vendors' data blocked
- Verification method: integration tests (including permission tests)

## UOW-7. Settlement audit log
- Responsibility: record settlement status change events, query API
- Expected location: center/back-end/src/.../settlement/audit/
- Dependencies: UOW-1, UOW-5
- Size: S
- Acceptance criteria: all status changes recorded in the audit log, 5-year retention policy applied
- Verification method: integration tests

## Recommended Delivery Order
1. UOW-1 — the overall foundation
2. UOW-2 — a precondition for settlement calculation
3. UOW-4 — reconciliation integration (can be done independently)
4. UOW-3 — the core batch (requires UOW-1, UOW-2)
5. UOW-5 — the approval workflow (after UOW-3)
6. UOW-7 — the audit log (requires UOW-5 events)
7. UOW-6 — vendor query (meaningful after data has accumulated)

## Sizing Criteria
`core/unit-sizing.md`
