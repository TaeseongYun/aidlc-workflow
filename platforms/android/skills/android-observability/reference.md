# Android Observability — Reference

Deep-dive material for `SKILL.md`: Kotlin code pairs (bad → good) for all 10
guard rules, plus canonical Do examples for structured logging with correlation
IDs and Crashlytics/metrics wiring. For rule summaries and decision criteria,
see `SKILL.md`.

---

## Setup: Timber + ReleaseTree + Crashlytics

```kotlin
// App.kt
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        } else {
            Timber.plant(ReleaseTree())
        }
        // Crashlytics auto-initializes from google-services.json;
        // call here only if you disabled auto-init in the manifest.
    }
}

// ReleaseTree.kt — no-ops debug/verbose, forwards errors to Crashlytics
class ReleaseTree : Timber.Tree() {
    override fun isLoggable(tag: String?, priority: Int): Boolean =
        priority >= Log.WARN

    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
        if (priority == Log.ERROR && t != null) {
            FirebaseCrashlytics.getInstance().recordException(t)
        }
        // WARN and ERROR still written to logcat in release for ADB debugging;
        // remove the super call to silence them entirely in prod.
        super.log(priority, tag, message, t)
    }
}
```

---

## Rule 1 — Raw `android.util.Log` in production paths

### Bad

```kotlin
class AuthRepository(private val api: AuthApi) {
    suspend fun login(email: String, password: String): Result<User> {
        Log.d("AuthRepository", "Attempting login for $email")   // raw Log, leaks PII
        return try {
            val user = api.login(email, password)
            Log.i("AuthRepository", "Login OK")
            Result.success(user)
        } catch (e: Exception) {
            Log.e("AuthRepository", "Login failed", e)
            Result.failure(e)
        }
    }
}
```

### Good

```kotlin
class AuthRepository(private val api: AuthApi) {
    suspend fun login(userId: String): Result<User> {
        Timber.tag("auth").d("login_attempt user_id=%s", userId)
        return try {
            val user = api.login(userId)
            Timber.tag("auth").i("login_success user_id=%s", userId)
            Result.success(user)
        } catch (e: Exception) {
            Timber.tag("auth").e(e, "login_failure user_id=%s", userId)
            Result.failure(e)
        }
    }
}
```

No raw `Log.*`. PII-free (user ID, not email/password). Exception forwarded.

---

## Rule 2 — PII / secrets in logs

### Bad

```kotlin
fun onLoginResponse(user: User, token: String) {
    Timber.i("Logged in: user=$user token=$token")   // full object + auth token
    prefs.save(token)
}

// OkHttp interceptor
override fun intercept(chain: Interceptor.Chain): Response {
    val request = chain.request()
    Timber.d("Request headers: ${request.headers}")  // logs Authorization value
    return chain.proceed(request)
}
```

### Good

```kotlin
fun onLoginResponse(user: User, token: String) {
    Timber.tag("auth").i("login_complete user_id=%s", user.id)   // ID only, no PII
    prefs.save(token)
}

// OkHttp interceptor — log only safe metadata
override fun intercept(chain: Interceptor.Chain): Response {
    val request = chain.request()
    Timber.tag("http").d(
        "outbound method=%s url=%s has_auth=%b",
        request.method,
        request.url.redact(),          // strip query params that may carry secrets
        request.header("Authorization") != null
    )
    return chain.proceed(request)
}
```

Log IDs and boolean presence flags. Never log token values or full headers.
See `android-security` for the full PII field list.

---

## Rule 3 — Unstructured string concatenation

### Bad

```kotlin
Timber.i("User " + userId + " placed order " + orderId + " total " + total)
Timber.d("Retry #$attempt for request $requestId failed with status $status")
```

### Good

```kotlin
Timber.tag("order").i(
    "order_placed user_id=%s order_id=%s total_cents=%d",
    userId, orderId, totalCents
)
Timber.tag("http").d(
    "retry_attempt request_id=%s attempt=%d status=%d",
    requestId, attempt, status
)
```

Named key=value fields make lines grep- and query-able. Avoid interpolated
template strings as the sole message body.

---

## Rule 4 — Missing correlation / trace ID

### Bad

```kotlin
// ViewModel
fun loadProfile() {
    Timber.d("loadProfile called")
    viewModelScope.launch {
        val result = repo.fetchProfile(userId)
        Timber.d("profile loaded")   // no ID ties these two lines together
    }
}

// Repository
suspend fun fetchProfile(userId: String): Profile {
    Timber.d("fetching profile")    // which request? which user?
    return api.getProfile(userId)
}
```

### Good

```kotlin
// Generate once per user action, pass through every layer
fun loadProfile() {
    val traceId = UUID.randomUUID().toString().take(8)
    Timber.tag("profile").d("load_start trace_id=%s user_id=%s", traceId, userId)
    viewModelScope.launch {
        val result = repo.fetchProfile(userId, traceId)
        Timber.tag("profile").d("load_complete trace_id=%s", traceId)
    }
}

suspend fun fetchProfile(userId: String, traceId: String): Profile {
    Timber.tag("profile").d("fetch_start trace_id=%s user_id=%s", traceId, userId)
    return api.getProfile(userId)   // pass traceId as X-Request-Id header in OkHttp interceptor
}
```

A single `traceId` threads through every log call in the flow, making it
possible to reconstruct what happened for one user action from a log dump.

---

## Rule 5 — Wrong log level

### Bad

```kotlin
try {
    val session = sessionStore.getActive()
    processSession(session)
} catch (e: SessionExpiredException) {
    Timber.e(e, "session error")    // ERROR for an expected, recoverable case
    refreshSession()
}

fun onSyncComplete(result: SyncResult) {
    if (result.hasErrors) {
        Timber.d("sync had some issues")   // DEBUG for a user-visible failure
    }
}
```

### Good

```kotlin
try {
    val session = sessionStore.getActive()
    processSession(session)
} catch (e: SessionExpiredException) {
    Timber.tag("session").w("session_expired session_id=%s", session?.id)  // WARN: expected
    refreshSession()
}

fun onSyncComplete(result: SyncResult) {
    if (result.hasErrors) {
        Timber.tag("sync").e("sync_failed error_count=%d", result.errorCount)  // ERROR: blocks user
    }
}
```

Expected recoverable states → WARN. User-blocking failures → ERROR (so alerts
fire). Routine operational events → INFO.

---

## Rule 6 — Swallowed error / dropped stack

### Bad

```kotlin
try {
    database.saveOrder(order)
} catch (e: Exception) {
    // silently swallowed
}

try {
    analytics.track(event)
} catch (e: Exception) {
    Timber.e("analytics error")    // message logged, exception object dropped
}
```

### Good

```kotlin
try {
    database.saveOrder(order)
} catch (e: Exception) {
    Timber.tag("order").e(e, "save_failed order_id=%s", order.id)
    FirebaseCrashlytics.getInstance().recordException(e)
    // propagate or surface to UI as appropriate
}

try {
    analytics.track(event)
} catch (e: Exception) {
    Timber.tag("analytics").w(e, "track_failed event=%s", event.name)  // exception forwarded
}
```

Always pass the exception object (`e`) to `Timber.e`/`Timber.w`. Call
`recordException(e)` from Crashlytics for non-fatal errors on high-value paths.

---

## Rule 7 — Logging in hot paths / tight loops

### Bad

```kotlin
// RecyclerView adapter
override fun onBindViewHolder(holder: ViewHolder, position: Int) {
    Timber.d("binding position=%d item=%s", position, items[position].id)  // fires per cell
    holder.bind(items[position])
}

// Polling loop
while (isActive) {
    Timber.d("poll_tick ts=%d", System.currentTimeMillis())   // floods Logcat
    val result = poller.check()
    delay(500)
}
```

### Good

```kotlin
override fun onBindViewHolder(holder: ViewHolder, position: Int) {
    // no per-bind logging; trace at the list-load level instead
    holder.bind(items[position])
}

// Log outside the loop; log errors inside only on state change
var lastErrorState = false
while (isActive) {
    val result = poller.check()
    if (result.isError && !lastErrorState) {
        Timber.tag("poller").w("poll_error detail=%s", result.detail)
        lastErrorState = true
    } else if (!result.isError) {
        lastErrorState = false
    }
    delay(500)
}
```

Log at the boundary of a loop (before/after), not on every iteration. Inside
`onBindViewHolder`, `onDraw`, or frame callbacks: no logging at all.

---

## Rule 8 — No metrics on critical operations

### Bad

```kotlin
suspend fun processPayment(orderId: String, amount: Long): PaymentResult {
    Timber.tag("payment").i("payment_start order_id=%s", orderId)
    return try {
        val result = api.charge(orderId, amount)
        Timber.tag("payment").i("payment_success order_id=%s", orderId)
        result
    } catch (e: Exception) {
        Timber.tag("payment").e(e, "payment_failure order_id=%s", orderId)
        throw e
    }
    // no counters, no timers → nothing to alert on
}
```

### Good

```kotlin
// Using a lightweight counter/timer — adapt to your metrics library
// (e.g. Micrometer via OTel Android, or a simple AtomicLong + periodic upload)
suspend fun processPayment(orderId: String, amount: Long): PaymentResult {
    val start = SystemClock.elapsedRealtime()
    Timber.tag("payment").i("payment_start order_id=%s", orderId)
    return try {
        val result = api.charge(orderId, amount)
        val latencyMs = SystemClock.elapsedRealtime() - start
        metrics.increment("payment.success")
        metrics.record("payment.latency_ms", latencyMs)
        Timber.tag("payment").i(
            "payment_success order_id=%s latency_ms=%d", orderId, latencyMs
        )
        result
    } catch (e: Exception) {
        metrics.increment("payment.failure")
        Timber.tag("payment").e(e, "payment_failure order_id=%s", orderId)
        FirebaseCrashlytics.getInstance().recordException(e)
        throw e
    }
}
```

Every auth, payment, sync, and push-delivery path needs at minimum a success
counter, a failure counter, and a latency timer. Logs alone cannot drive alerts.

---

## Rule 9 — Missing crash / error reporting

### Bad

```kotlin
// Application.onCreate — Crashlytics never initialized (missing google-services.json
// wiring, or auto-init disabled and not re-enabled)
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        Timber.plant(Timber.DebugTree())   // no ReleaseTree, no Crashlytics
    }
}

// Handled error — never reported
try {
    syncManager.runSync()
} catch (e: SyncException) {
    Timber.tag("sync").e(e, "sync_failed")   // logged, not recorded
}
```

### Good

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        } else {
            Timber.plant(ReleaseTree())    // ReleaseTree calls recordException on ERROR
        }
        // Crashlytics auto-init picks up google-services.json; set user ID for
        // correlation after consent.
        if (!BuildConfig.DEBUG) {
            FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(true)
        }
    }
}

// Handled non-fatal error — explicitly recorded
try {
    syncManager.runSync()
} catch (e: SyncException) {
    Timber.tag("sync").e(e, "sync_failed attempt=%d", attempt)
    FirebaseCrashlytics.getInstance().apply {
        setCustomKey("sync_attempt", attempt)
        recordException(e)
    }
}
```

Unhandled crashes are captured automatically. Handled errors on important paths
require an explicit `recordException(e)` call so they appear in the Crashlytics
dashboard.

---

## Rule 10 — Non-actionable log messages

### Bad

```kotlin
Timber.e("error occurred")
Timber.w("failed")
Timber.i("done")
Timber.e(e, "null")
```

### Good

```kotlin
Timber.tag("checkout").e(
    e,
    "checkout_submit_failed user_id=%s cart_id=%s step=%s",
    userId, cartId, currentStep.name
)
Timber.tag("upload").w(
    "upload_retry_exhausted file_id=%s attempts=%d last_status=%d",
    fileId, MAX_ATTEMPTS, lastHttpStatus
)
Timber.tag("sync").i(
    "sync_complete records_added=%d records_updated=%d duration_ms=%d",
    added, updated, durationMs
)
```

Every message must name the operation, the entity ID(s), and the relevant
state. An on-call engineer reading the line cold must know what broke, which
user or object was affected, and what happened.

---

## Canonical Do: structured log + correlation ID + redaction

Full example combining Rules 3, 4, and 2:

```kotlin
class OrderRepository(
    private val api: OrderApi,
    private val crashlytics: FirebaseCrashlytics,
) {
    suspend fun placeOrder(
        userId: String,
        cart: Cart,
        traceId: String,                    // Rule 4: caller-provided correlation ID
    ): Result<Order> {
        Timber.tag("order").i(
            "place_start trace_id=%s user_id=%s item_count=%d total_cents=%d",
            traceId, userId, cart.items.size, cart.totalCents   // Rule 2: no PII, no card data
        )
        return try {
            val order = api.placeOrder(
                cart,
                headers = mapOf("X-Request-Id" to traceId)      // Rule 4: propagate to backend
            )
            Timber.tag("order").i(
                "place_success trace_id=%s order_id=%s",
                traceId, order.id
            )
            Result.success(order)
        } catch (e: Exception) {
            Timber.tag("order").e(
                e,
                "place_failure trace_id=%s user_id=%s",          // Rule 10: actionable
                traceId, userId
            )
            crashlytics.recordException(e)                        // Rule 9: non-fatal reported
            Result.failure(e)
        }
    }
}
```

---

## Canonical Do: metrics + Crashlytics wiring for auth

```kotlin
class LoginViewModel(
    private val authRepo: AuthRepository,
    private val metrics: AppMetrics,
    private val crashlytics: FirebaseCrashlytics,
) : ViewModel() {

    fun login(userId: String) {
        val traceId = UUID.randomUUID().toString().take(8)
        val start = SystemClock.elapsedRealtime()
        Timber.tag("auth").i("login_start trace_id=%s user_id=%s", traceId, userId)

        viewModelScope.launch {
            when (val result = authRepo.login(userId, traceId)) {
                is Result.Success -> {
                    val latencyMs = SystemClock.elapsedRealtime() - start
                    metrics.increment("auth.login.success")
                    metrics.record("auth.login.latency_ms", latencyMs)
                    Timber.tag("auth").i(
                        "login_success trace_id=%s user_id=%s latency_ms=%d",
                        traceId, userId, latencyMs
                    )
                }
                is Result.Failure -> {
                    metrics.increment("auth.login.failure")
                    Timber.tag("auth").e(
                        result.exception,
                        "login_failure trace_id=%s user_id=%s",
                        traceId, userId
                    )
                    crashlytics.recordException(result.exception)
                }
            }
        }
    }
}
```

---

## Review checklist

- [ ] No `Log.*` calls outside the logging layer / ReleaseTree.
- [ ] No `println` / `System.out.println` in Kotlin/Java source.
- [ ] No PII (email, phone, card, SSN, password, token value) in log arguments.
- [ ] No raw auth header values or full request/response bodies logged.
- [ ] Log messages use named key=value fields, not string interpolation blobs.
- [ ] Multi-step flows carry a `traceId` through every log call and network hop.
- [ ] Log levels match the table in SKILL.md (WARN for recoverable, ERROR for blocking failures).
- [ ] No empty catch blocks; exception object always passed to `Timber.e`/`Timber.w`.
- [ ] `recordException(e)` called for non-fatal errors on high-value paths.
- [ ] No `Timber.*` inside `onBindViewHolder`, `onDraw`, or loop bodies.
- [ ] Auth/payment/sync/push paths have at least one success counter and one failure counter.
- [ ] Crashlytics enabled in the release `Application.onCreate` (or via auto-init).
- [ ] Every log message includes entity ID(s), operation name, and relevant state.

## Official references

- Timber: https://github.com/JakeWharton/timber
- Firebase Crashlytics Android: https://firebase.google.com/docs/crashlytics/get-started?platform=android
- Android Logcat best practices: https://developer.android.com/studio/debug/logcat
- OpenTelemetry Android: https://opentelemetry.io/docs/zero-code/android/
- Perfetto: https://perfetto.dev/docs/instrumentation/tracing-sdk
- Team baseline: [../../guidance.md](../../guidance.md)
- PII / secrets taxonomy: [../android-security/SKILL.md](../android-security/SKILL.md)
