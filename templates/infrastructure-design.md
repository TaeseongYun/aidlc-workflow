<!-- workflow-step: STEP-6.7 | gate: GATE-4 | producer: ctx-aidlc-run | condition: infrastructure change required -->
# Infrastructure Design

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/infrastructure-design.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/technical-design.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this when new infrastructure resource creation, existing infrastructure configuration change, or deployment topology change is required.
- It may be omitted when only deploying code to existing infrastructure.
- When omitted, record in status.md: "Infrastructure design omitted — no existing infrastructure change".

---

## 1. Infrastructure Overview

Summary of the infrastructure changes needed for this feature. Describe in 2~5 sentences.

- Change type: new resource / existing resource change / configuration change
- Target environments: dev / staging / production
- IaC tool: Terraform / CDK / CloudFormation / manual / other

## 2. Resource Inventory

### New Resources

| Resource | Service | Purpose | Expected Spec | Target UOW |
|--------|--------|------|---------|---------|
| | | | | |

### Changed Resources

| Resource | Current State | Change Content | Impact Scope | Target UOW |
|--------|---------|---------|---------|---------|
| | | | | |

## 3. Network & Security

- VPC/Subnet change: yes / no
- Security group change: {change content or "none"}
- IAM role/policy change: {change content or "none"}
- Certificate/encryption: {change content or "none"}

## 4. CI/CD Pipeline

- Build pipeline change: {change content or "unchanged"}
- Deployment strategy: Rolling / Blue-Green / Canary / unchanged
- Deployment order per environment: {dev -> staging -> production, etc.}

## 5. Cost Estimate

| Resource | Monthly Estimated Cost | Basis |
|--------|-----------|---------|
| | | |
| **Total** | | |

Costs are rough estimates; actual costs vary with usage.

## 6. Migration Plan

Describe when DB migration, data transfer, or service cutover is required.
If none, mark as "Not applicable".

- Migration strategy:
- Rollback plan:
- Expected downtime:
