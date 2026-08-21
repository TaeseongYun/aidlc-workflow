<!-- workflow-step: STEP-9 | gate: GATE-5 | producer: ctx-aidlc-run | condition: M/L units exist -->
# Test Instructions

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/test-instructions.md`.

Prerequisite artifacts:
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/technical-design.md`
- `aidlc-docs/features/<feature-slug>/build-instructions.md`

Related state file:
- `aidlc-docs/features/<feature-slug>/status.md`

## Authoring Conditions

- Write this together when build-instructions.md has been written.
- This document makes the Testing Approach section of technical-design.md concrete.

---

## 1. Test Strategy Overview

- Test framework: {JUnit / pytest / Jest / other}
- Coverage target: {line coverage % or "follows project standard"}
- Test strategy: {follows the test-strategy in ctx/project-profile.ctx.md: TDD / Test-after}

## 2. Unit Tests

| Target UOW | Test Subject | Test Scenario | Expected Result |
|---------|-----------|-------------|---------|
| UOW-{N} | | | |
| UOW-{M} | | | |

## 3. Integration Tests

| Test Scenario | Related UOW | Precondition | Execution Order | Expected Result |
|--------------|---------|---------|---------|---------|
| | | | | |

## 4. Edge Case / Exception Tests

| Scenario | Input Condition | Expected Behavior | Related Requirement |
|---------|---------|---------|-----------|
| | | | |

## 5. Performance Tests

If not applicable, mark as "Not applicable".

- Target: {API endpoint / batch processing / other}
- Goal: {response time, throughput}
- Tool: {k6 / JMeter / other}

## 6. Test Execution

```bash
# Run unit tests
{command}

# Run integration tests
{command}

# Run all tests
{command}
```

## 7. Quality Gate

- Test pass criteria: {all pass / coverage N% or above}
- Action on failure: {halt build / decide after review}

## 8. Runtime Verification

After the build and tests pass, verify that the service actually runs.
When M/L scale units are included, the routine below must be completed to pass GATE-5.
If the entire scope is S scale or there is no server startup (as in batch/CLI), mark as "Not applicable".

### Startup Command

```bash
{server/process run command}
```

### Health Check

```bash
{health check command — e.g. curl -s http://localhost:{port}/health}
```

### Representative Use Case Verification

| # | Description | Run Command | Expected Response |
|---|------|---------|---------|
| 1 | {key success case} | `{curl or CLI command}` | {summary of expected result} |
| 2 | {key blocking/exception case} | `{command}` | {expected error response} |

### Execution Log Check

```bash
{log check command}
```

### Environment Constraints (if applicable)

Record any execution environment constraints such as sandbox, port binding, or network.
If none, mark as "none".
