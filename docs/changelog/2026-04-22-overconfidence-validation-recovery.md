# 2026-04-22: Overconfidence Prevention, Content Validation Enhancement, Error Recovery

## Background

A comparative analysis against awslabs/aidlc-workflows identified that team-ai-workflow's analysis/design depth is superior, but reinforcement is needed in 3 areas.

1. **AI overconfidence prevention**: the problem where AI-led steps (STEP 6, 6.5, 6.7) proceed without questions or treat uncertain judgments as if confirmed
2. **Pre-write output validation**: the problem where diagram syntax errors, broken reference integrity, etc. are only discovered after the file is created
3. **Absence of an error recovery procedure**: the problem where no recovery path is defined for session interruption, output corruption, or state inconsistency

## Changes

### 1. Overconfidence Prevention

**File**: `common/overconfidence-prevention.md` new

Defines 5 rules:
- **Duty to state uncertainty**: attach a `⚠️ UNCERTAIN` marker to judgments with no basis in CTX/code
- **Self-Verification**: perform 3 verification questions after writing outputs in STEP 6, 6.5, 6.7
- **Missing-question detection**: at STEP 3 completion, automatically check whether questions were generated against high-risk keywords
- **Readiness Score cap**: apply a cap of 80% of the maximum score for domains that have a `⚠️ UNCERTAIN` marker
- **No vague expressions**: prohibit using phrases such as "it will probably...", "of course", "can be handled simply" as confirmed statements

Integration with the existing system:
- Linked with the confidence tagging (`[confidence: estimate]`, `[confidence: AI-recommended]`) of `question-governance.md`
- Applies the cap rule to the domain scores of `readiness-score.md`
- Records an `[OVERCONFIDENCE-CHECK]` event in `audit.md`

### 2. Content Validation enhancement (pre-write output validation)

**File**: `common/content-validation.md` new section 0 + reinforcement of existing sections 2, 3

Added section 0 "Pre-Write Validation":
- **Structure validation**: presence of required sections, empty-section detection, sequential heading-level check
- **Reference integrity**: consistency of file links, UOW IDs, question numbers, feature-slug
- **Diagram validation**: Mermaid syntax/node ID/special-character escaping, ASCII allowed-character/width rules
- **Special-character validation**: table pipe escaping, backtick pairing, YAML frontmatter validity
- Records a `[PRE-WRITE-VALIDATION]` event in `audit.md` on validation failure

Reinforcement of existing sections:
- Section 2 (Mermaid): added node ID rules, label special-character escaping, mandatory text alternative for 5+ nodes
- Section 3 (ASCII): specified the allowed-character list, the equal-width rule

### 3. Error Recovery

**File**: `common/error-recovery.md` new

- **4 error severity levels**: CRITICAL / HIGH / MEDIUM / LOW classification criteria
- **Session resume procedure**: check aidlc-state.md → verify output integrity → recover inconsistency
  - State marked complete but output missing → re-run the STEP
  - Output exists but state incomplete → verify output, then update state
- **Per-STEP error handling**: Project Detection, analysis/questions, Unit Decomposition, Readiness Score
- **Output recovery**: mandatory backup, regeneration procedure, reconstruction when aidlc-state.md is corrupted
- **Reverting user requests**: dependency warnings on STEP re-run, handling of GATE change requests
- **audit.md integration**: defines the `[RECOVERY]` event logging format

### 4. core-workflow.md update

**File**: `core/core-workflow.md`

- Added section 11 "Overconfidence prevention" — references `common/overconfidence-prevention.md`
- Added section 12 "Error recovery" — references `common/error-recovery.md`
- Sequentially adjusted existing section numbers (Forbidden items → 13, Context priority → 14)

## Full list of modified files

| File | Change type |
|------|----------|
| `common/overconfidence-prevention.md` | New |
| `common/content-validation.md` | Section added + existing sections reinforced |
| `common/error-recovery.md` | New |
| `core/core-workflow.md` | Added 2 sections, adjusted numbering |
| `README.md` | Updated changelog, doc links |
| `docs/concepts.md` | Added overconfidence-prevention, error-recovery concepts |

### 5. Evaluation framework (tools/evaluator/)

**File**: `tools/evaluator/` directory new

An output auto-validation tool composed of 4 bash scripts:
- **validate-artifacts.sh**: required file presence, required sections, empty sections, UOW ID reference integrity, feature-slug consistency, diagram validation
- **validate-questions.sh**: Request Anchor, Summary, per-question required fields (classification/impact/if-unanswered/scope/priority), no AI recommendation on policy questions, BLOCK status, confidence statistics
- **validate-readiness-score.sh**: presence/sum extraction of the Score table, verdict consistency (READY/CONDITIONAL/NOT_READY), BLOCK cross-check, score summation, UNCERTAIN markers
- **validate-all.sh**: runs the above 3 sequentially and prints the aggregate result

### 6. Golden Baseline test cases

**File**: `examples/golden-baselines/` directory new

3 reference output sets by depth:
- **minimal-bugfix/**: 1 question, 1 UOW, only GATE-2/3 proceed, READY 94 points
- **standard-feature/**: 3 questions (2 BLOCK), 6 UOWs, CONDITIONAL 64 points
- **comprehensive-platform/**: 12 questions, 7 UOWs, all GATEs active, READY 111/120 points

### 7. Extension packs

**File**: `extensions/performance/`, `extensions/api-contract/` new

- **performance-baseline**: PERF-01~06 (response time, throughput, batch performance, DB queries, caching, load testing)
- **api-contract**: API-01~05 (version management, schema, error responses, backward compatibility, documentation)

**File**: `common/extension-rules.md`, `templates/aidlc-state.md` updated

## Full list of modified files (additions)

| File | Change type |
|------|----------|
| `tools/evaluator/validate-artifacts.sh` | New |
| `tools/evaluator/validate-questions.sh` | New |
| `tools/evaluator/validate-readiness-score.sh` | New |
| `tools/evaluator/validate-all.sh` | New |
| `tools/evaluator/README.md` | New |
| `examples/golden-baselines/README.md` | New |
| `examples/golden-baselines/minimal-bugfix/*` | New (4 files) |
| `examples/golden-baselines/standard-feature/*` | New (4 files) |
| `examples/golden-baselines/comprehensive-platform/*` | New (4 files) |
| `extensions/performance/performance-baseline.opt-in.md` | New |
| `extensions/performance/performance-baseline.md` | New |
| `extensions/api-contract/api-contract.opt-in.md` | New |
| `extensions/api-contract/api-contract.md` | New |
| `common/extension-rules.md` | Added Extension list |
| `templates/aidlc-state.md` | Added Extension items |

## References

| Source | Pattern borrowed |
|------|-----------|
| awslabs/aidlc-workflows `overconfidence-prevention.md` | Need for overconfidence prevention, the "when in doubt, ask" principle |
| awslabs/aidlc-workflows `error-handling.md` | Error severity classification, per-step error handling, recovery procedure structure |
| awslabs/aidlc-workflows `session-continuity.md` | State validation on session resume, output loading order |
| awslabs/aidlc-workflows `content-validation.md` | Pre-file-creation validation, Mermaid/ASCII pre-check |
| team-ai-workflow existing system | Confidence tagging, Readiness Score, own design via audit.md integration |
