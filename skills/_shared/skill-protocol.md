# Skill Protocol

The common execution protocol that all skills follow. Each skill's SKILL.md references this document and defines only its skill-specific content.

## Common Structure Rules

Every skill MUST include the following sections (order is free):
1. Role definition (fixed - never change)
2. Scope of responsibility (no actions beyond this)
3. Absolute prohibition rules (Guardrail)
4. Input format + input validation
5. Processing/judgment/implementation procedure
6. Output format
7. Halt conditions + output format on halt
8. Execution guidelines

## Input Format Validation Criteria

Input format validation is based on **logical structure**.
- Ignore leading whitespace, UI characters (`›`, `•`), and blank-line differences.
- Validate only whether required sections exist and whether they have content.

## Output Constraints

- Do NOT change output order
- Do NOT omit items (if absent, state "없음" or "해당 없음" explicitly)
- Code block usage follows per-skill rules

## Standard Output Format on Halt

```markdown
## [동작명] 중단

중단 사유:
- (구체적인 중단 사유)

확인이 필요한 사항:
1. ...
```

On halt:
- Do NOT propose alternatives
- Do NOT explain how to fix
- Output only the halt reason

## Standard Execution Guidelines

Every skill executes in the following order.

1. Validate whether the user input follows the input format
2. Check validity according to the input validation rules
3. If invalid, respond with the output format on halt
4. If valid, perform the skill-specific procedure in order
5. Review the output so as not to violate the absolute prohibition rules
6. Return the result according to the output format

If there are additional per-skill guidelines, insert them between 4 and 6.

## Execution Boundary Principle

- Each skill does not perform actions beyond its scope of responsibility.
- Do not automatically branch to the next step based on a skill's output alone.
- Proceed to the next step only when there is an explicit approval command from the user.
