# backend-observability — Reference

Deep-dive material for `SKILL.md`. **Anti-pattern (❌) vs correct (✅)** code samples per
failure mode. JVM/Kotlin first, Python and Go alongside. Decision criteria live in `SKILL.md`.

---

## Do — canonical patterns

### Structured log with trace ID (JVM/Kotlin + Logback JSON)

```kotlin
// Filter: inject traceId into MDC at request boundary
@Component
class TraceFilter : OncePerRequestFilter() {
    override fun doFilterInternal(req: HttpServletRequest, res: HttpServletResponse, chain: FilterChain) {
        val traceId = req.getHeader("X-Trace-Id") ?: UUID.randomUUID().toString()
        MDC.put("traceId", traceId)
        res.setHeader("X-Trace-Id", traceId)
        try { chain.doFilter(req, res) } finally { MDC.clear() }
    }
}

// Service: structured fields, no concatenation, no PII
private val log = LoggerFactory.getLogger(OrderService::class.java)

fun processOrder(userId: Long, orderId: Long, itemCount: Int) {
    log.info("order.processing_started", kv("userId", userId), kv("orderId", orderId), kv("itemCount", itemCount))
    // traceId is automatically included by Logback because it is in the MDC
}
// logback-spring.xml: <appender class="ch.qos.logback.contrib.json.classic.JsonLayout"> → emits JSON
```

### Structured log with trace ID (Python + structlog)

```python
import structlog
import structlog.contextvars

log = structlog.get_logger()

# FastAPI middleware: bind traceId for every request
@app.middleware("http")
async def trace_middleware(request: Request, call_next):
    structlog.contextvars.clear_contextvars()
    trace_id = request.headers.get("x-trace-id", str(uuid.uuid4()))
    structlog.contextvars.bind_contextvars(trace_id=trace_id)
    response = await call_next(request)
    response.headers["x-trace-id"] = trace_id
    return response

# Handler: structured key/value, no f-string concatenation, no PII
async def process_order(user_id: int, order_id: int, item_count: int):
    log.info("order.processing_started", user_id=user_id, order_id=order_id, item_count=item_count)
    # trace_id automatically present via contextvars binding
```

### Wiring a metric + Sentry (JVM/Kotlin + Micrometer)

```kotlin
@Service
class PaymentService(
    private val meterRegistry: MeterRegistry,
    private val paymentGateway: PaymentGateway,
) {
    private val log = LoggerFactory.getLogger(PaymentService::class.java)

    private val paymentTimer = meterRegistry.timer("payment.process")
    private val paymentSuccess = meterRegistry.counter("payment.result", "outcome", "success")
    private val paymentFailure = meterRegistry.counter("payment.result", "outcome", "failure")

    fun charge(orderId: Long, amountCents: Long): PaymentResult {
        return paymentTimer.record<PaymentResult> {
            runCatching { paymentGateway.charge(orderId, amountCents) }
                .onSuccess {
                    paymentSuccess.increment()
                    log.info("payment.charged", kv("orderId", orderId), kv("amountCents", amountCents))
                }
                .onFailure { e ->
                    paymentFailure.increment()
                    log.error("payment.failed", kv("orderId", orderId), kv("amountCents", amountCents), e)
                    Sentry.captureException(e)  // forward unexpected failure to error tracker
                }
                .getOrThrow()
        }
    }
}
```

---

## 1. Debug print left in production

```kotlin
// ❌ Quick debug output left in service code
fun getUser(id: Long): User {
    println("getUser called with id=$id")           // stdout, not in log pipeline
    val user = repo.findById(id)
    System.out.println("found: $user")              // prints PII, bypasses MDC/traceId
    return user
}

// ✅ Named logger, structured, trace ID automatic via MDC
private val log = LoggerFactory.getLogger(UserService::class.java)

fun getUser(id: Long): User {
    log.debug("user.fetch", kv("userId", id))       // debug level — off in production
    return repo.findById(id) ?: throw NotFoundException("user $id")
}
```

```python
# ❌
def get_user(user_id: int):
    print(f"get_user called: {user_id}")            # not in log pipeline, no trace_id
    user = db.query(User).filter_by(id=user_id).first()
    print(user)                                      # may dump PII
    return user

# ✅
log = structlog.get_logger()

def get_user(user_id: int):
    log.debug("user.fetch", user_id=user_id)        # structured, trace_id via contextvars
    return db.query(User).filter_by(id=user_id).first()
```

```go
// ❌
func GetUser(id int64) (*User, error) {
    fmt.Println("getUser", id)                       // bypasses slog, no traceId
    return repo.FindByID(id)
}

// ✅
func GetUser(ctx context.Context, id int64) (*User, error) {
    slog.DebugContext(ctx, "user.fetch", "userId", id)  // context carries traceId attr
    return repo.FindByID(ctx, id)
}
```

---

## 2. PII / secrets in logs

```kotlin
// ❌ Logging the whole entity (email, phone, address inside) + token
fun login(email: String, password: String): String {
    val user = userRepo.findByEmail(email)
    val token = jwtService.issue(user)
    log.info("login successful: user={}, token={}", user, token)   // PII + secret in log
    return token
}

// ✅ Log IDs and event category only; never the token or user object
fun login(email: String, password: String): String {
    val user = userRepo.findByEmail(email) ?: throw UnauthorizedException()
    val token = jwtService.issue(user)
    log.info("auth.login_success", kv("userId", user.id), kv("role", user.role))
    return token
}
```

```python
# ❌
log.info("payment_processed", user=user.__dict__, card_number=card.number)  # PII + PAN

# ✅ Log only IDs and typed summary; for PII depth see backend-security-guard
log.info("payment.processed", user_id=user.id, order_id=order.id, masked_pan=card.masked_pan)
```

```go
// ❌
slog.Info("request received",
    "authorization", r.Header.Get("Authorization"),  // credential in log
    "body", string(body))                             // may contain PII

// ✅
slog.InfoContext(ctx, "request.received",
    "method", r.Method,
    "path", r.URL.Path,
    "content_length", r.ContentLength)
```

---

## 3. Unstructured logging (string concatenation)

```kotlin
// ❌ String-concatenated message — unqueryable, breaks log aggregation
log.info("User " + userId + " performed " + action + " on resource " + resourceId + " result=" + result)

// ✅ Structured fields — each key is independently filterable in Kibana/Datadog/Loki
log.info("resource.action",
    kv("userId", userId),
    kv("action", action),
    kv("resourceId", resourceId),
    kv("result", result))
```

```python
# ❌ f-string baked into the message
logger.info(f"User {user_id} did {action} on {resource_id}: result={result}")

# ✅ Keyword arguments — structlog renders these as JSON fields
log.info("resource.action", user_id=user_id, action=action, resource_id=resource_id, result=result)
```

```go
// ❌
slog.Info("user " + strconv.FormatInt(userID, 10) + " processed order " + strconv.FormatInt(orderID, 10))

// ✅
slog.InfoContext(ctx, "order.processed", "userId", userID, "orderId", orderID)
```

---

## 4. Missing correlation / trace ID

```kotlin
// ❌ Logging in a controller with no traceId — impossible to correlate across services
@GetMapping("/orders/{id}")
fun getOrder(@PathVariable id: Long): OrderResponse {
    log.info("Fetching order {}", id)   // which request? which user? which trace?
    return orderService.get(id).toResponse()
}

// ✅ TraceFilter (see Do section above) puts traceId in MDC; every subsequent log carries it
@GetMapping("/orders/{id}")
fun getOrder(@PathVariable id: Long): OrderResponse {
    log.info("order.fetch", kv("orderId", id))   // traceId auto-included by Logback MDC layout
    return orderService.get(id).toResponse()
}
```

```python
# ❌ No trace binding — logs from concurrent requests are indistinguishable
async def get_order(order_id: int):
    log.info("fetching order", order_id=order_id)  # which request called this?
    return await order_service.get(order_id)

# ✅ trace_middleware (see Do section above) binds trace_id via contextvars before this runs
async def get_order(order_id: int):
    log.info("order.fetch", order_id=order_id)   # trace_id automatically present
    return await order_service.get(order_id)
```

```go
// ❌ context not threaded through — slog has no trace ID to attach
func (s *OrderService) Get(id int64) (*Order, error) {
    slog.Info("order.fetch", "orderId", id)   // no traceId
    return s.repo.FindByID(id)
}

// ✅ Middleware injects traceId into context; pass ctx through every call
func (s *OrderService) Get(ctx context.Context, id int64) (*Order, error) {
    slog.InfoContext(ctx, "order.fetch", "orderId", id)   // slog.SetDefault uses ctx attrs
    return s.repo.FindByID(ctx, id)
}

// Middleware pattern (chi/net http):
func TraceMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        traceID := r.Header.Get("X-Trace-Id")
        if traceID == "" { traceID = uuid.New().String() }
        ctx := context.WithValue(r.Context(), traceKey{}, traceID)
        w.Header().Set("X-Trace-Id", traceID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

---

## 5. Wrong log level

```kotlin
// ❌ ERROR for expected control flow (404) — alert fatigue + meaningless dashboards
fun getOrder(id: Long): Order {
    return orderRepo.findById(id)
        ?: run { log.error("Order not found: {}", id); throw NotFoundException() }
}

// ❌ INFO for a genuine payment failure — hides real errors
fun charge(orderId: Long): PaymentResult {
    return try { gateway.charge(orderId) }
    catch (e: PaymentException) { log.info("Payment failed", e); throw e }
}

// ✅ Level matches severity: 404 is WARN (expected), payment failure is ERROR (unexpected)
fun getOrder(id: Long): Order {
    return orderRepo.findById(id)
        ?: run { log.warn("order.not_found", kv("orderId", id)); throw NotFoundException() }
}

fun charge(orderId: Long): PaymentResult {
    return try { gateway.charge(orderId) }
    catch (e: PaymentException) {
        log.error("payment.gateway_error", kv("orderId", orderId), e)   // ERROR → triggers alert
        throw e
    }
}
```

```python
# ❌
log.error("user_not_found", user_id=user_id)   # 404 is not an error

# ✅
log.warning("user.not_found", user_id=user_id)   # warn: expected, caller gets 404
```

---

## 6. Swallowed error

```kotlin
// ❌ Silent swallow — exception and stack completely lost
try {
    inventoryService.reserve(orderId, items)
} catch (e: Exception) { }   // nothing logged, nothing reported

// ❌ Message only — stack trace gone, cause unknown
} catch (e: Exception) {
    log.error("reservation failed")   // `e` not passed → no stack, no cause
}

// ✅ Log exception object (stack + cause) AND forward to error reporter
} catch (e: Exception) {
    log.error("inventory.reservation_failed", kv("orderId", orderId), e)   // `e` as last arg → SLF4J logs stack
    Sentry.captureException(e)
    throw InternalException("reservation failed", e)
}
```

```python
# ❌
try:
    inventory_service.reserve(order_id, items)
except Exception:
    pass   # silent swallow

# ❌
except Exception as e:
    log.error("reservation failed")   # e never logged

# ✅
except Exception as e:
    log.error("inventory.reservation_failed", order_id=order_id, exc_info=True)  # exc_info=True → stack
    sentry_sdk.capture_exception(e)
    raise
```

```go
// ❌
if err := inventoryService.Reserve(ctx, orderID, items); err != nil {
    // silently ignored — caller never knows
}

// ❌
if err != nil {
    slog.Error("reservation failed")   // err not included
}

// ✅
if err := inventoryService.Reserve(ctx, orderID, items); err != nil {
    slog.ErrorContext(ctx, "inventory.reservation_failed", "orderId", orderID, "error", err)
    sentry.CaptureException(err)
    return fmt.Errorf("reserve order %d: %w", orderID, err)
}
```

---

## 7. Logging in hot path / loop

```kotlin
// ❌ Per-item log inside a loop — millions of lines/min under load
fun importProducts(products: List<Product>) {
    for (product in products) {
        log.info("Importing product {}", product.id)   // O(n) logs
        productRepo.save(product)
    }
}

// ✅ Log once before and once after with a count summary
fun importProducts(products: List<Product>) {
    log.info("product.import_started", kv("count", products.size))
    productRepo.saveAll(products)
    log.info("product.import_completed", kv("count", products.size))
}
```

```python
# ❌
for row in rows:
    log.info("processing row", row_id=row["id"])   # O(n) log entries

# ✅
log.info("batch.processing_started", count=len(rows))
process_all(rows)
log.info("batch.processing_completed", count=len(rows))
```

```go
// ❌ — inside a tight event loop
for _, item := range items {
    slog.InfoContext(ctx, "processing item", "itemId", item.ID)
}

// ✅
slog.InfoContext(ctx, "batch.started", "count", len(items))
for _, item := range items {
    process(ctx, item)
}
slog.InfoContext(ctx, "batch.completed", "count", len(items))
```

---

## 8. No metrics (logs only)

```kotlin
// ❌ Verbose logs for the auth flow — but nothing alertable, no dashboard
fun authenticate(credentials: Credentials): AuthResult {
    log.info("Attempting authentication for username={}", credentials.username)
    val result = authProvider.authenticate(credentials)
    log.info("Authentication result={} username={}", result.status, credentials.username)
    return result
}

// ✅ Counter + timer; logs describe, metrics alert
@Service
class AuthService(private val meterRegistry: MeterRegistry) {
    private val authTimer  = meterRegistry.timer("auth.attempt")
    private val authOk     = meterRegistry.counter("auth.result", "outcome", "success")
    private val authFail   = meterRegistry.counter("auth.result", "outcome", "failure")

    fun authenticate(userId: Long, credentials: Credentials): AuthResult {
        return authTimer.record<AuthResult> {
            authProvider.authenticate(credentials).also { result ->
                if (result.success) { authOk.increment(); log.info("auth.success", kv("userId", userId)) }
                else                { authFail.increment(); log.warn("auth.failure", kv("userId", userId)) }
            }
        }
    }
}
```

```python
# ❌ — no metrics, only logs
def process_job(job_id: int):
    log.info("job.started", job_id=job_id)
    run_job(job_id)
    log.info("job.completed", job_id=job_id)

# ✅ — OpenTelemetry metrics alongside logs
from opentelemetry import metrics
meter = metrics.get_meter("jobs")
job_counter = meter.create_counter("job.executions")
job_duration = meter.create_histogram("job.duration_ms")

def process_job(job_id: int):
    log.info("job.started", job_id=job_id)
    start = time.monotonic()
    try:
        run_job(job_id)
        job_counter.add(1, {"outcome": "success"})
        log.info("job.completed", job_id=job_id)
    except Exception as e:
        job_counter.add(1, {"outcome": "failure"})
        log.error("job.failed", job_id=job_id, exc_info=True)
        raise
    finally:
        job_duration.record((time.monotonic() - start) * 1000, {"job_id": str(job_id)})
```

---

## 9. Missing crash / error reporting

```kotlin
// ❌ Sentry never initialized; caught exceptions never forwarded
@SpringBootApplication
class App

// ❌ Catch handles it "locally" — error dashboard stays empty
} catch (e: ExternalApiException) {
    log.error("External API failed", e)   // logged, but NOT in Sentry → no alert, no trend
}

// ✅ Initialize Sentry in application.yml + SentryOptions, and capture explicitly
// application.yml: sentry.dsn: ${SENTRY_DSN}
// Spring Boot Sentry starter handles init automatically via sentry-spring-boot-starter

} catch (e: ExternalApiException) {
    log.error("external.api_failed", kv("service", "payment-gateway"), e)
    Sentry.captureException(e)   // also visible in Sentry error dashboard + triggers alert rules
    throw ServiceUnavailableException("payment gateway unavailable", e)
}
```

```python
# ❌ No Sentry init — exception is logged but never tracked
import logging
log = logging.getLogger(__name__)

def call_external(url: str):
    try:
        return requests.get(url, timeout=5)
    except requests.RequestException as e:
        log.error("external call failed", exc_info=True)   # not in error tracker

# ✅
import sentry_sdk
sentry_sdk.init(dsn=os.environ["SENTRY_DSN"], traces_sample_rate=0.1)  # init at startup

def call_external(url: str):
    try:
        return requests.get(url, timeout=5)
    except requests.RequestException as e:
        log.error("external.call_failed", url=url, exc_info=True)
        sentry_sdk.capture_exception(e)   # tracked in Sentry
        raise
```

---

## 10. Non-actionable message

```kotlin
// ❌ No IDs, no context — useless in an incident
log.error("Error occurred")
log.error("Failed")
log.warn("Something went wrong while processing")

// ✅ Every field answers a question an on-call engineer would ask
log.error("order.fulfillment_failed",
    kv("orderId", orderId),
    kv("userId", userId),
    kv("warehouseId", warehouseId),
    kv("itemCount", items.size),
    kv("failureReason", e.reason),
    e)
// An on-call engineer sees: which order, which user, which warehouse, how many items, why → act immediately
```

```python
# ❌
log.error("failed")
log.warning("something went wrong")

# ✅
log.error("order.fulfillment_failed",
    order_id=order_id,
    user_id=user_id,
    warehouse_id=warehouse_id,
    item_count=len(items),
    failure_reason=str(e),
    exc_info=True)
```

```go
// ❌
slog.Error("error occurred")

// ✅
slog.ErrorContext(ctx, "order.fulfillment_failed",
    "orderId", orderID,
    "userId", userID,
    "warehouseId", warehouseID,
    "itemCount", len(items),
    "error", err)
```

---

## Vibe-guard review checklist

- [ ] No `println` / `print()` / `fmt.Println` / `System.out` in server paths.
- [ ] No PII, tokens, passwords, Authorization headers in any log line.
- [ ] All messages use structured key/value fields (no `+`/f-string concatenation).
- [ ] TraceId injected per-request and auto-included in every log (MDC / contextvars / ctx).
- [ ] Level discipline: `ERROR` only for unexpected failures; 404/validation at `WARN`.
- [ ] Every catch logs the exception object (stack) or re-throws — no silent swallows.
- [ ] No log calls inside tight loops or high-frequency callbacks.
- [ ] Critical operations (payment/auth/job) emit counter + timer metrics.
- [ ] Sentry initialized at startup; unexpected caught exceptions forwarded via `captureException`.
- [ ] Every log line carries entity IDs and operation context — no bare "failed".

## Official references

- OpenTelemetry SDK: https://opentelemetry.io/docs/
- Micrometer: https://micrometer.io/docs
- SLF4J MDC guide: https://www.slf4j.org/manual.html#mdc
- Logback JSON layout: https://github.com/qos-ch/logback-contrib/wiki/Json
- structlog contextvars: https://www.structlog.org/en/stable/contextvars.html
- Go slog: https://pkg.go.dev/log/slog
- Sentry Java SDK: https://docs.sentry.io/platforms/java/
- Sentry Python SDK: https://docs.sentry.io/platforms/python/
- Team baseline: [../../guidance.md](../../guidance.md)
- PII/secret depth: [backend-security-guard](../backend-security-guard/SKILL.md)
