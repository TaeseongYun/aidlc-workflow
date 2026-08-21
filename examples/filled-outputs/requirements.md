<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Feature Requirements

## Goal
Automatically issue discount coupons to repurchasing customers to increase the revisit rate and the second-purchase conversion rate.

## Background
- Currently, coupons can only be issued manually by an administrator
- The marketing team requested a campaign to drive repurchases
- The existing `coupon` domain and `order` domain already exist

## In-Scope
- Define the repurchase criterion (has a purchase history within the last N days)
- Coupon auto-issuance batch or event trigger
- Coupon usage conditions: minimum order amount, one per person, validity period
- Administrator campaign ON/OFF feature
- Issuance/usage status query API

## Out-of-Scope
- Push notification / email delivery (split into a separate feature)
- Coupon design / front-end UI
- Integration with existing manually issued coupons (out of first-phase scope)

## User Scenarios
1. Customer A completed an order 3 days ago → the system automatically issues a repurchase coupon → Customer A sees it in their coupon box
2. Customer B applies the coupon to reorder → order is at or above the minimum order amount → discount is applied
3. Customer C has already used the coupon → duplicate use is blocked
4. The administrator switches the campaign to OFF → new issuance stops, already-issued coupons remain usable until their validity period

## Functional Requirements
- FR-1: The repurchase criterion is defined as "at least 1 completed order within the last N days" (N is a campaign setting)
- FR-2: When a campaign is active, coupons are automatically issued to customers who meet the criterion
- FR-3: A coupon is issued only once per person per campaign
- FR-4: Coupon usage conditions: at or above the minimum order amount, within the validity period
- FR-5: Campaign creation/modification/ON/OFF is possible via the administrator API
- FR-6: An issuance/usage status query API is provided

## Derived Requirements
- DR-1: A coupon issuance history table is needed (campaign_id, user_id, issued_at, used_at)
- DR-2: A campaign settings table is needed (campaign_id, period_days, min_order_amount, discount_amount, active)
- DR-3: A purchase-history query API or query must be provided by the existing order domain

## Requirement Gaps
- RG-1: Whether the discount amount is a percentage or a fixed amount is undecided → see Q1
- RG-2: Whether the coupon can be stacked with other promotions is undecided → see Q2

## Approval Preconditions
- The discount method (percentage/fixed) must be decided
- The coupon stacking policy must be decided

## Initial Risk Assessment
- Batch performance during bulk issuance → split into an M-sized UOW
- Possible conflict between the existing coupon domain and campaign coupons → addressed by separating tables
