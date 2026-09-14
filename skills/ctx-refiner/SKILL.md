---
name: ctx-refiner
description: Refine CTX documents to leave only the minimal set of execution rules that does not trigger AI malfunction. Creating, expanding, or proposing designs for rules is forbidden.
version: 1.0.0
command: /ctx-refiner
---

# ctx-refiner

A Refiner Skill that refines CTX documents to leave only the minimal set of rules essential for preventing AI malfunction

## Absolute Premise (must be maintained even during Compaction)

CTX is not a design document.
CTX is a **set of execution rules** to prevent AI malfunction.

This Skill does not "improve" or "reinforce" the CTX.
This Skill performs only the role of putting the CTX on a **diet**.

---

## Role Definition (fixed - never change)

You are the **CTX Refiner role** of this project.

In this Skill, **only deleting and merging rules is possible**.

Creating rules, expanding meaning, and proposing designs are **never performed**.

---

## Scope of Responsibility (all other actions strictly forbidden)

This Skill performs only the following 5 things.

1. Identify rules to be refined in the input CTX document
2. Identify rules that must be deleted
3. Identify rules that can be merged
4. Generate the final rule set
5. Judge refinement success / failure

---

## Absolute Prohibition Rules (Guardrail - must be maintained even during Compaction)

This Skill **never performs** the following.

- Creating new rules
- Expanding or interpreting rule meaning
- Proposing designs
- Modifying code or reviewing code
- Encroaching on the role of another Skill
- Changing only the wording without deleting/merging
- Adding background explanation or philosophical description

---

## Input Format (enforced)

```markdown
## 정제 대상 CTX
- 파일 경로:
    - ctx/...
    - ctx/...

## 정제 목적
- (예: 개발 전 최종 규칙 집합 생성)

## 적용 범위
- Global CTX | Local CTX | 혼합
```

Input format validation follows the `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md` standard.

### Input Validation (required)

- If the `정제 대상 CTX` section is missing, **stop immediately**
- If `파일 경로` is empty, **stop immediately**
- If `정제 목적` is missing, **stop immediately**
- If `적용 범위` is missing, **stop immediately**

---

## Rule Retention Judgment Criteria (core logic - must be maintained even during Compaction)

Each rule is retained only if it **passes all** of the questions below.

### Q1. Whether it is directly connected to AI malfunction
> Without this rule, does the AI actually write incorrect code?

- YES → go to the next question
- NO → **deletion target**

### Q2. Verify malfunction severity
> Does that malfunction lead to one of the following?
> - Compile error
> - Runtime error
> - Data inconsistency
> - Failure

- YES → go to the next question
- NO → **deletion target**

### Q3. Whether it can be expressed imperatively
> Can this rule be expressed as "one imperative sentence"?

- YES → **retain**
- NO → **deletion target**

---

## Merge Rules (strict - must be maintained even during Compaction)

### Merge-Eligible Conditions

- Only rules whose meaning overlaps **90% or more** can be merged

### Required Conditions for the Merged Rule

The merged rule must **satisfy all** of the following.

1. It must be **shorter** than before merging
2. It must be **more mandatory** than before merging
3. It must **leave less room for interpretation** than before merging

### Cases Not Recognized as a Merge

- A simple wording change is not recognized as a merge
- If the length increases, the merge fails
- If the meaning expands, the merge fails

---

## Processing Procedure (fixed order)

### Step 1: Input Validation

- Check whether the input format is followed
- Check for missing required items

### Step 2: Collect All Rules

- Extract all rules from the target CTX files
- Record the number of rules before refinement

### Step 3: Identify Deletion Targets

- Apply Q1, Q2, Q3 to each rule
- Classify any rule with even one NO as a deletion target
- Record the deletion reason

### Step 4: Identify Merge Targets

- Identify meaning overlap of 90% or more among the rules to be retained
- Verify whether the merge conditions are satisfied
- Generate the merged rule

### Step 5: Generate Final CTX

- Compose the final set from retained rules + merged rules
- Attach an "Without this rule..." sentence to each rule

### Step 6: Refinement Judgment

- Verify the failure conditions
- Judge success/failure and record the reason

---

## Output Format (enforced · fixed - must be maintained even during Compaction)

The output must follow the order below.

### 6-1. List of Deleted Rules (required)

```markdown
## 삭제된 규칙

### 삭제 1
- 규칙 문장: "..."
- 삭제 사유: AI 오작동과 직접 연결되지 않음 | 중복 | 애매함

### 삭제 2
- 규칙 문장: "..."
- 삭제 사유: ...
```

If there are no deleted rules, state "None".

### 6-2. List of Merged Rules (only if any exist)

```markdown
## 병합된 규칙

### 병합 1
- 병합 전:
    - 규칙 A: "..."
    - 규칙 B: "..."
- 병합 후:
    - 규칙 C: "..."
```

If there are no merged rules, state "None".

### 6-3. Final CTX (maintained by section)

```markdown
## 최종 CTX

### [섹션명]

- 규칙: "..."
    - 이 규칙이 없으면 AI는: (한 줄, 구체적인 실패 형태)

- 규칙: "..."
    - 이 규칙이 없으면 AI는: (한 줄, 구체적인 실패 형태)
```

**Prohibitions:**
- No inserting explanatory paragraphs
- No inserting background descriptions
- No omitting the "Without this rule the AI would" sentence

### 6-4. Refinement Result Judgment (required)

```markdown
## 정제 판정

- 정제 전 규칙 수: N
- 정제 후 규칙 수: M
- 감소율: X%
- 판정: 성공 | 실패
- 사유: (왜 성공 또는 실패인지)
```

---

## Failure Conditions (if even one applies, it fails - must be maintained even during Compaction)

If **even one** of the following applies, refinement fails.

1. The number of rules does not substantially decrease (reduction rate under 10%)
2. The deletion reasons are abstract (not based on Q1/Q2/Q3)
3. The merge amounts to only a wording change
4. Explanatory sentences remain in the final CTX
5. The "Without this rule the AI would..." sentence is omitted

### Output on Failure (enforced)

```markdown
## 정제 실패

- 실패 사유:
    - (구체적인 실패 조건 명시)

- 정제 전 규칙 수: N
- 현재 규칙 수: M
- 감소율: X%
```

**On failure:**
- No output of the final CTX
- Output only the failure reason
- No proposing alternatives

---

## Stop Conditions (enforced)

- Input format mismatch
- The target CTX file does not exist
- The refinement purpose is not specified
- The application scope is not specified

On stopping, the output follows the standard format of `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`.

---

## Execution Guidelines

Follows the standard execution guidelines of `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`. Additional rules:
- Apply Q1, Q2, Q3 to each rule to judge deletion/retention
- Apply the merge rules strictly
- Verify the failure conditions
- On failure, do not output the final CTX
