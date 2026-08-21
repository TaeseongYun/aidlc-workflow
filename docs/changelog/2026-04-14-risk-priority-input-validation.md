# 2026-04-14: Risk-Based Priority, Input Validation, AI-Driven Unit Decomposition, Session Separation

## Background

After analyzing the retrospectives from 5 days of the AIDLC workshop, we identified and reflected 4 problems that occurred in practice and are solvable at the methodology level.

Core problems derived from the retrospective:
1. AI concentrates questions on low-risk details (batch size) and overlooks high-risk areas (external APIs)
2. Humans forcibly assign units, so heterogeneous features get bundled into a single unit
3. Policy holes in the input document (prepared_doc) propagate across the entire inception
4. Step-by-step answer inconsistency occurs due to LLM context limits

## Changes

### 1. Risk-Based Priority (question priority system)

**File**: `common/question-governance.md` section 4, new

- Assign a `P0-CRITICAL` / `P1-IMPORTANT` / `P2-DEFERRABLE` priority to every question
- P0: external system integration, security boundaries, data integrity — must have human confirmation
- P1: business policy, exception handling, data model — standard question flow
- P2: batch size, log level, retry count — AI decides by default, only notifies humans
- Risk-tag (`⚠️ RISK:`) input mechanism lets humans pre-mark high-risk areas
- P2 questions are not counted in the question budget
- Changed the importance sort order to be based on P0/P1/P2
- Added 3 prohibitions (no demoting P0→P2, no presenting P2→BLOCK, no classifying schema/auth/API contracts as P2)

**File**: `templates/requirement-verification-questions.md`

- Added a `Priority` column to the Summary table
- Added a `Priority` field to the question format
- Added a new "AI auto-decision (P2)" section

### 2. Input Validation (pre-document validation)

**Files**: `core/input-validation.md`, new; `core/core-workflow.md` STEP 1-C, added

- On `prepared-requirement` input, perform document validation before entering STEP 2
- Validation items: completeness check (6 areas), contradiction detection, undefined-term detection, risk-tag collection
- After validation, present the user 3 options (supplement the document / proceed as-is / reduce scope)
- Pre-warn the expected number of BLOCK questions

**File**: `templates/aidlc-state.md`

- Added an `Input Validation Result` field
- Added a STEP 1-C checkbox

### 3. AI-Driven Unit Decomposition

**File**: `core/units-generation.md`, fully strengthened

- New "Decomposition owner" section: AI proposes first → human approves/adjusts
- States that having humans directly assign units is discouraged
- 3 cohesion-verification rules:
  - Single-domain principle: if a unit contains 2 or more independent domains, review for splitting
  - Question-count-based size check: 3 or fewer is appropriate, 8 or more must be split
  - External-integration separation: an external API is a separate unit

### 4. Session-separation guide (progressive context)

**File**: `docs/workflow-guide.md`, new section

- Split the workflow into 3 phases: Phase A (Discovery) / B (Definition) / C (Design)
- Each Phase references only the previous Phase's deliverables — it does not reference conversation content
- Strongly recommend session separation at comprehensive depth
- Rule to read aidlc-state.md first on session resume

**File**: `templates/aidlc-state.md`

- Added a `Current Phase` field (A/B/C)

### 5. Skill reflection

**File**: `skills/ctx-aidlc-run/SKILL.md`

- Added `core/input-validation.md` to PRIMARY INPUTS
- Added the entire STEP 1-C execution flow (condition check, validation, risk-tag collection, user options)
- Added the entire Risk-Based Priority rule to STEP 4 (P0/P1/P2 classification, risk-tag promotion, P2 auto-decision)
- Added AI-driven decomposition + cohesion-verification rules to STEP 6

**File**: `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

- Added a STEP 1-C reference to the Mission
- Added `input-validation.md` to the Required Reading Order
- Added the entire P0/P1/P2 rule to the Question Rules

## Full list of modified files

| File | Change type |
|------|------------|
| `common/question-governance.md` | Added section + adjusted existing section numbers |
| `core/core-workflow.md` | Added STEP 1-C line |
| `core/input-validation.md` | New |
| `core/units-generation.md` | Fully strengthened |
| `docs/workflow-guide.md` | Added section |
| `templates/aidlc-state.md` | Added field/checkbox |
| `templates/requirement-verification-questions.md` | Added column/field/section |
| `skills/ctx-aidlc-run/SKILL.md` | Added input list, execution flow, rules |
| `skills/ctx-aidlc-run/CLAUDE_COMMAND.md` | Added mission, reading list, question rules |
| `README.md` | Updated workflow flow, documentation links, changelog |

## Reference sources

| Source | Pattern borrowed |
|------|-----------|
| AIDLC workshop retrospective | Question-priority problem, forced-unit-assignment problem, undocumented-review problem, context collapse |
| BMAD-METHOD | Per-phase document-based context handoff (basis for session separation) |
| aidlc-workflows | Need for input validation (integrity issue when injecting prepared_doc) |
