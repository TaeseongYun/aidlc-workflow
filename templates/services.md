<!-- workflow-step: STEP-5.7 | gate: GATE-2.7 | producer: ctx-aidlc-run | condition: UOW >= 3 or new component creation -->
# Services

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/application-design/services.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/application-design/components.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this together when components.md has been written.
- It may be omitted for a simple structure that needs no service-layer distinction.

---

## Service Layer Overview

| ID | Service Name | Responsibility | Owning Component | External Exposure |
|----|---------|------|------------|-------------|
| S-1 | | | C-{N} | internal / external API |
| S-2 | | | C-{N} | |

## S-1. {service name}

- Responsibility: {the business logic this service handles}
- Owning component: C-{N}
- External exposure: internal-only / REST API / gRPC / event
- Key operations:
  - {operation 1}: {input} -> {output}
  - {operation 2}: {input} -> {output}
- Depends on services: S-{N} / external system name / none
- Transaction boundary: {single transaction / distributed / event-based}

## S-2. {service name}

- Responsibility:
- Owning component:
- External exposure:
- Key operations:
  -
- Depends on services:
- Transaction boundary:

## Inter-Service Communication

- Synchronous calls: {direct call relationships between services}
- Asynchronous events: {event-based communication relationships}
- External integration: {connection method with external systems}
