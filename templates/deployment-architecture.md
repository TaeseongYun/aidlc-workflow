<!-- workflow-step: STEP-6.7 | gate: GATE-4 | producer: ctx-aidlc-run | condition: infrastructure change required -->
# Deployment Architecture

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/deployment-architecture.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/infrastructure-design.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this together when infrastructure-design.md has been written.
- It may be omitted for simple infrastructure changes (config value edits, etc.).

---

## 1. Deployment Topology

Describe the overall deployment structure. Include diagrams following `diagram-standards.md`.

### Configuration per Environment

| Environment | Configuration | Notes |
|------|------|------|
| dev | | |
| staging | | |
| production | | |

## 2. Component-to-Infrastructure Mapping

| Component | Deployment Target | Runtime | Scaling Policy |
|---------|---------|--------|-----------|
| | | | |

## 3. External Integration Paths

| Integration Target | Protocol | Auth Method | Network Path |
|---------|---------|---------|-----------|
| | | | |

## 4. Monitoring & Alerting

- Monitoring tools: {CloudWatch / Datadog / Grafana / other}
- Key metrics: {response time, error rate, throughput, etc.}
- Alert configuration: {thresholds and alert channels}

## 5. Disaster Recovery

- Recovery Time Objective (RTO):
- Recovery Point Objective (RPO):
- Backup strategy:
- Failover approach:

If not applicable, mark as "Not applicable".
