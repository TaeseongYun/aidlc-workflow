# Change: Added the Technical Design stage

## Change Date
2026-03-23

## Background

In the existing workflow, there was no stage for performing technical design between **requirements analysis (ctx-aidlc-run) → implementation (ctx-run)**.

Problems this caused:
- Entering implementation while the API response shape was undecided → STOP every time at `ctx-run` DESIGN VALIDATION
- The DB schema, module structure, etc. were decided ad hoc by the implementer, or had to be specified directly by the user
- No record was kept of "why this design was chosen"

## What Changed

### Flow before the change

```
requirements analysis → unit-of-work decomposition → GATE-3 → Readiness Score → done
                                                ↓
implementation(ctx-run) → design gap found at DESIGN VALIDATION → STOP → ask the user
```

### Flow after the change

```
requirements analysis → unit-of-work decomposition → GATE-3
  → [M/L size exists] technical design(STEP 6.5) → GATE-3.5 → Readiness Score → done
  → [all S size]      Readiness Score → done (technical design skipped)

implementation(ctx-run) → check technical-design.md at DESIGN VALIDATION → already verified → proceed directly to implementation
```

---

## List of Changed Files

### New files

| File | Description |
|------|------|
| `templates/technical-design.md` | Technical design document template |

### Modified files

| File | Change |
|------|----------|
| `skills/ctx-aidlc-run/SKILL.md` | Added STEP 6.5 + GATE-3.5, made the sizing field mandatory, added the artifact list |
| `skills/ctx-run/SKILL.md` | DESIGN VALIDATION references technical-design.md first, and ROLE 1 follows the design document |
| `common/stage-gate-rules.md` | Added the GATE-3.5 definition, added sizing-field validation to GATE-3 |
| `core/core-workflow.md` | Reflected in the approval gates + artifact list |
| `common/diagram-standards.md` | Added technical-design.md to the usage points |

---

## Technical Design Template Structure

`technical-design.md` consists of 9 sections.

| Section | Content | Required |
|------|------|----------|
| 1. Design Overview | Design summary, target modules, brownfield connection points | Required |
| 2. Architecture Decisions | Record technical decisions in ADR format (context/options/decision/impact) | Required |
| 3. API Specification | Endpoints, request/response structure, error codes | When the API changes |
| 4. Data Model | Entities/fields/constraints, migration strategy | When the DB changes |
| 5. Module/Component Structure | Responsibilities per module and UOW mapping | Required |
| 6. Interaction Flow | Sequence/flow diagrams | When the flow is not self-evident |
| 7. Non-functional Design | Performance/consistency/security/operations (applicable items only) | Required |
| 8. Testing Approach | Test types per UOW and what they verify | Required |
| 9. Open Items | Undecided matters (write "none" if there are none) | Required |

### Rules for marking as not applicable
- No API change → "not applicable" in Section 3
- No DB change → "not applicable" in Section 4
- Flow is self-evident → "not applicable" in Section 6

---

## Execution Conditions

| Condition | Action |
|------|------|
| At least one M or L size in the units-of-work | Run STEP 6.5 → generate technical-design.md |
| All units-of-work are S size | Skip STEP 6.5 → record "technical design skipped — all S size" in status.md |

### Sizing criteria
Follows `core/unit-sizing.md`.

### Making the sizing field mandatory (additional change)
- Before: GATE-3 could pass even if the unit-of-work sizing field was empty
- After: GATE-3 can pass only when the sizing field (S/M/L) of every UOW is filled in
- Reason: whether STEP 6.5 runs depends on the sizing field, so empty values cannot be allowed

---

## GATE-3.5 Review Checklist

Items to check during technical design review:

- [ ] Is the ADR decision a well-grounded choice (not a guess)?
- [ ] Is the API response shape explicit and complete?
- [ ] Are the data model changes compatible with the existing schema?
- [ ] Does the module structure match the unit-of-work decomposition?
- [ ] Are there no implicit design decisions left?

---

## ctx-run Integration

Behavioral changes in `ctx-run` (the implementation stage):

| Situation | Before | After |
|------|--------|--------|
| technical-design.md exists | - | DESIGN VALIDATION passes (pre-validation complete). ROLE 1 implements following the API/Data Model/Module design. |
| technical-design.md absent (S size) | Individual validation at DESIGN VALIDATION | Same (existing approach retained) |
| Open Items unresolved | - | STOP at DESIGN VALIDATION. Outputs "DESIGN OPEN ITEMS UNRESOLVED". |

---

## Compatibility with the Existing Workflow

- **Backward compatible**: ctx-run still works the existing way even without technical-design.md
- **No change to existing artifacts**: existing document formats such as requirements.md, unit-of-work.md remain the same
- **Role separation preserved**: added as an internal STEP within ctx-aidlc-run. No separate skill is created

---

## Design Rationale

This change was designed based on a survey of industry best practices.

| Applied pattern | Source |
|------------|------|
| Architect/Editor separation | Aider Architect Mode — separating design reasoning from code writing |
| ADR (Architecture Decision Record) | Michael Nygard standard, adopted by AWS/Microsoft |
| Spec-first approach | GitHub Spec Kit — implement after the spec is confirmed |
| Technical blueprint | implementation-planning-guide — file/class-level design |
| C4 model Component level | Industry standard — up to L3 among Context/Container/Component |
| Google design document structure | Design Overview + Alternatives + Open Questions |

### Deliberately excluded items

| Item | Reason for exclusion |
|------|----------|
| Timeline/schedule | Already handled by unit-of-work.md sizing (S/M/L) |
| Alternatives (separate section) | Integrated as options within the ADR |
| Dependencies (separate section) | Already handled by unit-of-work-dependency.md |
| Rollout/deployment strategy | Outside the workflow scope (operational concern) |
| Security (separate section) | Integrated into Non-functional Design |
