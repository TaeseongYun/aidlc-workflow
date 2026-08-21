<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Requirement Verification Questions

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`.

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

Question writing criteria:
- Question format and rules follow `common/question-rules.md`.
- Question governance (scope, type, confidence, budget) follows `common/question-governance.md`.
- If even one BLOCK question remains, requirements.md is not implementation-ready.

> **Request Anchor**: {1-2 line summary of the initial request — confirmed in STEP 2}

## Summary

| ID | Priority | Scope | Type | Category | Impact | Status | If Unanswered | Confidence |
|----|----------|------|------|------|--------|------|-----------|------|
| Q1 | P0/P1 | | policy/domain/scope | | | OPEN / ANSWERED | BLOCK / ASSUME / AI-RECOMMEND / DEFER | |

## 1. Domain And Scope

### Q1. {question title}
- Priority: P0-CRITICAL / P1-IMPORTANT
- Scope: [original request] {explanation of the relevant part}
- Type: policy / domain / scope
- Category: scope
- Impact: high / medium / low
- Reason: {why this question is needed}
- Options:
  - A) {option} → {implementation impact}
  - B) {option} → {implementation impact}
  - C) Other (enter manually)
- AI recommendation: {option}) {recommendation} — rationale: {basis for the judgment}
- If unanswered: BLOCK / ASSUME-{X} ({assumption basis}) / AI-RECOMMEND-{X} / DEFER-TO-FEATURE
- [Answer]:
- [Confidence]: confirmed / estimated / AI-recommended / undecided

## 2. User Flow
<!-- Same format as Q1. Add questions that fit the category -->

## 3. Policy / Exception
<!-- Same format as Q1. policy-type questions do not use the AI recommendation field -->

## 4. Integration
<!-- Same format as Q1. Add questions that fit the category -->

## 5. Ops / Notification / Reporting
<!-- Same format as Q1. Add questions that fit the category -->

## AI Automatic Decisions (P2)
<!-- P2-DEFERRABLE items are decided by the AI as defaults and recorded here. Humans can review afterward. -->

| # | Item | Default Value | Rationale | Impact if Changed |
|---|------|----------|------|-------------|
| | | | | |

## Additional Questions (next round)
<!-- Store here when the question budget is exceeded. Promote after the current round's answers are complete -->
