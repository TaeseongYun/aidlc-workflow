<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run | EXAMPLE -->
# Requirement Verification Questions — Book Borrowing

> **Request Anchor**: A member borrows a book. If stock is available, lend it out; up to 3 books per person, 14 days.

## Summary

| ID | Priority | Scope | Type | Category | Impact | Status | If unanswered | Confidence |
|----|----------|------|------|------|--------|------|-----------|------|
| Q1 | P1-IMPORTANT | Duplicate loan | domain | policy | high | ANSWERED | AI-RECOMMEND-A | AI-recommended |

## 1. Policy / Exception

### Q1. What if a member who already has the same book on loan tries to borrow it again?
- Priority: P1-IMPORTANT
- Scope: [original request] loan eligibility conditions
- Type: domain
- Category: policy
- Impact: high
- Reason: Allowing a duplicate loan of the same book blurs the meaning of the per-person limit (3 books) and can let stock concentrate in one person. The policy must be fixed to lock down the implementation.
- Options:
  - A) Reject — the same book can be loaned only 1 copy per person → add duplicate-loan blocking logic
  - B) Allow — within the limit (3 books), multiple copies of the same book may be loaned → no separate blocking
  - C) Other (enter manually)
- AI recommendation: A) Reject — rationale: a typical library loans only 1 copy of the same book to the same member (industry practice). It also aligns with the intent of the limit policy (accessibility for diverse members).
- If unanswered: AI-RECOMMEND-A (reject duplicate loans of the same book)
- [Answer]: A) Reject — only 1 copy of the same book per person
- [Confidence]: AI-recommended

## AI Auto Decisions (P2)

| # | Item | Default value | Rationale | Impact if changed |
|---|------|----------|------|-------------|
| 1 | Stock decrement concurrency strategy | Pessimistic lock (SELECT FOR UPDATE) | Last-copy contention is rare but consistency matters | Performance vs. consistency trade-off, re-confirm in technical design |
| 2 | Loan date basis | Server request time (UTC) | Standard, timezone consistency | Basis for due date calculation |
