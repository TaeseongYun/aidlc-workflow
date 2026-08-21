<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Requirement Verification Questions

Question format: follow `common/question-rules.md`.
If even one BLOCK question remains, requirements.md is not implementation-ready.

## Summary

| ID | Category | Impact | Status | If Unanswered |
|----|------|--------|------|-----------|
| Q1 | policy | high | OPEN | BLOCK |
| Q2 | policy | high | OPEN | BLOCK |
| Q3 | scope | medium | ANSWERED | ASSUME-A |

## 1. Domain And Scope

### Q3. Definition of "purchase completed" in the repurchase criterion
- Category: scope
- Impact: medium
- Reason: whether "purchase completed" means payment completed or delivery completed changes the repurchase determination query.
- Options:
  - A) At payment completion → query based on paid_at in the order table
  - B) At delivery completion → query based on delivered_at in the delivery table
  - C) Other (free input)
- If unanswered: ASSUME-A (the payment-completion basis is the simplest and has the smallest rework scope)
- [Answer]: A) Use the payment-completion point in time.

## 2. User Flow
<!-- Same format as Q1. Add questions matching the category -->

## 3. Policy / Exception

### Q1. Discount method: percentage vs. fixed amount
- Category: policy
- Impact: high
- Reason: a percentage requires amount-calculation logic and a maximum discount cap, while a fixed amount is a simple deduction. The data model and payment-integration logic are completely different.
- Options:
  - A) Fixed-amount discount (e.g., 3,000 won) → a discount_amount field in the campaign settings. Simple calculation
  - B) Percentage discount (e.g., 10%) → discount_rate + max_discount_amount fields in the campaign settings. Add amount-calculation logic
  - C) Selectable per campaign → both fields are needed. Add branching logic
- If unanswered: BLOCK
- [Answer]:

### Q2. Whether stacking with other promotions is allowed
- Category: policy
- Impact: high
- Reason: if stacking is allowed, the discount order (coupon → points → other) must be defined in the payment amount calculation. If not allowed, "at most 1 coupon" validation logic is needed.
- Options:
  - A) No stacking — block other discounts when the repurchase coupon is used → add coupon-type validation at payment
  - B) Stacking allowed — a discount order must be defined → add order logic to the payment calculation pipeline
  - C) Other (free input)
- If unanswered: BLOCK
- [Answer]:

## 4. Integration
<!-- Same format as Q1. Add questions matching the category -->

## 5. Ops / Notification / Reporting
<!-- Same format as Q1. Add questions matching the category -->
