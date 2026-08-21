# Performance Baseline

The complete set of rules for the 6 performance requirement items.
This file is loaded only when the user opts in.

## Application Rules

- On opt-in, every item is treated as a **blocking constraint**.
- FAIL items must be resolved within the corresponding UOW.
- The artifact is generated at `aidlc-docs/features/<feature-slug>/extensions/performance-baseline.md`.

---

## PERF-01. API Response Time Criteria

**Evaluation criteria**:
- PASS: Target response times for key APIs are specified (e.g., p95 < 200ms). The measurement method is defined.
- FAIL: No response time targets defined, no measurement method defined.
- N/A: A feature with no APIs (batch-only, etc.).

**Typical action**: Define per-API SLOs, integrate an APM tool, set up slow-query alerts.
**Brownfield consideration**: Measure the current response times of existing APIs before setting targets.

## PERF-02. Throughput Criteria

**Evaluation criteria**:
- PASS: Concurrent user count or TPS targets are specified. Capacity against peak time is confirmed.
- FAIL: No throughput targets defined, no capacity plan established.
- N/A: Single-user tool, internal admin feature.

**Typical action**: Estimate expected TPS, review connection pool/thread pool sizes, autoscaling policy.
**Brownfield consideration**: Analyze current traffic patterns, identify bottlenecks.

## PERF-03. Batch/Async Processing Performance

**Evaluation criteria**:
- PASS: The volume of data to be batch-processed and the target completion time are specified. Chunk size and parallelism are defined.
- FAIL: No processing time target defined, large-data scenarios not considered.
- N/A: A feature with no batch/async processing.

**Typical action**: Determine chunk size, parallel processing strategy, timeout settings, retry policy.
**Brownfield consideration**: Check for conflicts with existing batch schedules, distribute DB load.

## PERF-04. DB Query Optimization

**Evaluation criteria**:
- PASS: An index strategy is defined for key queries. N+1 problems are identified/resolved. Paging is applied to large lookups.
- FAIL: No index strategy defined, N+1 problems unverified, full scans present.
- N/A: A feature with no DB access.

**Typical action**: Review query execution plans, design composite indexes, use read-only replicas.
**Brownfield consideration**: Check for conflicts with existing indexes, lock impact during migration.

## PERF-05. Caching Strategy

**Evaluation criteria**:
- PASS: Data that needs caching is identified. A cache expiration/invalidation strategy is defined.
- FAIL: No caching applied to repeatedly-looked-up data, no invalidation strategy defined.
- N/A: A feature that does not need caching (one-time processing, etc.).

**Typical action**: Choose local/distributed cache, set TTL, cache warming strategy.
**Brownfield consideration**: Consistency with the existing cache layer, separating cache key namespaces.

## PERF-06. Load Test Plan

**Evaluation criteria**:
- PASS: Load test scenarios are defined (target TPS, ramp-up, duration). The test environment is specified.
- FAIL: No load test plan established, no performance verification method defined.
- N/A: An internal tool with no performance thresholds.

**Typical action**: Write k6/JMeter scenarios, base on a staging environment, measure a baseline and compare against it.
**Brownfield consideration**: Secure the existing performance baseline, include regression tests.

---

## Artifact Format

```markdown
# Performance Baseline

> **Request Anchor**: {summary of the initial request}

## Performance Checklist

| ID | Item | Status | Notes |
|----|------|------|------|
| PERF-01 | API response time criteria | PASS / FAIL / N/A | |
| PERF-02 | Throughput criteria | PASS / FAIL / N/A | |
| PERF-03 | Batch/async performance | PASS / FAIL / N/A | |
| PERF-04 | DB query optimization | PASS / FAIL / N/A | |
| PERF-05 | Caching strategy | PASS / FAIL / N/A | |
| PERF-06 | Load test plan | PASS / FAIL / N/A | |

## Findings

### PERF-{NN}. {item name}
- Status: PASS / FAIL / N/A
- Current state: {current application status}
- Target: {defined performance target}
- Action required: {required action or "none"}
- Related UOW: UOW-{N} / not applicable

## Summary
- Total items: 6
- PASS: {N}
- FAIL: {N}
- N/A: {N}
- If any item is FAIL, it must be resolved during the implementation of the corresponding UOW.
```
