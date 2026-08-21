# Question Governance

The **format** of questions is defined by `question-rules.md`.
This document defines the **governance** of questions — scope control, type classification, confidence tracking, and question budget.

## Background

From real-world workshop experience, three major problems with question-driven workflows were found.

1. **Focus drift** — Questions expand beyond the original request scope, causing the user to lose the initial intent
2. **No decision owner** — Who has the authority to answer which question is undefined, so answers waver
3. **Accumulation of low-knowledge answers** — Low-confidence answers are treated as if settled, making the deliverable sloppy

The rules in this document directly address the three problems above.

---

## 1. Focus Anchor

### Request Anchor
- Fix a **Request Anchor** at the top of every question file (`requirement-verification-questions.md`, etc.).
- The Request Anchor is a 1-2 line summary of the original request.
- It is finalized at STEP 2 (Request Capture) and is not changed thereafter.

```markdown
> **Request Anchor**: {1-2 line summary of the original request}
```

### Scope Tag
- Add a `Scope` field to every question as a required field.
- This field states which part of the Request Anchor the question relates to.

```markdown
- Scope: [Original Request] {description of the relevant part}
```

### Scope Drift Detection
- When generating a question, judge whether the question falls within the Request Anchor scope.
- If judged to be out of scope:
  1. Do not generate the question.
  2. Instead, inform the user: "This item is outside the current request scope. Would you like to split it into a separate feature?"
  3. If the user approves scope expansion, update the Request Anchor and add the question.
  4. If the user chooses to split, record the item in the Parked Features of `aidlc-state.md`.

### Progress Line
- Add the following single line to the gate message (`stage-gate-rules.md` format).

```markdown
> **Progress**: {Request Anchor summary} → Current: {current step} → Next: {next step}
```

---

## 2. Question Classification

The existing BLOCK/ASSUME in `question-rules.md` defines **the response when unanswered**.
Here, on a separate dimension, we classify **the nature of the question**.

### Type Definitions

| Type | Description | Who Answers | Response When Unanswered |
|------|------|-----------|-------------|
| `policy` | Business policy decisions. Refunds/settlement/permissions/discounts/notifications, etc. | Business decision owner (a human is required) | BLOCK only |
| `domain` | Judgment based on domain/technical knowledge. Authentication method, data model, API design, etc. | Domain expert, or accept the AI recommendation | BLOCK / ASSUME / **AI-RECOMMEND** |
| `scope` | Judgment of whether it is inside or outside the current work scope | Requester | BLOCK / **DEFER-TO-FEATURE** |

### AI-RECOMMEND (New No-Response Handling)

Applies only to `domain`-type questions.

**How it works**:
1. The AI presents a recommendation based on industry standards, best practices, and project context (CTX).
2. The recommendation must always state its **rationale**.
3. User response scenarios:
   - **Approve** → finalize with that choice. `[Confidence: Certain]`
   - **Modify** → reflect the modification. `[Confidence: Certain]`
   - **"Don't know, accept the AI recommendation"** → finalize with the AI recommendation. `[Confidence: AI-Recommended]`
   - **"Don't know, hold"** → handle as DEFER. `[Confidence: Undecided]`

**Format**:
```markdown
- AI Recommendation: {choice}) {recommended content} — Rationale: {basis for the judgment}
- If unanswered: AI-RECOMMEND-{choice} ({summary of recommendation rationale})
```

### DEFER-TO-FEATURE (New No-Response Handling)

Applies only to `scope`-type questions.

- Exclude the item from the current feature and record it in the Parked Features of `aidlc-state.md`.
- The current workflow proceeds without interruption.

---

## 3. Confidence Tagging

Tag the confidence on every question's answer.

### Confidence Levels

| Tag | Meaning | Readiness Score Impact |
|------|------|-------------------|
| `[Confidence: Certain]` | Clear grounding. Confirmed by the decision owner or stated in CTX | None |
| `[Confidence: Estimated]` | Grounded but uncertain. May need re-review | **Warning mark** on the relevant domain |
| `[Confidence: AI-Recommended]` | AI recommendation accepted. Expert review recommended later | **Warning mark** on the relevant domain |
| `[Confidence: Undecided]` | Decision deferred (DEFER). Tracked as a risk | Score deduction for the relevant domain |

### Meaning of the Warning Mark
- Answers containing `[Confidence: Estimated]` and `[Confidence: AI-Recommended]` attach a warning mark to the relevant domain when computing the Readiness Score.
- The warning mark does not deduct points, but it is made visible as an "Uncertain Areas" section in `status.md`.
- When a domain expert joins later, they can review the warning-marked items first.

### Confidence Summary
- Record confidence statistics in `aidlc-state.md`.

```markdown
## Confidence Summary
- Certain: N
- Estimated: N
- AI-Recommended: N
- Undecided: N
```

---

## 4. Risk-Based Priority

Assign priority not only by the nature of the question but also by **implementation risk**.
In real-world workshops, the AI repeatedly concentrated questions on low-risk details (batch size, logging level)
while overlooking high-risk areas (external API integration, known constraints).

### Priority Levels

| Level | Target | Handling |
|------|------|----------|
| `P0-CRITICAL` | External system integration, known technical constraints, possibility of data loss, security boundaries | Must ask. Human confirmation required. |
| `P1-IMPORTANT` | Business policy, exception handling, data model design, state transitions | Generate a question. BLOCK or ASSUME. |
| `P2-DEFERRABLE` | Batch size, logging level, default value tuning, format/alignment, retry count | AI decides by default. Notify the human only. |

### P0 Determination Criteria
It is P0 if any of the following conditions applies:
- External API/system integration is involved, and constraints/instability of that system are known or suspected
- There is a possibility of data loss, double processing, or integrity corruption
- It affects a security boundary (authentication, permission, encryption)
- Rollback is impossible or very difficult if a failure occurs

### P2 Automatic Decision Rules
- For P2 questions, the AI selects a default value based on industry standards or project context.
- Record the chosen default and its rationale in the **"AI Automatic Decisions (P2)"** section of `requirement-verification-questions.md`.
- The human may review this section after the fact, but the workflow proceeds even without a response.
- Classify as P2 only items that can be adjusted after deployment to the operating environment. Items hard to change after deployment are P1 or higher.

### Risk Information Input
- Known risks may be stated in `prepared_doc` or `request-intake.md`.
- Format: `> ⚠️ RISK: {area} — {description}` (e.g., `> ⚠️ RISK: Naver API — documentation and actual behavior frequently differ`)
- The AI automatically promotes questions in areas tagged with this risk to P0.
- Even without a risk tag, classify external integration as at least P1.

### Question Format Extension
Add a `Priority` field to the existing question format:

```markdown
### Q{N}. {question title}
- Priority: P0-CRITICAL / P1-IMPORTANT / P2-DEFERRABLE
- Scope: [Original Request] {description of the relevant part}
- Type: policy / domain / scope
...
```

### P2 Automatic Decision Section Format

```markdown
## AI Automatic Decisions (P2)

| # | Item | Default Value | Rationale | Impact of Change |
|---|------|----------|------|-------------|
| 1 | Batch size | 100 items | Typical initial value, adjustable after operation | Affects processing speed only |
| 2 | Retry count | 3 (exponential backoff) | AWS recommended pattern | Failure recovery time |
```

---

## 5. Question Budget

Prevents focus drift caused by excessive questions.

### Per-Round Question Cap

| Depth Level | Cap |
|-------------|-----|
| minimal | 3 |
| standard | 7 |
| comprehensive | 12 |

Depth Level is defined in `common/depth-levels.md`.

### Handling When Exceeded
1. Sort all questions by importance (impact × whether policy).
2. Present only the questions within the cap in the current round.
3. Keep the rest in the **"Additional Questions (Next Round)"** section at the bottom of the question file.
4. Once all current-round questions are answered, promote the additional-questions section to the next round.

### Importance Sorting Criteria
1. `P0-CRITICAL` + `policy` → highest priority
2. `P0-CRITICAL` + `domain` → 2nd priority
3. `P1-IMPORTANT` + `policy` → 3rd priority
4. `P1-IMPORTANT` + `domain` → 4th priority
5. `P1-IMPORTANT` + `scope` → 5th priority
6. `P2-DEFERRABLE` → not included in the round (moved to the AI Automatic Decisions section)

---

## 6. Question Format

The question format follows `question-rules.md`. The fields added in this document (Priority, Confidence) are included in that format.

### Per-Type No-Response Handling Restrictions

| Type | BLOCK | ASSUME | AI-RECOMMEND | DEFER-TO-FEATURE | AI Recommendation Field |
|------|-------|--------|-------------|-----------------|------------|
| policy | ✓ | ✗ | ✗ | ✗ | Forbidden |
| domain | ✓ | ✓ | ✓ | ✗ | Required |
| scope | ✓ | ✗ | ✗ | ✓ | ✗ |

---

## 7. Prohibitions

- Do not present an AI recommendation for a `policy`-type question. Business policy is decided only by a human.
- Do not generate a question without a Request Anchor.
- Do not add an out-of-scope question without user confirmation.
- Do not present more than the question budget at once.
- Do not reflect a `[Confidence: Undecided]` answer in the design as if it were settled.
- Do not downgrade a P0 question to P2. External integration, security boundaries, and data integrity are always P0 or higher.
- Do not present a P2 question to a human as BLOCK. Notify only after deciding the default.
- Do not classify items hard to change after deployment (data schema, authentication method, API contract) as P2.
