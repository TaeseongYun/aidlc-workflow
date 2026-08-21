# 2026-04-14: Token Diet — Compressing Duplicate Prose

## Background

Of the project's 8,700 total lines, the same rule was described repeatedly across multiple files, consuming unnecessary tokens. Without removing any process or rule itself, we apply the principle of **"define in one place + reference everywhere else"** to improve token efficiency.

## Core principles

- **Repeat the existence of a rule, but define its content in only one place.**
- Since each skill must retain the core instructions in context when run independently, keep the "follow this rule" mentions.
- For detailed definitions (the meaning of P0/P1/P2, the stop-output format, etc.), reference the original document.

## Changes

### 1. ctx-aidlc-run/SKILL.md — consolidate STEP boilerplate (-90 lines)

- **STEP LIFECYCLE common pattern** declared once at the top: rules for updating audit.md and aidlc-state.md on start/skip/completion
- Removed the `Append [STEP-X]... to audit.md`, `Update aidlc-state.md` boilerplate from individual STEPs
- Compressed the STEP 4 question-governance re-description from 25 lines to 7 lines of core rules (details reference `question-governance.md`)
- Unified conditional STEPs into the "Condition: X. Otherwise skip." pattern
- Unified GATE messages into a single line: "Use the `stage-gate-rules.md` format. Do not proceed before approval."

### 2. stage-gate-rules.md — consolidate gate details (-73 lines)

- Before: summary table + separate per-gate sections for trigger condition / review items / after-pass
- Change: consolidate trigger condition / after-pass / skip into the table, leaving **only review items** in the individual sections
- Resolved the problem where trigger condition / after-pass were double-defined in both the table and the individual sections

### 3. question-governance.md — remove format duplication (-21 lines)

- Section 6 "Question format consolidation": replaced with a reference the re-description of the question format that duplicated `question-rules.md`
- Kept the per-type field-usage table, compressed into a "no-answer response limits" table

### 4. 4 skills — remove stop-output-format duplication (-14 lines each)

Targets: ctx-reviewer, ctx-refiner, ctx-domain-exec, ctx-architect-judge

- Before: each skill re-described the stop conditions + stop-output format in full
- Change: keep only the stop-condition list, reference `skills/_shared/skill-protocol.md` for the output format
- ctx-updater and ctx-commit-planner have a unique stop-output format, so they were not changed

## Full list of modified files

| File | Change type | Line count change |
|------|----------|-----------|
| `skills/ctx-aidlc-run/SKILL.md` | Boilerplate consolidation, reference-izing | 556 → 466 (-90) |
| `common/stage-gate-rules.md` | Gate-detail consolidation | 222 → 149 (-73) |
| `common/question-governance.md` | Format-duplication removal | 257 → 236 (-21) |
| `skills/ctx-reviewer/SKILL.md` | Stop-output reference-izing | 183 → 169 (-14) |
| `skills/ctx-refiner/SKILL.md` | Stop-output reference-izing | 298 → 285 (-13) |
| `skills/ctx-domain-exec/SKILL.md` | Stop-output reference-izing | 205 → 191 (-14) |
| `skills/ctx-architect-judge/SKILL.md` | Stop-output reference-izing | 165 → 151 (-14) |

**Total change: 86 lines inserted, 318 lines deleted = net -232 lines**

## What was not changed

- Process flow (STEP order, GATE trigger conditions, skip conditions)
- Rule content (question governance, guardrails, input validation)
- Output format (each skill's output structure)
- ctx-run/SKILL.md, ctx-updater/SKILL.md, ctx-commit-planner/SKILL.md (unique structure, not a compression target)
- core/, templates/, docs/ (already efficient)
