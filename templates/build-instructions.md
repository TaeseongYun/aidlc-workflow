<!-- workflow-step: STEP-9 | gate: GATE-5 | producer: ctx-aidlc-run | condition: M/L units exist -->
# Build Instructions

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/build-instructions.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/technical-design.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this when there is at least one M/L scale unit.
- It may be omitted if the entire scope is S scale.
- When omitted, record in status.md: "Build/test guide omitted — entire scope is S scale".

---

## 1. Prerequisites

- Runtime environment: {language version, framework version}
- Required tools: {build tools, CLI tools}
- Environment variables:

| Variable | Purpose | Example Value |
|--------|------|--------|
| | | |

## 2. Build Steps

```bash
# 1. Install dependencies
{command}

# 2. Build
{command}

# 3. Run locally
{command}
```

## 3. Build Order by UOW

| Order | UOW | Build Command | Dependency Condition |
|------|-----|---------|---------|
| 1 | UOW-{N} | | none |
| 2 | UOW-{M} | | UOW-{N} completed |

## 4. Deployment Procedure

- Deployment target: {environment}
- Deployment command:

```bash
{command}
```

- Post-deployment verification: {health check URL, smoke test, etc.}

## 5. Rollback

- Rollback procedure:
- Rollback decision criteria: {error rate threshold, monitoring metrics}
