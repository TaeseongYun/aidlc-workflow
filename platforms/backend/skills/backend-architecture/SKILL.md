---
name: backend-architecture
description: Backend architecture · server-architecture skeleton reference rules. Covers dependency flow (Controller/Handler → Service(UseCase) → Repository → DB/External Client Adapter, never reversed), layer responsibilities, transaction boundary in the service, entities never crossing the controller boundary (responses are explicit DTOs), external systems behind a port/adapter, and the Feature Slice decision table. Prefers Spring Boot/JPA (Kotlin/Java) but applies the same boundaries to Node/TypeScript (Express/Nest). Use when designing, reviewing, or refactoring backend architecture, or deciding which slice (simple CRUD/UseCase/event-async/read model) to take. The umbrella skill tying the other five backend skills together.
when_to_use: Designing backend service architecture, judging layer boundaries, placing Service/Repository/Adapter, locating the transaction boundary, choosing a feature slice, architecture refactor/review. Also for backend/server/API architecture, layered/clean/hexagonal architecture requests.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# backend-architecture — server-architecture skeleton

The spine of the backend: dependency flow, layer responsibilities, and transaction
boundary, pinned as always-referenced rules. Project `ctx/` overrides this skill,
and this skill overrides the agent's general knowledge. Deeper material (detailed
layer responsibilities, port/adapter samples, event slice examples) lives in
[reference.md](./reference.md).

## Scope

- In scope: layer placement, dependency direction, transaction boundary, slice
  selection, and refactor judgment for new backend features/services. Primary stack
  Kotlin/Java + Spring Boot + JPA, secondary Node/TS (Express/Nest).
- Out of scope: API contract details · error envelope, transaction/data details,
  authN/authZ, security vulnerability patterns, observability/supply chain — each
  delegated to the Related skills below.

## Core rules — dependency flow and layer responsibilities

Dependency flows top→down, one-way, **never reversed**.

```
Controller/Handler → Service(UseCase) → Repository → DB / External Client Adapter
```

### Do

- **Controller/Handler**: input parsing/validation, DTO mapping, delegation only. No
  business logic, no direct repository access, no transaction management. Validate
  every external input here (trust boundary) → [backend-security-guard],
  [backend-api-contract].
- **Service(UseCase)**: owns business rules and the **transaction boundary**. One
  service method = one unit of work. Do not open transactions in controllers or
  repositories.
- **Repository**: exposes domain-shaped operations. Does not leak query language
  outward. Entities do not cross the controller boundary — responses are built as
  **explicit DTOs**.
- **External Client Adapter**: external systems (payment, notification, other
  services) sit behind a project-owned client interface (port/adapter). Retries,
  timeouts, and error mapping live in the adapter → [backend-reliability].
- **Domain model/entity**: no web-layer imports. Pure domain.

### Don't

- Controller holding business logic or calling a Repository directly → forbidden.
- Opening a transaction outside the Service (in controller/repository) → forbidden.
- Serializing an entity straight into a response → forbidden (excessive exposure of
  sensitive data) → [backend-data-transactions].
- Making external calls inline inside the service (without adapter/timeout/error
  mapping) → forbidden.
- A lower layer depending on a higher layer → forbidden (reversed dependency).

## Feature Slice Decision Table

Start at the **smallest** slice that fits. Move up only on a **real signal**, not
speculation.

| Situation | Slice | Signal to move up |
|-----------|-------|-------------------|
| Simple CRUD over one aggregate | Controller → Service → Repository | Rule spanning aggregates or an external call appears |
| Business rules across aggregates / external calls | + explicit UseCase methods, adapter interfaces | Async/deferred processing needed |
| Async/deferred processing | + event/queue consumer, **idempotent** handler | Read model diverges from write model |
| Read model differs from write | separate query service/DTO path | — (do not introduce a full CQRS framework) |

- **Don't build ahead**: do not add a UseCase layer, event pipeline, or CQRS before a
  second consumer or a real requirement forces it (over-engineering).
- Do not create a service/use case that only delegates.

## Refactor / red-flag signals

- Business logic in a Controller, or a Controller accessing a Repository directly.
- Serializing an entity straight into a response (excessive exposure · Mass Assignment).
- A transaction opened outside the service, or no transaction on writes spanning
  multiple repositories.
- An external call inline in a service without an adapter/timeout/error mapping.
- A schema change applied without a migration (relying on ddl-auto).
- A webhook/consumer handler that breaks on duplicate delivery (no idempotency).
- Response shape silently changed in a refactor (RESPONSE SHAPE LOCK violation).

## Related skills

Umbrella skill. Drill down into each concern's detail below:

- [backend-api-contract](../backend-api-contract/SKILL.md) — RESPONSE SHAPE LOCK · error envelope · versioning · CORS.
- [backend-data-transactions](../backend-data-transactions/SKILL.md) — transaction boundary · N+1 · idempotency · sensitive-data exposure · money/time.
- [backend-security-guard](../backend-security-guard/SKILL.md) — **vibe-coding security guard**: blocks vulnerable patterns in AI-generated code.
- [backend-auth](../backend-auth/SKILL.md) — authN/authZ, BOLA·BFLA, JWT/session verification.
- [backend-reliability](../backend-reliability/SKILL.md) — observability · logging · resilience · dependency/supply chain.

## References

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Deeper material: [reference.md](./reference.md)
- OWASP Top 10 2021: https://owasp.org/Top10/
- OWASP API Security Top 10 2023: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- Spring architecture guide: https://spring.io/guides
- 12-Factor App: https://12factor.net/
