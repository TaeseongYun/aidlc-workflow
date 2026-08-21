<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run | EXAMPLE -->
# Unit of Work — Book Borrowing

> **Request Anchor**: A member borrows a book. If stock is available, lend it out; up to 3 books per person, 14 days.

## Summary

| ID | Responsibility | Size | Dependencies | Status |
|----|------|------|--------|------|
| UOW-1 | Add Loan entity/repository | S | None | TODO |
| UOW-2 | Loan domain service (stock/limit/duplicate/period validation + stock decrement) | M | UOW-1 | TODO |
| UOW-3 | Loan API endpoint (POST /loans) | S | UOW-2 | TODO |

Size: 1 M (UOW-2) → technical-design recommended (only the essentials are summarized in this example).

## UOW-1. Loan entity/repository
- Responsibility: Define and store the loan record (member, book, loan date, due date, status).
- Expected location: `domain/loan/*`
- Dependencies: None
- Size: S
- Acceptance criteria: The Loan entity and repository are created, and the member/book references are correct.
- Verification method: Unit test

## UOW-2. Loan domain service
- Responsibility: Stock check (FR-2) + limit validation (FR-3) + duplicate loan rejection (FR-6) + due date calculation (FR-4) + atomic stock decrement (FR-5).
- Expected location: `domain/loan/LoanService`
- Dependencies: UOW-1
- Size: M
- Acceptance criteria: All 4 rules (stock/limit/duplicate/period) are applied, and the stock decrement is concurrency-safe.
- Verification method: Unit test + concurrency test (contention over the last copy)

## UOW-3. Loan API
- Responsibility: Receive loan requests via the POST /loans endpoint, respond with result/error.
- Expected location: `api/LoanController`
- Dependencies: UOW-2
- Size: S
- Acceptance criteria: On success, response includes the due date; on rejection, an error code per reason (out of stock / limit exceeded / duplicate).
- Verification method: Integration test

## Cohesion Verification Result
- Cohesive around a single domain (loan). No violations.
- No external integrations.

## Recommended Delivery Order
1. UOW-1 (entity) → 2. UOW-2 (domain logic) → 3. UOW-3 (API). Serial.
