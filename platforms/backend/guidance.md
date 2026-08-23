# Backend Architecture — Current Guidance

Baseline for backend work. Primary stack: Kotlin/Java + Spring Boot + JPA +
Gradle. The same boundaries apply to a Node/TypeScript service; framework
names change, layers do not. Project `ctx/` overrides this document; this
document overrides the agent's general knowledge.

## Boundaries

Dependency flow (never reversed):

```
Controller/Handler -> Service (UseCase) -> Repository -> DB / External Client Adapter
```

- Controllers parse/validate input, map to DTOs, and delegate. No business
  logic, no repository access, no transaction management.
- Services own business rules and **transaction boundaries**. One service
  method = one unit of work; do not open transactions in controllers or
  repositories.
- Repositories expose domain-shaped operations, not leaked query language.
  Entities do not cross the controller boundary — responses are explicit DTOs.
- External systems (payment, notification, other services) sit behind a
  project-owned client interface (port/adapter). Retries, timeouts, and error
  mapping live in the adapter, not in the service.
- Domain models/entities have no web-layer imports.

## API Contract

- The response shape is part of the requirement, never an implementation
  detail. This aligns with `ctx-run`'s RESPONSE SHAPE LOCK: if the shape is
  not explicitly decided, STOP and ask — do not pick String vs List, nullable
  vs default, or flat vs nested on your own.
- New/changed endpoints are recorded in the feature's technical design
  (Section 3) with method, path, request/response schema, and error responses.
- Error responses follow the project's existing error envelope; do not invent
  a second format.
- Backward compatibility: additive changes only on public APIs; removing or
  retyping a field is a design decision requiring approval
  (`extensions/api-contract/` rules when opted in).

## Data & Transactions

- Schema changes ship as migrations (Flyway/Liquibase or the project's tool),
  never by editing DDL by hand or relying on `ddl-auto`.
- Transaction boundary at the service layer; read-only paths marked read-only.
- Watch N+1 on JPA relations: default lazy, fetch explicitly per use case.
- Any handler that external systems may call more than once (webhooks,
  payment callbacks, message consumers) must be idempotent.
- Time in UTC at the boundary; money as integer minor units or decimal —
  never floating point.

## Trust Boundaries

- Validate every external input at the controller boundary (bean validation
  or the project's validator) — types, ranges, and business preconditions
  before the service runs.
- AuthN/AuthZ checks live in the existing security layer (filter/interceptor/
  middleware); services may re-assert ownership rules on resource access.
- Never log secrets, tokens, or full PII; follow
  `extensions/security/security-baseline.md` items when opted in.

## Module Baseline

Follow the project's existing layout. Absent one:

```
api/ (or app/)           # controllers, request/response DTOs, exception handlers
domain/                  # entities, domain services, repository interfaces
infra/                   # repository impls, external clients, config
batch/                   # scheduled/batch jobs (if any)
```

Single-module is fine until a second deployable or a shared domain forces a
split.

## Feature Slice Decision Table

| Situation | Slice |
|-----------|-------|
| Simple CRUD over one aggregate | Controller → Service → Repository |
| Business rules across aggregates or external calls | + explicit UseCase methods, adapter interfaces |
| Async/deferred processing | + event or queue consumer, idempotent handler |
| Read model diverging from write model | separate query service/DTO path — not a full CQRS framework |

## Rules

- One service method per use case; no controller calling two services to
  stitch a business rule together.
- DTO ↔ entity mapping is explicit (constructor/factory/mapper) — no
  reflection magic that hides field drift.
- New dependency = justification in the PR; prefer stdlib/framework built-ins
  (ties to `core/lazy-implementation.md` ladder).
- Configuration via typed config properties, not scattered `@Value` lookups;
  secrets from the environment/secret manager, never committed.
- Tests: service-level tests with fake/in-memory adapters for business rules;
  slice or integration tests for the controller contract (status codes,
  response shape, validation errors). Follow existing test conventions.
- Build verification: `./gradlew build` (or the project's equivalent) after
  implementation, per `ctx-run` ROLE 1.

## Feature Implementation Checklist

1. API contract: endpoints, request/response DTOs, error responses (approved
   shape only).
2. Migration for any schema change.
3. Domain model/entity changes + repository operations.
4. Service method(s) with transaction boundary.
5. Controller + validation + mapping.
6. Adapter changes for external systems (with timeout/retry/error mapping).
7. Tests: business rules, contract tests, validation/error cases,
   idempotency where applicable.

## Refactor Signals

- Business logic in a controller, or a controller touching a repository.
- Entities serialized straight into responses.
- Transactions opened outside the service layer, or none where writes span
  multiple repositories.
- External calls made inline in services without an adapter, timeout, or
  error mapping.
- Schema drift applied without a migration file.
- A webhook/consumer handler that breaks when delivered twice.
- Response shape changed silently in a refactor (RESPONSE SHAPE LOCK
  violation).
