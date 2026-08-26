---
name: rn-observability
description: React Native observability guard — structured logging, correlation/trace IDs, metrics, and
  crash/error reporting done right, and detect/block the anti-patterns AI ships (debug print left in prod,
  PII/secrets in logs, unstructured concatenated messages, missing correlation IDs, wrong log levels,
  swallowed errors, logging in hot loops, no metrics, missing crash reporting, non-actionable messages).
  Auto-loads when writing or reviewing logging, error handling, metrics, or telemetry.
when_to_use: When adding/reviewing logging, error handling, metrics, tracing, or crash reporting, or on
  requests like "why can't we debug this in prod", "is this logging safe", "observability review".
paths: **/*.ts, **/*.tsx, **/*.js, **/*.jsx
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-observability — vibe-coding observability guard

AI-generated React Native code is **observability-blind**: it leaves `console.log` calls scattered
throughout production builds, logs tokens and emails verbatim, concatenates string messages that nothing
can query, swallows exceptions in empty catch blocks, spams logs inside render loops, and ships zero
metrics or crash reporting. When that code breaks in production — and it will — **there is nothing to
see**. No structured fields to search, no trace to follow, no alert to fire.

This skill is the **review gate**: detect and block those patterns before merge, and guide the team
toward structured logging, correlation IDs, correct log levels, metric instrumentation, and wired crash
reporting. The rules here are **operational-safety rules** and must not be relaxed. Project `ctx/`
may tighten them but the observability floor is never lowered.

## Scope

- Targets: RN source (TS/JS) — logging calls, error handlers, metrics instrumentation, crash reporter
  wiring; especially AI-generated or quickly-pasted code.
- What it does: **detect anti-patterns → propose safe, observable alternatives** for each failure mode
  below.
- Delegate: PII/secrets depth → [rn-security](../rn-security/SKILL.md); log-assertion test coverage →
  [rn-testing]; where the logging seam lives in the layer graph → [rn-architecture].
- Stack: Sentry RN SDK (`@sentry/react-native`) or Firebase Crashlytics for crash/error reporting;
  a thin structured logger wrapper (not raw `console.*`); Flipper for dev-only inspection;
  `console.*` calls stripped from release builds (Babel plugin or Metro config).

## Core Guidance (Do)

1. **One logger, not console** — import a shared logger module everywhere. The module decides
   transport (Sentry breadcrumb, Flipper, void in release) per environment. Never call `console.log`
   directly in production paths.
2. **Structured key/value fields** — pass fields as an object, never concatenate strings.
   `logger.info('order.placed', { orderId, userId, amount })` — not `logger.info('order ' + id + ' placed')`.
3. **Correlation / trace ID** — generate a request/session/operation ID at the entry point and thread
   it through every log call and error report in that flow. Without it, logs from concurrent operations
   are indistinguishable.
4. **Right level** — `debug` for dev noise, `info` for normal milestones, `warn` for degraded but
   recoverable, `error` only for actual failures that require attention. Expected control flow is never
   `error`.
5. **Redact PII** — never log tokens, passwords, emails, card numbers, SSNs, full user objects, or
   Authorization headers. Log IDs and non-sensitive keys only. See [rn-security](../rn-security/SKILL.md)
   for the full PII/secrets policy.
6. **Metrics for critical ops** — every payment, auth, job queue operation, and API call should emit
   a counter or timer. Logs are for humans; metrics are for alerts.
7. **Crash/error reporting wired** — Sentry or Crashlytics initialized before the root component mounts.
   Handled errors that represent real failures are forwarded to the crash reporter with context.
8. **Actionable context** — every log and error report includes the relevant IDs, state, and enough
   context that the on-call engineer knows what broke, which entity it affected, and where to look next.

## Guard Rules — 10 Observability Failure Modes (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Debug print left in prod

- **Rule**: `console.log` / `console.warn` / `console.error` / `console.debug` are not a logging
  strategy. They output to Metro in development and to the device syslog in release, are unstructured,
  have no level enforcement, and cannot be centrally controlled. All production logging goes through
  the shared logger. Strip `console.*` from release via Babel transform
  (`babel-plugin-transform-remove-console`) or equivalent.
- **Common AI failure**: scattering `console.log('data', res)` throughout the codebase as the primary
  visibility mechanism, leaving them in because "they're harmless in prod".
- **red-flag**: `console.log` / `console.warn` / `console.debug` calls outside `__DEV__` guards or
  the logging module itself; no Babel console-removal plugin in the production build config.

### 2. PII / secrets in logs

- **Rule**: never log tokens, passwords, email addresses, phone numbers, card/SSN data, full user
  objects, Authorization headers, or raw request/response bodies. Log the ID, not the entity. Redact
  before passing to any logger or crash reporter. See [rn-security](../rn-security/SKILL.md) for
  the full secrets/PII policy.
- **Common AI failure**: `logger.info('login', { user })` where `user` contains email + hashed
  password; logging the full Axios response which includes auth tokens; forwarding the raw error
  object to Sentry when it holds a bearer token in its config.
- **red-flag**: `log(user)`, `log(response)`, `log(error.config)`, logging `Authorization` header
  content, whole payloads in breadcrumbs or crash reports.

### 3. Unstructured logging

- **Rule**: log messages are structured key/value records, not concatenated strings. A structured
  log is searchable, filterable, and parseable by any log aggregator. A concatenated string is not.
  Pass a context object as the second argument; never build a message with `+` or template literals
  that embed dynamic data inline.
- **Common AI failure**: `logger.info('User ' + userId + ' placed order ' + orderId + ' for ' + amount)`
  — looks readable in terminal, useless in Datadog/CloudWatch/Kibana.
- **red-flag**: log calls where dynamic data is embedded in the message string via `+` or `${}`
  rather than passed as a structured fields object.

### 4. Missing correlation / trace ID

- **Rule**: every non-trivial async operation (API call, background task, payment flow, auth flow)
  must carry an operation/request/trace ID from creation through every log line and error report it
  produces. Without it, concurrent flows produce an undifferentiated log soup.
- **Common AI failure**: logs at each step of a multi-step flow with no shared identifier — impossible
  to reconstruct what happened for a specific user/request.
- **red-flag**: a multi-step operation (multiple log lines, multiple async calls) with no shared
  correlation ID field threaded through; no `traceId` / `requestId` / `sessionId` in structured fields.

### 5. Wrong log level

- **Rule**: `debug` — verbose dev detail; `info` — normal business milestone; `warn` — degraded but
  recovered; `error` — actual failure requiring attention. Expected outcomes (empty results, 404s,
  user validation failures) are `info` or `warn`, never `error`. Failures that wake someone up are
  `error`. Noise at `error` level means real errors are buried.
- **Common AI failure**: `logger.error('No results found')` for an empty API response (expected);
  `logger.info('Payment failed')` for an actual charge failure; using `error` level for every catch
  block regardless of severity.
- **red-flag**: `error()` calls for expected/handled outcomes; `info()` or `warn()` for actual
  failures; no level variation across a codebase (everything at one level).

### 6. Swallowed error

- **Rule**: every catch block either recovers fully (in which case log a `warn` with context) or
  propagates / reports the failure. An empty catch `{}` or a catch that logs a bare string with no
  exception object is a silent failure — the bug happened, no one will ever know.
- **Common AI failure**: `catch (e) {}`, `catch { console.log('error') }`, or passing only
  `e.message` to the logger while dropping the stack trace and root cause.
- **red-flag**: `catch {}`, `catch (e) {}`, catch blocks with no log/report call, or catch blocks
  that log a plain string without passing the exception object (stack and cause lost).

### 7. Logging in hot path / loop

- **Rule**: log calls have non-trivial cost (string formatting, I/O, breadcrumb allocation). Inside
  a render function, a `FlatList` `renderItem`, a tight `for`/`while` loop, an animation frame
  callback, or a WebSocket `onmessage` handler, per-iteration logging will degrade performance and
  flood any log aggregator. Sample, batch, or move the log outside the loop.
- **Common AI failure**: `items.forEach(item => logger.debug('Processing', { item }))` inside a
  list render; `logger.info('frame', { ts })` inside `requestAnimationFrame`.
- **red-flag**: a log call as a direct child of a loop body, a `renderItem` callback, a
  `useEffect` with a high-frequency dependency, or an animation/frame tick.

### 8. No metrics (logs only)

- **Rule**: logs are for post-hoc investigation; metrics are for alerting and dashboards. Every
  critical operation — payment, authentication, API call, background job, significant user action —
  must emit at least one metric (counter, timer, or gauge) so that failure rates and latencies can
  be tracked and alerted on without manually reading logs.
- **Common AI failure**: an entire payment or auth module with detailed logs but zero metric
  instrumentation — no way to alert on a spike in failures or a latency regression.
- **red-flag**: a payment, auth, or job-dispatch code path with log calls but no
  counter/timer/metric emission; no metrics client initialized anywhere in the app.

### 9. Missing crash / error reporting

- **Rule**: Sentry (`@sentry/react-native`) or Firebase Crashlytics must be initialized before the
  root component mounts. Unhandled JS exceptions, unhandled promise rejections, and native crashes
  must be captured automatically. Significant handled errors (payment failure, auth failure,
  data-corruption detection) must be forwarded explicitly with `Sentry.captureException` or
  equivalent — not just logged locally.
- **Common AI failure**: a full RN app with no crash reporter initialized; handled errors that reach
  a catch block are `console.error`'d and forgotten — never forwarded to a reporter that can alert.
- **red-flag**: no `Sentry.init` / Crashlytics init in the app entry point; caught errors in critical
  flows that are only `console.error`'d but never forwarded to a crash/error reporter.

### 10. Non-actionable message

- **Rule**: every log and error report must contain enough context that an on-call engineer —
  who has never seen this code — can identify which entity failed, what state it was in, and
  what to do next. A bare `"error occurred"`, `"failed"`, or `"something went wrong"` with no IDs,
  no state, and no next-step guidance is useless.
- **Common AI failure**: `logger.error('Request failed')` with no URL, no status code, no user ID,
  no operation name; `Sentry.captureException(e)` with no added context at all.
- **red-flag**: log messages that are a single generic phrase with no structured fields; error
  reports forwarded to Sentry/Crashlytics with no tags, user context, or extra data attached.

## Observability Review Checklist

For RN code that AI generated or was pasted in quickly, before merge:

- [ ] No `console.log` / `console.debug` in production paths; Babel console-removal configured.
- [ ] No PII, tokens, passwords, or full objects in log/error-reporter calls.
- [ ] All log calls use structured key/value fields — no string concatenation of dynamic data.
- [ ] Multi-step flows carry a correlation/trace ID through every log line and error report.
- [ ] Log levels match actual severity; `error` reserved for real failures only.
- [ ] No empty catch blocks; every catch logs or reports the exception object (stack preserved).
- [ ] No log calls inside tight loops, `renderItem`, or animation/frame callbacks.
- [ ] Critical operations (payment, auth, job) emit at least one counter or timer metric.
- [ ] Sentry or Crashlytics initialized at app entry; handled failures forwarded, not just logged.
- [ ] Every log/error message includes relevant IDs, state, and actionable context.

## Halt Conditions

Halt and output the halt notice (per [skill-protocol.md](../../../../skills/_shared/skill-protocol.md)) if:

- The input contains no logging, error-handling, metrics, or telemetry code to review.
- The request is to **lower** any guard rule (e.g., "it's fine to log the full user object here").

**Output on halt**:

```
## Observability Review Halted

Halt reason:
- (specific reason)

Items requiring confirmation:
1. ...
```

Do NOT propose alternatives or explain how to fix the halt condition. Output only the halt reason.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (bad vs good code samples): [reference.md](./reference.md)
- Adjacent security guard (PII/secrets depth): [rn-security](../rn-security/SKILL.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md)
- Sentry React Native: https://docs.sentry.io/platforms/react-native/
- Firebase Crashlytics RN: https://rnfirebase.io/crashlytics/usage
- React Native performance: https://reactnative.dev/docs/performance
- OWASP Top 10 A09 — Security Logging and Monitoring Failures: https://owasp.org/Top10/A09_2021-Security_Logging_and_Monitoring_Failures/
