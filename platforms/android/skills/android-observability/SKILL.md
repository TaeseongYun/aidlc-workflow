---
name: android-observability
description: Android observability guard — structured logging, correlation/trace IDs, metrics, and
  crash/error reporting done right, and detect/block the anti-patterns AI ships (debug Log.d left
  in prod, PII/secrets in logs, unstructured concatenated messages, missing correlation IDs, wrong
  log levels, swallowed errors, logging in hot loops, no metrics, missing crash reporting,
  non-actionable messages). Auto-loads when writing or reviewing logging, error handling, metrics,
  or telemetry.
when_to_use: When adding/reviewing logging, error handling, metrics, tracing, or crash reporting,
  or on requests like "why can't we debug this in prod", "is this logging safe",
  "observability review".
paths: "**/*.kt", "**/*.java"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android Observability

The observability baseline for the team's Android app. AI-generated code is
**observability-blind**: it leaves raw `Log.d`/`Log.e` calls in production,
logs PII and secrets, emits unstructured string-concatenated messages nothing
can query, swallows errors in empty catch blocks, floods hot loops with tags,
and ships no metrics or crash reporting — so when it breaks in production,
there is nothing to see. This skill is a **guard** (detect and block those
patterns) plus **guidance** (Timber, structured tags, Crashlytics, metrics,
redaction).

The rules here are **operational-safety rules** and must not be weakened or
relaxed. A project's `ctx/` may tighten them, but the floor is not lowered.

## Scope

- Applies to: `**/*.kt`, `**/*.java`.
- Covers: logging (Timber vs `android.util.Log`), structured log events, log
  levels, PII redaction, correlation/trace ID propagation, metrics (counters,
  timers), Firebase Crashlytics wiring, Perfetto/OTel tracing, hot-path
  discipline, actionable message conventions.
- **Delegates to:**
  - [`android-security`](../android-security/SKILL.md) — PII classification,
    secrets-in-logs depth, data-at-rest.
  - `android-testing` — asserting that log events fire in tests.
  - `android-architecture` — where the logging seam (AppLogger / DI binding)
    lives in the module graph.

## Core Guidance (Do)

### Use Timber, not `android.util.Log` directly

`android.util.Log` calls are stripped in release only when ProGuard rules or
Timber's no-op tree are in place. Raw `Log.*` calls with PII or verbose output
are a source of leaks. Plant a `Timber.DebugTree` in debug builds and a
stripped/Crashlytics-forwarding `ReleaseTree` in release.

```kotlin
// Application.onCreate
if (BuildConfig.DEBUG) {
    Timber.plant(Timber.DebugTree())
} else {
    Timber.plant(ReleaseTree())   // forwards errors to Crashlytics, no-ops debug/verbose
}
```

### Structured context, not concatenated strings

Pass structured key/value context as tag suffixes or use a wrapper that emits
structured key/value pairs. Avoid string interpolation for searchable fields.

```kotlin
// preferred: structured tag + named fields
Timber.tag("auth").i("login_success user_id=%s method=%s", userId, method)
```

### Propagate a correlation / trace ID

For every request or user-initiated flow, generate or receive a trace/request
ID and carry it through every log call and network hop via a header
(`X-Request-Id` or W3C `traceparent`).

### Right log level

| Level | When |
|-------|------|
| `v` / `d` | Debug-only development noise. Strip in release. |
| `i` | Normal operational events worth keeping (auth success, screen open). |
| `w` | Recoverable unexpected state — something is off but the app continues. |
| `e` | Unexpected failure requiring investigation. Include the exception. |

Never use `e` for expected control-flow outcomes (token expired → refresh is
expected). Never use `i` for a failure that blocks the user.

### Redact PII before logging

Log IDs and hashed/truncated identifiers, never raw email, phone, card, SSN,
password, or token values. See `android-security` for full PII taxonomy.

### Metrics for critical operations

Every high-value operation (auth, payment, sync job, push delivery) must have
at least one counter (success/failure) and a timer. Logs alone are not
alertable.

### Wire Firebase Crashlytics

Initialize Crashlytics in `Application.onCreate`. Forward non-fatal errors from
catch blocks using `FirebaseCrashlytics.getInstance().recordException(e)`. Do
not silently swallow exceptions.

### Actionable messages

Every log or crash report must carry enough context to act on it: the entity ID
(user, order, job), the operation, and what state was reached. Bare "error
occurred" is not actionable.

## Guard Rules (Mode B)

Review every file in scope against all 10 rules. For each failure: flag it,
state the rule, show the red-flag line.

---

### Rule 1 — No raw `android.util.Log` in production paths

**What AI does:** generates `Log.d(TAG, "...")` and `Log.e(TAG, "error", e)`
throughout feature code, assuming the reader will strip them. Raw `Log.*` calls
survive in release when ProGuard rules are absent, leaking verbose output and
potentially PII.

**Red-flag:** any `Log.d(`, `Log.v(`, `Log.i(`, `Log.w(`, `Log.e(`, or
`Log.wtf(` call outside the dedicated logging layer / `ReleaseTree`. Also
`System.out.println` or `println(` in Kotlin source.

---

### Rule 2 — No PII or secrets in logs

**What AI does:** logs full user objects (`Log.d(TAG, "user=$user")`), auth
tokens in request-logging interceptors, or full request/response bodies
containing card or identity data.

**Red-flag:** `log(user)`, `log(token)`, logging `Authorization` header value,
logging a full JSON body that may contain PII, `password`, `email`, `phone`,
`ssn`, `cardNumber` appearing as a log argument. Cross-reference
`android-security` for the full field list.

---

### Rule 3 — Structured logging, not string concatenation

**What AI does:** builds messages with string interpolation:
`Timber.i("User $userId completed $action")`. These produce unqueryable blobs
in Logcat and any log aggregation pipeline.

**Red-flag:** template strings with variable interpolation used as the entire
message, no named key=value fields, no structured map/context attached.

---

### Rule 4 — Correlation / trace ID must propagate

**What AI does:** generates per-operation log calls with no shared ID tying a
request's log lines together. In multi-step flows (auth → fetch → cache →
render) there is no way to correlate events for a single user action.

**Red-flag:** a multi-step flow (ViewModel → Repository → network) where no
`requestId`, `traceId`, or W3C `traceparent` is threaded through and appears
in log calls at each layer.

---

### Rule 5 — Use the correct log level

**What AI does:** logs all failures at `Timber.e` (triggering false-alarm
alerting) or logs recoverable errors at `Timber.i` (hiding real failures).
Common: using `e` for an expected token-expired response, or `i` for a network
error that blocks the screen.

**Red-flag:** `Timber.e` on a branch that represents expected control flow
(token refresh, retry, cache miss). `Timber.i` or `Timber.d` on a branch that
returns an error state to the UI.

---

### Rule 6 — Never swallow errors silently

**What AI does:** generates `try { ... } catch (e: Exception) { }` or
`catch (e: Exception) { Timber.e("failed") }` without forwarding the exception
object or recording it with Crashlytics. The stack trace and root cause are
lost.

**Red-flag:** an empty catch body, a catch that logs a string but drops `e`, or
a catch with no `recordException(e)` for non-fatal errors that should be
tracked.

---

### Rule 7 — No logging inside hot paths or tight loops

**What AI does:** adds `Timber.d(...)` inside `RecyclerView.Adapter.onBindViewHolder`,
`Canvas.draw*`, a `while`-polling loop, or a `Flow` operator that fires on
every frame/event. This floods Logcat, burns CPU, and can mask real log lines.

**Red-flag:** a `Timber.*` or `Log.*` call directly inside a loop body, inside
`onBindViewHolder`, inside a `draw`/`onDraw` override, or inside a hot
`StateFlow`/`SharedFlow` collector that emits at high frequency.

---

### Rule 8 — Critical operations must have metrics, not just logs

**What AI does:** adds log lines around a payment, auth, or background-job
operation but no counter or timer. Logs are not alertable; if the operation
silently degrades (success rate drops, latency spikes), there is nothing to
page on.

**Red-flag:** an auth, payment, sync, or push-delivery code path that has
`Timber.*` calls but zero metric increments (no counter, no timer, no gauge).

---

### Rule 9 — Firebase Crashlytics must be initialized and used

**What AI does:** scaffolds the app without wiring Crashlytics, or wires it
only in the `Application` but never calls `recordException(e)` from handled
error paths. Unhandled crashes are captured automatically; handled errors are
invisible without an explicit call.

**Red-flag:** `FirebaseCrashlytics` absent from `Application.onCreate`, or a
catch block on a high-value path that logs but never calls
`recordException(e)`.

---

### Rule 10 — Every log message must be actionable

**What AI does:** emits `Timber.e("error occurred")`, `Timber.w("failed")`, or
`Timber.i("done")` with no entity ID, no operation name, no state. On-call
engineers cannot act on bare strings.

**Red-flag:** a log call whose message string contains no IDs, no field=value
pairs, and no indication of which entity or operation failed. Messages like
`"error"`, `"failed"`, `"null"`, `"exception"` alone.

---

## Halt Conditions

Stop and output the halt block (per `skill-protocol.md`) when:

- The file cannot be read (missing, binary, generated).
- The logging framework in use is entirely unknown and cannot be determined from
  imports or the build files.

```markdown
## Observability Review Halted

Halt reason:
- (specific reason)

Items requiring confirmation:
1. ...
```

On halt: do NOT propose fixes. Do NOT explain how to resolve. Output only the
halt reason.

## References

- [reference.md](reference.md) — Kotlin code pairs (bad → good) for all 10 rules
- [../android-security/SKILL.md](../android-security/SKILL.md) — PII taxonomy, secrets
- [../../guidance.md](../../guidance.md) — team Android baseline
- `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md` — execution protocol
