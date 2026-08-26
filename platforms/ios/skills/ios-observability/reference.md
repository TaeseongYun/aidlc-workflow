# ios-observability — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs safe (✅)** code samples per failure mode.
Swift / unified logging (`os.Logger`) + Firebase Crashlytics / Sentry / MetricKit.
Decision criteria live in `SKILL.md`.

---

## Why this guard is needed

AI-generated iOS code has no production observability by default. It scaffolds features with
`print()` calls, logs entire model objects (including PII), drops errors in empty `catch` blocks,
and ships no crash reporter initialisation. When something breaks in production, there is nothing
to see — no log query, no metric spike, no crash report. This guard closes that gap before merge.

---

## 1. No debug print in production

```swift
// ❌ print() bypasses unified logging — stripped from Console.app, unqueryable, ships to prod
print("did fetch \(items.count) items")
NSLog("token: %@", token)
debugPrint(response)

// ✅ os.Logger — unified logging, Privacy controls, filterable in Console.app / Instruments
import os

extension MyService {
    static let log = Logger(subsystem: "com.example.app", category: "MyService")
}

// Call site
MyService.log.info("fetch complete count=\(items.count, privacy: .public)")
```

Note: declare `Logger` as a `static let` at the type level — one instance per category, not one
per call site.

---

## 2. No PII or secrets in logs

```swift
// ❌ entire User model (contains email, phone, token) interpolated as .public (the default)
log.info("user logged in: \(user)")
log.debug("auth header: \(request.value(forHTTPHeaderField: "Authorization") ?? "")")
log.error("response body: \(String(data: responseData, encoding: .utf8) ?? "")")

// ✅ log only non-sensitive identifiers; mark sensitive fields .private or .sensitive
log.info("login ok userID=\(user.id, privacy: .public) tier=\(user.tier, privacy: .public)")
// token, email, phone — never logged; if needed for debugging, .private hides in release
log.debug("email=\(user.email, privacy: .private)")
// Never log Authorization header values or full response bodies
```

Cross-reference: PII classification and Keychain storage → [ios-security](../ios-security/SKILL.md).

---

## 3. Structured logging only

```swift
// ❌ concatenated prose — nothing a log pipeline can group, filter, or alert on
log.info("User \(id) performed \(action) and it took \(duration)ms")

// ✅ labelled key=value fields — indexable, filterable, survives log ingestion
log.info("""
    action=\(action, privacy: .public) \
    userID=\(id, privacy: .public) \
    durationMS=\(duration, privacy: .public)
    """)
```

---

## 4. Correlation / trace ID

```swift
// ❌ no trace ID — log lines for a single request are unsearchable
func fetchOrder(id: String) async throws -> Order {
    log.info("fetching order")
    let order = try await api.getOrder(id: id)
    log.info("order fetched status=\(order.status)")
    return order
}

// ✅ requestID propagated through every log line and crash-reporter breadcrumb
func fetchOrder(id: String, requestID: UUID = UUID()) async throws -> Order {
    let rid = requestID.uuidString
    log.info("fetch start orderID=\(id, privacy: .public) requestID=\(rid, privacy: .public)")
    do {
        let order = try await api.getOrder(id: id)
        log.info("fetch ok orderID=\(id, privacy: .public) requestID=\(rid, privacy: .public) status=\(order.status, privacy: .public)")
        // Also set as Crashlytics key so a subsequent crash carries context
        Crashlytics.crashlytics().setCustomValue(rid, forKey: "lastRequestID")
        return order
    } catch {
        log.error("fetch failed orderID=\(id, privacy: .public) requestID=\(rid, privacy: .public) error=\(error, privacy: .public)")
        Crashlytics.crashlytics().record(error: error)
        throw error
    }
}
```

---

## 5. Correct log level

```swift
// ❌ level mismatch — .error for an expected empty state; .info for a money-path failure
log.error("no items found")                        // empty list is expected, not an error
log.info("payment failed: \(err.localizedDescription)") // payment failure must be .error

// ✅ levels matched to actual severity
log.info("items empty — showing placeholder")       // expected, routine
log.notice("migration complete version=\(newVersion, privacy: .public)") // notable, not alarming
log.error("payment failed orderID=\(id, privacy: .public) error=\(err, privacy: .public)") // unexpected, actionable
log.fault("Keychain unavailable — app cannot proceed") // system-level, requires immediate action
```

Level reference:
- `.debug` / `.trace` — dev noise, OS strips in release
- `.info` — routine lifecycle
- `.notice` — notable, expected
- `.warning` — recoverable anomaly
- `.error` — unexpected, actionable
- `.fault` — system-level emergency

---

## 6. Never swallow errors

```swift
// ❌ silent failure — nothing in logs, nothing in Crashlytics
do {
    try syncData()
} catch {}

// ❌ message logged but error object dropped — no stack, no type, no root cause
do {
    try syncData()
} catch {
    log.error("sync failed")
}

// ✅ log the error, forward unexpected errors to crash reporter, rethrow or handle
do {
    try syncData()
} catch {
    log.error("sync failed error=\(error, privacy: .public)")
    Crashlytics.crashlytics().record(error: error)
    // rethrow, show user-facing message, or recover — never silently discard
    throw error
}
```

---

## 7. No logging in hot paths or loops

```swift
// ❌ per-iteration log floods unified log, degrades scroll / render performance
for item in largeCollection {
    log.debug("processing itemID=\(item.id)")
    process(item)
}

// ❌ log inside a CADisplayLink / animation frame callback
displayLink.add(to: .main, forMode: .common)
func update(_ link: CADisplayLink) {
    log.debug("frame tick")   // fires 60–120× per second
}

// ✅ log once before + once after; include aggregate stats
log.info("batch start count=\(largeCollection.count, privacy: .public)")
largeCollection.forEach { process($0) }
log.info("batch complete count=\(largeCollection.count, privacy: .public)")

// ✅ for frame callbacks: sample, aggregate, or log only on state change
var frameCount = 0
func update(_ link: CADisplayLink) {
    frameCount += 1
    if frameCount % 300 == 0 {   // log once every 5 s at 60 fps
        log.debug("animation running frames=\(frameCount, privacy: .public)")
    }
}
```

---

## 8. Metrics for critical operations

```swift
// ❌ checkout flow logs only — no metric, nothing alertable
func checkout(cart: Cart) async throws -> Order {
    log.info("checkout start cartID=\(cart.id, privacy: .public)")
    let order = try await api.placeOrder(cart)
    log.info("checkout ok orderID=\(order.id, privacy: .public)")
    return order
}

// ✅ emit a Crashlytics custom event (or MetricKit / Sentry transaction) so failures are alertable
func checkout(cart: Cart) async throws -> Order {
    let start = Date()
    log.info("checkout start cartID=\(cart.id, privacy: .public)")
    do {
        let order = try await api.placeOrder(cart)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        log.info("checkout ok orderID=\(order.id, privacy: .public) durationMS=\(ms, privacy: .public)")
        Crashlytics.crashlytics().setCustomValue("success", forKey: "lastCheckoutResult")
        return order
    } catch {
        log.error("checkout failed cartID=\(cart.id, privacy: .public) error=\(error, privacy: .public)")
        Crashlytics.crashlytics().setCustomValue("failure", forKey: "lastCheckoutResult")
        Crashlytics.crashlytics().record(error: error)
        throw error
    }
}
```

MetricKit custom signal (for background / extension work):

```swift
// ✅ MetricKit — aggregate metrics reported by the OS, no PII risk
import MetricKit

class AppMetricSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // Log aggregate stats — never individual user data
            log.info("metricKit report received timeStamp=\(payload.timeStampBegin, privacy: .public)")
        }
    }
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            log.error("metricKit diagnostic received timeStamp=\(payload.timeStampBegin, privacy: .public)")
            // Forward aggregated diagnostic to backend / Crashlytics
        }
    }
}
```

---

## 9. Crash / error reporter — init and use

```swift
// ❌ Crashlytics in Package.swift but never initialised — crash reports never arrive
@main
struct MyApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
    // FirebaseApp.configure() missing
}

// ❌ error caught and logged, never forwarded — invisible to on-call
catch {
    log.error("download failed error=\(error, privacy: .public)")
    // Crashlytics never hears about it
}

// ✅ initialise before first view; forward unexpected errors
@main
struct MyApp: App {
    init() {
        FirebaseApp.configure()
        // Optional: enable collection explicitly (required in some regions)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }
    var body: some Scene { WindowGroup { ContentView() } }
}

// ✅ catch + log + forward
catch {
    log.error("download failed error=\(error, privacy: .public)")
    Crashlytics.crashlytics().record(error: error)
    throw error   // or surface to the user
}
```

Sentry variant:

```swift
// ✅ Sentry init
import Sentry

SentrySDK.start { options in
    options.dsn = Configuration.sentryDSN   // from build config, not hardcoded
    options.tracesSampleRate = 0.2
}

// ✅ Sentry error capture
catch {
    log.error("sync failed error=\(error, privacy: .public)")
    SentrySDK.capture(error: error)
    throw error
}
```

---

## 10. Actionable, contextual messages

```swift
// ❌ bare strings — useless in production; on-call cannot act
log.error("Failed")
log.error("Something went wrong")
log.warning("Error occurred")

// ✅ name the entity, operation, and state — everything on-call needs to start investigating
log.error("""
    imageLoad failed \
    url=\(url.absoluteString, privacy: .public) \
    httpStatus=\(httpStatus, privacy: .public) \
    attempt=\(attempt, privacy: .public)/\(maxAttempts, privacy: .public)
    """)

log.error("""
    CoreData save failed \
    entity=Order \
    orderID=\(order.id, privacy: .public) \
    error=\(error, privacy: .public)
    """)
```

---

## Do examples — full structured log with correlation ID + redaction

```swift
import os
import FirebaseCrashlytics

struct OrderService {
    static let log = Logger(subsystem: "com.example.app", category: "OrderService")

    func submit(_ order: Order, requestID: UUID = UUID()) async throws -> Receipt {
        let rid = requestID.uuidString
        // Set context on crash reporter so a subsequent crash carries the trace
        Crashlytics.crashlytics().setCustomValue(rid, forKey: "activeRequestID")
        Crashlytics.crashlytics().setCustomValue(order.id, forKey: "activeOrderID")

        Self.log.info("""
            order submit start \
            orderID=\(order.id, privacy: .public) \
            requestID=\(rid, privacy: .public) \
            itemCount=\(order.items.count, privacy: .public)
            """)
        // ✅ user.email never logged; token never logged
        do {
            let receipt = try await api.post("/orders", body: order)
            Self.log.info("""
                order submit ok \
                orderID=\(order.id, privacy: .public) \
                requestID=\(rid, privacy: .public) \
                receiptID=\(receipt.id, privacy: .public)
                """)
            return receipt
        } catch {
            Self.log.error("""
                order submit failed \
                orderID=\(order.id, privacy: .public) \
                requestID=\(rid, privacy: .public) \
                error=\(error, privacy: .public)
                """)
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
    }
}
```

---

## Review checklist

- [ ] No `print` / `NSLog` / `debugPrint` outside `#if DEBUG`.
- [ ] All `Logger` / `os_log` interpolations have explicit privacy annotations; PII/tokens → `.private`.
- [ ] Messages use labelled key=value fields, not concatenated prose.
- [ ] `requestID` / `traceID` propagated; appears in every log line and crash-reporter breadcrumb.
- [ ] Log levels match severity; `.error` only for unexpected failures.
- [ ] Every `catch` logs the error value and forwards unexpected errors to crash reporter.
- [ ] No log calls inside loops or frame/draw callbacks.
- [ ] Critical operations (payment, auth, job) emit at least one metric or crash-reporter signal.
- [ ] Crash reporter initialised at app start; caught unexpected errors forwarded.
- [ ] Every `.error` / `.fault` message names the entity, operation, and relevant state.

---

## Official references

- Apple — Logging (os.Logger): https://developer.apple.com/documentation/os/logging
- Apple — Logger: https://developer.apple.com/documentation/os/logger
- Apple — MetricKit: https://developer.apple.com/documentation/metrickit
- Apple — Privacy annotations (OSLogPrivacy): https://developer.apple.com/documentation/os/oslogprivacy
- Firebase Crashlytics iOS: https://firebase.google.com/docs/crashlytics/get-started?platform=ios
- Sentry iOS SDK: https://docs.sentry.io/platforms/apple/
- Team baseline: [../../guidance.md](../../guidance.md)
- PII / secrets depth: [ios-security reference](../ios-security/reference.md)
