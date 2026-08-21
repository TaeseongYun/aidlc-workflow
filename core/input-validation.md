# Input Validation (input document validation)

## Goal
- Validate `prepared-requirement` type input documents before full analysis.
- Detect empty areas, contradictions, and undefined terms in the document in advance to raise inception quality.

## Background

In hands-on workshops, feeding a large amount of planning artifacts in at once without review resulted in:
- The AI failing to detect contradictions within the document and generating different answers at each step
- Policy holes propagating through the entire inception, so the same question repeated
- Humans also not reading the document, lowering artifact trust

This step blocks the above problems before entering STEP 2.

## Execution condition
- Run when the request classification is `prepared-requirement`.
- `raw-request` fills gaps in STEP 1-A Discovery, so it skips this step.

## Validation items

### 1. Completeness check
Confirm the presence of the following areas in the input document:

| Area | What to check |
|------|----------|
| Goal/background | Is the service purpose and target user specified |
| Feature list | Are the features to implement enumerated |
| Policy/rules | Are business policies (payment, refund, authorization, etc.) defined |
| Exception handling | Are failure/cancellation/expiration scenarios mentioned |
| External integration | Are the external API/system list and constraints specified |
| Data model | Are the main entities and relationships defined |

Count the number of empty areas.

### 2. Contradiction detection
- Check whether there are conflicting descriptions of the same concept within the document.
- Example: document A says "only the admin can delete" while document B states "the user deletes directly".

### 3. Undefined term detection
- Identify domain terms used without definition in the document.
- Detect cases where different terms are used interchangeably for the same concept.

### 4. Risk tag check
- If there is a `> ⚠️ RISK:` tag, collect it and pass it to the question priority (P0) judgment.
- If there is an external integration but no risk tag, warn.

## Output

Present the validation result to the user as a report. Do not create a separate file.

```markdown
## Input document validation result

### Completeness
- Empty areas: {N}
- Missing items: {list}

### Contradictions
- {list of contradiction items, "none found" if none}

### Undefined terms
- {list of terms, "none found" if none}

### Risk tags
- {collected risks, "none" if none}
- Untagged risks among external integrations: {list, "none" if none}

### Estimated number of BLOCK questions: about {N}

### Recommended action
- {if 3 or more empty areas} "We recommend supplementing the document before proceeding with inception."
- {if 1 or more contradictions} "If you proceed without resolving contradictions, per-step answer inconsistencies may occur."
- {if 2 or fewer empty areas and no contradictions} "Validation passed. Proceeding to STEP 2. However, STEP 4 question generation and GATE-2 are performed separately."
```

## Follow-up step guidance (mandatory)

Regardless of whether validation passes, the following flow is all performed:

- STEP 2 (request capture) → STEP 3 (analysis) → STEP 4 (question generation) → STEP 5 (requirements authoring) → GATE-2 (requirements review)

Rules:
- Even if the input document looks sufficient, do not skip STEP 4 question generation.
- Empty areas (missing items) identified in STEP 1-C are converted into BLOCK questions in STEP 4.
- GATE-2 is not skipped even for `prepared-requirement`. Do not enter STEP 6 (UOW) without user approval.
- The AI does not interpret passing validation as "decisions complete". Validation is only a shape check of the input document, not agreement on policy/design decisions.

## User choices
After presenting the validation result, let the user choose from the following:
1. **Supplement the document and re-validate** — the user supplements the empty areas and runs STEP 1-C again
2. **Proceed as-is** — convert the empty areas into BLOCK questions and proceed to STEP 2
3. **Narrow scope and proceed** — narrow the scope to only the validated areas and proceed

## Rules
- Do not finalize requirements in this step. Only perform validation.
- Do not force the user to supplement the document. Present choices.
- Record the validation result in `audit.md`.
