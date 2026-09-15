---
name: frontend-observability
description: Frontend (web) observability guard — structured logging, correlation/trace IDs, metrics, and
  crash/error reporting done right, and detect/block the anti-patterns AI ships (debug console.log left
  in prod, PII/secrets in logs, unstructured concatenated messages, missing correlation IDs, wrong log
  levels, swallowed errors, logging in hot loops, no metrics, missing crash reporting, non-actionable
  messages). Auto-loads when writing or reviewing logging, error handling, metrics, or telemetry.
when_to_use: When adding/reviewing logging, error handling, metrics, tracing, or crash reporting, or on
  requests like "why can't we debug this in prod", "is this logging safe", "observability review".
paths: **/*.ts, **/*.tsx, **/*.js, **/*.jsx
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-observability — vibe-coding observability guard

AI-generated web code is **observability-blind**: it leaves `console.log` debugging in production,
logs PII and secrets, emits unstructured string-concatenated messages nothing can query, swallows errors
in empty catch blocks, floods render paths with per-frame logs, and ships no metrics or crash reporting
— so when it breaks in production, there is nothing to see. This skill is the **review gate**. The rules
here are **operational-safety rules** and must not be relaxed. Project `ctx/` may tighten them but the
observability floor is never lowered.

## Scope

- Targets: web source (TS/JS/React) — especially AI-generated or quickly-pasted code that touches
  logging, error handling, metrics, or telemetry.
- What it does: **detect anti-patterns → propose safe, structured alternatives** for each failure mode below.
- Delegate:
  - PII/secrets depth → [frontend-security](../frontend-security/SKILL.md) (this skill cross-references it for redaction rules).
  - Log-assertion test patterns → [frontend-testing](../frontend-testing/SKILL.md).
  - Where the logging seam lives architecturally → [frontend-architecture](../frontend-architecture/SKILL.md).
- Stack: a logging **wrapper** (not raw `console.log`; enforce `no-console` in prod), **Sentry browser
  SDK** for crash/error reporting, **web-vitals / RUM** for performance metrics, **breadcrumbs** for
  trace context. Never log PII or dump user data into analytics.

## Core Guidance (Do)

- **Use one logger, not `console.*`**. Wrap all log output behind a single module (`src/lib/logger.ts`
  or equivalent). Enable `eslint-plugin-no-console` (error in prod) so raw `console.log` is caught at
  lint time.
- **Structured key/value fields**. Every log call includes discrete fields (`userId`, `traceId`,
  `action`, etc.) — not a concatenated string. This makes logs queryable in any log aggregator.
- **Correlation / trace ID**. Propagate a `traceId` (or W3C `traceparent`) from the entry point
  (route change, user action, API call) through every log and error in that request's scope.
- **Right level**. `debug` for dev-only detail, `info` for normal events, `warn` for recoverable
  anomalies, `error` for failures. Expected control-flow paths (e.g. 404s) are `warn` or handled
  silently — not `error`.
- **Redact PII before logging**. Emails, tokens, card numbers, SSNs, full request/response bodies
  must be stripped or masked. See [frontend-security](../frontend-security/SKILL.md) for the full
  PII/secrets surface.
- **Metrics for critical operations**. Every important user action (auth, payment, key feature) emits
  at least one counter or timing metric (web-vitals, a RUM event, or a custom metric).
- **Wire crash reporting on startup**. `Sentry.init()` (or equivalent) must be called unconditionally
  before the app mounts. Caught errors that are re-thrown or displayed to the user must also be
  forwarded via `Sentry.captureException()`.
- **Actionable context**. Every error log includes: which entity (`userId`, `orderId`, etc.), which
  state, and enough fields for an on-call engineer to locate the problem without reading source code.

## Guard Rules (Mode B) — 10 failure modes (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Debug print left in production

- **Rule**: never use `console.log`/`console.warn`/`console.error`/`console.debug` directly in
  production source. Route all output through the project's logger wrapper. Enforce with
  `eslint-plugin-no-console` set to `error` in the production ESLint config.
- **Common AI failure**: scaffolds components and utility functions with `console.log("result:", data)`
  left in place; copies examples from docs that use `console.log` directly; uses `console.error` in
  catch blocks as the only error handling.
- **red-flag**: `console.log`, `console.warn`, `console.error`, `console.debug` appearing anywhere
  outside a dedicated `src/lib/logger.ts` or equivalent; any `console.*` call in a component, hook,
  service, or utility file.

### 2. PII / secrets in logs

- **Rule**: never log tokens, passwords, emails, card/SSN, full auth headers, or raw
  request/response bodies. Always redact or mask sensitive fields before they reach any log call.
  Cross-reference: [frontend-security](../frontend-security/SKILL.md) for the full secrets surface.
- **Common AI failure**: logs the entire user object (`logger.info("user", { user })`), logs an
  `Authorization` header verbatim when debugging API calls, passes full `req.body` / response JSON
  to a log statement during error handling.
- **red-flag**: `log(user)`, `log({ user })`, `log(headers)`, `log(body)`, logging an
  `Authorization` / `Cookie` header value, logging a full API response payload without redaction.

### 3. Unstructured logging

- **Rule**: use structured key/value fields for every log call — not string concatenation. Log
  aggregators (Datadog, CloudWatch, Logtail) can only filter and alert on discrete fields, not
  embedded substrings.
- **Common AI failure**: writes `logger.info("User " + userId + " completed action " + action)` or
  template literals `logger.info(\`Payment ${id} failed\`)` with no structured context object.
- **red-flag**: a log call whose first argument is a concatenated string or template literal with
  variables embedded inline and no separate structured context argument.

### 4. Missing correlation / trace ID

- **Rule**: every log emitted during a user action or API call must carry a `traceId` (or W3C
  `traceparent`). Without it, logs from the same request cannot be grouped in production.
- **Common AI failure**: creates logging calls in event handlers or API fetch wrappers with no
  trace/correlation ID; no context propagation between the initiating event and subsequent async calls.
- **red-flag**: log calls in fetch wrappers, route handlers, or async operations with no `traceId`,
  `correlationId`, or `traceparent` field; no trace-context provider or context-propagation utility
  anywhere in the codebase.

### 5. Wrong log level

- **Rule**: `debug` = dev-only verbose detail; `info` = normal business events; `warn` = recoverable
  anomaly or expected-but-notable case; `error` = actual failure requiring attention. Expected
  control flow (404, validation failure, user not found) is `warn` or silent — not `error`.
- **Common AI failure**: uses `logger.error()` for every caught exception including expected cases
  like "session expired" or "item not found"; uses `logger.info()` for genuine failures that
  need alerting; no level discipline at all — everything is `info` or `error`.
- **red-flag**: `error()` in a catch block that catches known non-fatal cases (auth expiry,
  not-found, rate-limit); `info()` for a genuine failure that should page someone; every log
  at the same level regardless of severity.

### 6. Swallowed error

- **Rule**: catch blocks must either handle the error visibly, log it with the full exception
  object (so the stack trace is preserved), or re-throw. An empty `catch {}` or a catch that
  logs a string but drops the exception object is silent data loss.
- **Common AI failure**: writes `catch (e) {}`, `catch { /* ignore */ }`, or
  `catch (e) { logger.error("failed") }` — logging the message but discarding `e` (and its stack).
- **red-flag**: `catch {}`, `catch (e) {}` with no body, or any catch block that calls a log
  function without passing the caught exception object as a field or argument.

### 7. Logging in hot path / loop

- **Rule**: never place a log call inside a tight loop, per-render React function body, animation
  frame callback, or scroll/resize handler. Log flooding degrades performance and makes logs
  unusable by drowning signal in noise.
- **Common AI failure**: adds `logger.debug("rendering item", { id })` inside a list `.map()`,
  logs inside a `useEffect` that fires on every render, or places a log call directly in a
  `requestAnimationFrame` or `scroll` event handler.
- **red-flag**: a log call inside a `for`/`while`/`.map()`/`.forEach()` loop, inside a React
  component's render body (not inside a one-time effect with an empty dep array), or inside a
  `scroll`, `mousemove`, `resize`, or `requestAnimationFrame` callback.

### 8. No metrics (logs only)

- **Rule**: critical operations (auth, payment, form submission, feature toggle, key API call) must
  emit at least one metric — a web-vitals measurement, a RUM custom event, or a Sentry performance
  transaction. Logs alone cannot drive alerts or dashboards.
- **Common AI failure**: implements a payment flow or auth handshake with detailed logging but zero
  metrics; skips `Sentry.startTransaction()` or `reportWebVitals`; no custom performance marks for
  user-critical paths.
- **red-flag**: a function that handles payments, auth, or another critical operation with log calls
  but no `performance.mark`, `Sentry.startSpan`, `reportWebVitals`, or any equivalent metric emission.

### 9. Missing crash / error reporting

- **Rule**: `Sentry.init()` (or an equivalent crash reporter) must be called on app startup,
  unconditionally, before the root component mounts. Errors caught in boundaries or service calls
  that affect the user must also be forwarded via `Sentry.captureException()`.
- **Common AI failure**: scaffolds a React app with error boundaries that `console.error` the
  caught error but never call `Sentry.captureException()`; forgets `Sentry.init()` in the entry
  point entirely; wires Sentry only in development.
- **red-flag**: an `ErrorBoundary` whose `componentDidCatch` does not call
  `Sentry.captureException()`; no `Sentry.init()` (or equivalent) in `main.tsx`/`_app.tsx`/`index.ts`;
  Sentry imported but `init()` called conditionally only in dev.

### 10. Non-actionable message

- **Rule**: every log and error message must include enough discrete fields for an on-call engineer
  to locate the problem without reading source code: which entity (`userId`, `orderId`, `featureId`),
  which operation, which state, and — for errors — what the next likely action is.
- **Common AI failure**: logs `"error occurred"`, `"request failed"`, `"something went wrong"` with
  no fields; emits an error event with only a generic message string and no structured context.
- **red-flag**: log or error call whose message is a generic phrase (`"error"`, `"failed"`,
  `"something went wrong"`, `"oops"`) with no accompanying structured fields identifying the entity
  and operation.

## Observability review checklist

For frontend code that AI generated or was pasted in quickly, before merge:

- [ ] No raw `console.*` calls outside the logging wrapper; `no-console` ESLint rule enforced in prod.
- [ ] No PII (email, token, card, SSN, auth header, full body) in any log call — see [frontend-security](../frontend-security/SKILL.md).
- [ ] All log calls use structured key/value fields — no string concatenation or embedded template variables.
- [ ] Every async operation and API call propagates a `traceId` / `correlationId` through all logs.
- [ ] Log levels match severity: `debug` dev-only, `info` normal, `warn` recoverable, `error` real failures.
- [ ] No empty catch blocks; every catch passes the exception object to the logger.
- [ ] No log calls inside render bodies, loops, scroll/resize handlers, or animation frame callbacks.
- [ ] Critical operations (auth, payment, key feature) emit at least one metric or performance mark.
- [ ] `Sentry.init()` called unconditionally on startup; `ErrorBoundary.componentDidCatch` calls `Sentry.captureException()`.
- [ ] Every log and error includes entity IDs and operation context — no bare "error occurred" strings.

## Halt conditions

Halt review and output the standard halt block (per `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`) when:

- The logging wrapper module does not exist and the codebase uses raw `console.*` everywhere — the
  architectural seam must be established before a rule-by-rule review is meaningful.
- PII exposure in logs requires immediate triage — escalate to [frontend-security](../frontend-security/SKILL.md) first.
- Sentry (or an equivalent crash reporter) is entirely absent from the project and there is no plan
  to add one — this is a missing operational-safety baseline, not a style issue.

```markdown
## Observability Review — Halted

Halt reason:
- (specific halt reason from the list above)

Items requiring attention before review can continue:
1. ...
```

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (bad → good code samples): [reference.md](./reference.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- Adjacent: [frontend-security](../frontend-security/SKILL.md) (PII/secrets), [frontend-testing](../frontend-testing/SKILL.md) (log assertions)
- Sentry Browser SDK: https://docs.sentry.io/platforms/javascript/
- web-vitals: https://github.com/GoogleChrome/web-vitals
- W3C Trace Context: https://www.w3.org/TR/trace-context/
- ESLint no-console: https://eslint.org/docs/latest/rules/no-console
