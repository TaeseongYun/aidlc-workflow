# Brownfield Guide

A guide for performing requirements analysis and impact-scope assessment on a project that has an existing system.

## Detection criteria

If any one of the following applies, it is brownfield.
- An existing codebase exists
- There is a DB schema in operation
- It is integrated with an external system
- A deployment pipeline is configured
- There is an API already in use by existing users

## Exploration order

When running `/ctx-aidlc-run` on a brownfield project, understand the existing system in the following order.

### Stage 1: Read the project context
```
ctx/INDEX.md → ctx/project-profile.ctx.md → AGENTS.md → CLAUDE.md → README.md
```
- Understand the project type, stack, module structure, and domain
- Confirm prohibition rules and reusable components

### Stage 2: Identify affected domains
- List the existing modules/packages the new requirement touches
- Identify existing tables/entities that need to be changed or referenced
- Identify existing APIs that need modification or that must maintain compatibility

### Stage 3: Confirm existing patterns
- Confirm how similar functionality is implemented in the existing code
- Understand naming conventions, package structure, and error-handling patterns
- Confirm the existing test strategy (unit/integration/E2E)

### Stage 4: Screen for conflict points
- List the points where the new requirement conflicts with existing rules/policies
- Confirm contradictions between prohibition rules stated in the CTX and the new requirement
- On finding a conflict → STOP, raise it as a question

### Stage 5: Document the impact scope
- Describe the existing system context in the Background of `requirements.md`
- Specify existing file paths in the expected locations of `unit-of-work.md`
- Describe the relationship with the existing schema in the Data Model of `technical-design.md`

## Example: Adding campaign coupons to an existing coupon system

```
Existing structure:
  domains/domain-rds/src/.../coupon/    ← existing manually-issued coupons
  center/back-end/src/.../payment/      ← existing payment service

New requirement: automatic repurchase coupons

Affected domains:
  - coupon domain: add tables (campaign, coupon_issue)
  - order domain: add repurchase-detection query (read-only)
  - payment domain: modify coupon-application logic

Confirm existing patterns:
  - existing coupon entity uses the JPA + Spring Data pattern
  - existing payment applies discounts via the Strategy pattern
  - existing batch uses Spring Batch

Conflict points:
  - overlapping application of existing coupons and campaign coupons → policy question needed (BLOCK)
  - add campaign_id to the existing coupon table vs. a separate table → design decision needed
```

## Cautions
- Do not force a new structure without first understanding the existing one
- Follow the existing patterns first, before proposing a "better way"
- When you must introduce a pattern different from the existing code, leave the rationale as an ADR
- When modifying an existing table, always include a migration strategy
