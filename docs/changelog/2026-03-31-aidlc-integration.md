# Change: AI-DLC Artifact Integration and Real-time audit/state Updates

## Change Date
2026-03-31

## Background

A comparative analysis against the AWS AI-DLC (aidlc-workflows) project identified the following gaps:
- Absence of a user-perspective (User Stories) artifact → cannot verify "who this is for"
- The system structure (Application Design) artifact was lumped into a single technical-design.md, making review difficult
- Absence of infrastructure/deployment/operations artifacts → a gap after Construction
- No support for a security checklist
- audit.md/aidlc-state.md updated only when a Gate passed → process records were missing

The integration aimed to raise coverage from 60% (15) to 80% (20) of the 25 AI-DLC artifacts.

---

## New Templates (10)

### INCEPTION extension (5)

| File | Purpose | Trigger Condition | Gate |
|------|------|---------|------|
| `templates/personas.md` | User persona definition | User Scenarios >= 3 or a new user type | GATE-2.5 |
| `templates/stories.md` | INVEST + Gherkin user stories | Same as above | GATE-2.5 |
| `templates/components.md` | System component identification | UOW >= 3 expected or a new component | GATE-2.7 |
| `templates/services.md` | Service layer / API boundaries | Same as above | GATE-2.7 |
| `templates/component-dependency.md` | Component-to-component dependency matrix | Same as above | GATE-2.7 |

### CONSTRUCTION extension (4)

| File | Purpose | Trigger Condition | Gate |
|------|------|---------|------|
| `templates/infrastructure-design.md` | Infrastructure resources / cost / migration | When infrastructure changes are needed | GATE-4 |
| `templates/deployment-architecture.md` | Deployment topology / monitoring / DR | Same as above | GATE-4 |
| `templates/build-instructions.md` | Build procedure / per-UOW build order | When M/L size units exist | GATE-5 |
| `templates/test-instructions.md` | Test strategy / scenarios / Quality Gate | Same as above | GATE-5 |

### Extension (1)

| File | Purpose | Trigger Condition | Gate |
|------|------|---------|------|
| `templates/security-baseline.md` | SECURITY-01~11 checklist | On user opt-in | GATE-2 |

---

## New STEPs / GATEs (8)

| STEP | Name | Condition |
|------|------|------|
| STEP 5.5 | User Stories | User Scenarios >= 3 or a new user type |
| STEP 5.7 | Application Design | UOW >= 3 expected or a new component |
| STEP 6.7 | Infrastructure Design | When infrastructure changes are needed |
| STEP 9 | Build & Test Instructions | When M/L size units exist |

| Gate | Name | Condition |
|------|------|------|
| GATE-2.5 | User Stories Review | When STEP 5.5 runs |
| GATE-2.7 | Application Design Review | When STEP 5.7 runs |
| GATE-4 | Infrastructure Design Review | When STEP 6.7 runs |
| GATE-5 | Build & Test Review | When STEP 9 runs |

---

## Readiness Score Extension

- Existing 6 areas at 100 points retained
- 2 conditional bonus areas added:
  - User story quality (up to 10 points) — scored only when GATE-2.5 triggers
  - System structure design (up to 10 points) — scored only when GATE-2.7 triggers
- Decision thresholds are converted to the 80%/60% ratios of the actual maximum score

---

## Real-time audit.md / aidlc-state.md Updates

### Before
- audit.md: recorded only when a Gate passed (up to 8 times)
- aidlc-state.md: updated only at STEP 1/6/7 (3 times)

### After
- audit.md: recorded at every STEP start/completion/skip + Gate + question answer + state change (20+ times)
- aidlc-state.md: checkbox updated at every STEP completion/skip (12+ times)

### 4 logging triggers (audit.md)
1. **STEP start/completion**: on entering/completing each STEP. The reason is recorded even on a conditional skip.
2. **GATE pass**: on approval/change request/skip.
3. **User input**: on BLOCK/ASSUME question answers and Discovery round responses.
4. **State change**: on a feature status change.

### Checkbox legend (aidlc-state.md)
- `[x]` complete
- `[-]` skipped (reason in parentheses)
- `[ ]` not started

---

## Modified Files (9)

| File | Change |
|------|---------|
| `core/core-workflow.md` | Added STEP 5.5/5.7/6.7/9, added GATE-2.5/2.7/4/5, restructured the artifacts section, added a new real-time update rules section |
| `common/stage-gate-rules.md` | GATE-2.5/2.7/4/5 detailed rules, added skip conditions, expanded audit log integration |
| `core/readiness-score.md` | 2 conditional bonus areas, ratio-converted decision criteria |
| `core/readiness-score.schema.yaml` | Added the user_stories_quality, system_design_quality areas + a conditional_scoring section |
| `templates/feature-status.md` | Expanded the Readiness Score table, expanded Gate History, expanded Related Files |
| `templates/audit.md` | Added the 4 logging trigger formats |
| `templates/aidlc-state.md` | Specified update rules, new STEP/GATE checkboxes, checkbox legend |
| `skills/ctx-aidlc-run/SKILL.md` | Expanded PRIMARY INPUTS, expanded OUTPUT CONTRACT, added new STEP/GATE + real-time audit update commands to EXECUTION FLOW |
| `docs/workflow-guide.md` | Updated the requirements analysis stage, approval stage, and greenfield artifact list |

---

## Coverage vs. AI-DLC

| Category | Before integration | After integration |
|------|--------|--------|
| AI-DLC 25-artifact correspondence | 15 (60%) | 20 (80%) |
| Not integrated (deliberately excluded) | 10 | 5 |
| Artifacts unique to team-ai-workflow | 5 | 5 (retained) |

5 not integrated: component-methods.md, story-generation-plan.md, application-design-plan.md, security-baseline.opt-in.md, operations.md — replaced by the Gate system or absorbed into existing sections.

---

## Change Statistics

| Category | Count |
|------|---|
| New files | 10 |
| Modified files | 9 |
| Deleted files | 0 |

## Compatibility

- Backward compatible: no change to the 6 existing required artifacts
- All new artifacts are conditional — no impact on the existing workflow
- Skill redeployment required: `bash scripts/install-skills.sh`
