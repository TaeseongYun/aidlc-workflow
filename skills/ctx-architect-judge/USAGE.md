# How to Use ctx-architect-judge

## Usage Summary

1. Invoke the Skill with the `/ctx-architect-judge` command
2. Provide the task requirements and CTX list according to the input format
3. The Skill judges the domain scope and CTX reference scope and returns a structured result
4. If judgment is impossible, the stop reason and confirmation questions are returned

---

## Correct Invocation Example

```
/ctx-architect-judge

## Task Requirements
- Apply caching to the user grade (Grade) lookup API

## Provided Global CTX
- @ctx/back-end/api/api-design.ctx.md
- @ctx/back-end/api/api-response.ctx.md
- @ctx/back-end/api/error-handling.ctx.md
- @ctx/back-end/api/swagger-global.ctx.md

## Provided Local CTX
- .ctx/domains/grade/grade-domain.ctx.md
- .ctx/domains/grade/grade-api.ctx.md
```

**Expected output:**

## 1. Affected Domain List
- Grade: The user grade lookup API belongs to the Grade domain

## 2. Local CTX That Must Be Referenced
- .ctx/domains/grade/grade-domain.ctx.md
- .ctx/domains/grade/grade-api.ctx.md

## 3. Whether Global CTX Is Impacted
- Impacted
- When applying caching, compliance with the caching-policy.ctx.md rules is required

## 4. Points That Cannot Be Judged / Require Additional Confirmation
- None

---

## Incorrect Invocation Example (case that stops)

```
/ctx-architect-judge

## Task Requirements
- Improve performance

## Provided Global CTX
- See the global caching policy

## Provided Local CTX
- See the grade-related rules
```

**Expected output:**

## Judgment Stopped

Stop reason:
- The task requirement is abstract (cannot pin down which feature's performance to improve)
- CTX was provided as descriptive text rather than file paths

Questions that need confirmation:
1. What is the specific API or feature that is the target of the performance improvement?
2. Please provide the exact paths of the Global CTX files
3. Please provide the exact paths of the Local CTX files
