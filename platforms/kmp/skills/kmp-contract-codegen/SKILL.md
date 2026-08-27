---
name: kmp-contract-codegen
description: KMP API contract codegen — generate typed Kotlin client code from the OpenAPI/GraphQL contract (the single source of truth) instead of hand-writing types, and detect/block the drift AI commonly produces (hand-written DTO duplicating the schema, Any/dynamic at the boundary, stringly-typed endpoints, unmodeled error/status responses, manual (de)serialization drift, nullable/required mismatch, enum-as-raw-string, regen without diffing, hand-edited generated files, no single source of truth). Covers openapi-generator (kotlin/Ktor client), typed Ktor client, and Apollo Kotlin for GraphQL. Auto-loads when generating Kotlin clients from a schema or reviewing hand-written API models.
when_to_use: When generating or wiring a Kotlin API client from OpenAPI/GraphQL, adding an endpoint, reviewing hand-written models or DTOs, or on requests like "generate the client", "types from the schema", "why is the client out of sync", "add the API call".
paths: "**/openapi*.yaml, **/*.graphql, **/generated/**/*.kt, **/build.gradle.kts"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# kmp-contract-codegen — API contract → typed Kotlin client

The OpenAPI or GraphQL schema is the **single source of truth**. AI codegen ignores it: it
hand-writes a `data class UserDto` that mirrors a schema component, types the response as `Any`
or `Map<String, Any>`, hardcodes the URL string, models only the happy 200 path, and hand-edits
a generated file that the next codegen run silently overwrites. The result is client/server drift
and runtime type errors that only surface in production. This skill is both a **generator** (run
the codegen tool, wire the typed client) and a **guard** (block hand-written drift before it
merges). Project `ctx/` overrides this document. Code samples in [reference.md](./reference.md).

## Scope

- In scope: running the Kotlin codegen tool, wiring the generated client, typed error handling,
  regenerate discipline, and the 10 guard rules below.
- Out of scope: defining or reviewing the contract itself — the schema is owned by the backend.
  Cross-link `backend-api-contract` (where it exists) for contract ownership.
- Delegate to adjacent skills: overall client/data layer architecture →
  [kmp-architecture](../kmp-architecture/SKILL.md); contract tests, MockEngine responses →
  [kmp-testing](../kmp-testing/SKILL.md); auth headers, token storage, TLS →
  [kmp-security](../kmp-security/SKILL.md).

## Mode A — Generate: schema → typed Kotlin client

### 1. Locate the schema (the single source of truth)

Find the OpenAPI spec (`openapi.yaml` / `openapi.json`) or GraphQL schema (`*.graphql` /
`*.graphqls`) that the backend publishes. Never copy-paste type shapes from a browser network
tab or from another client's DTO — that is already drift. The spec is what you run codegen
against.

### 2. Run the codegen tool

**OpenAPI → openapi-generator (kotlin-client / Ktor):**

```bash
# Install once (or run via Docker in CI)
brew install openapi-generator   # or: npx @openapitools/openapi-generator-cli

# Generate into commonMain/generated/ — commit the output OR generate in CI, pick one
openapi-generator generate \
  -i api/openapi.yaml \
  -g kotlin \
  -o shared/src/commonMain/generated \
  --additional-properties=library=multiplatform,serializationLibrary=kotlinx_serialization,packageName=com.example.api
```

**OpenAPI → typed Ktor client (manual but typed):**

```kotlin
// shared/src/commonMain/kotlin/data/remote/UserApi.kt
// Thin typed wrapper around HttpClient — no codegen, but types derived from schema manually.
// Acceptable only for very small APIs; prefer codegen for any schema with 5+ endpoints.
interface UserApi {
    suspend fun getUser(id: Int): User            // @Serializable data class from schema
    suspend fun createUser(req: CreateUserRequest): User
}
```

**GraphQL → Apollo Kotlin:**

```bash
# pubspec.yaml equivalent: build.gradle.kts
# Add Apollo Kotlin plugin
plugins {
    id("com.apollographql.apollo3") version "4.x.x"
}

apollo {
    service("api") {
        packageName.set("com.example.graphql")
        schemaFile.set(file("src/commonMain/graphql/schema.graphqls"))
        srcDir("src/commonMain/graphql")
    }
}

# Place *.graphql operation files alongside; run:
./gradlew generateApolloSources
# → generates typed Query/Mutation/Subscription classes + @Serializable data classes
```

The calibration knob: a new field or endpoint is a **schema change + regen**, reviewed once
in the generated diff — never a hand-written parallel model.

### 3. Wire a typed call with typed error handling

Import the generated client; never re-declare its types:

```kotlin
// ✅ Generated client wired in the data layer
class UserRemoteDataSource(private val api: UserApi) {

    suspend fun fetchUser(id: Int): User {
        return try {
            api.getUser(id)             // generated method, returns typed User
        } catch (e: ClientRequestException) {
            val status = e.response.status
            when (status) {
                HttpStatusCode.NotFound -> throw UserNotFoundException(id)
                HttpStatusCode.UnprocessableEntity -> {
                    val err = e.response.body<ValidationErrorResponse>() // generated type
                    throw ValidationException(err.message)
                }
                else -> throw ApiException("Unexpected status $status", e)
            }
        }
    }
}
```

### 4. Regenerate discipline

- When the schema changes, run the codegen command and commit the diff.
- Review the generated diff for breaking changes (removed fields, changed types, renamed
  operations) before merging — this is the schema-bump review, not a handwritten change.
- Never hand-edit a file inside the generated output directory. Put customizations (error
  mapping, retry logic, auth interceptors) in wrapper classes outside the generated tree.
- Decide once: commit generated files OR generate in CI. Mixed conventions cause the
  "why is the client out of sync" class of bugs.

## Mode B — Guard: 10 contract-drift failure modes (must not be relaxed)

Each item: **rule → common AI failure → red-flag**. Bad/good Kotlin pairs in
[reference.md](./reference.md).

### 1. Hand-written DTO instead of generated

- **Rule**: model classes for API types are generated from the schema, not hand-written. A
  `data class UserDto` with fields mirroring a schema component is a duplicate that will drift.
- **Common AI failure**: writing `data class CreateOrderRequest(val userId: String, val items:
  List<Item>)` from memory or from a network-tab snapshot, instead of running codegen against
  the spec that already defines this shape.
- **red-flag**: a Kotlin data class whose field names mirror a schema component, no generated
  companion or `@Serializable` annotation pointing at a codegen output, and no generated file
  in the same module.

### 2. Untyped boundary

- **Rule**: API call results are typed to the generated `@Serializable` data class, never to
  `Any`, `Map<String, Any?>`, or `JsonObject` at the call site.
- **Common AI failure**: `val data = response.body<Map<String, Any>>(); val name = data["name"]
  as String` — abandons the type system at the network boundary.
- **red-flag**: `Any`, `Map<String, Any>`, `JsonObject`, or `as Map` at the return type or
  first-use site of an API response.

### 3. Stringly-typed endpoint

- **Rule**: call API operations via the generated client method (which encodes the path, verb,
  and parameters). Do not hardcode URL path strings inline.
- **Common AI failure**: `client.get("$baseUrl/api/v1/users/$id")` — duplicates the spec's path
  outside codegen, diverges on rename or version bump.
- **red-flag**: a raw `client.get("$baseUrl/api/...")` / `client.post("$baseUrl/api/...")` string
  literal at a call site where a generated client method exists.

### 4. Unmodeled error/status responses

- **Rule**: the spec's declared 4xx/5xx error schemas are typed and handled. Only modeling the
  200 path leaves error bodies untyped and unhandled.
- **Common AI failure**: `try { val r = api.createOrder(req) } catch (e: Exception) { log(e) }`
  — catches the exception but ignores the typed error body the spec defines for 400/422/500.
- **red-flag**: a `catch` block that ignores `e.response.status` and the typed error schema, or
  no `catch` at all on an API call that declares errors.

### 5. Manual (de)serialization drift

- **Rule**: JSON (de)serialization uses the generated `@Serializable` data class and
  `kotlinx.serialization`. Hand-rolled `jsonObject["field"]` access drifts from the schema on
  field renames.
- **Common AI failure**: `val name = jsonObject["user_name"]!!.jsonPrimitive.content` where the
  schema field is `userName` (camelCase) and the generated codec would have applied
  `@SerialName("user_name")`.
- **red-flag**: manual `jsonObject["key"]` / `JsonObject` key access on an API response type
  that the schema defines; string-keyed map unpacking on a schema-defined model.

### 6. Nullable/required mismatch

- **Rule**: nullability in Kotlin mirrors the schema. A field the schema marks optional
  (`required: false` / absent from the `required` array) must be `T?` in Kotlin. Force-unwrapping
  an optional field crashes on any response that omits it.
- **Common AI failure**: `val email = user.email!!` where the schema marks `email` as optional —
  works in the happy path, crashes the moment the backend legally omits the field.
- **red-flag**: `!!` (non-null assertion) on a field the schema declares optional; or a non-null
  Kotlin type for an optional schema field; or `T?` for a field the schema marks required.

### 7. Enum as raw string

- **Rule**: schema-defined enum values are used as the generated `enum class` or `sealed class`,
  not as bare string literals. String literals have no exhaustiveness check — a new enum value
  added to the schema silently falls through.
- **Common AI failure**: `if (order.status == "PENDING") { … }` where the spec and codegen
  produce `OrderStatus.PENDING` — the raw string is unchecked and breaks on a spec rename.
- **red-flag**: a string literal compared or assigned where a generated enum type exists in the
  same module.

### 8. Regen without diffing

- **Rule**: after bumping the schema version and regenerating, review the generated diff for
  breaking changes (removed fields, changed types, renamed operations) before merging.
  Regenerating silently and committing is how breaking changes slip through.
- **Common AI failure**: `openapi-generator generate …` → `git add shared/src/commonMain/generated`
  → commit, with no review of what changed in the generated output.
- **red-flag**: a schema/version bump commit whose PR contains changed generated files but no
  comment or diff annotation noting what broke or changed in the client surface.

### 9. Hand-edited generated file

- **Rule**: files inside the generated output directory carry `// DO NOT EDIT` or are under a
  configured generated-output path and must not be hand-modified. Edits are silently overwritten
  by the next codegen run.
- **Common AI failure**: patching `shared/src/commonMain/generated/UserApi.kt` directly to add
  a missing header or fix a serialization issue — the fix evaporates on the next regen.
- **red-flag**: a diff that modifies lines inside a file containing `// DO NOT EDIT` or inside
  the configured generated-output directory (`generated/`, `build/generated/`).

### 10. No single source of truth

- **Rule**: there is exactly one definition of each API type — the schema. The Kotlin client
  types are derived from it via codegen. A second hand-maintained copy of the same shape (a DTO
  in the KMP module that mirrors a DTO in the backend) means two things to keep in sync manually.
- **Common AI failure**: defining `data class UserProfile` in the KMP `commonMain` that mirrors
  `UserProfile` in the backend, both hand-maintained, diverging on every field addition.
- **red-flag**: two independent Kotlin class definitions of the same schema component — one in a
  hand-written `model/` file and one generated, or two hand-written copies in different layers.

## Guard checklist

For any Kotlin API client code before merge:

- [ ] Model classes generated from the schema; no hand-written DTO duplicating a schema type.
- [ ] API call results typed to generated `@Serializable` model, not `Any`/`Map<String,Any>`.
- [ ] Endpoint called via generated client method; no raw `client.get("$baseUrl/...")` string.
- [ ] Spec-declared error schemas typed and handled in `catch`; not silently swallowed.
- [ ] JSON (de)serialization via generated `@Serializable` codec; no manual `jsonObject["key"]` access.
- [ ] Kotlin nullability matches schema: no `!!` on optional fields, no `T?` on required fields.
- [ ] Generated enum types used; no raw string literals where an enum exists.
- [ ] Schema bump + regen diff reviewed in PR for breaking changes.
- [ ] No hand edits inside `generated/` or any file containing `// DO NOT EDIT`.
- [ ] One definition per schema type — no hand-maintained parallel copy.

## Halt conditions

Halt and report before proceeding if:

- The schema cannot be located — codegen has no source of truth to run against.
- The requested change adds a field or endpoint that is not yet in the schema — the schema must
  be updated first (backend), then regen; do not hand-write.
- A generated file has been hand-edited — flag the edit, do not extend the pattern.

```markdown
## [Codegen] Halted

Halt reason:
- (specific reason — missing schema / schema mismatch / hand-edited generated file)

What needs resolving:
1. ...
```

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Umbrella: [kmp-architecture](../kmp-architecture/SKILL.md)
- Contract tests, MockEngine: [kmp-testing](../kmp-testing/SKILL.md)
- Auth headers, token storage, TLS: [kmp-security](../kmp-security/SKILL.md)
- Bad/good Kotlin pairs for all 10 rules + codegen command examples: [reference.md](./reference.md)
- openapi-generator kotlin client: https://openapi-generator.tech/docs/generators/kotlin
- Apollo Kotlin: https://www.apollographql.com/docs/kotlin/
- kotlinx.serialization: https://github.com/Kotlin/kotlinx.serialization
- Ktor client: https://ktor.io/docs/client-create-new-application.html
- Ktor MockEngine (testing): https://ktor.io/docs/client-testing.html
