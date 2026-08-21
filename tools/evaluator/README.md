# Evaluator — Artifact Validation Tool

Automatically validates the quality of aidlc-docs artifacts.

## Usage

```bash
# Full validation (recommended)
bash tools/evaluator/validate-all.sh aidlc-docs/features/<feature-slug>

# Individual validation
bash tools/evaluator/validate-artifacts.sh aidlc-docs/features/<feature-slug>
bash tools/evaluator/validate-questions.sh aidlc-docs/features/<feature-slug>
bash tools/evaluator/validate-readiness-score.sh aidlc-docs/features/<feature-slug>
```

## Validation Items

### validate-artifacts.sh — Artifact Completeness
- Required files exist (status.md, requirements.md, questions.md, unit-of-work.md)
- Required sections exist (Goal, In-Scope, Summary, etc.)
- Empty section detection
- UOW ID reference integrity (Summary ↔ body headings)
- feature-slug consistency (status.md ↔ directory name)
- Diagram validation (Mermaid text alternative, Unicode box characters)

### validate-questions.sh — Question Governance Tags
- Request Anchor exists
- Summary table exists
- Required fields per question (classification, impact, if unanswered, scope, priority)
- Verify no AI recommendation on policy questions
- BLOCK questions/unanswered status
- Confidence tag statistics

### validate-readiness-score.sh — Readiness Score
- Score table exists and total extractable
- Verdict (READY/CONDITIONAL/NOT_READY) consistency (against the score thresholds)
- BLOCK question cross-check (error if READY but BLOCK exists)
- Point sum verification
- UNCERTAIN marker cross-check

## Exit Codes

| Code | Meaning |
|------|------|
| 0 | Pass (may include warnings) |
| 1 | Fail (errors present) |
```
