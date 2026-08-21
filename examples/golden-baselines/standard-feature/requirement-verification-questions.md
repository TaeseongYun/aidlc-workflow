<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Requirement Verification Questions

> **Request Anchor**: Repeat-customer discount coupon — automatic issuance, usage conditions, administrator campaign management

## Summary

| ID | Category | Priority | Impact | Status | If Unanswered |
|----|------|---------|--------|------|-----------|
| Q1 | policy | P1-IMPORTANT | high | OPEN | BLOCK |
| Q2 | policy | P1-IMPORTANT | high | OPEN | BLOCK |
| Q3 | domain | P1-IMPORTANT | medium | ANSWERED | ASSUME-A |

## 1. Domain And Scope

### Q3. Definition of "purchase completed" in the repeat-purchase criterion
- Priority: P1-IMPORTANT
- Scope: [original request] repeat-purchase criterion definition
- Type: domain
- Category: domain
- Impact: medium
- Reason: whether "purchase completed" means payment completed or delivery completed changes the repeat-purchase determination query.
- Options:
  - A) At payment completion → query based on paid_at in the order table
  - B) At delivery completion → query based on delivered_at in the delivery table
  - C) Other (enter directly)
- AI recommendation: A) payment-completion basis — rationale: payment completion is the simplest and has the smallest rework scope
- If unanswered: ASSUME-A (payment-completion basis is the simplest and has the smallest rework scope)
- [Answer]: A) Base it on the payment-completion point.
- [Confidence: certain]

## 2. Policy / Exception

### Q1. Discount method: percentage vs. fixed amount
- Priority: P1-IMPORTANT
- Scope: [original request] discount coupon issuance
- Type: policy
- Category: policy
- Impact: high
- Reason: a percentage discount requires amount-calculation logic and a maximum discount cap; a fixed amount is a simple subtraction. The data model and payment-integration logic are entirely different.
- Options:
  - A) Fixed-amount discount (e.g., 3,000 won) → a discount_amount field in the campaign settings. Simple calculation
  - B) Percentage discount (e.g., 10%) → discount_rate + max_discount_amount fields in the campaign settings. Adds amount-calculation logic
  - C) Selectable per campaign → both fields needed. Adds branching logic
- If unanswered: BLOCK
- [Answer]:

### Q2. Whether stacking with other promotions is allowed
- Priority: P1-IMPORTANT
- Scope: [original request] coupon usage conditions
- Type: policy
- Category: policy
- Impact: high
- Reason: if stacking is allowed, the discount order in payment-amount calculation must be defined. If not, "at most 1 coupon" validation logic is needed.
- Options:
  - A) No stacking — block other discounts when a repeat-purchase coupon is used
  - B) Stacking allowed — discount order must be defined
  - C) Other (enter directly)
- If unanswered: BLOCK
- [Answer]:

## AI Automatic Decisions (P2)

| # | Item | Default Value | Rationale | Impact If Changed |
|---|------|----------|------|-------------|
| 1 | Batch execution cycle | Once daily (3 AM) | Lowest-traffic time window, adjustable after operation | Issuance delay time |
| 2 | Coupon validity period default | 30 days | Industry practice, adjustable per campaign | Affects usage rate only |
