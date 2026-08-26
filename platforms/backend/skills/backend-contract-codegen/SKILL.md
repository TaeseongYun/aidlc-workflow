---
name: backend-contract-codegen
description: Backend API contract codegen — generate typed server code from the OpenAPI/GraphQL
  contract (the single source of truth) instead of hand-writing types, and detect/block the drift AI
  commonly produces (hand-written DTO duplicating the schema, any/dynamic at the boundary, stringly-typed
  endpoints, unmodeled error/status responses, manual (de)serialization drift, nullable/required mismatch,
  enum-as-raw-string, regen without diffing, hand-edited generated files, no single source of truth).
  Covers the backend codegen tools (openapi-generator server stubs, springdoc/FastAPI/oapi-codegen
  code-first export, DGS/graphql-java/strawberry/gqlgen). Auto-loads when generating or wiring server
  code from a schema, or reviewing hand-written models against the contract.
when_to_use: When generating or wiring a server from OpenAPI/GraphQL, adding an endpoint, reviewing
  hand-written models against the contract, or on requests like "generate the server stubs", "types
  from the schema", "why is the server out of sync with the spec".
paths: "**/openapi*.yaml, **/openapi*.yml, **/openapi*.json, **/*.graphql, **/*.graphqls,
  **/generated/**, **/build/generated/**, **/src/main/resources/openapi*, **/*Api.java,
  **/*Api.kt, **/*DTO.java, **/*DTO.kt, **/schema.graphqls"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# backend-contract-codegen — API contract codegen + drift guard

The API contract (OpenAPI spec or GraphQL schema) is the **single source of truth the server owns.**
AI codegen ignores it: it hand-writes a parallel DTO that drifts from the schema, leaves response
types untyped, hardcodes URL paths, models only the 200 path, and edits generated files that the
next regen wipes. The result is server/client drift, broken consumers, and runtime surprises.

This skill is a **generator** (run the platform codegen tool, wire the typed server) plus a **guard**
(detect and block the ten drift patterns AI routinely introduces). It is the codegen counterpart to
[backend-api-contract](../backend-api-contract/SKILL.md), which defines and reviews the contract
shape; this skill turns the finalized contract into running typed server code.

## Scope

- **In scope**: OpenAPI/GraphQL schema as source of truth; codegen tool invocation; wiring generated
  server stubs/interfaces; regeneration discipline; guarding against the 10 contract-drift failure
  modes below.
- **Delegate to adjacent skills**:
  - Contract design (shape, error envelope, versioning, CORS) → [backend-api-contract](../backend-api-contract/SKILL.md)
  - Auth/transport security → [backend-security-guard](../backend-security-guard/SKILL.md)
  - Data layer / ORM → [backend-data-transactions](../backend-data-transactions/SKILL.md)
  - Contract tests (consumer-driven, Pact, schema validation) → [backend-testing](../backend-testing/SKILL.md)
  - Overall service structure → [backend-architecture](../backend-architecture/SKILL.md)

## Mode A — Generate: schema as source of truth

The server **owns** the schema and publishes it for client consumers. A new field or endpoint is
always a **schema change + regen**, never a hand-written parallel model.

### Step 1 — Locate or create the schema

Point at a single authoritative file. Two equally valid origins:

**Schema-first (OpenAPI)** — write `openapi.yaml`, then generate:
```
src/main/resources/
  openapi.yaml          ← schema lives here; all types derived from this
```

**Code-first export** — annotate source, export the spec at build time:
- Spring: `springdoc-openapi` generates the spec from `@RestController`+`@Schema` annotations
- Python/FastAPI: spec generated from type hints automatically at startup (`/openapi.json`)
- Go: `oapi-codegen` generates Go code from a spec, or use `swaggo` to export from annotations

Pick **one** origin per service and commit the exported spec to version control so clients have a
stable artifact.

### Step 2 — Run the codegen tool

**OpenAPI → server stubs (JVM/Kotlin)**

```bash
# openapi-generator-cli (Maven plugin or CLI)
openapi-generator-cli generate \
  -i src/main/resources/openapi.yaml \
  -g kotlin-spring \
  -o build/generated \
  --additional-properties=interfaceOnly=true,useTags=true,useSpringBoot3=true

# Maven plugin (preferred — runs automatically on compile):
# <plugin>
#   <groupId>org.openapitools</groupId>
#   <artifactId>openapi-generator-maven-plugin</artifactId>
#   <configuration>
#     <inputSpec>src/main/resources/openapi.yaml</inputSpec>
#     <generatorName>kotlin-spring</generatorName>
#     <configOptions><interfaceOnly>true</interfaceOnly></configOptions>
#   </configuration>
# </plugin>
```

**OpenAPI → server (Python / FastAPI)**

```bash
# FastAPI generates the spec from code; for strict schema-first use openapi-python-client
openapi-python-client generate --path openapi.yaml
# Or use datamodel-code-generator for Pydantic models only:
datamodel-codegen --input openapi.yaml --input-file-type openapi --output app/models/generated.py
```

**OpenAPI → server (Go)**

```bash
oapi-codegen -package api -generate types,server openapi.yaml > api/generated.go
```

**GraphQL schema-first (JVM — DGS)**

```bash
# Netflix DGS: place schema in src/main/resources/schema/schema.graphqls
# DGS generates type-safe data fetcher interfaces + POJOs at build time via Gradle plugin:
# id("com.netflix.dgs.codegen") version "6.x"
./gradlew generateJava
```

**GraphQL schema-first (Python — Strawberry)**

```python
# Strawberry derives the schema from Python types; export with:
import strawberry, json
schema = strawberry.Schema(query=Query)
print(schema.as_str())   # SDL — publish this as the contract
```

**GraphQL schema-first (Go — gqlgen)**

```bash
# gqlgen reads schema.graphqls and generates resolvers + models:
go run github.com/99designs/gqlgen generate
```

### Step 3 — Wire the generated interface

Generated code produces an interface/delegate (not a concrete class). Implement it in your service:

```kotlin
// Generated by openapi-generator (kotlin-spring, interfaceOnly=true):
//   interface UsersApi { fun getUser(id: Long): ResponseEntity<UserResponse> }

@RestController
class UserController(private val svc: UserService) : UsersApi {
    override fun getUser(id: Long): ResponseEntity<UserResponse> =
        ResponseEntity.ok(svc.find(id).toResponse())
}
```

The compiler enforces the contract. If the schema changes the return type, the build fails — that
is the signal, not a runtime surprise.

### Step 4 — Regeneration discipline

| Trigger | Action |
|---|---|
| Schema field added/changed/removed | Re-run codegen → compile → fix breakages → commit |
| Schema version bump | Diff the generated output (`git diff build/generated`) before merging |
| CI/CD | Generated code either **committed to source** (visible diffs in PR) or **generated at build time** (never both) — pick one and be consistent |

**Calibration knob**: commit generated code for visibility (reviewers see exact diffs) vs. generate
at build time for cleanliness (no generated noise in PRs). Either is fine; mixing them creates drift.

## Mode B — Guard: 10 contract-drift failure modes

AI hand-writes types instead of generating them. The rules below are **safety rules** for the
server/contract boundary and must not be relaxed. Each item: **rule → common AI failure → red-flag**.
Code examples in [reference.md](./reference.md).

### 1. Hand-written DTO instead of generated

- **Rule**: server DTOs/models are generated from the schema or derived directly by the codegen
  framework (springdoc annotations, FastAPI type hints, DGS POJOs). Never maintain a parallel
  hand-written class whose fields mirror a schema component.
- **Common AI failure**: writes `data class UserResponse(val id: Long, val name: String)` alongside
  an `openapi.yaml` that already defines `UserResponse` — two definitions, guaranteed to diverge.
- **red-flag**: a model class whose fields mirror a schema `components/schemas` entry, with no
  `@Generated` annotation or codegen plugin producing it.

### 2. Untyped boundary

- **Rule**: generated operation methods use the schema's generated types end-to-end. No `Any`,
  `Map<String, Any>`, `dynamic`, `object`, or `interface{}` at the API boundary.
- **Common AI failure**: returns `Map<String, Any>` from a controller, or types the deserialized
  body as `any` in intermediate TS/JS glue code.
- **red-flag**: `Map<String, Any>`, `Any`, `object`, or `interface{}` as a controller return type
  or request-body parameter type.

### 3. Stringly-typed endpoint

- **Rule**: call-site code uses the generated operation method or router registration — not a
  hardcoded path string. Tests hit the typed method, not a raw URL.
- **Common AI failure**: a handler that duplicates the path string from the spec (`@GetMapping("/api/v1/users/{id}")`) without referencing the generated interface, so a path rename in the spec doesn't cascade.
- **red-flag**: a path literal in a controller annotation that also appears verbatim in `openapi.yaml`
  without being generated or validated by a plugin.

### 4. Unmodeled error/status

- **Rule**: every HTTP status the spec declares gets a typed response class and is handled in the
  global exception mapper. The generated interface includes error response types if the generator
  supports them; hand-write only what the generator cannot produce.
- **Common AI failure**: generates or writes only the 200 branch; 400/404/422/500 fall through to
  the framework default, leaking stack traces or producing undocumented shapes.
- **red-flag**: spec declares `400`/`404`/`422` responses but the controller has no typed error
  handling and no global exception handler maps them.

### 5. Manual (de)serialization drift

- **Rule**: rely on the generated serialization layer (Jackson `@JsonProperty`, Pydantic validators,
  `encoding/json` struct tags from oapi-codegen). Never hand-parse JSON fields; never hand-write
  field-name mappings that the generator already emits.
- **Common AI failure**: writes `val name = json.getString("user_name")` alongside a generated
  class that already has `@JsonProperty("user_name") val userName: String`.
- **red-flag**: manual `JSONObject.get()`/`json[key]` access in a path that has a generated model;
  snake_case↔camelCase mapping done by hand instead of via `@JsonProperty` or `json_encoders`.

### 6. Nullable/required mismatch

- **Rule**: the schema's `required` array and `nullable` flag drive nullability in generated code.
  Do not add `!!` / `?.let` patches that contradict the schema's intent.
- **Common AI failure**: force-unwraps (`!!`) a field the schema marks optional, or declares a
  non-null Kotlin type for a field with `nullable: true` — compiles, crashes at runtime on real data.
- **red-flag**: `!!` on a generated field, or a generated nullable type silently unwrapped without
  handling the null branch; Pydantic field declared non-optional when schema says `required: false`.

### 7. Enum as raw string

- **Rule**: schema `enum` values are used via the generated enum type, not bare string literals.
  The exhaustiveness check is the compiler's job, not a runtime `when`/`switch` with a default.
- **Common AI failure**: passes `"PENDING"` as a string where the generated `OrderStatus.PENDING`
  exists; or maps enum values in a `when` with a `else -> throw RuntimeException("unknown")` that
  silently hides new schema values.
- **red-flag**: string literals matching a schema enum in a path that has access to the generated
  enum type; `else` branch in a `when`/`match` over a generated sealed/enum class.

### 8. Regen without diffing

- **Rule**: every schema/version bump that triggers a regen must include a review of the generated
  diff before the PR is merged. Breaking changes in the generated interface (removed operation,
  changed parameter type) are caught here, not in production.
- **Common AI failure**: bumps the spec version, reruns codegen, and commits `build/generated`
  wholesale without a diff review — a removed field or renamed operation is invisible until
  a consumer breaks.
- **red-flag**: a PR that bumps the spec version or changes `openapi.yaml` with no corresponding
  diff of the generated output, or a commit message like "regen" with no mention of what changed.

### 9. Hand-edited generated file

- **Rule**: files inside generated output directories (`build/generated/`, `**/generated/**`) are
  never hand-edited. Customization goes in the implementing class, a Mustache template override,
  or a post-generation decorator — not in the generated file.
- **Common AI failure**: edits `build/generated/src/main/kotlin/com/example/api/UsersApi.kt`
  directly to add a missing field — the edit is silently overwritten on the next regen.
- **red-flag**: `git diff` shows changes inside a `generated/` directory; a file with a
  `// GENERATED — do not edit` header that has hand-written additions.

### 10. No single source of truth

- **Rule**: there is exactly one authoritative definition of each contract type. The server schema
  (OpenAPI spec or GraphQL SDL) is that definition. Client teams derive from it; they do not
  maintain a parallel copy.
- **Common AI failure**: server has `UserResponse` in `openapi.yaml`; client team hand-writes
  `interface UserResponse` in TypeScript that "matches" — two files, two maintenance burdens, eventual drift.
- **red-flag**: the same schema component defined independently in two or more places (server model
  class + client TS interface + mobile Kotlin data class — each hand-maintained instead of generated
  from the shared spec).

## Drift-guard checklist

For any PR that touches `openapi.yaml`, `*.graphqls`, or a model class:

- [ ] No hand-written DTO duplicating a schema `components/schemas` entry.
- [ ] No `Any`/`Map<String,Any>`/`object`/`interface{}` at the controller boundary.
- [ ] No hardcoded path literals that duplicate spec paths without generation.
- [ ] All declared error status codes have typed response handling.
- [ ] No manual JSON field parsing alongside a generated model.
- [ ] Nullable/required annotations match the schema; no `!!` on optional fields.
- [ ] Schema enum values used via generated enum type, not raw strings.
- [ ] Schema/version bump includes a generated-code diff review.
- [ ] No hand edits inside `build/generated/` or `**/generated/**`.
- [ ] One authoritative schema definition; consumers derive from it.

## Halt conditions

Stop and ask the user before proceeding when:

- The schema file does not exist and there is no annotation-based export configured — the source
  of truth is missing. Ask which approach the team uses (schema-first vs. code-first export).
- The team uses both committed generated code and build-time generation in the same service — pick
  one strategy before regenerating.
- A breaking schema change (removed operation, changed required field) is detected in the generated
  diff with no version bump or migration plan.

### Output on halt

```
## Codegen halt

Halt reason:
- (specific reason)

Required clarification:
1. ...
```

Do not propose alternatives. Do not explain how to fix. Output only the halt reason.

## References

- Contract definition + shape rules: [backend-api-contract](../backend-api-contract/SKILL.md)
- Security guard for server code: [backend-security-guard](../backend-security-guard/SKILL.md)
- Contract tests (Pact, schema validation): [backend-testing](../backend-testing/SKILL.md)
- Umbrella: [backend-architecture](../backend-architecture/SKILL.md)
- Deep-dive code pairs: [reference.md](./reference.md)
- openapi-generator: https://openapi-generator.tech/docs/generators/kotlin-spring
- Netflix DGS codegen: https://netflix.github.io/dgs/generating-code-from-schema/
- gqlgen: https://gqlgen.com/getting-started/
- oapi-codegen: https://github.com/oapi-codegen/oapi-codegen
- springdoc-openapi: https://springdoc.org/
- FastAPI OpenAPI: https://fastapi.tiangolo.com/tutorial/first-steps/#openapi
