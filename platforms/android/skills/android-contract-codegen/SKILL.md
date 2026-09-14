---
name: android-contract-codegen
description: Android API contract codegen — generate typed Kotlin client code from the OpenAPI/GraphQL
  contract (the single source of truth) instead of hand-writing types, and detect/block the drift AI
  commonly produces (hand-written DTO duplicating the schema, Map<String,Any> at the boundary,
  stringly-typed endpoints, unmodeled error/status responses, manual (de)serialization drift,
  nullable/required mismatch, enum-as-raw-string, regen without diffing, hand-edited generated files,
  no single source of truth). Covers openapi-generator (kotlin + retrofit2), Retrofit + Moshi /
  kotlinx.serialization, and Apollo Kotlin (GraphQL). Auto-loads when generating clients from a schema.
when_to_use: When generating or wiring a Kotlin API client from OpenAPI/GraphQL, adding an endpoint,
  reviewing hand-written models, or on requests like "generate the client", "types from the schema",
  "why is the client out of sync".
paths: "**/openapi*.yaml, **/openapi*.yml, **/openapi*.json, **/*.graphql, **/apollo/**, **/generated/**/*.kt, **/*.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# android-contract-codegen

The API contract (OpenAPI spec or GraphQL schema) is the **single source of truth**. AI codegen
ignores it: it hand-writes a duplicate data class that drifts from the schema, types responses as
`Map<String, Any>`, hardcodes URL path strings, models only the happy 200 path, and hand-edits
generated files that the next regen wipes. The result is client/server drift and runtime surprises.

This skill is a **generator** (run the codegen tool, wire the typed Kotlin client) plus a **guard**
(block hand-written drift). It is the codegen counterpart to the backend API contract skill, which
defines/reviews the contract; this one turns the contract into code. Project `ctx/` overrides this
document. Code samples and bad→good pairs live in [reference.md](./reference.md).

## Scope

- **In scope:** running the Android codegen tool, wiring the generated typed client, regenerating on
  schema change, and guarding against the 10 drift failure modes below.
- **Covers:** openapi-generator (kotlin + retrofit2), Retrofit + Moshi / kotlinx.serialization direct
  setup, Apollo Kotlin for GraphQL, sealed-class error/result modeling.
- **Doesn't cover:**
  - Defining or reviewing the contract itself → backend API contract skill (server is the contract's
    owner; cross-link it for the source schema file).
  - Client/data layer architecture (Repository pattern, use-cases) → [android-architecture].
  - Contract-level tests (contract tests, mock server) → [android-testing].
  - Auth headers, TLS, certificate pinning → [android-security].

## Mode A — Generate

### 1. Locate the schema (single source of truth)

The schema lives in the backend repo (or a shared submodule/package registry). Never copy-paste it
into the Android repo by hand; point the generator at the canonical location (local path, URL, or
resolved artifact). OpenAPI: `openapi.yaml` / `openapi.json`. GraphQL: `schema.graphql` /
`schema.graphqls`.

### 2. Run the codegen tool

**OpenAPI → Retrofit2 (openapi-generator Gradle plugin)**

Add to `build.gradle.kts` (app or `:network` module):

```kotlin
plugins {
    id("org.openapi.generator") version "7.6.0"
}

openApiGenerate {
    generatorName.set("kotlin")
    inputSpec.set("$rootDir/specs/openapi.yaml")
    outputDir.set("$buildDir/generated/openapi")
    apiPackage.set("com.example.api")
    modelPackage.set("com.example.api.model")
    configOptions.set(mapOf(
        "library"          to "jvm-retrofit2",
        "serializationLibrary" to "kotlinx_serialization",
        "useCoroutines"    to "true",
        "enumPropertyNaming" to "UPPERCASE",
    ))
}
```

Then regenerate:

```bash
./gradlew openApiGenerate
```

**GraphQL → Apollo Kotlin**

```bash
# Add to build.gradle.kts
plugins { id("com.apollographql.apollo3") version "3.8.5" }

apollo {
    service("api") {
        packageName.set("com.example.api")
        schemaFile.set(file("src/main/graphql/schema.graphqls"))
    }
}

# Generate
./gradlew generateApolloSources
```

### 3. Wire the generated client

Provide the generated `ApiClient` / `ApolloClient` via dependency injection (Hilt/Koin). Call the
generated operation method; wrap the result in a `sealed class` for typed error handling:

```kotlin
sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class HttpError(val code: Int, val error: ApiErrorBody) : ApiResult<Nothing>()
    data class NetworkError(val cause: Throwable) : ApiResult<Nothing>()
}

suspend fun getUser(id: String): ApiResult<User> = runCatching {
    userApi.getUser(id)   // generated Retrofit suspend fun
}.fold(
    onSuccess = { ApiResult.Success(it) },
    onFailure = { e ->
        when (e) {
            is HttpException -> ApiResult.HttpError(e.code(), parseError(e))
            else             -> ApiResult.NetworkError(e)
        }
    }
)
```

See [reference.md](./reference.md) for a full wiring example with Apollo Kotlin.

### 4. Regen discipline

- A new field or endpoint = a schema change → run `openApiGenerate` / `generateApolloSources` →
  commit the generated diff. Never hand-write a parallel model for the new field.
- Choose **one** of: commit generated code to VCS (reviewable diff, faster CI) or generate at
  build time (always fresh). Be consistent across the project — mixing the two causes confusion.
- Generated dirs go in `:network` or `:data` module (see [android-module-structure]). Add a
  `// GENERATED — do not edit` header or rely on the tool's own header.
- Review the generated diff before merging: a breaking schema change (renamed field, required →
  optional) shows up here.

## Mode B — Guard

The 10 contract-drift failure modes AI commonly introduces. Each: **rule → common AI failure →
red-flag**. Bad→good Kotlin code is in [reference.md](./reference.md).

---

### Rule 1 — No hand-written DTO duplicating the schema

**Rule:** All request/response model classes must be generated from the schema. Do not write a
`data class` by hand that mirrors a schema component.

**Common AI failure:** AI writes `data class UserResponse(val id: String, val name: String)` inline
alongside the Retrofit call, duplicating a schema component it never read.

**Red-flag:** A `data class` (or POJO) whose fields mirror a schema `#/components/schemas/` entry,
maintained by hand in a non-generated file.

---

### Rule 2 — No untyped API boundary

**Rule:** API call results and request bodies must be typed with generated model classes. Never use
`Map<String, Any>`, `Any`, `JsonObject`, or `JsonElement` as a request/response type at the network
boundary.

**Common AI failure:** AI types the Retrofit response as `Map<String, Any>` because it doesn't know
the schema. Callers then cast or access keys by string throughout the codebase.

**Red-flag:** `Map<String, Any>`, `Any`, `JsonObject`, or `JsonElement` as the type parameter of a
`@GET`/`@POST`/`@Body`/`Call<T>`/`Response<T>` at the API boundary.

---

### Rule 3 — No stringly-typed endpoint

**Rule:** Endpoint paths and HTTP verbs must come from the generated API interface, not hardcoded
inline. Do not duplicate a path string that already exists in the generated client.

**Common AI failure:** AI writes `retrofit.create(Retrofit.Builder::class.java)` with a raw
`@GET("users/{id}")` that duplicates (and can drift from) the spec.

**Red-flag:** A raw `@GET("...")` / `@POST("...")` annotation in non-generated code whose path
matches a spec operation; hardcoded URL strings constructed with string concatenation for an API
call that the generated client already covers.

---

### Rule 4 — Model all error/status responses

**Rule:** Every error response defined in the spec (4xx, 5xx, error schema) must be handled with a
typed `sealed class` branch. Do not model only the 200 path.

**Common AI failure:** AI wraps the call in a `try/catch(Exception)` and ignores `HttpException`,
leaving all error bodies untyped and unhandled.

**Red-flag:** An API call with no typed handling for the spec's declared error responses; a
`catch (e: Exception)` that discards the HTTP error body; no `sealed class` or `Result`/`Either`
wrapping the call result.

---

### Rule 5 — No manual (de)serialization drift

**Rule:** JSON serialization must go through the generated codec (Moshi adapter, kotlinx.serialization
`@Serializable`, or Apollo's generated parsers). Never hand-roll `JSONObject`/`JSONArray` access or
hand-map JSON keys to fields.

**Common AI failure:** AI writes `val name = json.getString("user_name")` or a custom `JsonDeserializer`
that maps fields by string key, introducing snake/camelCase mismatches with the schema.

**Red-flag:** `JSONObject.getString(...)`, `JSONArray.getJSONObject(...)`, manual `GsonDeserializer`,
or `JsonDeserializer` implementations for a type that the schema already defines.

---

### Rule 6 — Respect nullable/required as declared in the schema

**Rule:** A field marked `nullable: true` or absent from `required` in the schema must be typed `T?`
in Kotlin. Never force-unwrap or assert non-null on an optional field.

**Common AI failure:** AI makes every field non-null because it only sees the happy-path response
sample. On a real response with a missing optional field, the serializer throws or the app crashes.

**Red-flag:** `!!` on a field whose schema property is not in `required`; a non-null `val` in a
generated or hand-written model for a schema property that is `nullable: true`.

---

### Rule 7 — No enum as raw string

**Rule:** A schema `enum` property must be represented by the generated `enum class`, not a bare
`String`. Use the generated type; exhaustiveness is enforced by `when` with no `else`.

**Common AI failure:** AI uses `val status: String` and compares with `== "active"` rather than
using the generated `UserStatus` enum, losing exhaustiveness checks and making future values silently
unhandled.

**Red-flag:** A string literal compared to a field that maps to a schema `enum`; a property typed
`String` where the schema specifies an `enum` with known values.

---

### Rule 8 — Diff the generated output after every schema/version bump

**Rule:** When the spec version changes or a field/endpoint is added/changed, regenerate and review
the generated-code diff before merging. Never regenerate silently without reviewing breaking changes.

**Common AI failure:** AI bumps the `openapi.yaml` version, reruns the generator, and merges without
checking that a renamed field or changed nullability broke existing callers.

**Red-flag:** A commit that bumps the spec version or modifies `openapi.yaml` with no corresponding
diff in the generated output directory; a PR with a schema change and no generated-code review note.

---

### Rule 9 — Never hand-edit generated files

**Rule:** Files inside a generated directory (annotated `// GENERATED — do not edit` or produced by
`openApiGenerate` / `generateApolloSources`) must not be edited by hand. Edits are lost on the next
regen. Add customizations in wrapper classes or extension files outside the generated dir.

**Common AI failure:** AI edits a generated `UserApi.kt` directly to add a helper method, which
disappears on the next `./gradlew openApiGenerate`.

**Red-flag:** A diff that modifies files inside `build/generated/`, `generated/`, or `apollo/`
dirs; custom logic mixed into generated classes.

---

### Rule 10 — One source of truth, not two

**Rule:** There must be exactly one definition of each contract type — the generated one. Do not
maintain a hand-written copy alongside the generated class.

**Common AI failure:** AI creates a `UserDto` in the feature module because it "doesn't know where
the generated classes are", resulting in two definitions that diverge the moment the schema changes.

**Red-flag:** Two classes (one generated, one hand-written) with the same fields representing the
same schema component; a mapper between two classes that model the same API type.

---

## Halt conditions

Stop and surface a halt (per `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`) when:

- The canonical schema file cannot be located (not in the repo, no submodule pointer, no registry
  reference). Do not proceed by inferring types from sample responses.
- The project mixes generated and hand-written clients for the same endpoint with no migration plan.
- A Rule 1 or Rule 10 violation is found where the generated class and the hand-written class have
  already diverged (different field names or types) — fix the divergence before generating more code.

**Output on halt:**

```
## Generation halted

Halt reason:
- (specific reason)

Items requiring confirmation:
1. ...
```

Do not propose alternative types or infer the schema from response samples. Output only the halt
reason.

## References

- [../../guidance.md](../../guidance.md) — team Android baseline
- [android-architecture](../android-architecture/SKILL.md) — Repository/data-layer wiring
- [android-testing](../android-testing/SKILL.md) — contract tests, MockWebServer, Apollo MockServer
- [android-security](../android-security/SKILL.md) — auth headers, TLS, certificate pinning
- [android-module-structure](../android-module-structure/SKILL.md) — where generated sources live
- openapi-generator: https://openapi-generator.tech/docs/generators/kotlin
- Apollo Kotlin: https://www.apollographql.com/docs/kotlin
- kotlinx.serialization: https://kotlinlang.org/docs/serialization.html
- Moshi: https://github.com/square/moshi
- Code samples and bad→good pairs: [reference.md](./reference.md)
