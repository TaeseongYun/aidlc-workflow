# 2026-04-10: Question Governance, Adaptive Depth, Extension System

## Background

Updated team-ai-workflow by referencing the BMAD-METHOD and aidlc-workflows projects.
Directly solves the 3 major problems found in hands-on workshop experience (question focus drift, absence of a decision-maker, accumulation of knowledge-deficient answers).

## Philosophy shift

```
Before: "AI does not decide policy. If it doesn't know, stop and ask."
After:  "AI does not decide policy, but it actively proposes domain knowledge.
         The depth and scope of questions match the complexity of the work,
         and every question states its relationship to the original request."
```

## Changes

### 1. Question Governance (new)
- `common/question-governance.md` — question scope control, type classification, confidence tracking, question budget
- Focus Anchor: pin the original-request anchor in every question file
- Question types: policy (human required) / domain (AI may recommend) / scope (scope judgment)
- AI-RECOMMEND: for domain-type questions, AI presents a grounded recommendation
- Confidence Tagging: mark confidence in the answer (certain/estimated/AI-recommended/undecided)
- Question Budget: per-round question cap by depth

### 2. Adaptive Depth (new)
- `common/depth-levels.md` — 3 depth levels (minimal/standard/comprehensive)
- Determine depth at STEP 1-B, then apply it to all subsequent stages
- Differentiate question budget, template detail, and gate-message depth by depth level

### 3. Extension / Opt-In System (new)
- `extensions/` directory + `common/extension-rules.md`
- `*.opt-in.md` lightweight prompt → load the full ruleset only on opt-in
- Migrated and elaborated security-baseline as the first extension (SECURITY-01~11 evaluation criteria)

### 4. Reverse Engineering strengthening
- `core/reverse-engineering.md` — systematic brownfield analysis as STEP 1.5
- `templates/reverse-engineering/` — business-overview, architecture-overview, component-inventory

### 5. Skill Validation Framework (new)
- `tools/skill-validator.md` — 10 validation rules (6 automatic + 4 inferential)
- `tools/validate-skills.sh` — automatic validation script

### 6. Content Validation (new)
- `common/content-validation.md` — cross-answer contradiction detection, Mermaid/ASCII validation

## Existing files modified

- `core/core-workflow.md` — added STEP 1-B (depth), STEP 1.5 (RE), question-governance/content-validation references
- `common/question-rules.md` — added AI-RECOMMEND, DEFER-TO-FEATURE, confidence field
- `common/stage-gate-rules.md` — added Progress Line
- `templates/aidlc-state.md` — added Depth Level, Confidence Summary, Extension Configuration, STEP 1-B/1.5
- `templates/requirement-verification-questions.md` — Request Anchor, Scope Tag, AI recommendation, confidence format
- `templates/security-baseline.md` — changed to a migration notice to extensions/

## Reference sources

| Source | Pattern borrowed |
|------|-----------|
| BMAD-METHOD | AI-facilitator role, Skill Validation |
| aidlc-workflows | Adaptive Depth, Extension Opt-In, Contradiction Detection |
| Workshop experience | Question Governance (a new pattern absent from all 3 projects) |
