<!-- workflow-step: STEP-5.7 | gate: GATE-2.7 | producer: ctx-aidlc-run | condition: UOW >= 3 or new component creation -->
# Component Dependency

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/application-design/components.md`
- `aidlc-docs/features/<feature-slug>/application-design/services.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this together when components.md and services.md have been written.
- It may be omitted if there are two or fewer components.

---

## Dependency Matrix

| From \ To | C-1 | C-2 | C-3 | External System |
|-----------|-----|-----|-----|----------|
| C-1 | - | {relationship} | | |
| C-2 | | - | {relationship} | |
| C-3 | | | - | {relationship} |

Relationship types: `call` / `event` / `shared DB` / `none`

## Dependency Direction Rules

- Are there circular dependencies: yes / no
- If there are circular dependencies, describe the resolution approach.

## Key Dependency Paths

1. {user request} -> C-{N} -> C-{M} -> {result}
2. {batch trigger} -> C-{N} -> {external system} -> {result}

## Brownfield Impact

- Specify cases where a new dependency is added to an existing component.
- Where an existing dependency change is needed, describe the scope of impact.
