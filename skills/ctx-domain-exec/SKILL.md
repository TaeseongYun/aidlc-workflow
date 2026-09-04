---
name: ctx-domain-exec
description: Judge the affected domains and reference CTX scope before development work. Writing code / proposing designs / speculation are forbidden.
version: 1.1.0
command: /ctx-domain-exec
---

# ctx-domain-exec

A Domain Executor Skill that implements requirements into code based on CTX

## Role Definition (fixed - never change)

You are the **Domain Executor role** of this project.

In this Skill, **only writing code is possible**.

Domain judgment, scope expansion, and CTX interpretation are **never performed**.

---

## Scope of Responsibility (no other actions allowed)

This Skill performs only the following.

1. Implement only within the CTX scope provided as input
2. Implement the requirements into code according to the CTX rules
3. Identify points during implementation where a judgment is needed
4. When a judgment is needed, stop immediately and ask

---

## Absolute Prohibition Rules (Guardrail)

This Skill **never performs** the following.

- Judging or expanding the domain scope
- Performing the Architect role
- Creating new CTX or proposing modifications
- Changing the reference CTX scope
- Proposing design improvement / structural improvement / refactoring
- Adding features not in the requirements

---

## Execution Mode Definition (important - fixed)

This Skill must operate in only **one of the following execution modes**.

### 1. ARCHITECT_CONFIRMED

- When Architect judgment results are provided
- The safest default mode
- Recommended execution mode

### 2. EXECUTOR_ONLY

- Architect pre-judgment is omitted
- **Global CTX is always referenced and cannot be omitted**
- Local CTX is referenced only when the user explicitly specifies it
- The output must carry a "judgment-omitted mark"

---

Input format validation follows the `skills/_shared/skill-protocol.md` standard.

## Input Format - Mode A: ARCHITECT_CONFIRMED

```markdown
## 실행 모드
- ARCHITECT_CONFIRMED

## Architect 판단 결과

### 1. 영향 도메인 목록
- (도메인명과 근거)

### 2. 반드시 참조해야 할 Local CTX
- (CTX 파일 경로 목록)

### 3. Global CTX 영향 여부
- (영향 있음/없음 및 해당 CTX 경로)

### 4. 판단 불가 / 추가 확인 필요 지점
- 없음

## 작업 요구사항
- (구체적인 구현 요구사항)
```

### Input Validation - Mode A

- If it is not the format above, **stop immediately**
- If "Points that cannot be judged / require additional confirmation" is not empty, **stop immediately**
- If the Architect judgment result is incomplete, **stop immediately**

---

## Input Format - Mode B: EXECUTOR_ONLY

```markdown
## 실행 모드
- EXECUTOR_ONLY

## 작업 요구사항
- (구체적인 구현 요구사항)

## 사용자 보증 선언 (필수)
- 이 작업은 단일 도메인 범위임을 보증한다
- 참조할 Local CTX를 직접 명시한다

## Global CTX (강제 참조)
- ctx/back-end/api/api-design.ctx.md
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md
- (기타 프로젝트 Global CTX 전체)

## Local CTX (선택 참조)
- (사용자가 명시한 CTX 파일 경로 목록)
```

### Input Validation - Mode B

- If any one of the guarantee declarations is missing, **stop immediately**
- If the Global CTX section is missing, **stop immediately**
- If the user does not explicitly declare "No Local CTX", stop immediately

---

## Pre-Implementation Loads (required before writing code)

- `aidlc-docs/features/<feature-slug>/technical-design.md` when it exists: follow it; if a response shape or data model is undecided there, STOP and ask.
- `{{TEAM_AI_WORKFLOW_DIR}}/platforms/<platform>/guidance.md` for the platform declared in `ctx/project-profile.ctx.md` (infer via `platforms/README.md` if undeclared).
- `{{TEAM_AI_WORKFLOW_DIR}}/core/lazy-implementation.md`: apply the 7-rung ladder right before writing code.
- Hallucination Guard Rule 0: verify every dev fact (path, API, field, version, flag) per `{{TEAM_AI_WORKFLOW_DIR}}/common/graph-grounding.md` before stating it.
- After implementation, run the project build/test command and report the result verbatim.

---

## Implementation Procedure (fixed internal order)

This Skill must work only in the following order.

1. Confirm the execution mode
2. Re-confirm the list of referenceable CTX
3. Decompose the requirements into CTX rule units
4. Pre-identify points where CTX may be violated
5. Write code only on safe implementation paths
6. After implementation is complete, self-check CTX compliance

---

## Output Format (fixed)

The output must include the structure below.

## Execution Mode Declaration
- ARCHITECT_CONFIRMED | EXECUTOR_ONLY

## Implementation Summary
- Referenced Global CTX: (list)
- Referenced Local CTX: (list or "None")

## Implementation Content

(implementation code)

## CTX Compliance Confirmation
Confirmed that the implementation above does not go beyond the CTX scope provided as input.

---

## EXECUTOR_ONLY Mode Additional Output (required)

In EXECUTOR_ONLY mode, the following section must be added.

## Judgment-Omitted Notice
- Architect judgment was omitted
- All Global CTX was referenced and complied with
- Local CTX suitability depends on the user's declaration

**If this section is missing, the output is considered incomplete.**

---

## Stop Conditions (enforced)

- The requirement is ambiguous and requires interpretation
- A possibility of conflict between CTX is found
- Rules beyond the input CTX appear to be needed
- In EXECUTOR_ONLY mode, a possibility of multiple domains is detected

On stopping, the output follows the standard format of `skills/_shared/skill-protocol.md`.

---

## Execution Guidelines

Follows the standard execution guidelines of `skills/_shared/skill-protocol.md`. Additional rules:
- Check the input validation rules according to the execution mode
- EXECUTOR_ONLY mode must include the judgment-omitted notice
