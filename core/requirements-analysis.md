# Requirements Analysis

## Goal
- Structure the user request into functional requirements.
- Extract missing policies/exceptions/operational conditions as questions.

## Question extraction criteria
- Is it unclear who uses it
- Is it unclear where it applies
- Is it unclear when the state changes
- Are exceptions such as failure/cancellation/refund/expiration unclear
- Is an admin/operator action required
- Are notifications/logs/audit trails required
- Is the connection method with existing systems unclear

## Output format
- Goal
- In-Scope
- Out-of-Scope
- Functional Requirements
- Derived Requirements
- Requirement Gaps
- Initial Risk Assessment

## Brownfield additional criteria
- Specify the connection points with existing services/domains/tables.
- Distinguish whether the new feature replaces or extends the existing flow.

## Greenfield additional criteria
- Core entities
- State transitions
- User roles
- MVP scope
- Baseline operating model
