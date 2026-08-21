<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Feature Requirements

## Goal
Build a settlement system for a multi-vendor marketplace that automatically calculates each vendor's settlement amount and pays it out after administrator approval.

## Background
- Currently settlement is done manually in Excel (once a month, by 1 staff member)
- The growing number of vendors has reached the limits of manual work (currently 50 → 200 expected by year-end)
- Reconciliation must be automated by integrating with the PG provider (Toss Payments)
- The existing order, payment, and vendor domains exist

## In-Scope
- Per-vendor sales aggregation (based on completed orders)
- Fee policy application (percentage/fixed-amount/mixed, differs per vendor)
- Settlement cycle management (daily/weekly/monthly, configured per vendor)
- PG-provider reconciliation integration (matching per payment transaction)
- Administrator settlement approval workflow (create → review → approve → pay)
- Vendor portal settlement-history query API
- Settlement history audit log

## Out-of-Scope
- Automatic tax-invoice issuance (second phase)
- Vendor sign-up/screening process
- Real-time sales dashboard (separate feature)

## User Scenarios
1. The settlement staff runs the monthly settlement → the system automatically calculates the per-vendor amounts → the staff reviews and approves
2. Vendor A queries their settlement history on the portal → checks the fee, settlement amount, and status per order
3. A PG-provider reconciliation mismatch occurs → the system generates a list of mismatched items → the staff handles them manually
4. Vendor B's fee rate changes → the new fee applies from the next settlement cycle (no retroactivity)
5. Payout fails after settlement approval → retry or manual handling → recorded in the audit log

## Functional Requirements
- FR-1: Aggregate per-vendor sales for completed (delivered) orders
- FR-2: Calculate the settlement amount by applying each vendor's fee policy (percentage/fixed-amount/mixed)
- FR-3: The settlement cycle (daily/weekly/monthly) can be configured per vendor
- FR-4: Automatically match and reconcile the PG provider's payment records with order transactions
- FR-5: Settlement workflow: create → review → approve → pay status management
- FR-6: Settlement creation/review/approval/rejection is possible via the administrator API
- FR-7: Vendors can query their own settlement history via the vendor API
- FR-8: All settlement status changes are recorded in the audit log
- FR-9: Reconciliation mismatches are managed as a separate list and support manual handling

## Non-Functional Requirements
- NFR-1: The settlement batch completes within 30 minutes for 200 vendors × 100,000 monthly orders
- NFR-2: PG-provider API calls respect the rate limit (100 req/s)
- NFR-3: Settlement amount calculation rounds to the won unit and truncates below the decimal point
- NFR-4: Settlement data is retained for 5 years
- NFR-5: Settlement approval is possible only with the ROLE_SETTLEMENT_ADMIN permission

## Derived Requirements
- DR-1: settlement table (settlement_id, vendor_id, period, amount, fee, net_amount, status)
- DR-2: settlement_detail table (settlement_id, order_id, order_amount, fee_amount)
- DR-3: vendor_fee_policy table (vendor_id, fee_type, fee_rate, fee_amount, effective_from)
- DR-4: reconciliation table (pg_transaction_id, order_id, match_status, resolved_at)
- DR-5: A per-period vendor sales aggregation query from the existing order domain is needed

## Requirement Gaps
- None (all questions answered)

## Approval Preconditions
- All resolved

## Initial Risk Assessment
- R-1: PG-provider API response time variability → timeout/retry policy needed (P0)
- R-2: DB load during large settlement batch execution → adjust batch size, consider using a read-only replica
- R-3: Whether existing settlements are retroactively affected when the fee policy changes → finalized as no retroactivity (Q3)
- R-4: Rollback process for settlement amount errors → revert to rejected status and recalculate
