# Question Rules

## Principles
- Questions target "what the project has not yet decided," not "what the AI does not know."
- Only raise items that affect implementation/operation/settlement.
- Prefer providing questions in a choice format so they are easy to answer.
- Each question states the consequence of not answering it (implementation blocked or assumption applied).

## Good Questions
- The choices are clear
- Each choice has a different implementation impact
- The answer locks in a design decision
- The impact level (high/medium/low) is clear

## Bad Questions
- Too broad
- Unrelated to the project
- The same question just reworded
- "Nice to know" level with no implementation impact

## Question Categories
- `policy` — Business policy decisions (refunds, discounts, permissions, etc.)
- `scope` — Feature scope, inclusion/exclusion criteria
- `flow` — User/operator flow, state transitions
- `integration` — External system integration methods
- `ops` — Operations, notifications, monitoring, batch

## Impact Levels
- `high` — Without an answer, implementation is impossible. Affects architecture/data model.
- `medium` — Can proceed with an assumption without an answer, but there is rework risk.
- `low` — Can proceed with a default even without an answer. Easy to change later.

## Recommended Format

```markdown
### Q{N}. {question title}
- Scope: [Original Request] {description of the relevant part}
- Type: policy / domain / scope
- Category: policy / scope / flow / integration / ops
- Impact: high / medium / low
- Reason: {why this question is needed}
- Choices:
  - A) {choice} → {implementation impact}
  - B) {choice} → {implementation impact}
  - C) Other (enter directly)
- AI Recommendation: {choice}) {recommended content} — Rationale: {basis for the judgment}
- If unanswered: BLOCK / ASSUME-{choice} ({basis for the assumption}) / AI-RECOMMEND-{choice} / DEFER-TO-FEATURE
- [Answer]:
- [Confidence]: Certain / Estimated / AI-Recommended / Undecided
```

> **Note**: The `AI Recommendation` field and the `AI-RECOMMEND` no-response handling are used only for `Type: domain` questions.
> For `Type: policy` questions, do not present an AI recommendation. See `common/question-governance.md` for detailed rules.

## Format Rules
- `If unanswered: BLOCK` — the default for high-impact questions. Without an answer, implementation must not proceed.
- `If unanswered: ASSUME-A` — when proceeding with an assumption is possible for medium/low-impact questions. Always state the basis for the assumption.
- `If unanswered: AI-RECOMMEND-A` — when the AI presents a grounded recommendation for a domain-type question. See `common/question-governance.md`.
- `If unanswered: DEFER-TO-FEATURE` — when a scope-type question is judged to be out of the current scope. Split it into a separate feature.
- Write the implementation impact of each choice concretely, e.g., "add 1 table," "change API response structure," "batch scheduler needed."
- If there are fewer than 2 choices, it is a confirmation request, not a question. Do not put it in the question list.
- Labels must always use English (Scope, Type, Category, Impact, Reason, Choices, AI Recommendation, If unanswered, [Answer], [Confidence]).

## Question Governance
Scope control, type classification, confidence tracking, and question budget for questions follow `common/question-governance.md`.
