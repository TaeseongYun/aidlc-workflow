<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Feature Requirements

## Goal
Fix the sort bug so that the most recent order is shown at the top when viewing the order list.

## Background
- Customer CS report: "In my order history, the oldest order appears at the top"
- Cause: the sort condition in `OrderRepository.findByUserId()` is set to `ASC`
- Existing pattern: all other list queries (products, reviews) sort by `DESC`

## In-Scope
- Fix the sort condition of `OrderRepository.findByUserId()` to `DESC`
- Verify the sort order of API responses that use this query

## Out-of-Scope
- Order list paging improvements
- Sort-criteria change UI (a separate future feature)

## User Scenarios
1. The customer enters the order history → the most recent order is shown at the top
2. The customer views page 2 of the order history → descending time order is maintained

## Functional Requirements
- FR-1: Change the sort condition of `OrderRepository.findByUserId()` to `created_at DESC`
- FR-2: Verify that the response of the related API (`GET /api/orders`) is sorted newest-first

## Derived Requirements
- None (reuses the existing code pattern)

## Requirement Gaps
- None

## Approval Preconditions
- None

## Initial Risk Assessment
- Low: single query fix, identical to the existing pattern
