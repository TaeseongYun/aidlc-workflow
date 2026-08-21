<!-- workflow-step: STEP-5.5 | gate: GATE-2.5 | producer: ctx-aidlc-run | condition: User Scenarios >= 3 or new user types -->
# Personas

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/user-stories/personas.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/requirements.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this when requirements.md has 3 or more User Scenarios or when new user types are included.
- It may be omitted for simple feature changes (only existing user types apply).
- When omitted, record in status.md: "Personas omitted — only existing user types apply".

---

## Persona 1. {persona name}

- Role: {user role — e.g. general customer, operations manager, external partner}
- Goal: {what they want to achieve through this feature}
- Context: {usage environment, frequency, device, constraints}
- Core needs: {requirements that must be met}
- Complaints/pain points: {problems with the current approach}

## Persona 2. {persona name}

- Role:
- Goal:
- Context:
- Core needs:
- Complaints/pain points:

## Relationships Between Personas

- Describe the interaction or conflict points between {Persona 1} and {Persona 2}.
- If there is an operator/admin persona, specify the permission boundary versus general users.
