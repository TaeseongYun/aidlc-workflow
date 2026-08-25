---
name: backend-data-transactions
description: Backend data · transaction rules — transaction boundary in the service, JPA N+1 prevention, schema changes via migrations (Flyway/Liquibase, no ddl-auto), idempotency (webhook · payment · message duplicate handling), preventing sensitive-data/PII excessive exposure (no entity-direct responses · no Mass Assignment), money as integer minor units/decimal (no floating point) · time at UTC boundary, encryption at rest/in transit. Use when authoring or reviewing Repository · Entity · migration files, or designing transaction boundary · concurrency · idempotent handling. Covers both Spring Data JPA (Kotlin/Java) and Node/TS (TypeORM/Prisma). Backend data & transaction rules: transaction boundary, N+1, idempotency, migrations, PII exposure, money/time.
when_to_use: Touching Repository/Entity/DTO mapping, distinguishing transaction boundary/read-only, N+1 fetch strategy, idempotent handling of webhooks/payments/consumers, schema migrations, designing money/time/PII fields
paths: **/*Repository.kt, **/*Repository.java, **/repository/**, **/entity/**, **/domain/**, **/*Entity.kt, **/*Entity.java, **/*Service.kt, **/db/migration/**, **/migration/**, **/*.entity.ts, **/*.repository.ts, **/prisma/schema.prisma
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# backend-data-transactions — data · transactions

The baseline for data integrity: transaction boundary · idempotency · sensitive-data
exposure · money/time handling. Expands the "Data & Transactions" section of
`../../guidance.md` to an actionable-decision level. Deeper material (N+1 examples,
idempotency key patterns, migration samples) lives in [reference.md](./reference.md).

## Scope

- In scope: transaction boundary, JPA/ORM fetch strategy, migrations, idempotency,
  sensitive-data/PII exposure, money · time, encryption at rest/in transit.
- Out of scope: attack patterns like injection/deserialization →
  [backend-security-guard], authN/authZ → [backend-auth], deciding the response
  schema shape → [backend-api-contract].

## Core rules (do / don't)

### Transaction boundary

- **DO** keep the transaction at **one service method** (unit of work). Mark read-only
  paths as read-only (`@Transactional(readOnly = true)`).
- **DON'T** open transactions in the controller/repository. Do not let writes spanning
  multiple repositories scatter without a transaction.

### JPA / ORM

- **DO** default relations to **lazy**, fetch explicitly per use case (fetch join /
  `@EntityGraph` / Prisma `include`). Catch N+1 in review.
- **DON'T** expose an entity past the controller boundary — responses are explicit DTOs
  (excessive exposure · BOPLA). Mapping is explicit (no reflection magic).

### Idempotency (duplicate delivery is normal)

- **DO** make a handler that an external party may call more than once (webhook ·
  payment callback · message consumer) **idempotent**: store an idempotency key and
  return the existing result on re-execution.
- **DON'T** assume "exactly-once delivery." Retries and duplicates are the default.

### Sensitive data / excessive exposure / over-binding

- **DO** put only the needed fields on the response DTO. Bind only allowed fields on
  the request DTO (Mass Assignment prevention) — do not accept fields like
  `role`/`isAdmin`/`balance` in the request body.
- **DO** **hash** passwords (bcrypt/argon2/scrypt); store tokens · PII to the minimum
  necessary. → hashing details in [backend-auth].

### Money · time

- **DO** money as integer **minor units** (cents) or `BigDecimal`. **No floating point**
  (no money math in `double`/`float`).
- **DO** store/transmit time as **UTC** at the boundary. Convert to a timezone only at
  display time.

### Encryption at rest/in transit · migrations

- **DO** ship schema changes as migration files (Flyway/Liquibase/Prisma Migrate).
  **Do not change the production schema with `ddl-auto`.**
- **DO** use TLS in transit; encrypt sensitive columns at rest (app-level or DB TDE).
  Keys from the secret manager → [backend-reliability], [backend-security-guard].

## Data-change checklist

| # | Check | If it fails |
|---|-------|-------------|
| 1 | Is the write transaction boundary at one service method? | Move to the service |
| 2 | Is the read-only path read-only? | Mark it |
| 3 | Is relation fetch explicit and free of N+1? | fetch join/EntityGraph |
| 4 | Do entities not leak into responses? | DTO mapping |
| 5 | Does the request DTO accept only allowed fields? | Remove internal fields |
| 6 | Are retryable handlers idempotent? | idempotency key |
| 7 | Is money integer/decimal, time UTC? | Fix the type |
| 8 | Does the schema change have a migration? | Add a migration (no ddl-auto) |

## Refactor / red-flag signals

- Transaction in the controller/repository, or no transaction on multi-writes.
- Entity serialized into a response (excessive exposure of sensitive data).
- Request body receiving authority/balance fields like `role`/`isAdmin`/`balance`.
- N+1 from repeated fetches (query inside a loop).
- Webhook/payment/consumer handler double-processing on duplicate delivery.
- Money stored as `double`/`float`, time stored in a local timezone.
- Schema changed via `ddl-auto` without a migration.

## References

- Team baseline: [../../guidance.md](../../guidance.md) (Data & Transactions section)
- Deeper material: [reference.md](./reference.md)
- Umbrella: [backend-architecture](../backend-architecture/SKILL.md)
- Related: [backend-security-guard](../backend-security-guard/SKILL.md), [backend-auth](../backend-auth/SKILL.md)
- Mass Assignment Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html
- OWASP API3:2023 (Broken Object Property Level Authorization): https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/
