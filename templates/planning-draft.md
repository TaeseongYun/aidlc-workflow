<!-- workflow-step: STEP-3 | gate: GATE-1 | producer: ctx-aidlc-run | condition: raw-request only -->
# Planning Draft

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/planning-draft.md`.

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

Prerequisite documents:
- `aidlc-docs/features/<feature-slug>/request-intake.md`

Follow-on documents:
- `aidlc-docs/features/<feature-slug>/requirements.md`

---

## Planning Mode
- Request Type:
  - raw-request / prepared-requirement
- Project Mode:
  - greenfield / brownfield

---

## 1. Executive Summary

Summarize the problem, solution, and expected impact in 1~2 paragraphs.
A non-developer (planner, business owner, executive) should be able to grasp the full context by reading only this paragraph.

> {write summary}

---

## 2. Problem Statement

### Who experiences it
-

### What is the problem
-

### Why it is a problem (business impact)
-

### Evidence
- Customer feedback:
- Data/metrics:
- Internal observations:

---

## 3. Target Users & Personas

### Primary Users
- Role:
- Core tasks (Jobs-to-be-Done):
- Current workaround:

### Secondary Users
- Role:
- Core tasks:

### Operators / Admin
- Role:
- Required permissions:
- Operations scenarios:

### Stakeholders
- Decision-makers:
- Items requiring approval:

---

## 4. Strategic Context

### Business Goals
- Related OKR/KPI:
- Business impact:

### Competitive Landscape (if applicable)
- Similar services/features:
- Differentiation points:

### Why now
- Market/internal trigger:
- Risk of delay:

This section is optional. When market context is unnecessary, such as for internal tools or operational improvements, mark it as "Not applicable".

---

## 5. Solution Overview

### High-level description
-

### Core feature list
1.
2.
3.

### User flows (key scenarios)

Describe the key scenarios in text.
For complex flows, add diagrams following `diagram-standards.md`.

1. {scenario name}:
   - Start condition:
   - User action:
   - System response:
   - End state:

### Brownfield touchpoints (when an existing system exists)
- Related modules/services:
- Related tables/APIs:
- Relationship to existing flow (replace / extend / coexist):

---

## 6. Scope Draft

### In-Scope Draft
-

### Out-of-Scope Draft
- {excluded item}: {reason for exclusion}

---

## 7. Policy Draft

Write only items related to business policy. Delete non-applicable items.

- Pricing / Discount:
- Eligibility:
- Lifecycle / Expiration:
- Cancellation / Refund:
- Notification / Messaging:
- Admin / Operations:

---

## 8. Success Metrics

### Primary Metric
- Metric:
- Current baseline:
- Target value:
- Measurement period:

### Secondary Metrics
- [ ] {metric}: {target value} (measurement period: ___)

### Guardrail Metrics
Record metrics this feature must not worsen.
- [ ] {metric}: {allowed range}

### Judgment Method
- Measurement tool:
- Judgment timing:
- Judgment owner:

---

## 9. Dependencies & Risks

### Technical Dependencies
-

### External Dependencies (integrations, partners, infrastructure)
-

### Risks & Mitigations
| Risk | Impact | Likelihood | Mitigation |
|--------|------|------------|----------|
| | high/medium/low | high/medium/low | |

---

## 10. Assumptions
-

---

## 11. Open Decisions
-

---

## 12. Recommendation
- Ready for requirements drafting:
- Requires stakeholder answers before requirements:
- Suggested next action:
