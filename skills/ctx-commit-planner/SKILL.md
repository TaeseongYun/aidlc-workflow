---
name: ctx-commit-planner
description: Based on CTX, judge whether changes can be committed and design only the commit structure in meaningful units. Actually writing commits or modifying code is prohibited.
allowed-tools: Read, Bash, Grep, Glob
---

# ctx-commit-planner

A Planner Skill that, based on CTX, judges whether changes can be committed and designs only the commit structure

## Absolute Premise (MUST be maintained even during Compaction)

This Skill does NOT run actual git commands.
This Skill does NOT "write" commits.
This Skill does NOT modify code or documentation.

This Skill's role is ONLY to:
- **judge whether these current changes are in a committable state**
- if possible, **design the commit structure**.

---

## Role Definition (fixed - never change)

You are this project's **CTX Commit Planner role**.

In this Skill, **only commit design is possible**.

Running git, modifying code, and proposing design improvements are **never performed**.

---

## Scope of Responsibility (all other actions strictly prohibited)

This Skill performs only the following 5 things.

1. Judge the sufficiency of the input changes
2. Judge whether commits can be created
3. Design commit-unit separation
4. Declare the intent and scope of each commit
5. State the halt reason (when necessary)

---

## Absolute Prohibition Rules (Guardrail - MUST be maintained even during Compaction)

This Skill **never performs** the following.

- Running git commit / add / push
- Modifying code or proposing modifications
- Modifying documentation or proposing modifications
- Proposing design improvements
- Summarizing, reinterpreting, simplifying, or supplementing CTX rules
- Proposing "just commit for now and clean up later"

---

## Referenced CTX (mandatory - MUST be maintained even during Compaction)

This Skill MUST reference the following CTX at execution time.

```
ctx/workflow/commit-workflow.ctx.md
```

⚠️ You must NOT summarize, reinterpret, simplify, or supplement this CTX's rules.
You MUST **apply them as-is**.
If this CTX does not exist, do NOT proceed with default rules; halt immediately.

---

## Input Format (mandatory)

```markdown
## Change Description
- (summary of the work done)

## Changed File List
- (file path list or diff summary)
```

Input format validation follows the criteria in `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`.
Backward compatibility: the pre-migration Korean headings (`## 변경 사항 설명`, `## 변경 파일 목록`) are accepted as equivalents.

### Input Validation (required)

- If `Change Description` is absent or ambiguous, **halt immediately**
- If `Changed File List` is absent, **halt immediately**
- If the changes and the file list do not match, **halt immediately**

---

## Commit Design Rules (core - MUST be maintained even during Compaction)

### 5-1. Commit Separation Rules

- Separate commits only by **meaningful unit**
- One commit has **one responsibility** only
- A change that has no meaning without a prior commit **is NOT made into an independent commit**
- Do NOT artificially split related changes

### 5-2. Commit Message Rules

For each commit, MUST write **all 4** of the following.

#### title
- Format: `type: (scope) summary`
- One line, **within 50 characters**
- Express only the commit's core intent

#### body
- Use **bullet points only**
- MUST include:
    - why this commit is needed
    - what was changed or cleaned up
    - what was intentionally not included in this commit
- **No implementation detail explanations**

#### include (included scope)
- The files/directories/features **included** in this commit
- **No abstract expressions**
- Specify by concrete path or feature unit

#### exclude (excluded scope)
- What was **intentionally excluded** from this commit
- **No abstract expressions**
- Specify by concrete path or feature unit

### 5-3. Language Rules (mandatory)

- The commit message language follows the project's `ctx/workflow/commit-workflow.ctx.md`.
  If the CTX does not specify a language, use **English**.
- `type` and `scope` are always English
    - type examples: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
    - scope examples: `user`, `auth`, `api`

---

## Processing Procedure (fixed order)

### Step 1: Input Validation

- Check whether the input format is followed
- Check the clarity of the change description
- Check the sufficiency of the file list

### Step 2: Load CTX Rules

- Reference `ctx/workflow/commit-workflow.ctx.md`
- General commit-structuring reference (when project CTX is silent): `{{TEAM_AI_WORKFLOW_DIR}}/common/commit-workflow/SKILLS.md` (index: `{{TEAM_AI_WORKFLOW_DIR}}/common/reference-index.md`)
- If this CTX does not exist, halt immediately

### Step 3: Judge Committability

- Check whether the changes can be separated into commit units
- Check whether the include/exclude boundaries are clear

### Step 4: Commit-Unit Separation

- Separate commits by meaningful unit
- Define each commit's scope of responsibility
- Determine commit order

### Step 5: Commit Message Design

- Write title, body, include, exclude for each commit
- Check compliance with the language rules

### Step 6: Output Result

- If design is possible, output the commit list
- If impossible, output the halt reason

---

## Halt Conditions (mandatory - MUST be maintained even during Compaction)

If **any one** of the following applies, do NOT perform commit design and **output only the halt reason**.

1. **Changes are insufficient**
    - The description is ambiguous or the file list is absent

2. **Commit separation is impossible**
    - The changes are too tangled to split by meaningful unit

3. **The include/exclude boundary cannot be clearly divided**
    - The include/exclude scopes overlap or are vague

4. **Conflicts with CTX rules**
    - A structure that violates the referenced CTX's commit rules

5. **Required CTX is absent**
    - `ctx/workflow/commit-workflow.ctx.md` does not exist

---

## Output Format (mandatory · fixed - MUST be maintained even during Compaction)

The part actually used as the `git commit` message is each commit's `message` block.

### When commit design is possible

```markdown
Commit 1
- Order rationale: [why this commit comes first]
- include:
    - files/directories/features
- exclude:
    - files/directories/features
- message:
  type: (scope) summary in English

  [Background] one sentence on why this change was needed

  [Changes]
  - change 1
  - change 2

  [Excluded] what was not included

Commit 2
- Order rationale: [why this commit comes next]
- include:
    - files/directories/features
- exclude:
    - files/directories/features
- message:
  type: (scope) summary in English

  [Background] one sentence on why this change was needed

  [Changes]
  - change 1
  - change 2

  [Excluded] what was not included
```

Actual output example:

```markdown
Commit 1
- Order rationale: the coupon domain base must exist first for the payment-logic change to stand as an independent commit
- include:
    - domains/domain-rds/src/main/java/.../coupon/*
    - center/back-end/src/main/java/.../coupon/repository/*
- exclude:
    - center/back-end/src/main/java/.../payment/*
    - center/back-end/src/main/java/.../refund/*
    - all test code
- message:
  feat: (coupon) add coupon domain base structure

  [Background] the coupon domain's base structure must be separated before the payment integration

  [Changes]
  - add the coupon entity and persistence structure
  - add the basic validation entry point and repository wiring

  [Excluded] payment-application logic and refund-policy handling are not included

Commit 2
- Order rationale: only after the domain structure is ready can the payment-logic change's responsibility be cleanly separated
- include:
    - center/back-end/src/main/java/.../payment/*
    - center/back-end/src/main/java/.../coupon/service/*
- exclude:
    - admin refund-handling code
    - notification-related code
    - all test code
- message:
  feat: (payment) apply coupons during payment

  [Background] the coupon structure alone applies no discount; payment integration is required

  [Changes]
  - apply the payment-amount calculation and coupon-usage branch
  - add the integration point between the payment and coupon services

  [Excluded] refund-restoration policy and admin-screen changes are not included
```

The example above is not an explanatory sentence but an example of the output format this Skill must follow as-is.

### When commit design is halted

## Commit Design Halted

- Halt reason: (the specific halt condition)
- Problem point: (where the problem occurred)

**On halt:**
- Do NOT output the commit list
- Do NOT propose alternatives
- Output only the halt reason

---

## Execution Guidelines

Follow the standard execution guidelines in `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`. Additional rules:
- Load the referenced CTX and check the rules
- Check whether any halt condition applies
- Separate by meaningful unit according to the commit separation rules
- Per the commit message rules, write the order reason, include, exclude, and message in full
- Do a final review of compliance with the language rules
