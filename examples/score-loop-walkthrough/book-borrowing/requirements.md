<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run | EXAMPLE -->
# Feature Requirements — Book Borrowing

> **Request Anchor**: Allow members to borrow books. If stock is available, lend it out; up to 3 books per person, with a 14-day loan period.

> ⚠️ This is a walkthrough example output. It is written against a fictional library backend.

## Goal

Allow members to borrow books that have available stock. The default policy is 3 concurrent loans per person and a 14-day loan period.

## Background

A small library backend has no borrowing feature. Member and book data are assumed to already exist (brownfield). This feature adds a new concept called "Loan".

## In-Scope

- The ability for a member to borrow a specific book
- Checking stock (available copies) and then allowing/denying the loan
- Validating the per-person concurrent loan limit (3 books)
- Calculating the loan period (14 days) and the due date

## Out-of-Scope

- Return processing (separate feature)
- Overdue / late-fee policy (separate feature)
- Reservations/waitlists (queuing when stock is unavailable — not in this scope)
- Notifications (e.g., due date approaching)

## User Scenarios

1. A member borrows a book with available stock → loan succeeds, due date is shown.
2. A member attempts to borrow a book with no stock → denied (out of stock).
3. A member already holding 3 loans attempts an additional loan → denied (limit exceeded).

### Edge Cases
- A member who **already has the same book on loan** tries to borrow it again → policy fixed in Q1.
- Two members simultaneously try to borrow the last remaining copy → concurrency (atomic stock decrement) required.

## Functional Requirements

- **FR-1** A member can request a loan by specifying a book ID. `[confidence: certain]`
- **FR-2** The system allows a loan only when the book's available stock is 1 or more. `[confidence: certain]`
- **FR-3** The system allows a loan only when the member's current loan count is under 3. `[confidence: certain]`
- **FR-4** On a successful loan, due date = loan date + 14 days. `[confidence: certain]`
- **FR-5** On a successful loan, decrement the book's available stock by 1 (atomically). `[confidence: certain]`
- **FR-6** Reject a duplicate loan of the same book. `[confidence: AI-recommended — Q1]`

## Derived Requirements

- **DR-1** Loan entity: member, book, loan date, due date, status.
- **DR-2** Guarantee concurrency for stock decrement (choose one of optimistic/pessimistic lock — technical design stage).

## Requirement Gaps

BLOCK question Q1 (duplicate loan policy) is the key one. Proceed with the AI recommendation (reject) or have a human confirm it. P2 (concurrency strategy) is decided automatically.

## Approval Preconditions

- [x] Loan limit (3 books) confirmed — specified in the request
- [x] Loan period (14 days) confirmed — specified in the request
- [x] Duplicate loan policy (Q1) — confirmed as AI-recommended reject
- [ ] GATE-2 user approval

## Initial Risk Assessment

| Risk | Impact | Mitigation |
|--------|------|------|
| Concurrent loan of the last copy → negative stock | Data consistency | FR-5 atomic decrement, DR-2 lock strategy |
| Limit bypass if duplicate loans are allowed | Policy bypass | FR-6 duplicate rejection |
