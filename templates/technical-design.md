<!-- workflow-step: STEP-6.5 | gate: GATE-3.5 | producer: ctx-aidlc-run | condition: M/L units exist -->
# Technical Design

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/technical-design.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this when unit-of-work has at least one M or L scale unit.
- If all unit-of-work items are S scale, this document may be omitted.
- When omitted, record in status.md: "Technical design omitted — entire scope is S scale".

---

## Implementation Scope

State the level of this implementation based on this design.
Even if the design targets production, always record it when this implementation is a prototype.

- Implementation level: `production` / `prototype` / `local-MVP`
- Mock allowance scope: `none` / `external-api-only` / `storage-only` / `all-external`
- Items excluded from this implementation:
  - (if none, "none")
- Additional work when transitioning to Production:
  - (if none, "none")

---

## 1. Design Overview

Technical design summary for this feature. Describe the key architecture decisions and design direction in 2~5 sentences.

- Target system/module:
- Design direction:
- brownfield touchpoints: (contact points with existing code/modules)

## 2. Architecture Decisions

Record the technical decisions made during design. Add items if there are several decisions.

### ADR-1. {decision title}

- Status: proposed | accepted
- Context: (the background and constraints that make this decision necessary)
- Options:
  - A) {option A} — {pros/cons}
  - B) {option B} — {pros/cons}
- Decision: {the chosen option and the reason}
- Impact: {technical consequences of this decision}

## 3. API Specification

If there is no API change/addition, mark as "Not applicable".

### {HTTP Method} {Path}

- Purpose:
- Request:

```
{request structure}
```

- Response:

```
{response structure}
```

- Error codes:
  - {code}: {description}

## 4. Data Model

If there is no DB schema change, mark as "Not applicable".

### New/Changed Entities

| Entity | Field | Type | Constraints | Notes |
|--------|------|------|----------|------|
| | | | | |

### Migration Needed

- needed / not needed
- (if needed, briefly describe the migration strategy)

## 5. Module/Component Structure

Specify the modules to be changed and their responsibilities.

| Module/Class | Responsibility | New/Changed | Target UOW |
|------------|------|----------|---------|
| | | | |

## 6. Interaction Flow

Interaction flow of the key use cases. Follows `diagram-standards.md`.
Use ASCII for simple flows, Mermaid + text alternative for complex relationships.

If the flow is self-evident, mark as "Not applicable".

## 7. Non-functional Design

Based on `nfr-checklist.md`, describe only the items that apply to this feature.

- Performance:
- Consistency:
- Security:
- Operations:

Omit non-applicable items.

## 8. Testing Approach

Make the verification method of the unit-of-work concrete.

| Target UOW | Test Type | Verification Content |
|---------|-----------|----------|
| | | |

## 9. Open Items

Undetermined items at the time of technical design. List items that need confirmation before implementation.
If none, mark as "none".
