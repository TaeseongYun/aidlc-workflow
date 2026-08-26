---
name: flutter-observability
description: Flutter observability guard — structured logging, correlation/trace IDs, metrics, and
  crash/error reporting done right, and detect/block the anti-patterns AI ships (debug print left in prod,
  PII/secrets in logs, unstructured concatenated messages, missing correlation IDs, wrong log levels,
  swallowed errors, logging in hot loops, no metrics, missing crash reporting, non-actionable messages).
  Auto-loads when writing or reviewing logging, error handling, metrics, or telemetry.
when_to_use: When adding/reviewing logging, error handling, metrics, tracing, or crash reporting, or on
  requests like "why can't we debug this in prod", "is this logging safe", "observability review".
paths: "**/lib/**/*.dart, **/*.dart"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-observability — vibe-coding observability guard

AI-generated Flutter code is **observability-blind**: it leaves `print`/`debugPrint` in release
builds, logs tokens and PII, concatenates string messages nothing can query, swallows errors in
empty catch blocks, floods build/frame callbacks with logs, and ships zero metrics or crash
reporting — so when it breaks in production, there is nothing to see. This skill is the
**review gate**. The rules here are **operational-safety rules** and must not be relaxed. Project
`ctx/` may tighten them, but the observability floor is never lowered.

## Scope

- Targets: Dart source under `lib/`, especially logging calls, error handlers, and any telemetry
  integration — particularly AI-generated or quickly-pasted code.
- What it does: **detect anti-patterns → propose safe, structured alternatives** for each failure
  mode below.
- Delegate to adjacent skills:
  - PII/secret depth → [flutter-security](../flutter-security/SKILL.md)
  - Log assertions in tests → [flutter-testing](../flutter-testing/SKILL.md)
  - Where the logging seam lives architecturally → [flutter-architecture](../flutter-architecture/SKILL.md)
- Reality: a Flutter release build still writes to the device log buffer. Anything printed with
  `print`/`debugPrint` in release is readable via `adb logcat` or the Xcode console — **PII and
  tokens in logs are exposed**. Unstructured logs cannot be queried in any log aggregator.
  Swallowed exceptions mean silent failures in production.

## Core Guidance (Do)

- **One logger, not print.** Use `dart:developer log()` or the `logging` package (`Logger`). Never
  call `print`/`debugPrint` in production paths. Gate debug output behind `kDebugMode`.
- **Structured key/value fields.** Pass structured data as named fields or a JSON-serializable
  `error`/`stackTrace` parameter — not string-interpolated concatenation.
- **Correlation/trace ID propagation.** Attach a request or trace ID to every log message that
  belongs to a logical operation. In a DI/provider layer, pass an ID through the call chain so
  logs for one operation can be filtered together.
- **Right log level.** Use `Level.FINE`/`FINER` for verbose/debug, `Level.INFO` for normal
  milestones, `Level.WARNING` for recoverable oddities, `Level.SEVERE` for errors that need
  attention. Never use `SEVERE` for expected control-flow failures.
- **Redact PII before logging.** Log user IDs and entity IDs, not emails, passwords, tokens, or
  card numbers. See [flutter-security](../flutter-security/SKILL.md) for full PII/secret rules.
- **Metrics for critical operations.** Auth, payments, job processing, and navigation flows need
  at minimum a counter (success/failure) and a timer. Logs alone are not alertable.
- **Wire crash/error reporting.** Integrate Firebase Crashlytics or Sentry at app startup. Forward
  caught errors via `FirebaseCrashlytics.instance.recordError` / `Sentry.captureException`.
  Override `FlutterError.onError` and `PlatformDispatcher.instance.onError`.
- **Actionable context.** Every error log must answer: which entity (ID), which operation, what
  state. "Error occurred" alone is worthless in production.

## Guard Rules — 10 Observability Failure Modes (Mode B)

Each item: **rule → common AI failure → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Debug print left in prod

- **Rule**: `print()` and `debugPrint()` are development tools. Use `dart:developer log()` or
  the `logging` package in all production paths. Gate any remaining debug output behind
  `if (kDebugMode)`. Configure release builds to suppress or redirect log output.
- **Common AI failure**: leaving `print('fetched $data')` or `debugPrint('error: $e')` scattered
  throughout service and repository classes, shipping them in release unchanged.
- **red-flag**: `print(` or `debugPrint(` calls outside `kDebugMode` guards and outside a
  dedicated logging layer/wrapper.

### 2. PII / secrets in logs

- **Rule**: never log tokens, passwords, emails, card/SSN, full request/response bodies, or
  authorization headers. Log entity IDs only. Redact or omit sensitive fields explicitly. See
  [flutter-security](../flutter-security/SKILL.md) for storage and transmission rules.
- **Common AI failure**: `log('user: ${user.toJson()}')`, `log('token=$jwt')`,
  `log('response: ${response.body}')` — logging the full user object, JWT, or raw HTTP body.
- **red-flag**: `log(user`, `log(token`, `log(jwt`, logging an `Authorization` header, logging
  a full `http.Response` body or any object that contains PII fields.

### 3. Unstructured logging

- **Rule**: messages are not string-concatenated blobs. Pass structured context as the `error`
  parameter, a separate named log record, or a structured JSON string — something a log
  aggregator can index and filter.
- **Common AI failure**: `log('user ' + userId + ' action ' + action + ' failed')` with no
  structured fields; the message is a single unindexable string.
- **red-flag**: `log('...' + variable + '...')` or heavily interpolated `log('...$var...$var2...')`
  with no structured error/data object alongside.

### 4. Missing correlation / trace ID

- **Rule**: every log statement belonging to a logical operation (a network request, a background
  job, an auth flow) carries a shared trace or request ID so its logs can be filtered as a unit.
  Propagate the ID through the call chain via a DI parameter or an `InheritedWidget`/provider.
- **Common AI failure**: each log call stands alone with no shared ID; a single user action
  produces N unconnected log lines that cannot be correlated after the fact.
- **red-flag**: no `traceId`, `requestId`, `correlationId`, or equivalent field in log statements
  across any multi-step or async operation.

### 5. Wrong log level

- **Rule**: level must match severity. Verbose state dumps → `FINE`/`FINER`. Normal milestones →
  `INFO`. Recoverable oddities → `WARNING`. Real errors requiring action → `SEVERE`. Never use
  `SEVERE` for expected failures (e.g., "user not found" is `WARNING`, not `SEVERE`).
- **Common AI failure**: every log call at `INFO` or every error at `SEVERE`; expected 404/not-found
  cases logged as errors; routine debug state logged at `INFO` creating noise in production.
- **red-flag**: `logger.severe(` for expected control-flow cases (validation errors, not-found),
  `logger.info(` for what should be verbose debug output, flat level usage across an entire file.

### 6. Swallowed error

- **Rule**: every `catch` block either rethrows, logs the exception **with its stack trace**, or
  forwards to the crash reporter. An empty catch or a catch that logs only a string message (not
  the exception object and stack) is a silent failure.
- **Common AI failure**: `} catch (e) {}`, `} catch (e) { return null; }`,
  `} catch (e) { log('error'); }` — swallowing the exception entirely or logging only a string
  with no stack trace.
- **red-flag**: `catch (e) {` with an empty body, `catch (e) { return`, a `log` call in a catch
  block that does not include the exception object `e` and `stackTrace` parameter.

### 7. Logging in hot path / loop

- **Rule**: no log calls inside `build()`, frame/animation callbacks (`Ticker`, `AnimationController`
  listeners), tight `for`/`while` loops over large collections, or stream handlers that fire at
  high frequency. Flood-logging degrades performance and fills device log buffers.
- **Common AI failure**: `log('building widget')` inside `build()`, `log('frame: $value')` in an
  `AnimationController` listener, `log('item: $i')` inside a list-processing loop.
- **red-flag**: a `log(` or `logger.` call inside a `build(` method body, inside a `for`/`while`
  loop, inside a `Ticker`/animation listener, or inside a `Stream.listen` handler that fires per
  data item.

### 8. No metrics (logs only)

- **Rule**: critical operations — auth, payments, API calls, background jobs — must emit at least
  a success/failure counter and ideally a latency timer via Firebase Analytics, a custom metrics
  sink, or an OTel exporter. Logs alone cannot drive alerts or dashboards.
- **Common AI failure**: a payment or auth flow that only `log`s events but sends no structured
  event or metric; nothing is alertable if the success rate drops.
- **red-flag**: an auth, payment, checkout, or critical background-job method with only `log`
  calls and no `FirebaseAnalytics.instance.logEvent` / metric recording / OTel span.

### 9. Missing crash / error reporting

- **Rule**: integrate Firebase Crashlytics or Sentry at app startup before `runApp`. Override
  `FlutterError.onError` and `PlatformDispatcher.instance.onError` to forward all unhandled
  errors. Forward caught fatal errors via `recordError`/`captureException`.
- **Common AI failure**: no crash reporter initialized; all caught exceptions logged but never
  forwarded to a crash tracker; `FlutterError.onError` never overridden; `main()` has no
  error-zone wrapper.
- **red-flag**: `main()` with no `runZonedGuarded`/error-zone, no `FlutterError.onError` override,
  no `Crashlytics.instance.recordError` / `Sentry.captureException` anywhere in the project.

### 10. Non-actionable message

- **Rule**: every log/error message answers: which entity (include an ID), which operation, what
  happened, and what state the system is in. Messages like "error occurred", "request failed",
  or "something went wrong" add no diagnostic value in production.
- **Common AI failure**: `log('error occurred')`, `logger.severe('failed')`, `log('something
  went wrong')` — bare messages with no entity ID, no operation name, no state.
- **red-flag**: a log message that is a plain English sentence with no structured fields or IDs;
  messages like `'error'`, `'failed'`, `'null'`, `'exception'` alone.

## Observability Review Checklist

For Flutter code that AI generated or was pasted in quickly, before merge:

- [ ] No `print`/`debugPrint` in production paths; all logging via `dart:developer log()` or `logging` package.
- [ ] No tokens, passwords, emails, card/SSN, full bodies, or auth headers in any log call.
- [ ] Log messages carry structured context (IDs, fields), not concatenated strings only.
- [ ] Multi-step and async operations carry a shared trace/request ID across all log calls.
- [ ] Log levels match severity: `FINE` debug, `INFO` milestones, `WARNING` recoverable, `SEVERE` real errors.
- [ ] Every `catch` block logs the exception object + stack trace, or rethrows, or forwards to crash reporter.
- [ ] No `log`/`logger.` calls inside `build()`, animation listeners, tight loops, or high-frequency streams.
- [ ] Critical operations (auth, payment, jobs) emit a metric/event, not only log calls.
- [ ] Firebase Crashlytics or Sentry initialized in `main()`; `FlutterError.onError` overridden; error zone active.
- [ ] Every log/error message includes an entity ID, operation name, and meaningful state — no bare "error".

## Halt Conditions

Halt and report (do not proceed with code generation) if:

- A log call contains what appears to be a token, password, or PII field (email, card, SSN).
- An empty `catch` block is found that swallows an exception silently in a payment, auth, or data-loss path.
- No crash reporter is present in the project at all and the task involves error handling.

Output on halt:

```
## Observability Review — Halted

Halt reason:
- (specific issue found)

Items requiring confirmation:
1. ...
```

Do NOT propose alternatives or explain how to fix. Output only the halt reason.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (bad → good code samples): [reference.md](./reference.md)
- Umbrella: [flutter-architecture](../flutter-architecture/SKILL.md)
- PII/secret depth: [flutter-security](../flutter-security/SKILL.md)
- Log assertions in tests: [flutter-testing](../flutter-testing/SKILL.md)
- dart:developer log API: https://api.dart.dev/stable/dart-developer/log.html
- logging package (pub.dev): https://pub.dev/packages/logging
- Firebase Crashlytics for Flutter: https://firebase.google.com/docs/crashlytics/get-started?platform=flutter
- Sentry for Flutter: https://docs.sentry.io/platforms/flutter/
- Firebase Analytics for Flutter: https://firebase.google.com/docs/analytics/get-started?platform=flutter
