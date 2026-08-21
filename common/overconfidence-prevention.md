# Overconfidence Prevention

Rules that prevent the AI from proceeding without asking questions, or treating an uncertain judgment as if it were settled.

## Background

Three patterns of AI overconfidence recurred in real-world workshops.

1. **Question avoidance** — Entering design directly without asking questions even for a complex request
2. **Ungrounded certainty** — Treating "it will probably be ~" or "usually it does ~" as established fact
3. **Ignoring gaps** — Skipping areas where information is insufficient and proceeding with only the available information

## Scope of Application

This rule is especially important in **STEPs that are not question-generation segments**.

| STEP | Overconfidence Risk | Reason |
|------|----------|------|
| STEP 1 (Project Detection) | Medium | A greenfield/brownfield misjudgment throws off the entire flow |
| STEP 1-B (Depth Level) | Medium | Setting the depth too low omits core questions |
| STEP 6 (Unit Decomposition) | **High** | AI-driven step. Decomposes without questions, so overconfidence is most likely |
| STEP 6.5 (Technical Design) | **High** | Risk of settling technical decisions without grounds |
| STEP 7 (Readiness Score) | Medium | Scoring leniently and judging NOT_READY as READY |

## Rules

### 1. Duty to State Uncertainty

Always attach an uncertainty marker to any judgment that is not certain.

**Marker format**:
```markdown
> ⚠️ UNCERTAIN: {area} — {reason for uncertainty}
```

**Trigger conditions** — attach the marker if any of the following applies:
- CTX has no relevant information and the code also does not allow a single interpretation
- 2 or more design options are possible but the basis for the choice is not in the project documents
- The behavior of an external system is being assumed

### 2. Self-Verification

In the STEPs below, perform self-verification after writing the artifact and before presenting the gate.

**Target STEPs**: 6 (Unit Decomposition), 6.5 (Technical Design), 6.7 (Infrastructure Design)

**3 verification questions** (answer them yourself about the artifact):
1. "Is there CTX- or code-based grounding for this decision?" — if not, add a `⚠️ UNCERTAIN` marker
2. "Does another reasonable alternative exist?" — if so, note the alternative in the artifact
3. "What is the impact scope if this decision is wrong?" — if the impact is large, include a warning in the gate message

### 3. Question Gap Detection

When STEP 3 (Analysis & Planning Draft) completes, perform the checks below.

- Does the request contain **external integration, payment/settlement, or permission/security** keywords but there are 0 related questions?
- Is the Depth Level standard or higher but 2 or fewer questions were generated?
- Is it brownfield but there are 0 questions related to existing-system impact?

If any applies:
1. Record an `[OVERCONFIDENCE-CHECK] question gap detected` event in `audit.md`.
2. Generate additional questions for the missing areas (within the question budget).

### 4. Preventing Lenient Readiness Score Judgments

When computing the Readiness Score in STEP 7:

- For a domain that includes an item with a `⚠️ UNCERTAIN` marker, cap that domain at **80% of its maximum**.
- For a domain with 3 or more `[Confidence: Estimated]` or `[Confidence: AI-Recommended]` answers, apply the cap along with a warning mark.
- State the fact that a cap was applied in the "Uncertain Areas" section of `status.md`.

### 5. No Ambiguous Expressions

Do not use the expressions below as definitive statements in artifacts.

| Forbidden pattern | Replacement |
|----------|----------|
| "it will be ~", "usually it does ~" | State the grounds or add a `⚠️ UNCERTAIN` marker |
| "obviously", "clearly" | State the grounds |
| "can be handled simply" | Concrete implementation method or `⚠️ UNCERTAIN` marker |
| "no separate review needed" | State the grounds for judging that review is unnecessary |

## Prohibitions

- Do not skip the self-verification step.
- Do not remove `⚠️ UNCERTAIN` markers before presenting the gate (the user must confirm them).
- Do not ignore question-gap detection results.
- Do not bypass the Readiness Score cap rule.
