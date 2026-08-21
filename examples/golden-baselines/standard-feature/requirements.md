<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Feature Requirements

## Goal
Automatically issue discount coupons to repeat customers to increase the revisit rate and the second-purchase conversion rate.

## Background
- Currently coupons can only be issued manually by an administrator
- The marketing team requested a repeat-purchase incentive campaign
- The existing `coupon` domain and `order` domain already exist

## In-Scope
- Definition of the repeat-purchase criterion (has purchase history within the last N days)
- Automatic coupon issuance batch or event trigger
- Coupon usage conditions: minimum order amount, one per person, validity period
- Administrator campaign ON/OFF feature
- Issuance/usage status query API

## Out-of-Scope
- Push notifications / email delivery (separated into a distinct feature)
- Coupon design / front-end UI
- Integration with existing manually issued coupons (out of first-phase scope)

## User Scenarios
1. Customer A completed an order 3 days ago → the system automatically issues a repeat-purchase coupon → Customer A sees it in their coupon box
2. Customer B applies the coupon and reorders → order amount is at or above the minimum → discount applied
3. Customer C has already used the coupon → duplicate use is blocked
4. An administrator switches the campaign to OFF → new issuance stops, already-issued coupons remain usable until their validity period ends

## Functional Requirements
- FR-1: The repeat-purchase criterion is defined as "at least 1 completed-order history within the last N days" (N is a campaign setting value)
- FR-2: When a campaign is active, coupons are automatically issued to customers who meet the criterion
- FR-3: A coupon is issued only once per person per campaign
- FR-4: Coupon usage conditions: at or above the minimum order amount, within the validity period
- FR-5: Campaign creation/modification/ON/OFF is possible via the administrator API
- FR-6: An issuance/usage status query API is provided

## Derived Requirements
- DR-1: A coupon issuance history table is needed (campaign_id, user_id, issued_at, used_at)
- DR-2: A campaign settings table is needed (campaign_id, period_days, min_order_amount, discount_amount, active)
- DR-3: A purchase-history query API or query from the existing order domain is needed

## Requirement Gaps
- RG-1: Whether the discount amount is percentage-based or fixed-amount is undecided → see Q1
- RG-2: Whether the coupon can be stacked with other promotions is undecided → see Q2

## Approval Preconditions
- The discount method (percentage/fixed-amount) must be finalized
- The coupon stacking policy must be finalized

## Initial Risk Assessment
- Batch performance during mass issuance → split off into an M-sized UOW
- Possible conflict between the existing coupon domain and campaign coupons → addressed by separating tables
