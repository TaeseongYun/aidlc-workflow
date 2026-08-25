# backend-architecture — Reference

Deeper material for `SKILL.md`. Detailed layer responsibilities · port/adapter ·
event slice samples. See `SKILL.md` for the rule summary and decision criteria.

## 1. Detailed layer responsibilities

| Layer | Owns | Forbidden | Returns/Exposes |
|-------|------|-----------|-----------------|
| Controller/Handler | input parsing/validation, DTO mapping, delegation | business logic, direct Repo access, transactions | Request/Response DTO |
| Service(UseCase) | business rules, **transaction boundary**, orchestration | web-type imports, HTTP status decisions | domain model / result object |
| Repository | persistence operations (domain-shaped) | business rules, web types | domain model (entities only within the boundary) |
| External Adapter | external calls, retry/timeout/error mapping | business rules | domain model / port result |
| Domain model | invariants, value rules | web/framework imports | pure domain |

## 2. Port/Adapter (external systems)

Put external systems behind a service-owned **port (interface)**, with the adapter
implementing it. The service knows only the port, not the implementation details
(HTTP/gRPC/SDK).

```kotlin
// Port: defined by the service (domain language)
interface PaymentPort {
    fun charge(order: OrderId, amount: Money): PaymentResult
}

// Adapter: infra layer. Timeout/retry/error mapping goes here.
@Component
class StripePaymentAdapter(private val client: StripeClient) : PaymentPort {
    override fun charge(order: OrderId, amount: Money): PaymentResult =
        runCatching { client.charge(order.value, amount.minorUnits) }
            .fold(::toDomainResult, ::mapToDomainError)  // map external errors to domain errors
}
```

```typescript
// Node/Nest: same principle. Port is domain, adapter is infra.
export interface PaymentPort {
  charge(order: OrderId, amount: Money): Promise<PaymentResult>;
}

@Injectable()
export class StripePaymentAdapter implements PaymentPort {
  constructor(private readonly client: StripeClient) {}
  async charge(order: OrderId, amount: Money): Promise<PaymentResult> {
    // timeout/retry/error mapping go in the adapter → backend-reliability
  }
}
```

## 3. Transaction boundary = Service

The unit of work is one service method. Do not open transactions in the controller
or repository.

```kotlin
@Service
class TransferService(private val accounts: AccountRepository) {
    @Transactional                                   // the boundary is here, only here
    fun transfer(from: AccountId, to: AccountId, amount: Money) {
        val src = accounts.findByIdOrThrow(from)
        val dst = accounts.findByIdOrThrow(to)
        src.withdraw(amount); dst.deposit(amount)    // domain rules stay in the domain
        accounts.saveAll(listOf(src, dst))
    }
}
```

- Mark read-only paths as read-only (`@Transactional(readOnly = true)`).
- A controller must not call two services to stitch a business rule together → the
  rule gets scattered.

## 4. Async/event slice — idempotent consumer

Split async processing into an event/queue consumer, but the handler must be
**idempotent** (duplicate delivery is normal). Details in
[backend-data-transactions] §idempotency.

```
Producer(service) → Queue/Topic → Consumer(handler, ignores duplicates via idempotency key)
```

## 5. Module baseline

Follow the project's existing layout. Absent one:

```
api/ (or app/)   # controllers, request/response DTOs, exception handlers
domain/          # entities, domain services, repository interfaces
infra/           # repository impls, external clients, config
batch/           # scheduled/batch jobs (if any)
```

Single module until single module is no longer enough. Split when a second
deployable or a shared domain forces it.

## 6. Architecture review checklist

- [ ] No business logic / direct Repo access in the Controller.
- [ ] One transaction boundary at the service method. Read-only paths marked.
- [ ] Entities do not cross the controller boundary — responses are explicit DTOs.
- [ ] External calls behind a port/adapter. Timeout/retry/error mapping present.
- [ ] No web/framework imports in the domain model.
- [ ] Writes spanning multiple repositories are in one transaction.
- [ ] Schema changes go through a migration file.
- [ ] Async handlers are idempotent.
- [ ] Slices promoted on a real signal (no preemptive UseCase/CQRS).

## Official references

- OWASP Top 10 2021: https://owasp.org/Top10/
- OWASP API Security Top 10 2023: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- OWASP Cheat Sheet Series: https://cheatsheetseries.owasp.org/
- Spring Boot Reference: https://docs.spring.io/spring-boot/documentation.html
- 12-Factor App: https://12factor.net/
- Team baseline: [../../guidance.md](../../guidance.md)
