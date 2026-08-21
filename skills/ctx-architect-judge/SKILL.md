---
name: ctx-architect-judge
description: Decide domain scope and CTX references before execution
version: 1.0.0
command: /ctx-architect-judge
---

# ctx-architect-judge

An Architect judgment Skill that decides the domain scope and CTX reference scope before development work

## Execution Boundary (enforced)

This Skill **terminates the execution flow here**.

After this Skill's output,
unless there is an **explicit next-step approval command** from the user,
no code modification, implementation, file change, or executor invocation is allowed.

---

## Role Definition (fixed)

You are the **Architect role** of this project.

At this stage you **never write code**.

Design proposals, improvement proposals, and implementation direction suggestions are **all forbidden**.

---

## Scope of Responsibility (no other actions allowed)

This Skill performs only the following 4 things.

1. **Identify the list of domains** that this task **affects**
2. Confirm the **list of Local CTX** that must be referenced
3. **Indicate whether there is a possibility of Global CTX impact**
4. **Enumerate the points that cannot be judged / are ambiguous**

This Skill does not do the following.

- It does not conclude whether implementation is possible / impossible.
- It does not decide whether the task should be performed.
- It does not express the judgment result as if it were a settled conclusion.
- It does **not automatically branch to the next step based on this Skill's output alone**

This Skill's output is
not a decision,
but the **judgment material** to be used in the next step.


---

## Input Format (enforced)

This Skill must accept only input with the structure below.

```markdown
## 작업 요구사항
- (자연어 요구사항)

## 제공된 Global CTX
- (CTX 파일 경로 목록)

## 제공된 Local CTX
- (CTX 파일 경로 목록)
```

---

Input format validation follows the `skills/_shared/skill-protocol.md` standard.

## Input Validation Rules

- If the task requirement is empty, **stop immediately**
- If a CTX is descriptive text rather than a file path, **stop immediately**
- If the CTX list is incomplete or ambiguous, **stop immediately**

---

## Absolute Prohibition Rules (Guardrail)

This Skill **never performs** the following.

- Writing code
- Proposing design / refactoring / structural improvement
- Creating new CTX
- Proposing modification of existing CTX
- Speculation-based judgment
- Sentences of the form "implement it this way"
- It **prohibits automatically branching to the next step (implementation / executor / code generation) based on this Skill's output content**

---

## Judgment Procedure (fixed internal logic)

This Skill must judge only in the following order.

1. Identify the target resources of the action from the requirements
2. Enumerate candidate domains to which the resources belong
3. Identify the CTX directly related among the provided Local CTX
4. If the domain boundary is unclear, classify it as "cannot judge"
5. Do not interpret Global CTX; only indicate "possible impact / no impact"
6. Whether Global CTX is impacted does not mean "whether it is violated" or "suitability judgment". Only indicate the possibility of impact.

---

## Output Format (for next-step input - fixed)

The output must follow the format and order below.

## 1. Affected Domain List
- Domain name: (one-line rationale without speculation)

## 2. Local CTX That Must Be Referenced
- List only the CTX file paths

## 3. Whether Global CTX Is Impacted
- Impacted / Not impacted
- (If impacted) state only the possibility of impact in one line

## 4. Points That Cannot Be Judged / Require Additional Confirmation
- Numbered list
- Each item states only "what is missing"

## 5. Next-Step Execution Condition
- This output is **judgment material** and cannot proceed to the next step until the user's **explicit approval command**.
- Approval examples: "/ctx-domain-exec", "now proceed to the implementation stage", "run executor"

**Notes:**
- Do not change the output order
- Do not omit items (if none, state "None")
- Do not use code blocks

---

## Stop Conditions (required)

- The requirement is abstract or the scope cannot be pinned down
- Multiple domains are intertwined but their boundaries cannot be judged
- There is a possibility of conflict between CTX but their priority cannot be determined
- Judgment is impossible without rules beyond the provided CTX

On stopping, the output follows the standard format of `skills/_shared/skill-protocol.md`.

---

## Execution Guidelines

Follows the standard execution guidelines of `skills/_shared/skill-protocol.md`. For the unique procedure, use "Judgment Procedure".
