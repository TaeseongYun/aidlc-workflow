---
name: ios-observability
description: iOS observability guard — structured logging, correlation/trace IDs, metrics, and
  crash/error reporting done right, and detect/block the anti-patterns AI ships (debug print left
  in prod, PII/secrets in logs, unstructured concatenated messages, missing correlation IDs, wrong
  log levels, swallowed errors, logging in hot loops, no metrics, missing crash reporting,
  non-actionable messages). Auto-loads when writing or reviewing logging, error handling, metrics,
  or telemetry in Swift/iOS code.
when_to_use: When adding/reviewing logging, error handling, metrics, tracing, or crash reporting,
  or on requests like "why can't we debug this in prod", "is this logging safe", "observability
  review", or when touching os.Logger / os_log / Crashlytics / Sentry / MetricKit code.
paths: "**/*.swift"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-observability — vibe-coding observability guard

AI-generated iOS code is **observability-blind**: it leaves `print()` / `NSLog()` debugging in
production, logs PII and device tokens with `%{public}` privacy annotations, emits
string-concatenated messages nothing can query, swallows errors in empty `catch {}` blocks, floods
hot paths with per-frame logs, and ships with no MetricKit or crash reporter wired — so when it
breaks in production, there is nothing to see. This skill is the **review gate**: detect and block
those patterns, and show the unified-logging / MetricKit / Crashlytics way. The rules here are
**operational-safety rules** and must not be relaxed. Project `ctx/` may tighten them; the floor
is never lowered.

## Scope

- Targets: Swift source — especially AI-generated or quickly-pasted logging, error-handling, and
  telemetry code.
- What it does: **detect anti-patterns → propose safe, structured alternatives** for each failure
  mode below. Code examples in [reference.md](./reference.md).
- Delegate:
  - PII classification depth and Keychain storage → [ios-security](../ios-security/SKILL.md)
  - Log-assertion test patterns → [ios-testing](../ios-testing/SKILL.md)
  - Where the logging seam lives in the module graph → [ios-architecture](../ios-architecture/SKILL.md)
- Stack: `os.Logger` / `os_log` (unified logging) with privacy annotations; Firebase Crashlytics
  or Sentry for crash/error reporting; MetricKit for metrics. Never `print`, never `NSLog` in
  production code.

## Core guidance (Do)

- **One logger, not `print`**: declare `static let log = Logger(subsystem:category:)` at the
  type level. Re-use it; do not create a `Logger` per call site.
- **Privacy annotations are mandatory**: every `os_log`/`Logger` interpolation must carry an
  explicit privacy level. User-controlled or PII-adjacent data → `.private` or `.sensitive`.
  Only non-sensitive, non-enumerable identifiers → `.public`. When in doubt → `.private`.
- **Structured messages**: use labelled fields (`userID=\(id) action=\(action)`), not concatenated
  sentences. Structured fields survive log-ingestion pipelines; string concatenation does not.
- **Right level per severity**:
  - `.debug` / `.trace` — local development noise, stripped in release builds by the OS
  - `.info` — routine lifecycle events
  - `.notice` — notable but expected (first launch, migration complete)
  - `.warning` — recoverable anomaly
  - `.error` — unexpected, actionable failure
  - `.critical` / `.fault` — system-level, requires immediate attention
- **Correlation ID on every significant operation**: propagate a `requestID` / `traceID` into
  every log line and into crash-reporter breadcrumbs so a request's full trace is reconstructable.
- **Redact PII before it reaches a log line**: strip or truncate tokens, emails, card numbers,
  auth headers. Mark remaining sensitive fields `.private`.
- **Metrics for critical operations**: every payment, auth, job dispatch, and background task must
  emit at least one `MXMetricPayload` signal or a Crashlytics custom key/event so failures are
  alertable without digging through logs.
- **Crash reporter wired and tested**: `FirebaseCrashlytics.crashlytics()` (or Sentry's
  `SentrySDK.start`) initialised before the first view appears; handled errors forwarded with
  `recordError(_:)` / `SentrySDK.capture(error:)`.
- **No logging in hot paths**: zero log calls inside animation closures, `drawRect`, per-frame
  callbacks, or tight loops. Sample or aggregate, then log once outside.
- **Actionable messages**: every `.error` / `.fault` log must name the entity (ID, URL, model
  type), the state that failed, and enough context to reproduce.

## Guard rules (Mode B)

Each item: **rule → common AI failure → red-flag**. Code samples in [reference.md](./reference.md).

### 1. No debug print in production

- **Rule**: never use `print()`, `NSLog()`, `debugPrint()`, or `Swift.print` in production code.
  All logging goes through `os.Logger` / `os_log`.
- **Common AI failure**: scaffolds a feature with `print("did fetch \(items.count) items")` and
  never replaces it with a real logger before shipping.
- **red-flag**: any `print(` / `NSLog(` / `debugPrint(` call outside the logging layer or a
  `#if DEBUG` guard.

### 2. No PII or secrets in logs

- **Rule**: tokens, passwords, emails, phone numbers, card/SSN data, full auth headers, and raw
  request/response bodies must **never** appear in log output. Mark sensitive fields `.private` in
  `os_log`; redact before reaching a log call.
- **Common AI failure**: `log.info("user=\(user)")` serialises the entire `User` model
  (including email and token) as `.public`; or logs the full `Authorization` header for debugging.
- **red-flag**: `log(user)` / `log("\(response)")` / `"\(token, privacy: .public)"` /
  logging an `Authorization` or `Set-Cookie` header value.

### 3. Structured logging only

- **Rule**: log messages use labelled key=value fields, not string concatenation. Structured
  messages are indexable, filterable, and parseable by log-aggregation systems.
- **Common AI failure**: `log.info("User \(id) performed \(action) at \(Date())")` — readable
  prose but nothing a pipeline can group or alert on.
- **red-flag**: log strings built with `+` or `\()` that produce a prose sentence with no
  discrete key=value fields.

### 4. Correlation / trace ID on every significant operation

- **Rule**: every network request, background task, and user-initiated action must carry a
  `requestID` or `traceID` that appears in every log line and in crash-reporter breadcrumbs for
  that operation. Without it, multi-step failures cannot be reconstructed from production logs.
- **Common AI failure**: generates a full networking or data-sync layer with no trace ID
  threaded through — each log line stands alone, unsearchable by request.
- **red-flag**: a handler or service with multiple log calls and no shared correlation field;
  breadcrumbs with no trace/request ID.

### 5. Correct log level — no level inflation or deflation

- **Rule**: expected / handled control-flow → `.info` or `.notice`; unexpected failures →
  `.error`; system-level failures → `.fault`. Never log `.error` for an empty state or a 404;
  never log `.info` for an unrecoverable failure.
- **Common AI failure**: `log.error("no items found")` for an empty list (expected); or
  `log.info("payment failed: \(err)")` for a money-path failure (should be `.error`).
- **red-flag**: `.error` / `.fault` on expected empty/not-found paths; `.info` / `.debug` on
  auth or payment failures.

### 6. Never swallow errors

- **Rule**: every `catch` block must (a) log the error with `.error` level including the caught
  value, and (b) forward it to the crash reporter if it is unexpected. Empty `catch {}` and
  `catch { _ = error }` are forbidden.
- **Common AI failure**: `do { try riskyOp() } catch {}` — silent failure, nothing in logs or
  Crashlytics; or `catch { log.error("operation failed") }` with the error object dropped.
- **red-flag**: `catch {}`, `catch { _ = error }`, a `catch` that logs a static string with no
  interpolation of the caught `error`.

### 7. No logging in hot paths or loops

- **Rule**: zero `Logger` / `os_log` calls inside `for`/`while` loops iterating large collections,
  `CADisplayLink` / `drawRect` / animation closures, or any per-frame callback. Log the aggregate
  after the loop, or sample one iteration in N.
- **Common AI failure**: `for item in items { log.debug("processing \(item.id)") }` — floods
  the unified log, degrades performance, and obscures real signals.
- **red-flag**: a log call directly inside a loop body or a frame/draw callback.

### 8. Metrics for every critical operation

- **Rule**: payments, auth flows, background jobs, and push-notification processing must emit at
  least one metric signal (MetricKit custom event, Crashlytics custom key/value, or a Sentry
  performance transaction) in addition to log lines. Logs are not alertable; metrics are.
- **Common AI failure**: implements a complete checkout flow with log lines only — no metric
  emitted, nothing to alert on when the payment failure rate spikes.
- **red-flag**: a payment / auth / job function with log calls but zero MetricKit, Crashlytics
  custom-key, or Sentry performance calls.

### 9. Crash / error reporter wired and used

- **Rule**: a crash reporter (Firebase Crashlytics or Sentry) must be initialised before the first
  view; caught unexpected errors must be forwarded with `recordError` / `capture(error:)`.
  Handled errors that are not forwarded are invisible to on-call.
- **Common AI failure**: adds Crashlytics to the package manifest but never calls
  `FirebaseApp.configure()` / `FirebaseCrashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)`,
  or catches and logs errors without forwarding them.
- **red-flag**: no `FirebaseApp.configure()` / `SentrySDK.start` in `AppDelegate` or `@main`
  entry point; `catch` blocks that log but never call `recordError` / `SentrySDK.capture`.

### 10. Actionable, contextual messages

- **Rule**: every `.error` / `.fault` log must identify the entity (ID, type, URL), the failed
  operation, and relevant state. "error occurred" and "failed" alone are worthless in production.
- **Common AI failure**: `log.error("Failed")` or `log.error("Something went wrong")` — no ID,
  no operation name, no state — on-call cannot act without adding more logs and waiting for a
  re-occurrence.
- **red-flag**: a log call whose message body contains only a bare string with no interpolated
  context fields.

## Halt conditions

Stop and request clarification before proceeding if:

- The diff touches a logging layer but has no `os.Logger` usage at all (may indicate the wrong
  stack or a pre-existing `print`-only codebase with deeper architectural issues).
- A catch block surfaces a security-adjacent error (auth, crypto, Keychain) and the proposed fix
  would log the raw error value — escalate to [ios-security](../ios-security/SKILL.md) for
  redaction guidance first.

**Output on halt:**

```
## Observability review halted

Halt reason:
- (specific reason)

Items requiring confirmation:
1. ...
```

## Review checklist

For any Swift logging / error-handling / telemetry code, before merge:

- [ ] No `print` / `NSLog` / `debugPrint` outside a `#if DEBUG` guard.
- [ ] All `os_log` / `Logger` interpolations have explicit privacy annotations; PII/tokens → `.private`.
- [ ] Messages use labelled key=value fields, not concatenated prose.
- [ ] A `requestID` / `traceID` is propagated and appears in every log line for the operation.
- [ ] Log levels match severity; `.error` only for unexpected failures.
- [ ] Every `catch` logs the error value and forwards unexpected errors to the crash reporter.
- [ ] No log calls inside loops or frame callbacks.
- [ ] Critical operations (payment, auth, job) emit at least one metric signal.
- [ ] Crash reporter initialised at app start; caught unexpected errors forwarded.
- [ ] Every `.error` / `.fault` message names the entity, operation, and relevant state.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (bad → good code samples): [reference.md](./reference.md)
- Umbrella: [ios-architecture](../ios-architecture/SKILL.md)
- Adjacent: [ios-security](../ios-security/SKILL.md) (PII/secrets depth), [ios-testing](../ios-testing/SKILL.md) (log assertions)
- Apple — Logging: https://developer.apple.com/documentation/os/logging
- Apple — os.Logger: https://developer.apple.com/documentation/os/logger
- Apple — MetricKit: https://developer.apple.com/documentation/metrickit
- Firebase Crashlytics iOS: https://firebase.google.com/docs/crashlytics/get-started?platform=ios
- Sentry iOS SDK: https://docs.sentry.io/platforms/apple/
