---
name: kmp-observability
description: KMP observability guard — structured logging with Kermit/Napier, correlation/trace IDs, metrics, and crash/error reporting done right, and detect/block the anti-patterns AI ships (println left in prod, PII/secrets in logs, unstructured concatenated messages, missing correlation IDs, wrong log severities, swallowed errors, logging in hot recomposition paths, no metrics, missing expect/actual crash reporting, non-actionable messages). Auto-loads when writing or reviewing logging, error handling, metrics, or telemetry in KMP code.
when_to_use: When adding/reviewing logging, error handling, metrics, tracing, or crash reporting in KMP code, or on requests like "why can't we debug this in prod", "is this logging safe", "observability review".
paths: "**/*.kt, **/commonMain/**/*.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-observability — vibe-coding observability guard

AI-generated KMP code is **observability-blind**: it leaves `println` in release builds, logs
tokens and PII, concatenates string messages nothing can query, swallows errors in empty catch
blocks, floods Compose recomposition paths with log calls, and ships zero metrics or crash
reporting — so when it breaks in production, there is nothing to see. This skill is the
**review gate**. The rules here are **operational-safety rules** and must not be relaxed. Project
`ctx/` may tighten them, but the observability floor is never lowered.

## Scope

- Targets: Kotlin source in `commonMain`, `androidMain`, `iosMain`, especially logging calls,
  error handlers, and any telemetry integration — particularly AI-generated or quickly-pasted code.
- What it does: **detect anti-patterns → propose safe, structured alternatives** for each failure
  mode below.
- Delegate to adjacent skills:
  - PII/secret depth → [kmp-security](../kmp-security/SKILL.md)
  - Log assertions in tests → [kmp-testing](../kmp-testing/SKILL.md)
  - Where the logging seam lives architecturally → [kmp-architecture](../kmp-architecture/SKILL.md)
- Reality: a KMP release build still writes to the device log buffer. Anything printed with
  `println` is readable via `adb logcat` or the Xcode console — **PII and tokens in logs are
  exposed**. Unstructured logs cannot be queried in any log aggregator. Swallowed exceptions
  mean silent failures in production.

## Core Guidance (Do)

- **One logger, not println.** Use **Kermit** or **Napier** — both are multiplatform. Never call
  `println` in production paths. Gate any remaining debug output with a severity level or a
  debug-only build flag.
- **Structured key/value fields.** Pass structured context as tag + message fields or a
  JSON-serializable payload — not string-interpolated concatenation that produces a single
  unindexable blob.
- **Correlation/trace ID propagation.** Attach a request or trace ID to every log message that
  belongs to a logical operation. Pass the ID through the call chain (DI parameter, or a
  coroutine `CoroutineContext` element) so logs for one operation can be filtered together.
- **Right log severity.** Kermit: `Logger.v` (verbose), `Logger.d` (debug), `Logger.i` (info),
  `Logger.w` (warn), `Logger.e` (error). Napier: `Napier.v/d/i/w/e`. Never use `e` for
  expected control-flow failures.
- **Redact PII before logging.** Log user IDs and entity IDs, not emails, passwords, tokens, or
  card numbers. See [kmp-security](../kmp-security/SKILL.md) for full PII/secret rules.
- **Metrics for critical operations.** Auth, payments, job processing, and navigation flows need
  at minimum a counter (success/failure) and a timer. Logs alone are not alertable.
- **Wire crash/error reporting via `expect`/`actual`.** Declare a `CrashReporter` interface in
  `commonMain` with an `expect` / `actual` per platform: Firebase Crashlytics on Android,
  the appropriate reporter (Sentry, Firebase iOS SDK) on iOS. Override
  `Thread.setDefaultUncaughtExceptionHandler` on Android; use `NSSetUncaughtExceptionHandler`
  or a Kotlin/Native crash handler on iOS.
- **Actionable context.** Every error log must answer: which entity (ID), which operation, what
  state. "Error occurred" alone is worthless in production.

## Guard Rules — 10 Observability Failure Modes (Mode B)

Each item: **rule → common AI failure → red-flag**. Code examples in [reference.md](./reference.md).

### 1. println / System.out left in prod

- **Rule**: `println()` and `System.out.println()` are development stubs. Use Kermit or Napier
  in all production paths. Gate any remaining debug output behind a severity level (verbose/debug
  only) or a build-time flag. Configure release log sinks to suppress below `Info`.
- **Common AI failure**: leaving `println("fetched $data")` or `println("error: $e")` scattered
  throughout service and repository classes, shipping them in release unchanged.
- **red-flag**: `println(` calls outside a debug-only guard and outside a dedicated logging
  layer/wrapper; `System.out.println(` anywhere in shared or production Kotlin code.

### 2. PII / secrets in logs

- **Rule**: never log tokens, passwords, emails, card/SSN, full request/response bodies, or
  authorization headers. Log entity IDs only. Redact or omit sensitive fields explicitly. See
  [kmp-security](../kmp-security/SKILL.md) for storage and transmission rules.
- **Common AI failure**: `Napier.d("user: ${user.toJson()}")`, `Logger.e("token=$jwt")`,
  `Kermit.v { "response: ${response.body}" }` — logging the full user object, JWT, or raw
  HTTP body.
- **red-flag**: `log(user`, `log(token`, `log(jwt`, logging a full `@Serializable` response
  object that contains PII, logging an `Authorization` header value.

### 3. Unstructured logging

- **Rule**: messages are not string-concatenated blobs. Pass structured context as a tag/message
  pair, a separate structured field, or a JSON-serializable payload — something a log aggregator
  can index and filter.
- **Common AI failure**: `Napier.d("user " + userId + " action " + action + " failed")` with no
  structured fields; the message is a single unindexable string.
- **red-flag**: `Logger.d("..." + variable + "...")` or heavily interpolated
  `Napier.i("...$var...$var2...")` with no structured tag or data object alongside.

### 4. Missing correlation / trace ID

- **Rule**: every log statement belonging to a logical operation (a network request, a background
  job, an auth flow) carries a shared trace or request ID so its logs can be filtered as a unit.
  Propagate the ID through the call chain via a DI parameter or a `CoroutineContext` element.
- **Common AI failure**: each log call stands alone with no shared ID; a single user action
  produces N unconnected log lines that cannot be correlated after the fact.
- **red-flag**: no `traceId`, `requestId`, `correlationId`, or equivalent field in log statements
  across any multi-step or async operation.

### 5. Wrong log severity

- **Rule**: severity must match the situation. Verbose state dumps → `v`. Normal milestones →
  `i`. Recoverable oddities → `w`. Real errors requiring action → `e`. Never use `e` for
  expected failures (e.g., "user not found" is `w`, not `e`).
- **Common AI failure**: every log call at `i` or every error at `e`; expected 404/not-found
  cases logged as errors; routine debug state logged at `i` creating noise in production.
- **red-flag**: `Napier.e(` / `Logger.e(` for expected control-flow cases (validation errors,
  not-found), `Napier.i(` for what should be verbose debug output, flat severity across a file.

### 6. Swallowed error

- **Rule**: every `catch` block either rethrows, logs the exception **with its stack trace**, or
  forwards to the crash reporter. An empty catch or a catch that logs only a string message (not
  the `Throwable` and its cause chain) is a silent failure.
- **Common AI failure**: `} catch (e: Exception) {}`, `} catch (e: Exception) { return null }`,
  `} catch (e: Exception) { Napier.e("error") }` — swallowing the exception entirely or logging
  only a string with no throwable.
- **red-flag**: `catch (e:` with an empty body, `catch (e:` with only `return`, a `Logger.*`
  call in a catch block that does not include the `Throwable` `e`.

### 7. Logging in hot recomposition path / loop

- **Rule**: no log calls inside `@Composable` bodies (they recompose), tight `for`/`while` loops
  over large collections, or `Flow.collect` handlers that fire at high frequency. Flood-logging
  degrades performance and fills device log buffers.
- **Common AI failure**: `Napier.d("composing ProductCard")` inside a `@Composable` function,
  `Logger.v("item: $i")` inside a list-processing loop, `Kermit.d { "state: $s" }` in a
  `StateFlow.collect` block that updates every frame.
- **red-flag**: a `Napier.*` / `Logger.*` / `Kermit.*` call inside a `@Composable` body, inside
  a `for`/`while` loop, or inside a high-frequency `Flow.collect` / `StateFlow.collect` handler.

### 8. No metrics (logs only)

- **Rule**: critical operations — auth, payments, API calls, background jobs — must emit at least
  a success/failure counter and ideally a latency timer. Wire platform metrics via `expect`/`actual`:
  Firebase Analytics on Android, the equivalent on iOS. Logs alone cannot drive alerts or dashboards.
- **Common AI failure**: a payment or auth flow that only logs events but sends no structured
  metric; nothing is alertable if the success rate drops.
- **red-flag**: an auth, payment, checkout, or critical background-job function with only `Napier.*`
  / `Logger.*` calls and no metric event emission.

### 9. Missing crash / error reporting

- **Rule**: wire crash reporting via an `expect`/`actual` `CrashReporter` declared in `commonMain`.
  The `actual` for Android integrates Firebase Crashlytics or Sentry; the iOS `actual` integrates
  the platform equivalent. Call `CrashReporter.recordException(e)` on caught fatals. Set the
  uncaught exception handler at app start.
- **Common AI failure**: no crash reporter `actual` anywhere; all caught exceptions logged but
  never forwarded to a crash tracker; the uncaught exception handler never set; `commonMain` has
  no error reporting seam.
- **red-flag**: no `expect class CrashReporter` / `expect fun recordException(` in `commonMain`,
  no `actual` implementations in `androidMain` / `iosMain`, no uncaught exception handler setup
  in the platform entry points.

### 10. Non-actionable message

- **Rule**: every log/error message answers: which entity (include an ID), which operation, what
  happened, and what state the system is in. Messages like "error occurred", "request failed",
  or "something went wrong" add no diagnostic value in production.
- **Common AI failure**: `Napier.e("error occurred")`, `Logger.w("failed")`,
  `Kermit.e { "something went wrong" }` — bare messages with no entity ID, no operation name,
  no state.
- **red-flag**: a log message that is a plain English sentence with no structured fields or IDs;
  messages like `"error"`, `"failed"`, `"null"`, `"exception"` alone.

## Observability Review Checklist

For KMP code that AI generated or was pasted in quickly, before merge:

- [ ] No `println` / `System.out` in production paths; all logging via Kermit or Napier.
- [ ] No tokens, passwords, emails, card/SSN, full bodies, or auth headers in any log call.
- [ ] Log messages carry structured context (IDs, fields, tags), not concatenated strings only.
- [ ] Multi-step and async operations carry a shared trace/request ID across all log calls.
- [ ] Log severity matches: `v/d` debug, `i` milestones, `w` recoverable, `e` real errors.
- [ ] Every `catch` block logs the `Throwable` (not just a string), or rethrows, or forwards to crash reporter.
- [ ] No `Napier.*` / `Logger.*` calls inside `@Composable` bodies, tight loops, or high-frequency collectors.
- [ ] Critical operations (auth, payment, jobs) emit a metric event, not only log calls.
- [ ] `expect`/`actual` `CrashReporter` wired in `commonMain`; `actual` implementations in `androidMain` / `iosMain`; uncaught handler set.
- [ ] Every log/error message includes an entity ID, operation name, and meaningful state — no bare "error".

## Halt Conditions

Halt and report (do not proceed with code generation) if:

- A log call contains what appears to be a token, password, or PII field (email, card, SSN).
- An empty `catch` block is found that swallows an exception silently in a payment, auth, or data-loss path.
- No crash reporter `expect`/`actual` is present in the project at all and the task involves error handling.

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
- Umbrella: [kmp-architecture](../kmp-architecture/SKILL.md)
- PII/secret depth: [kmp-security](../kmp-security/SKILL.md)
- Log assertions in tests: [kmp-testing](../kmp-testing/SKILL.md)
- Kermit (multiplatform logging): https://github.com/touchlab/Kermit
- Napier (multiplatform logging): https://github.com/AAkira/Napier
- Firebase Crashlytics for Android: https://firebase.google.com/docs/crashlytics/get-started?platform=android
- Sentry for Kotlin/KMP: https://docs.sentry.io/platforms/kotlin-multiplatform/
- Firebase Analytics for Android: https://firebase.google.com/docs/analytics/get-started?platform=android
