# Backend Module Structure — detailed reference

Deeper material for `SKILL.md`. Build files and hands-on examples for the
domain `api`/`impl` pair. The rules themselves are canonical in `SKILL.md`.

## 1. Gradle layout

```kotlin
// settings.gradle.kts
include(":app")
include(":domain:order:api")
include(":domain:order:impl")
include(":domain:payment:api")
include(":domain:payment:impl")
// optional shared leaf:
include(":core:common")
```

```kotlin
// domain/order/api/build.gradle.kts — plain library, no framework deps
plugins { alias(libs.plugins.kotlin.jvm) }
dependencies {
    implementation(project(":core:common"))
}
```

```kotlin
// domain/order/impl/build.gradle.kts
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.spring.boot.library)   // convention plugin: spring + jpa deps
}
dependencies {
    implementation(project(":domain:order:api"))     // its own contract
    implementation(project(":domain:payment:api"))   // calls payment — api only
}
```

```kotlin
// app/build.gradle.kts — the only module that sees impls
plugins { alias(libs.plugins.spring.boot.application) }
dependencies {
    implementation(project(":domain:order:impl"))
    implementation(project(":domain:payment:impl"))
}
```

`app` holds the `@SpringBootApplication` main class and configuration only; its
component scan picks up every impl on the classpath.

## 2. What crosses the api boundary

```kotlin
// domain/order/api — interface + DTO + event, nothing else
interface OrderQueryPort {
    fun findSummary(orderId: OrderId): OrderSummary?
}

data class OrderSummary(val id: OrderId, val totalAmount: Money, val status: String)

data class OrderCompletedEvent(val orderId: OrderId, val amount: Money)
```

```kotlin
// domain/order/impl — implements the port, everything internal
@Service
internal class OrderQueryService(
    private val repository: OrderRepository,          // never visible outside impl
) : OrderQueryPort {
    override fun findSummary(orderId: OrderId): OrderSummary? =
        repository.findByIdOrNull(orderId.value)?.toSummary()   // entity → DTO here
}
```

```kotlin
// domain/payment/impl — a consumer sees only the port and DTOs
@Service
internal class PaymentService(
    private val orderQuery: OrderQueryPort,           // injected; impl unknown
) {
    fun charge(orderId: OrderId) {
        val order = orderQuery.findSummary(orderId) ?: throw OrderNotFound(orderId)
        // ...
    }
}
```

Key points:

- The JPA entity never crosses the boundary — the impl maps to the `api` DTO
  at the edge.
- The consumer's compile classpath contains only `:domain:order:api`; a build
  fails fast if someone reaches for the entity or repository.
- Cross-domain transactions: a synchronous port call joins the caller's
  transaction — keep those calls read-only where possible, and prefer an event
  (below) when the reaction can be eventually consistent.

## 3. Domain events across domains

```kotlin
// domain/order/impl — publish at the transaction boundary
applicationEventPublisher.publishEvent(OrderCompletedEvent(order.id, order.total))
```

```kotlin
// domain/payment/impl — consume idempotently, after commit
@TransactionalEventListener
fun on(event: OrderCompletedEvent) { /* idempotent handler */ }
```

The event type lives in the publisher's `api`; the handler lives in the
consumer's `impl`. Neither impl knows the other exists.

## 4. Second deployable

A batch/worker/admin deployable is another thin bootstrap module beside `app`,
reusing the same domain impls it needs:

```kotlin
// batch/build.gradle.kts
dependencies {
    implementation(project(":domain:order:impl"))    // only the domains it runs
}
```

Bootstrap modules never share code with each other — shared logic is already in
the domains.

## 5. Node/TypeScript workspace mapping

Same rules, workspace packages instead of Gradle modules:

```
packages/
  app/                    # bootstrap: server setup, DI container wiring
  domain-order-api/       # interfaces, DTOs, event types (types + ports only)
  domain-order-impl/      # controllers, services, repositories
  domain-payment-api/
  domain-payment-impl/
```

- `domain-payment-impl` lists `domain-order-api` in `dependencies` — never
  `domain-order-impl`.
- Enforce with `package.json` `exports` (api packages export their public
  surface; impl packages export only a registration function for the app).

## 6. Structure review checklist

- [ ] Every domain has the `:domain:<name>:api` + `:domain:<name>:impl` pair.
- [ ] `api` modules contain interfaces/DTOs/events only — no entities,
      controllers, services, or framework config.
- [ ] `api` modules have no Spring web/data dependencies.
- [ ] Only bootstrap modules (`app`, `batch`, …) depend on impls.
- [ ] Cross-domain calls go through injected `api` ports, returning DTOs.
- [ ] Impl internals are `internal`/package-private.
- [ ] `app` is bootstrap and wiring only.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Layer rules inside a module: [../backend-architecture/SKILL.md](../backend-architecture/SKILL.md)
