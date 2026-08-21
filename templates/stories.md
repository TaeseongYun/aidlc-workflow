<!-- workflow-step: STEP-5.5 | gate: GATE-2.5 | producer: ctx-aidlc-run | condition: User Scenarios >= 3 or new user types -->
# User Stories

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/user-stories/stories.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/user-stories/personas.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this together when personas.md has been written.
- Each story must satisfy the INVEST criteria.
- Write Acceptance Criteria in Gherkin format (Given-When-Then).

---

## Summary

| ID | Persona | Story Title | Priority |
|----|---------|-----------|---------|
| US-1 | | | Must / Should / Could |
| US-2 | | | Must / Should / Could |

## US-1. {story title}

- Persona: {Persona N}
- Story: As a {role}, I want {feature} in order to achieve {goal}.
- Priority: Must / Should / Could

### Acceptance Criteria

```gherkin
Given {precondition}
When {user action}
Then {expected result}
```

### Notes
- {reference to related requirements.md items}

## US-2. {story title}

- Persona: {Persona N}
- Story: As a {role}, I want {feature} in order to achieve {goal}.
- Priority: Must / Should / Could

### Acceptance Criteria

```gherkin
Given {precondition}
When {user action}
Then {expected result}
```

### Notes
-

## INVEST Checklist

| Criterion | Description | US-1 | US-2 |
|------|------|------|------|
| Independent | Can it be implemented independently of other stories | | |
| Negotiable | Is there room in how it is implemented | | |
| Valuable | Does it provide value to the user | | |
| Estimable | Can its size be estimated | | |
| Small | Can it be completed within a single sprint | | |
| Testable | Are the acceptance criteria verifiable | | |
