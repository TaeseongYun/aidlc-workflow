# team-ai-workflow Methodology Reference Sources

team-ai-workflow is not a single methodology adopted wholesale; it is a framework that **selects only the patterns that worked in practice** from multiple sources and combines them. This document lays out what was taken from each source and what was not.

---

## 1. AWS AI-DLC (aidlc-workflows)

A framework that defines the AI-driven software development lifecycle as 25 artifacts.

### What we took

| Pattern | Location in our project | Description |
|------|----------------------|------|
| 25-artifact system | `aidlc-docs/features/` structure | Tracks requirements → design → implementation → verification at the artifact level. We cover 20 (80%) of these. |
| Adaptive Depth (depth adjustment) | `common/depth-levels.md` | Adjusts artifact detail across 3 levels (minimal/standard/comprehensive) depending on task complexity |
| Extension Opt-In | `extensions/`, `common/extension-rules.md` | An approach where the user explicitly enables optional rule packs such as the security checklist |
| Input Validation | `core/input-validation.md` | Pre-validation when a prepared-requirement is submitted (completeness, contradictions, risk tags) |
| Contradiction Detection | `common/content-validation.md` | Automatically detects logical contradictions between question answers |
| aidlc-state / audit tracking | `templates/aidlc-state.md`, `templates/audit.md` | Tracks project state and decision history in real time |

### What we did not take

| Item | Reason |
|------|------|
| AI-DLC's implementation/deployment automation | Our framework only covers requirements/design. Implementation is separated into a dedicated skill (`/ctx-run`) |
| All 25 artifacts | 5 (Monitoring, Observability, Deployment Pipeline, etc.) are excluded as operational concerns |
| Estimation system | Deliberately excluded. We use only S/M/L sizing and do not do time estimation |

---

## 2. BMAD-METHOD

A methodology where an AI agent switches between various roles (PM, Architect, Developer, etc.) to design software.

### What we took

| Pattern | Location in our project | Description |
|------|----------------------|------|
| Document-based context handoff per phase | `docs/workflow-guide.md` session separation guide | Addresses LLM context limits. Split into Phase A/B/C, referencing only the **artifacts** from the previous phase (not the conversation) |
| AI facilitator role | `common/question-governance.md` AI-RECOMMEND | A role separation where the AI proposes recommendations for domain questions but never decides business policy |
| Skill Validation | `tools/skill-validator.md` | A tool that automatically validates the quality of skill definitions |

### What we did not take

| Item | Reason |
|------|------|
| Per-role persona system | Instead of role switching, we separate into **independent skills** (architect-judge, domain-exec, reviewer, etc.) |
| Yolo Mode (fully automatic) | We enforce human approval via Stage Gates. Fully automatic mode is not supported |
| Master-prompt-based execution | We use a `core-workflow.md` + individual skill composition approach |

---

## 3. AIDLC Workshop (our own hands-on experience)

Patterns derived from a workshop retrospective applied to 3 projects over 5 days. Not an external methodology but **based on our own experience**.

### Patterns derived

| Problem found | Solution | Location |
|------------|--------|------|
| AI focused on low-risk questions (batch size), overlooked high-risk (external API) | Risk-Based Priority (P0/P1/P2) | `question-governance.md` Section 4 |
| Humans forcibly assigned units → heterogeneous features bundled together | AI-led unit decomposition + cohesion validation | `core/units-generation.md` |
| prepared_doc policy gaps propagated across the entire inception | Input Validation (STEP 1-C) | `core/input-validation.md` |
| LLM context limits → inconsistent answers across steps | Session separation per phase | `docs/workflow-guide.md` |
| Questions expanded beyond the scope of the original request | Request Anchor + Scope Drift Detection | `question-governance.md` Section 1 |
| Low-confidence answers treated as if confirmed | Confidence Tagging | `question-governance.md` Section 3 |

### Question Governance is entirely our own pattern

The 6 sections of `question-governance.md` (Focus Anchor, Question Classification, Confidence Tagging, Risk-Based Priority, Question Budget, format integration) are **new patterns discovered in the workshop** that existed in neither BMAD nor AI-DLC.

---

## 4. Industry Standards / Individual Tools

### Aider Architect Mode

| Pattern | Location in our project |
|------|----------------------|
| Architect/Editor role separation | `/ctx-architect-judge` → `/ctx-domain-exec` 2-stage execution |

Separates design reasoning (architect) from code writing (executor), forcing the AI to write only code without making design judgments.

### ADR (Architecture Decision Record)

| Pattern | Location in our project |
|------|----------------------|
| Michael Nygard's standard ADR format | `templates/technical-design.md` Section 2 |

Records technical decisions in a context/options/decision/impact format. An industry standard also adopted by AWS and Microsoft.

### GitHub Spec Kit

| Pattern | Location in our project |
|------|----------------------|
| Spec-first approach | The core philosophy of the entire workflow |

The principle of "implement after the spec is confirmed." A Readiness Score of 80% or higher is required to enter implementation.

### C4 Model

| Pattern | Location in our project |
|------|----------------------|
| Component level (L3) | `templates/components.md`, `templates/services.md` |

Covers only Context(L1) → Container(L2) → Component(L3), delegating Code(L4) to the implementation stage.

### Google Design Document

| Pattern | Location in our project |
|------|----------------------|
| Design Overview + Alternatives + Open Questions structure | The overall structure of `templates/technical-design.md` |

---

## 5. Contribution Summary by Source

```text
                         team-ai-workflow
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    AWS AI-DLC           BMAD-METHOD         AIDLC Workshop
    (structure/artifacts)(execution model)  (governance)
          │                   │                   │
  ┌───────┴───────┐    ┌─────┴─────┐    ┌────────┴────────┐
  │ 25 artifacts  │    │ Phase     │    │ Question        │
  │ Adaptive Depth│    │ separation│    │ Governance      │
  │ Extension     │    │ AI role   │    │ Risk Priority   │
  │ Input Valid.  │    │ definition│    │ Confidence Tag  │
  │ Contradiction │    │           │    │ AI-led units    │
  └───────────────┘    └───────────┘    └─────────────────┘
                              │
                   ┌──────────┼──────────┐
                   │          │          │
              Aider       ADR/C4    Google Design
              (role split)(design std)(doc structure)
```

## 6. What We Built Ourselves

Parts designed in-house without any external source:

| Pattern | Description |
|------|------|
| CTX-based execution rule system | "CTX is not a design document but a set of execution rules to prevent AI misbehavior" |
| Stage Gate approval system (8 stages) | GATE-1 ~ GATE-5 + conditional gate combinations |
| Readiness Score (quantitative evaluation) | 6 areas on a 100-point scale + bonus point system |
| Skill pipeline (`/ctx-run`) | architect → implementor → test → reviewer → updater → refiner → commit planner |
| No-Implicit-Decisions principle | If two or more valid designs exist, always stop and ask |
| Execution Boundary principle | A rule that each skill never performs actions outside its own responsibility |
| No-estimation principle | Does not do time estimation, using only S/M/L sizing |
