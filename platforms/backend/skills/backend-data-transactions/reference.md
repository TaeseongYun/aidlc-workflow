# backend-data-transactions — Reference

Deeper material for `SKILL.md`. N+1 · idempotency key · migration · money/time ·
encryption samples.

## 1. N+1 prevention

```kotlin
// Bad: after loading orders, accessing each order.items runs N queries
orders.forEach { it.items.size }                 // N+1

// Good: fetch join / @EntityGraph in one shot
@Query("select o from Order o join fetch o.items where o.userId = :uid")
fun findWithItems(uid: Long): List<Order>

@EntityGraph(attributePaths = ["items"])
fun findByUserId(uid: Long): List<Order>
```

```typescript
// TypeORM: explicit relations / Prisma: include
const orders = await repo.find({ where: { userId }, relations: { items: true } });
const orders2 = await prisma.order.findMany({ where: { userId }, include: { items: true } });
```

## 2. Idempotency — idempotency key

An entry point that an external party may retry (webhook · payment callback ·
message) absorbs duplicates with a key.

```kotlin
@Service
class WebhookService(private val processed: ProcessedEventRepository) {
    @Transactional
    fun handle(eventId: String, payload: Payload): Result {
        // 1) if the event is already processed, return the existing result (side effect once even on re-run)
        processed.findById(eventId)?.let { return it.result }
        // 2) process + record the result and key in the same transaction
        val result = doWork(payload)
        processed.save(ProcessedEvent(eventId, result))   // a unique constraint also guards against races
        return result
    }
}
```

- Store the key and the side effect in the **same transaction**. A DB unique constraint
  also blocks concurrent duplicates.
- For payments and the like, use the idempotency key the provider gives (e.g. Stripe
  `Idempotency-Key`).

## 3. Migrations (no ddl-auto)

```yaml
# application.yml (production)
spring:
  jpa:
    hibernate:
      ddl-auto: validate      # none/validate. no update/create-drop
  flyway:
    enabled: true             # schema only via Flyway migrations
```

```sql
-- db/migration/V12__add_orders_status.sql  (reversible; do breaking changes in stages)
ALTER TABLE orders ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'PENDING';
```

- Breaking changes like dropping/retyping a column go in stages (add → backfill →
  dual-write → switch → drop).

## 4. Money · time

```kotlin
// Money: integer minor units or BigDecimal. No double/float
@JvmInline value class Money(val minorUnits: Long)   // 1000 = 10.00
// When using BigDecimal, specify scale/RoundingMode. Use compareTo instead of ==.

// Time: UTC at the boundary (Instant / timestamptz). Convert only at display time
val now: Instant = Instant.now()
```

```typescript
// Node: money as integer minor units or a decimal library. No Number(float)
// Time: store Date as UTC, convert with Intl at display time
```

## 5. Encryption at rest (sensitive columns)

```kotlin
// Column-level encryption via a JPA AttributeConverter. Key injected from the secret manager
@Converter
class EncryptedStringConverter(private val cipher: FieldCipher) : AttributeConverter<String, String> {
    override fun convertToDatabaseColumn(attribute: String?) = attribute?.let(cipher::encrypt)
    override fun convertToEntityAttribute(dbData: String?) = dbData?.let(cipher::decrypt)
}
```

- Do not put the key in code/VCS → [backend-security-guard], [backend-reliability].
- Do not implement your own crypto algorithm — standard AES-GCM + `SecureRandom` IV.

## 6. Review checklist

- [ ] Write transaction boundary at one service method, read-only marked.
- [ ] Relation fetch explicit, no query inside a loop (N+1).
- [ ] Entities do not leak into responses (DTO mapping).
- [ ] Request DTO accepts only allowed fields (over-binding prevention).
- [ ] Retryable handlers idempotent via an idempotency key.
- [ ] Money integer/decimal, time UTC.
- [ ] Schema changes as migration files (ddl-auto=validate/none).
- [ ] Sensitive-column encryption key from the secret manager.

## Official references

- OWASP API3:2023 (BOPLA): https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/
- Mass Assignment Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html
- Cryptographic Storage Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html
- Spring Data JPA: https://docs.spring.io/spring-data/jpa/reference/
- Flyway: https://documentation.red-gate.com/flyway
- Team baseline: [../../guidance.md](../../guidance.md)
