---
name: backend-observability
description: Backend observability guard — structured logging, correlation/trace IDs, metrics, and
  crash/error reporting done right, and detect/block the anti-patterns AI ships (debug print left
  in prod, PII/secrets in logs, unstructured concatenated messages, missing correlation IDs, wrong
  log levels, swallowed errors, logging in hot loops, no metrics, missing crash reporting,
  non-actionable messages). Auto-loads when writing or reviewing logging, error handling, metrics,
  or telemetry.
when_to_use: When adding/reviewing logging, error handling, metrics, tracing, or crash reporting,
  or on requests like "why can't we debug this in prod", "is this logging safe", "observability
  review".
paths: "**/*.java, **/*.kt, **/*.py, **/*.go, **/*.ts, **/logback*.xml, **/*.yaml"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# backend-observability — logging/metrics/error-reporting guard

AI-generated backend code is **observability-blind.** It leaves `print`/`println` debugging in
production, logs PII and tokens in plaintext, emits unstructured string-concatenated messages
nothing can query, swallows errors in empty catch blocks, floods hot loops with per-iteration
logs, and ships zero metrics or crash reporting — so when it breaks in production, there is
nothing to see. This skill is a **guard** (detect/block those patterns) plus **guidance**
(structured logging, correlation IDs, metrics, error reporting, redaction). These are
operational-safety rules; project `ctx/` may tighten them but the floor is not lowered.

## Scope

- Targets: server source (`**/*.java`, `**/*.kt`, `**/*.py`, `**/*.go`, `**/*.ts`),
  Logback config (`**/logback*.xml`), app config (`**/*.yaml`) — especially AI-generated or
  quickly pasted code.
- What it does: **detect anti-patterns → propose safe, structured alternatives** for each
  failure mode below.
- Delegate to adjacent skills:
  - PII/secret redaction depth and data classification → [backend-security-guard]
  - Log assertions and test coverage for logging paths → [backend-testing]
  - Where the logging seam lives in the service layer → [backend-architecture]
  - SLO/alerting policy on top of the metrics emitted here → [backend-reliability]

## Core guidance (Do)

**Structured logging — one logger, key/value fields:**
Use SLF4J + Logback JSON appender (JVM), `structlog` (Python), `slog`/`zap` (Go). Every log
entry must be machine-parseable (key/value pairs, not concatenated strings). Never fall back to
`System.out.println`, `print()`, or bare `fmt.Println` in production paths.

**Correlation / trace ID propagation:**
Inject a `traceId` (or use the OpenTelemetry `traceparent`) into every inbound request via
middleware/filter and put it in MDC (JVM), `structlog.contextvars` (Python), or the `context`
(Go). Every log line in that request's lifetime must carry the ID so a single request's logs can
be reconstructed in production.

**Right log levels:**
- `ERROR`: unexpected failure that requires action (alert on this).
- `WARN`: degraded but recoverable; expected transient failures that exceed a threshold.
- `INFO`: significant lifecycle events (service start, job completion, auth success). Not per-request.
- `DEBUG`: developer context, never on in production.
Expected control flow (e.g., record-not-found, validation failure) is `WARN` or `INFO`, not `ERROR`.

**Redact PII and secrets:**
Log IDs and categories, never the values. No tokens, passwords, email addresses, card numbers,
SSNs, or Authorization header values in any log line. Mask full payloads; log only typed
summaries (`{ userId, orderId, itemCount }`). For depth → [backend-security-guard].

**Metrics for critical operations:**
Any operation the business cares about (payment, auth, job, external API call) must have at
least a counter (success/failure) and a timer (latency). Use Micrometer (JVM) or the
OpenTelemetry Metrics SDK. Export to Prometheus. Logs alone are not alertable.

**Error/crash reporting:**
Wire Sentry (or equivalent) at service startup and forward all unhandled exceptions plus
explicitly caught errors that represent unexpected failures. Never silently swallow an exception
that indicates a bug or data-integrity issue.

**Actionable messages:**
Every log line must answer: which entity? which state? what happened? Include IDs, operation
names, and relevant counts. "error occurred" with no context is not a log — it is a void.

## Guard rules — 10 observability failure modes (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Debug print left in production

- **Rule**: all output goes through a named logger (`LoggerFactory.getLogger` / `structlog` /
  `slog.Default()`). Never ship `System.out.println`, `print()`, `fmt.Println`, bare `console.log`
  (outside a logging wrapper) in server code.
- **Common AI failure**: using `print(f"user={user}")` or `println("got here")` for quick
  debugging and leaving it in. AI frequently emits these instead of wiring up a real logger.
- **red-flag**: `System.out.print`, `println(`, `print(` (Python/Go outside logging), `fmt.Println`
  outside main/CLI utilities, `console.log` outside a logging wrapper.

### 2. PII / secrets in logs

- **Rule**: log only IDs and event categories. Never log tokens, passwords, emails, card numbers,
  SSNs, Authorization headers, or raw request/response bodies.
- **Common AI failure**: `log.info("user={}", user)` (logs the whole entity), logging the raw
  Authorization header for "debugging", printing the full request body on error.
- **red-flag**: `log(user)`, `log(request.body)`, `log.info("token={}", jwt)`, `log(password)`,
  `log.debug("Authorization: {}", header)`. For PII classification depth → [backend-security-guard].

### 3. Unstructured logging (string concatenation)

- **Rule**: structured key/value fields only. No string concatenation or f-string interpolation
  building the entire message. Use the logger's structured argument API or a structured context dict.
- **Common AI failure**: `log.info("User " + userId + " performed " + action + " on " + resourceId)`.
  This produces unqueryable, unsearchable log lines that break log-aggregation pipelines.
- **red-flag**: log message built with `+`/`${}` / f-string / `%s` substituted into the
  message string itself (as opposed to structured key/value parameters).

### 4. Missing correlation / trace ID

- **Rule**: every inbound request gets a `traceId` (or OTel `traceparent`) injected in a
  filter/middleware and placed in MDC (JVM) / `structlog.contextvars` (Python) / `context.Context`
  (Go). Every log line in the request's scope carries it automatically.
- **Common AI failure**: adding logging statements but no request-scoped ID — so a 500-error log
  cannot be matched to the request that caused it, and a multi-service trace is impossible.
- **red-flag**: no MDC `put("traceId", ...)` / no `structlog.contextvars.bind_contextvars` /
  no `context.WithValue(ctx, traceKey, ...)` wired into the middleware chain.

### 5. Wrong log level

- **Rule**: level discipline is mandatory. `ERROR` for unexpected failures that require operator
  action. `WARN` for expected degraded states. `INFO` for significant lifecycle events. `DEBUG`
  for developer context (disabled in production). Do not use `ERROR` for expected control flow.
- **Common AI failure**: `log.error("User not found")` (404 is expected), `log.info("Payment
  failed: {}", e)` (should be `error` or `warn`), spamming `error` so alerts are meaningless.
- **red-flag**: `error(` / `ERROR` for 404 / validation failures / record-not-found;
  `info(` for exceptions that indicate actual failures.

### 6. Swallowed error

- **Rule**: catch blocks must either re-throw, log the exception **with its stack trace and
  cause**, or forward to the error reporter. An empty catch or a catch that logs only a string
  (dropping the `Throwable`/`Exception` object) is forbidden.
- **Common AI failure**: `catch (e: Exception) { }` (silent swallow), `except Exception: pass`,
  `catch (err) { logger.error("failed") }` (drops the stack — the `err` is never logged).
- **red-flag**: `catch {}`, `except: pass`, `except Exception: pass`, `catch (e) { log.error("msg") }`
  without passing `e` as the second argument.

### 7. Logging in hot path / loop

- **Rule**: no log call inside a tight loop, per-row iteration, render callback, or
  high-frequency scheduled task. Log once before/after with a count or summary.
- **Common AI failure**: `for (item in items) { log.info("Processing item {}", item.id) }` —
  generating millions of log lines per minute that saturate the log pipeline and obscure real errors.
- **red-flag**: a log call inside a `for`/`while`/`forEach`, an `@Scheduled` method that runs
  sub-second, a streaming handler, or any hot loop.

### 8. No metrics (logs only)

- **Rule**: any operation the business monitors — payment, auth, job, external API call, cache
  access — must emit at minimum a counter (success/error labelled) and a timer. Logs describe
  what happened; metrics are what you alert on.
- **Common AI failure**: writing verbose logs for a payment flow but adding zero Micrometer
  counters/timers — so there is no dashboard, no SLO, no alert.
- **red-flag**: a handler for a critical operation (payment/auth/job) with no `MeterRegistry`,
  `Counter`, `Timer`, or OTel `meter` in scope.

### 9. Missing crash / error reporting

- **Rule**: Sentry (or equivalent error tracker) must be initialized at service startup and
  `Sentry.captureException(e)` (or equivalent) called for all unexpected caught exceptions and
  all unhandled exceptions via the global handler.
- **Common AI failure**: no Sentry DSN configured, no `Sentry.init`, or catch blocks that log
  but never forward to the error tracker — so errors are invisible in the error dashboard.
- **red-flag**: no Sentry/error-reporter initialization in application startup; catch blocks
  that handle errors without a `captureException` / `report` call for unexpected failures.

### 10. Non-actionable message

- **Rule**: every log line must carry enough context to act on without re-reading the code:
  which entity (ID), which operation, what state, what the next step is for the operator.
  Bare "error occurred" / "failed" / "something went wrong" are not acceptable.
- **Common AI failure**: `log.error("Error occurred")`, `logger.warning("Failed")` with no IDs,
  no operation name, no clue which entity triggered it or why.
- **red-flag**: log message that is only a bare status word ("failed", "error", "exception")
  with no structured fields and no entity identifiers.

## Vibe-guard review checklist

For backend code that AI generated or was pasted in quickly, before merge:

- [ ] No `System.out.println` / `print()` / `fmt.Println` / `console.log` in server paths.
- [ ] No PII, tokens, passwords, or Authorization headers in any log line.
- [ ] All log messages use structured key/value fields (no string concatenation).
- [ ] A `traceId` is injected per-request and appears in every log line (MDC / contextvars / ctx).
- [ ] Level discipline: `ERROR` only for unexpected failures, not 404/validation.
- [ ] Every catch block logs the exception object (with stack) or re-throws.
- [ ] No log calls inside tight loops or high-frequency callbacks.
- [ ] Critical operations (payment/auth/job) emit a counter and a timer metric.
- [ ] Sentry (or equivalent) initialized; unexpected caught exceptions forwarded.
- [ ] Every log line carries IDs and context — no bare "failed" messages.

## Halt conditions

Halt (do not proceed, surface a finding) when any of the following is detected:

- PII / secret value present in a log statement (rule 2) — this is a data-exposure defect.
- Empty or exception-dropping catch block on a path that affects data integrity (rule 6).
- A critical operation (payment, auth) with no metrics at all (rule 8).

Output on halt:

```markdown
## [observability] Halted — [rule number]: [rule name]

Halt reason:
- (specific file:line and what was found)

Action required:
1. ...
```

Do NOT propose the fix inline — surface the finding and let the engineer decide.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code samples (bad → good per rule): [reference.md](./reference.md)
- Umbrella: [backend-architecture](../backend-architecture/SKILL.md)
- PII/secret depth: [backend-security-guard](../backend-security-guard/SKILL.md)
- Reliability/SLO: [backend-reliability](../backend-reliability/SKILL.md)
- OpenTelemetry: https://opentelemetry.io/docs/
- Micrometer: https://micrometer.io/docs
- SLF4J MDC: https://www.slf4j.org/manual.html#mdc
- structlog: https://www.structlog.org/en/stable/contextvars.html
- Go slog: https://pkg.go.dev/log/slog
