<!-- workflow-step: STEP-5.7 | gate: GATE-2.7 | producer: ctx-aidlc-run | condition: UOW >= 3 or new component creation -->
# Components

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/application-design/components.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/requirements.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this when 3 or more UOWs are expected or when new component creation is included.
- It may be omitted when changes within existing components are sufficient.
- When omitted, record in status.md: "System structure design omitted — only existing component changes apply".

---

## Component Overview

| ID | Component Name | Responsibility | Type | New/Existing |
|----|----------|------|------|---------|
| C-1 | | | API / Service / Batch / UI / Infra | new / existing change |
| C-2 | | | | |

## C-1. {component name}

- Responsibility: {what this component is in charge of}
- Type: API / Service / Batch / UI / Infra
- New/Existing: new / existing change
- Key features:
  - {feature 1}
  - {feature 2}
- Tech stack: {specify if applicable}
- Brownfield touchpoints: {contact points with existing modules/services. "none" if there are none}

## C-2. {component name}

- Responsibility:
- Type:
- New/Existing:
- Key features:
  -
- Tech stack:
- Brownfield touchpoints:
