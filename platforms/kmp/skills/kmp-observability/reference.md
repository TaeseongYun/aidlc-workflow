# kmp-observability — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code samples per failure mode.
Kotlin/KMP, using Kermit, Napier, Firebase Crashlytics, and Sentry via `expect`/`actual`.
Decision criteria live in `SKILL.md`.

---

## Do examples — structured log with correlation ID + redaction; metric + crash reporter wiring

### Structured log with correlation ID and redaction

```kotlin
// ✅ Structured, correlated, redacted — using Napier
import io.github.aakira.napier.Napier

class AuthService(private val repo: AuthRepository) {

    suspend fun signIn(email: String, password: String, traceId: String): User {
        Napier.i("signIn.start traceId=$traceId") // no email — PII
        return try {
            val user = repo.signIn(email, password)
            Napier.i("signIn.success traceId=$traceId userId=${user.id}") // id only, not email
            user
        } catch (e: Throwable) {
            Napier.e("signIn.failed traceId=$traceId", e) // Throwable always passed
            throw e
        }
    }
}
```

### Crash reporter wiring via expect/actual

```kotlin
// commonMain/kotlin/infra/CrashReporter.kt
expect object CrashReporter {
    fun recordException(throwable: Throwable, isFatal: Boolean = false)
    fun setUserId(userId: String)
}

// androidMain/kotlin/infra/CrashReporter.android.kt
import com.google.firebase.crashlytics.FirebaseCrashlytics

actual object CrashReporter {
    actual fun recordException(throwable: Throwable, isFatal: Boolean) {
        FirebaseCrashlytics.getInstance().run {
            recordException(throwable)
            if (isFatal) sendUnsentReports()
        }
    }
    actual fun setUserId(userId: String) {
        FirebaseCrashlytics.getInstance().setUserId(userId)
    }
}

// iosMain/kotlin/infra/CrashReporter.ios.kt
// Sentry iOS SDK bridged via cinterop, or Firebase iOS SDK
actual object CrashReporter {
    actual fun recordException(throwable: Throwable, isFatal: Boolean) {
        SentryKt.captureException(throwable)
    }
    actual fun setUserId(userId: String) {
        SentryKt.configureScope { it.setTag("userId", userId) }
    }
}

// androidMain: set uncaught exception handler in Application.onCreate()
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Thread.setDefaultUncaughtExceptionHandler { _, throwable ->
            CrashReporter.recordException(throwable, isFatal = true)
        }
        Napier.base(DebugAntilog()) // or a release-only sink
    }
}
```

### Metric emission alongside logging

```kotlin
// ✅ Payment flow: log + metric together; logs alone are not alertable
import io.github.aakira.napier.Napier
// expect/actual MetricsReporter follows the same CrashReporter pattern
expect object MetricsReporter {
    fun increment(event: String, tags: Map<String, String> = emptyMap())
    fun timing(event: String, durationMs: Long, tags: Map<String, String> = emptyMap())
}

class PaymentService(private val gateway: PaymentGateway) {

    suspend fun processPayment(order: Order, traceId: String) {
        val start = getTimeMillis()
        try {
            gateway.charge(order)
            val elapsed = getTimeMillis() - start
            Napier.i("payment.success traceId=$traceId orderId=${order.id} ms=$elapsed")
            MetricsReporter.increment("payment.success", mapOf("currency" to order.currency))
            MetricsReporter.timing("payment.duration_ms", elapsed)
        } catch (e: Throwable) {
            Napier.e("payment.failed traceId=$traceId orderId=${order.id}", e)
            MetricsReporter.increment("payment.failure")
            CrashReporter.recordException(e)
            throw e
        }
    }
}
```

---

## 1. println / System.out left in prod

```kotlin
// ❌ println shipped in release — visible in adb logcat / Xcode console
class UserRepository(private val api: UserApi) {
    suspend fun fetchUser(id: String): User {
        val user = api.getUser(id)
        println("fetched user: $user")        // ships in release
        System.out.println("user data: $user") // also ships in release
        return user
    }
}

// ✅ Napier / Kermit — configure log sinks per build variant
import io.github.aakira.napier.Napier

class UserRepository(private val api: UserApi) {
    suspend fun fetchUser(id: String): User {
        val user = api.getUser(id)
        Napier.d("fetchUser id=$id") // debug level; release sink suppresses below Info
        return user
    }
}

// In Application.onCreate() / platform init:
// Debug: Napier.base(DebugAntilog())
// Release: Napier.base(CrashlyticsAntilog()) — or no-op for verbose levels
```

---

## 2. PII / secrets in logs

```kotlin
// ❌ Logging full user object, JWT, and response body — PII + secret in device logs
suspend fun login(email: String, password: String) {
    val resp = api.login(email, password)
    Napier.d("login response: ${resp.body}")   // full body may contain token
    Napier.i("user: ${resp.user}")             // email, phone, address...
    Logger.d("token=${resp.token}")            // JWT in plain log
}

// ✅ Log only non-sensitive IDs; redact everything else
suspend fun login(email: String, password: String) {
    Napier.i("login.start")                    // no email
    val resp = api.login(email, password)
    Napier.i("login.success userId=${resp.user.id}") // id only
    // token never logged; stored via SecureStorage (see kmp-security)
}
```

---

## 3. Unstructured logging

```kotlin
// ❌ Concatenated string — one unindexable blob; nothing is filterable
Napier.d("user " + userId + " performed action " + action + " result: " + result)
Napier.w("request to " + endpoint + " failed after " + retries + " retries")

// ✅ Structured fields — each key is queryable in a log aggregator
// Pattern: <component>.<operation>.<outcome> key=value ...
Napier.d("action.result userId=$userId action=$action result=$result")
Napier.w("request.failed endpoint=$endpoint retries=$retries error=${e.message}")

// For log aggregators that support JSON payloads, pass a structured tag:
Napier.e(
    message = "order.capture.failed orderId=${order.id} amount=${order.amountCents}",
    throwable = e,
    tag = "PaymentService",
)
```

---

## 4. Missing correlation / trace ID

```kotlin
// ❌ Disconnected logs — impossible to reconstruct a single request's journey
suspend fun placeOrder(cart: Cart) {
    Napier.i("validating cart")
    cartService.validate(cart)
    Napier.i("charging payment")
    paymentService.charge(cart)
    Napier.i("sending confirmation")
    notificationService.confirm(cart)
}

// ✅ Shared traceId threaded through every call and every log line
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

@OptIn(ExperimentalUuidApi::class)
suspend fun placeOrder(cart: Cart) {
    val traceId = Uuid.random().toString()
    Napier.i("order.validate traceId=$traceId cartId=${cart.id}")
    cartService.validate(cart, traceId = traceId)
    Napier.i("order.charge traceId=$traceId cartId=${cart.id}")
    paymentService.charge(cart, traceId = traceId)
    Napier.i("order.confirm traceId=$traceId cartId=${cart.id}")
    notificationService.confirm(cart, traceId = traceId)
}
```

---

## 5. Wrong log severity

```kotlin
// ❌ Expected failures at e — alert fatigue; debug noise at i
suspend fun findUser(id: String): User? {
    val user = repo.find(id)
    if (user == null) {
        Napier.e("user not found id=$id") // expected case; not a system error
    }
    Napier.i("cache value for id=$id: ${cache[id]}") // verbose debug, not a milestone
    return user
}

// ✅ Severity matches the situation
suspend fun findUser(id: String): User? {
    val user = repo.find(id)
    if (user == null) {
        Napier.w("user.notFound id=$id") // recoverable, expected → w
        return null
    }
    Napier.v("cache.check id=$id hit=${cache.containsKey(id)}") // verbose → v
    Napier.i("user.found id=$id")         // normal milestone → i
    return user
}
```

Severity ladder: `v` verbose · `d` debug · `i` info/milestone · `w` recoverable warning ·
`e` real error requiring action.

---

## 6. Swallowed error

```kotlin
// ❌ Empty catch — exception vanishes; production failure is invisible
suspend fun syncData() {
    try {
        api.sync()
    } catch (e: Exception) {} // silent failure — nobody knows sync broke

// ❌ Logging a string message but dropping the Throwable and stack trace
    try {
        api.sync()
    } catch (e: Exception) {
        Napier.e("sync failed") // no Throwable argument — stack trace lost
    }
}

// ✅ Log Throwable; forward to crash reporter for fatal paths
suspend fun syncData() {
    try {
        api.sync()
    } catch (e: Throwable) {
        Napier.e("sync.failed", e)              // Throwable always second arg
        CrashReporter.recordException(e)         // forward to tracker
        throw e                                  // rethrow or handle deliberately
    }
}
```

Napier's `e(message, throwable, tag)` — always pass the `Throwable`. Same for Kermit:
`Logger.e(message = "...", throwable = e, tag = "SyncService")`.

---

## 7. Logging in hot recomposition path / loop

```kotlin
// ❌ Log inside a @Composable body — fires on every recomposition
@Composable
fun ProductCard(product: Product) {
    Napier.d("composing ProductCard productId=${product.id}") // O(recompositions) per second
    Card { Text(product.name) }
}

// ❌ Log inside animation/state collector — fires at frame rate
LaunchedEffect(Unit) {
    snapshotFlow { animationValue }.collect { value ->
        Napier.v("animation value=$value") // ~60 logs/second
    }
}

// ❌ Log inside a loop over a large collection
items.forEach { item ->
    Napier.d("processing item=${item.id}") // 1 000 log lines per call
}

// ✅ Log once before/after, not per-recomposition or per-frame
// @Composable: remove logging; use side-effects or ViewModel for state observation
LaunchedEffect(product.id) {
    Napier.d("ProductCard.appeared productId=${product.id}") // once per lifecycle, not per recompose
}

// animation: log only on state transitions
LaunchedEffect(Unit) {
    snapshotFlow { animationState }.collect { state ->
        Napier.d("animation.state state=$state") // fires only on state enum change
    }
}

// loop: log summary counts
Napier.i("batch.start count=${items.size}")
items.forEach { item -> process(item) }
Napier.i("batch.done count=${items.size}")
```

---

## 8. No metrics (logs only)

```kotlin
// ❌ Auth flow logs events but emits no metric — success rate is not alertable
suspend fun signIn(email: String, password: String) {
    try {
        auth.signIn(email, password)
        Napier.i("sign in success")   // logged, not measured
    } catch (e: Throwable) {
        Napier.e("sign in failed", e)  // logged, not measured
    }
}

// ✅ Log + metric: success/failure counters make this alertable
suspend fun signIn(email: String, password: String, traceId: String) {
    try {
        auth.signIn(email, password)
        Napier.i("signIn.success traceId=$traceId")
        MetricsReporter.increment("auth.signin.success")
    } catch (e: Throwable) {
        Napier.e("signIn.failed traceId=$traceId", e)
        MetricsReporter.increment("auth.signin.failure")
        CrashReporter.recordException(e)
        throw e
    }
}
```

---

## 9. Missing crash / error reporting

```kotlin
// ❌ No expect/actual CrashReporter; no uncaught handler; caught fatals go nowhere
// commonMain — no CrashReporter declaration
// androidMain — no Application.onCreate setup

suspend fun migrateDatabase() {
    try {
        db.migrate()
    } catch (e: Throwable) {
        Napier.e("migration failed", e) // logged but not sent to any crash tracker
    }
}

// ✅ Full wiring with expect/actual (see Do examples above)
// commonMain: expect object CrashReporter { fun recordException(...) }
// androidMain: actual uses FirebaseCrashlytics
// iosMain: actual uses Sentry or Firebase iOS SDK

suspend fun migrateDatabase() {
    try {
        db.migrate()
    } catch (e: Throwable) {
        Napier.e("db.migrate.failed", e)
        CrashReporter.recordException(e, isFatal = true) // forwarded to crash tracker
        throw e
    }
}
```

---

## 10. Non-actionable message

```kotlin
// ❌ Bare messages — useless in production; no entity, no operation, no state
Napier.e("error occurred")
Napier.w("failed")
Napier.i("null")

// ✅ Every message answers: which entity, which operation, what happened, what state
Napier.e(
    "payment.capture.failed orderId=${order.id} amount=${order.amountCents} attempt=$attempt",
    e,
)
Napier.w("cart.validate.itemUnavailable cartId=${cart.id} skuId=${item.skuId}")
Napier.i("auth.tokenRefresh.success userId=${user.id} expiresAt=${token.expiresAt}")
```

Pattern: `<component>.<operation>.<outcome> <key>=<value> ...` — parseable, filterable, actionable.

---

## Official References

- Kermit (multiplatform logging): https://github.com/touchlab/Kermit
- Napier (multiplatform logging): https://github.com/AAkira/Napier
- Firebase Crashlytics (Android): https://firebase.google.com/docs/crashlytics/get-started?platform=android
- Sentry Kotlin Multiplatform: https://docs.sentry.io/platforms/kotlin-multiplatform/
- Firebase Analytics (Android): https://firebase.google.com/docs/analytics/get-started?platform=android
- Kotlin coroutines error handling: https://kotlinlang.org/docs/exception-handling.html
- Team baseline: [../../guidance.md](../../guidance.md)
