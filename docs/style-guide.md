# Style Guide

Language rules for this repo and for the artifacts the workflow produces.
Two layers, one rule each:

1. **Repository content** (skills, rules, templates, docs, commit messages in THIS repo): **English**.
   Source of truth: [CONTRIBUTING.md](../CONTRIBUTING.md) "Language Rules".
2. **Runtime artifacts** (the `aidlc-docs/` a team produces in ITS project): body text in the
   team's working language; **all structural labels in English** so they can be parsed by
   code/automation and validated by `tools/evaluator/`.

## Repository content (this repo)

| Item | Language |
|------|----------|
| Skill prompts, rule docs, templates, README/docs | English |
| Commit messages | English |
| Quoted examples of what a user might type | May stay in the user's language, with an English gloss |
| Backward-compat notes listing legacy Korean labels | Allowed (they document accepted input) |

## Runtime artifacts (a consuming project's aidlc-docs/)

| Item | Language | Example |
|------|----------|---------|
| Section headings & field labels | English (required) | `## Goal`, `Scope`, `Type`, `Category`, `Impact`, `If-unanswered` |
| Status values | English (required) | `OPEN`, `ANSWERED`, `BLOCK`, `ASSUME-A`, `TODO` |
| Requirement/answer body text | Team's working language | "재구매 고객에게 자동으로 할인 쿠폰을 발급한다" |
| Technical terms, file paths, code | English | `ctx/project-profile.ctx.md`, Repository, JPA |
| Commit messages in the team's project | Per the project's `ctx/workflow/commit-workflow.ctx.md`; default English | — |

Label rule source: `common/question-rules.md` ("Labels must always use English").
Chat responses to the user follow the user's language (e.g. `team-ai-workflow-start` responds in Korean); that is a conversation setting, not a document rule.

## Prohibited mixing (body text, any language)

- Do not needlessly mix languages within a single sentence.
  - Bad: "유저의 order를 cancel하는 로직"
  - Good: "사용자의 주문을 취소하는 로직" or, in a technical context, "Order 취소 로직"
- Do not alternate between two words for the same concept within one document
  (pick "쿠폰" or "coupon" for body text; code/paths always use the English identifier).
