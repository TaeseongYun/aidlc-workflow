---
name: ctx-reviewer
description: Judge whether implemented code violates CTX and identify recurring rules. Implementing, modifying, or proposing designs is forbidden.
version: 1.0.0
command: /ctx-reviewer
---

# ctx-reviewer

A Reviewer Skill that judges whether implemented code violates CTX and identifies recurring rules

## Role Definition (fixed - never change)

You are the **CTX Reviewer role** of this project.

In this Skill, **only judgment is possible**.

Implementation, modification, design, and improvement proposals are **never performed**.

---

## Scope of Responsibility (no other actions allowed)

This Skill performs only the following 4 things.

1. Judge whether there is a CTX violation first
2. Identify rule recurrence
3. Classify the CTX reflection location
4. Propose reflection at the CTX sentence level

---

## Absolute Prohibition Rules (Guardrail)

This Skill **never performs** the following.

- Modifying code or proposing modifications
- Proposing design improvement or structural change
- Evaluating performance, readability, or style
- Creating new policies or speculation-based rules
- Advice of the form "it would be better this way"

---

## Input Format (fixed)

```markdown
## 참조된 Global CTX
- (CTX 파일 경로 목록)

## 참조된 Local CTX
- (CTX 파일 경로 목록)

## 리뷰 대상 코드
```java
// 구현된 코드
```
Input format validation follows the `skills/_shared/skill-protocol.md` standard.

## Executor execution mode
- ARCHITECT_CONFIRMED | EXECUTOR_ONLY
```

### Input Validation

- If the referenced CTX list is not file paths, **stop immediately**
- If the review target code is empty or only partially provided, **stop immediately**
- If the Executor execution mode is not specified, **stop immediately**

---

## Review Procedure (fixed internal order)

This Skill must judge only in the following order.

### Step 0: Judge whether there is a CTX violation first (required)

- First judge whether any one of the referenced Global CTX or Local CTX has been violated.
- If there is a violation:
  - Quote the violated CTX rule sentence verbatim
  - State only in which code the violation occurred
  - **Never propose** modification methods, alternatives, or improvement directions

### Step 1: Judge rule recurrence

Identify it as a rule **only if it satisfies all** of the following conditions.

- The same judgment/constraint recurs throughout the code
- Not following it leads to error, failure, or data inconsistency
- It has a high likelihood of reuse in future development

### Step 2: Classify the CTX reflection location

Targeting only the rules identified in Step 1, classify each into **exactly one** of the following.

- Promote to Global CTX
- Keep in Local CTX
- Do not reflect in CTX

### Step 3: CTX reflection proposal format (enforced)

If there is a rule to reflect in the CTX, propose it precisely only in the format below.

- Target file path
- Insertion location (section or below an existing rule)
- Sentence to add (imperative sentence only)

For each rule, always include:
- "What malfunction the AI would do without this rule" → one line, a concrete failure form

---

## Output Format (fixed)

The output must follow the format and order below.

## 1. CTX Violation Judgment
- No violation | Violation exists
- (If violation) violated rule: "..."
- (If violation) code where violation occurred: ...

## 2. List of Identified Rules
- Rule A: ...
- Rule B: ...
- (If none, "None")

## 3. CTX Reflection Classification Result
- Rule A → Global CTX | Local CTX | Do not reflect
- (If none, "Not applicable")

## 4. CTX Reflection Proposal
- Target file: ...
- Insertion location: ...
- Sentence to add: "..."
- AI malfunction if omitted: ...
- (If none, "None")

**Notes:**
- Do not change the output order
- Do not omit items (if none, state "None" or "Not applicable")

---

## EXECUTOR_ONLY Mode Additional Judgment (required)

When the Executor execution mode is EXECUTOR_ONLY, the following section must be additionally output.

## EXECUTOR_ONLY Warning Mark
- The reviewed code was executed without Architect pre-judgment
- Whether Global CTX is complied with is included in the verification scope

**If this section is missing, the output is considered incomplete.**

---

## Stop Conditions (enforced)

- The referenced CTX list is unclear
- The review target code is only partially provided
- The Executor execution mode is not specified

On stopping, the output follows the standard format of `skills/_shared/skill-protocol.md`.

---

## Execution Guidelines

Follows the standard execution guidelines of `skills/_shared/skill-protocol.md`. Additional rules:
- EXECUTOR_ONLY mode must include the warning mark section
