# Content Validation

Rules for validating the consistency of answers and artifacts.

## 0. Pre-Write Validation

Perform the checks below **before** creating or updating an artifact file. If any check fails, fix the item and then write it to the file.

### Trigger Timing
- Immediately before creating/updating any artifact file (all .md files under aidlc-docs/)

### Checklist

#### Structure Validation
- [ ] Do all required sections exist (based on the required headings of the relevant template)?
- [ ] Are there no empty sections (a section with only a heading and no content)?
- [ ] Are the markdown heading levels sequential (e.g., not jumping from ## to #### by skipping ###)?

#### Reference Integrity
- [ ] Do links that reference other artifacts match the actual files?
- [ ] Do internal references such as UOW IDs and question numbers point to items that actually exist?
- [ ] Is the feature-slug used consistently?

#### Diagram Validation (when a diagram is included)
- [ ] Mermaid: Verify syntax validity (unclosed brackets, invalid arrows, etc.)
- [ ] Mermaid: Is a text alternative (fallback) provided alongside?
- [ ] Mermaid: Do node IDs use only alphanumerics + underscores?
- [ ] Mermaid: Are special characters within labels escaped?
- [ ] ASCII: Are Unicode box-drawing characters avoided (see `common/diagram-standards.md`)?
- [ ] ASCII: Is every line within a box the same width?

#### Special Character Validation
- [ ] Are `|` characters within markdown tables escaped (when the content contains a pipe)?
- [ ] Are backticks correctly closed outside of code blocks?
- [ ] If there is YAML frontmatter, is it valid YAML?

### Handling Validation Failures
1. Fix the failed item.
2. For items that cannot be fixed (e.g., a missing reference target), leave a `> ⚠️ TODO: {content}` marker.
3. Record a `[PRE-WRITE-VALIDATION] {filename} — {number of items fixed} fixed` event in `audit.md`.

---

## 1. Contradiction Detection

### Trigger Timing
- Immediately before STEP 5 (Requirements Finalization) — after all question answers are complete
- Final check before entering GATE-2

### Detection Targets
- Logical contradictions between answers (e.g., Q1 answered "no refunds" but Q5 mentions a "14-day refund window")
- Scope contradictions (e.g., said "single component change" but mentions "full architecture change needed")
- Risk contradictions (e.g., said "low risk" but mentions "existing data migration needed")
- Divergence between confidence and answer content (e.g., `[Confidence: Certain]` but uses uncertain phrasing such as "maybe" or "could be")

### Handling Detected Contradictions
1. State the contradiction concretely: "The answer to Q{X} ({content}) contradicts the answer to Q{Y} ({content})."
2. Generate a question to resolve it (counted in the question budget).
3. Do not proceed to GATE-2 until the contradiction is resolved.

## 2. Mermaid Diagram Validation

When including a Mermaid diagram in an artifact (same as the diagram items in the pre-write checklist):
- Verify syntax validity (unclosed brackets, invalid arrows, etc.).
- Node IDs use only alphanumerics + underscores.
- Escape special characters within labels: `"` -> `\"`, `'` -> `\'`.
- Always provide a text alternative (fallback) alongside (see `common/diagram-standards.md`).
- If it contains 5 or more nodes, a text alternative is mandatory.

## 3. ASCII Diagram Validation

- Do not use Unicode box-drawing characters (see `common/diagram-standards.md`).
- Allowed characters: `+` `-` `|` `^` `v` `<` `>` and alphanumeric/Korean text, whitespace.
- Every line within a box maintains the same width.
- Verify that indentation and alignment are not broken.
