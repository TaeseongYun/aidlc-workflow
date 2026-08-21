<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Requirement Verification Questions

> **Request Anchor**: Multi-vendor settlement system — per-vendor sales aggregation, fee calculation, PG reconciliation, approval workflow

## Summary

| ID | Category | Priority | Impact | Status | If Unanswered |
|----|------|---------|--------|------|-----------|
| Q1 | policy | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q2 | policy | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q3 | policy | P1-IMPORTANT | high | ANSWERED | BLOCK |
| Q4 | domain | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q5 | domain | P1-IMPORTANT | medium | ANSWERED | AI-RECOMMEND-B |
| Q6 | policy | P1-IMPORTANT | medium | ANSWERED | BLOCK |
| Q7 | domain | P1-IMPORTANT | medium | ANSWERED | AI-RECOMMEND-A |
| Q8 | scope | P1-IMPORTANT | medium | ANSWERED | DEFER-TO-FEATURE |
| Q9 | domain | P1-IMPORTANT | medium | ANSWERED | ASSUME-A |
| Q10 | policy | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q11 | domain | P1-IMPORTANT | medium | ANSWERED | AI-RECOMMEND-A |
| Q12 | scope | P1-IMPORTANT | low | ANSWERED | DEFER-TO-FEATURE |

## 1. Domain And Scope

### Q4. PG reconciliation method
- Priority: P0-CRITICAL
- Scope: [original request] PG reconciliation integration
- Type: domain
- Category: domain
- Impact: high
- Reason: The reconciliation batch design changes completely depending on the PG API structure. Since it is an external integration, it is P0.
- Options:
  - A) Per-transaction real-time matching → match immediately in the payment-completed webhook
  - B) Bulk batch matching → download the PG's daily transaction records and then match
  - C) Hybrid → webhook first, supplement missing items with a batch
- AI recommendation: C) Hybrid — rationale: real-time matching is fast but webhooks can be missed, so batch supplementation is needed
- If unanswered: BLOCK
- [Answer]: C) Adopt the hybrid method
- [Confidence: certain]

### Q5. Settlement batch execution time slot
- Priority: P1-IMPORTANT
- Scope: [original request] settlement cycle management
- Type: domain
- Category: domain
- Impact: medium
- Reason: Must avoid peak hours and align with the PG data refresh timing.
- Options:
  - A) 3 AM (lowest traffic)
  - B) 6 AM (after the PG's daily settlement is complete)
  - C) Manually triggered by an administrator
- AI recommendation: B) 6 AM — rationale: the PG's daily settlement data is usually finalized around 5 AM
- If unanswered: AI-RECOMMEND-B
- [Answer]: B) 6 AM
- [Confidence: certain]

### Q8. Whether to include a real-time sales dashboard
- Priority: P1-IMPORTANT
- Scope: [original request] vendor portal queries
- Type: scope
- Category: scope
- Impact: medium
- Reason: A dashboard requires query optimization separate from settlement.
- Options:
  - A) Include → requires a real-time aggregation query or a CQRS pattern
  - B) Exclude → split into a separate feature
- If unanswered: DEFER-TO-FEATURE
- [Answer]: B) Split into a separate feature
- [Confidence: certain]

### Q9. Settlement amount rounding rule
- Priority: P1-IMPORTANT
- Scope: [original request] fee calculation
- Type: domain
- Category: domain
- Impact: medium
- Reason: Depending on the precision of the amount calculation, disputes over a 1-won difference between vendors can arise.
- Options:
  - A) Round to the won, truncate decimals → simple, industry practice
  - B) Round to the won, round decimals → precise but complex
- If unanswered: ASSUME-A
- [Answer]: A) Round to the won, truncate decimals
- [Confidence: certain]

### Q11. Handling of reconciliation mismatches
- Priority: P1-IMPORTANT
- Scope: [original request] PG reconciliation
- Type: domain
- Category: domain
- Impact: medium
- Reason: The workflow differs depending on whether mismatched items block settlement approval or are handled separately.
- Options:
  - A) Exclude mismatched items from settlement and manage them separately → settlement proceeds only for matched items
  - B) Include mismatched items in settlement but flag them with a warning → the administrator confirms them at approval time
- AI recommendation: A) Manage separately — rationale: including mismatched items in settlement risks propagating errors
- If unanswered: AI-RECOMMEND-A
- [Answer]: A) Manage mismatched items separately
- [Confidence: certain]

### Q12. Whether to include tax invoice integration
- Priority: P1-IMPORTANT
- Scope: [original request] settlement system scope
- Type: scope
- Category: scope
- Impact: low
- Reason: Tax invoice issuance requires a separate external integration (the Hometax API).
- If unanswered: DEFER-TO-FEATURE
- [Answer]: Split into a second-phase scope
- [Confidence: certain]

## 2. Policy / Exception

### Q1. Fee policy type
- Priority: P0-CRITICAL
- Scope: [original request] fee policy application
- Type: policy
- Category: policy
- Impact: high
- Reason: The data model and calculation logic change completely. Since it is a core business policy, it is P0.
- Options:
  - A) Percentage only (e.g., 10%) → simple calculation
  - B) Fixed amount only (e.g., 500 won per transaction) → simple calculation
  - C) Percentage + fixed amount hybrid (configured per vendor) → flexible but complex data model
- If unanswered: BLOCK
- [Answer]: C) Hybrid method. Allow each vendor to choose among percentage / fixed amount / hybrid.
- [Confidence: certain]

### Q2. Default settlement cycle
- Priority: P0-CRITICAL
- Scope: [original request] settlement cycle management
- Type: policy
- Category: policy
- Impact: high
- Reason: The batch design and vendor cash flow change depending on the cycle. A business decision is essential.
- Options:
  - A) Once a month (aggregate 1st–last day, pay on the 15th of the next month)
  - B) Once a week (aggregate Mon–Sun, pay the following Wednesday)
  - C) Selectable per vendor (daily/weekly/monthly)
- If unanswered: BLOCK
- [Answer]: C) Selectable per vendor. Default is once a month.
- [Confidence: certain]

### Q3. Whether fee changes apply retroactively
- Priority: P1-IMPORTANT
- Scope: [original request] fee policy
- Type: policy
- Category: policy
- Impact: high
- Reason: Retroactive application requires recalculating already-computed settlement items and can lead to vendor disputes.
- Options:
  - A) No retroactivity → apply from the next settlement cycle. Based on effective_from.
  - B) Retroactive application → recalculate unpaid settlement items. Increased complexity.
- If unanswered: BLOCK
- [Answer]: A) No retroactivity. Apply the new fee to orders placed after effective_from.
- [Confidence: certain]

### Q6. Number of settlement approval stages
- Priority: P1-IMPORTANT
- Scope: [original request] approval workflow
- Type: policy
- Category: policy
- Impact: medium
- Reason: The state machine and role structure differ depending on the number of approval stages.
- Options:
  - A) Single approval → review → approve (= payment confirmed)
  - B) Dual approval → review → first approval → second approval (= payment confirmed)
- If unanswered: BLOCK
- [Answer]: A) Single approval. Add a second approval later if needed.
- [Confidence: certain]

### Q7. Whether to auto-retry on payment failure
- Priority: P1-IMPORTANT
- Scope: [original request] settlement payout
- Type: domain
- Category: domain
- Impact: medium
- Reason: Auto-retry requires logic to prevent duplicate payouts.
- Options:
  - A) Auto-retry (3 times, exponential backoff) → needs idempotency-key-based duplicate prevention
  - B) Manual retry only → the administrator clicks a re-pay button
- AI recommendation: A) Auto-retry — rationale: most failures are transient network errors, and duplicates can be prevented with an idempotency key
- If unanswered: AI-RECOMMEND-A
- [Answer]: A) Auto-retry 3 times. Notify the administrator on failure.
- [Confidence: certain]

### Q10. Settlement data access permissions
- Priority: P0-CRITICAL
- Scope: [original request] settlement approval workflow
- Type: policy
- Category: policy
- Impact: high
- Reason: Settlement amounts are sensitive information, so access permissions constitute a security boundary. P0.
- Options:
  - A) Only ROLE_SETTLEMENT_ADMIN has full settlement CRUD
  - B) ROLE_SETTLEMENT_ADMIN (approval) + ROLE_SETTLEMENT_VIEWER (view only)
  - C) Vendors can view only their own settlements; administrators manage everything
- If unanswered: BLOCK
- [Answer]: C) Vendors see only their own settlements; administrators manage everything via ROLE_SETTLEMENT_ADMIN.
- [Confidence: certain]

## AI Auto-Decisions (P2)

| # | Item | Default Value | Rationale | Impact if Changed |
|---|------|----------|------|-------------|
| 1 | Settlement batch chunk size | 1000 items | Common initial value, adjustable after operation | Affects batch speed only |
| 2 | PG reconciliation retry count | 3 times (exponential backoff) | AWS-recommended pattern | Reconciliation completion time |
| 3 | Audit log retention period | 5 years | Based on the Electronic Financial Transactions Act | Storage cost |
