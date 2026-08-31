---
name: backend-module-structure
description: Backend module structure/modularization reference rules — domain-based Gradle modules where every domain ships a {domain}:api + {domain}:impl pair from day one; api exposes ONLY the cross-domain contract (interfaces, DTOs, domain events) and impl holds controllers/services/repositories/entities; only the app (bootstrap) module may depend on impl modules; grouped Gradle paths (:domain:<name>:api|:impl). Expands the Module Baseline section of `platforms/backend/guidance.md`. Reference when creating a new domain module, deciding what belongs in api vs impl, touching build.gradle.kts/settings.gradle.kts, or seeing cross-domain coupling signals such as one domain importing another's entities or services.
when_to_use: When creating/splitting/merging backend module boundaries, deciding what goes in a domain's api vs impl module, or judging cross-domain dependencies and Gradle build configuration.
paths: **/build.gradle.kts, **/settings.gradle.kts, **/build.gradle, **/pom.xml
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Backend Module Structure

Reference rules expanding the **Module Baseline** section of
`platforms/backend/guidance.md` to an executable-judgment level. Primary stack:
Kotlin/Java + Spring Boot + Gradle; the same boundaries apply to a
Node/TypeScript workspace (package names change, rules do not). Project `ctx/`
overrides this document.

## Scope

- In scope: domain module boundaries, the mandatory `{domain}:api|impl` pair,
  cross-domain dependency direction, build layout.
- Out of scope: layer rules inside a module (controller/service/repository,
  transactions) → [backend-architecture]; HTTP contract shape →
  [backend-api-contract].

## Module map

Grouped Gradle paths — domains nest under `domain/`:

```
app/                     # bootstrap only: main class, config, wiring
domain/order/api         # :domain:order:api
domain/order/impl        # :domain:order:impl
domain/payment/api       # :domain:payment:api
domain/payment/impl      # :domain:payment:impl
```

**Every domain is born as an `api` + `impl` pair.** No single-module domain
stage and no "split later" step — the pair is the standard shape, matching the
frontend platforms' `{feature}:api|impl` convention.

## The api/impl contract

`{domain}:api` exposes **only what another domain is allowed to consume**:

- Service interfaces (ports) other domains call — e.g. `OrderQueryPort`.
- DTOs carried across the domain boundary — never JPA entities.
- Domain events other domains subscribe to.

Nothing else. No controllers, no services, no repositories, no entities, no
framework config. A type every domain needs (money, ID wrappers) graduates to a
shared `core`/`common` module, not into one domain's `api`.

`{domain}:impl` holds the rest: controllers, services (transaction boundaries),
repositories, entities, mappers, and the implementations of its own `api`
interfaces. Everything not implementing the `api` stays `internal`/
package-private.

## Dependency rules

Direction (never reversed):

```
app ──▶ every :domain:*:impl (wiring) — nothing else depends on an impl
:domain:<a>:impl ──▶ :domain:<a>:api, other domains' :api, shared core/common
:domain:<name>:api ──▶ shared core/common only — never another domain's api
```

- **Only `app` may depend on an `impl` module.** `app` aggregates impls for
  component scan and configuration; it contains no business logic.
- A domain calling another domain goes through that domain's `api` interface,
  injected by the DI container — the caller never sees the implementation,
  entities, or repository.
- Prefer domain events over synchronous cross-domain call chains when the
  interaction is naturally asynchronous (see guidance Feature Slice table).
- `api` modules are plain Kotlin/Java libraries — no Spring web/data
  dependencies. Framework deps live in `impl` and `app`.

## Module decision table

| Situation | Decision |
|---|---|
| A new business domain appears | Create the pair: `:domain:<name>:api` + `:domain:<name>:impl` |
| Domain B needs data from domain A | B's `impl` calls an interface in A's `api`, receiving DTOs |
| A change in one domain keeps rippling into another | The `api` is too wide or wrongly cut — narrow the contract, or merge the domains if they always change together |
| A type every domain needs (money, IDs, error envelope) | Shared `core`/`common` module — don't fatten one domain's `api` |
| Async/deferred cross-domain reaction | Publish a domain event from A's `api`; B's `impl` consumes it idempotently |
| A second deployable (batch, worker, admin) | Another thin bootstrap module beside `app`, reusing the same domain impls |

## Refactor / red-flag signals

- A domain module without the `api`/`impl` pair (legacy single module) → split
  on next touch: contract into `api`, rest into `impl`.
- Any module other than a bootstrap depending on a `:domain:*:impl` → reroute
  through `api`.
- Entities, repositories, or Spring config types inside an `api` module.
- An `api` module depending on another domain's `api` → the shared type belongs
  in `core`/`common`.
- One domain importing another's entity or repository directly.
- `app` containing controllers, services, or business logic — it is bootstrap
  and wiring only.
- Two domains with a circular `api` dependency → merge them or invert one side
  with an event.

## References

- Detailed material (Gradle build files, cross-domain call and event samples,
  Node/TypeScript workspace mapping): [reference.md](reference.md)
- Team baseline: [../../guidance.md](../../guidance.md)
- Layer rules inside a module: [../backend-architecture/SKILL.md](../backend-architecture/SKILL.md)
