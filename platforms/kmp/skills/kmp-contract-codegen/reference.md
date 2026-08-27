# kmp-contract-codegen — Reference

Deep-dive for `SKILL.md`. Mode-A codegen commands + wiring examples, and a
bad → good Kotlin pair for each of the 10 guard rules. Decision criteria live in
`SKILL.md`.

---

## Mode A — Codegen end to end

### OpenAPI → openapi-generator (kotlin / multiplatform)

```bash
# 1. Install (once per machine or CI image)
brew install openapi-generator
# or: docker run --rm -v "$PWD:/local" openapitools/openapi-generator-cli generate ...

# 2. Generate into commonMain/generated/ — run from repo root
openapi-generator generate \
  -i api/openapi.yaml \
  -g kotlin \
  -o shared/src/commonMain/generated \
  --additional-properties=\
library=multiplatform,\
serializationLibrary=kotlinx_serialization,\
packageName=com.example.api,\
dateLibrary=kotlinx-datetime

# 3. Wire as a source set (not a sub-project) — add to build.gradle.kts:
# kotlin { sourceSets { commonMain { kotlin.srcDir("src/commonMain/generated/src/main/kotlin") } } }

# 4. After every schema change: re-run step 2, review the diff, update callers
git diff shared/src/commonMain/generated/ | grep '^[+-]' | grep -v '^---\|^+++' | head -60
```

### GraphQL → Apollo Kotlin

```kotlin
// shared/build.gradle.kts
plugins {
    id("com.apollographql.apollo3") version "4.x.x"
}

apollo {
    service("api") {
        packageName.set("com.example.graphql")
        schemaFile.set(file("src/commonMain/graphql/schema.graphqls"))
        srcDir("src/commonMain/graphql")       // *.graphql operation files here
        generateKotlinModels.set(true)
    }
}
```

```bash
# Place operation files in src/commonMain/graphql/:
# GetUser.graphql, CreateOrder.graphql, etc.

./gradlew generateApolloSources
# → generates GetUserQuery, CreateOrderMutation, etc. as @Serializable data classes
```

### Wiring a generated call with typed error handling

```kotlin
// shared/src/commonMain/kotlin/data/remote/UserRemoteDataSource.kt
// ✅ Uses the generated UserApi from openapi-generator output; error bodies are typed.

import com.example.api.apis.UserApi
import com.example.api.models.User
import com.example.api.models.ValidationErrorResponse
import io.ktor.client.plugins.*

class UserRemoteDataSource(private val api: UserApi) {

    suspend fun fetchUser(id: Int): User {
        return try {
            api.getUser(id)                          // generated method, returns typed User
        } catch (e: ClientRequestException) {
            val status = e.response.status
            when (status.value) {
                404 -> throw UserNotFoundException(id)
                422 -> {
                    val err = e.response.body<ValidationErrorResponse>() // generated model
                    throw ValidationException(err.message)
                }
                else -> throw ApiException("Unexpected status ${status.value}", e)
            }
        }
    }
}
```

---

## Guard rule bad → good pairs

### 1. Hand-written DTO instead of generated

```kotlin
// ❌ Manual data class mirroring the schema — will drift on every schema change
data class CreateOrderRequest(
    val userId: String,
    val itemIds: List<String>,
    val total: Double,
)

// Hand-rolled serialization — @SerialName must be kept in sync manually
fun CreateOrderRequest.toJson(): String =
    """{"user_id":"$userId","item_ids":${itemIds},"total":$total}"""

// ✅ Use the generated model — run codegen, then import
import com.example.api.models.CreateOrderRequest

// CreateOrderRequest is already defined; just construct it:
val req = CreateOrderRequest(
    userId = userId,
    itemIds = selectedIds,
    total = cartTotal,
)
api.createOrder(req)
```

### 2. Untyped boundary

```kotlin
// ❌ Any / Map<String,Any?> at the response boundary
val response = client.get("$baseUrl/api/v1/users/$id")
val data = response.body<Map<String, Any?>>()
val name = data["name"] as String         // crashes if field renamed/missing
val email = data["email"] as String?

// ✅ Generated client returns a typed @Serializable model
val user = api.getUser(id)               // User — typed, IDE-navigable
val name = user.name                     // String
val email = user.email                   // String? — nullability from schema
```

### 3. Stringly-typed endpoint

```kotlin
// ❌ Raw URL string duplicates the spec path — diverges on rename or version bump
val response = client.post("$baseUrl/api/v1/orders") {
    setBody(mapOf("user_id" to userId, "item_ids" to itemIds))
    contentType(ContentType.Application.Json)
}

// ✅ Generated client method encodes path + verb + parameters
val order = api.createOrder(
    CreateOrderRequest(userId = userId, itemIds = itemIds, total = total)
)
```

### 4. Unmodeled error/status responses

```kotlin
// ❌ Only 200 happy path — error body silently dropped
try {
    val order = api.createOrder(req)
    return order
} catch (e: Exception) {
    Napier.e("error", e)  // drops the typed error body the spec defines for 400/422
    throw e
}

// ✅ Spec-declared error schemas typed and handled
try {
    return api.createOrder(req)
} catch (e: ClientRequestException) {
    val status = e.response.status.value
    val body = runCatching { e.response.body<Map<String, Any?>>() }.getOrNull()
    when (status) {
        422 -> {
            val err = e.response.body<ValidationErrorResponse>() // generated model
            throw OrderValidationException(fields = err.errors)
        }
        409 -> throw DuplicateOrderException()
        else -> throw ApiException("Unexpected $status", e)
    }
}
```

### 5. Manual (de)serialization drift

```kotlin
// ❌ Hand-rolled parsing — field name mismatch silently returns null or crashes
fun parseUser(json: JsonObject): User {
    return User(
        id = json["id"]!!.jsonPrimitive.int,
        name = json["user_name"]!!.jsonPrimitive.content, // schema says "userName" — mismatch
        createdAt = Instant.parse(json["created_at"]!!.jsonPrimitive.content),
    )
}

// ✅ Generated @Serializable data class handles @SerialName mappings
// User.kt is generated — do not edit
import com.example.api.models.User

val user = Json.decodeFromString<User>(responseBody) // field names, nullability: all from schema
// Or via Ktor ContentNegotiation: val user = response.body<User>()
```

### 6. Nullable/required mismatch

```kotlin
// ❌ Non-null assertion on a field the schema marks optional (not in required[])
// Schema: email is optional
val user = api.getUser(id)
val email = user.email!!   // crashes when backend legally omits email

// ❌ Non-null Kotlin type for an optional field in a hand-written model
data class User(
    val id: Int,
    val email: String,   // schema says optional — should be String?
)

// ✅ Nullability mirrors the schema; handle the absent case
val email = user.email        // String? — from generated model
if (email != null) {
    emailController.text = email
}
```

### 7. Enum as raw string

```kotlin
// ❌ Raw string literal — no exhaustiveness, breaks on schema rename
if (order.status == "PENDING") {
    showPendingBanner()
} else if (order.status == "SHIPPED") {
    showTrackingButton()
}
// New status "PROCESSING" added to schema → silently unhandled

// ✅ Generated enum class — when is exhaustive; compiler flags missing cases
when (order.status) {            // OrderStatus from generated model
    OrderStatus.PENDING -> showPendingBanner()
    OrderStatus.SHIPPED -> showTrackingButton()
    OrderStatus.PROCESSING -> showProcessingIndicator()
    // Kotlin sealed when → compile error if a new value is added and not handled
}
```

### 8. Regen without diffing

```kotlin
// ❌ Schema bumped, codegen re-run, committed without reviewing the generated diff
// PR description: "Bump API to v2.1"
// git diff shows shared/src/commonMain/generated/models/Order.kt changed:
//   - val total: Double
//   + val totalCents: Int    // ← breaking: callers using .total now fail to compile

// ✅ After regen, review the generated diff before merging
// In the PR:
// 1. Run: git diff shared/src/commonMain/generated/
// 2. Note breaking changes (field type, removed field, renamed operation)
// 3. Update callers in the same PR
// 4. Add a PR note: "Breaking: Order.total (Double) → Order.totalCents (Int, cents)"
```

```bash
# Surface only generated-file changes for quick review
git diff HEAD shared/src/commonMain/generated/ -- '*.kt' \
  | grep '^[+-]' | grep -v '^---\|^+++' | head -60
```

### 9. Hand-edited generated file

```kotlin
// ❌ Direct edit inside generated/ to "fix" a missing header
// shared/src/commonMain/generated/src/main/kotlin/com/example/api/apis/UserApi.kt
// DO NOT EDIT — generated by openapi-generator

suspend fun getUser(id: Int): User {
    return client.get("$baseUrl/users/$id") {
+       header("X-Client", "kmp")   // hand-added — wiped by next regen
    }.body()
}

// ✅ Customizations go in a wrapper outside the generated directory
// shared/src/commonMain/kotlin/infra/ApiClientFactory.kt
fun buildHttpClient(): HttpClient = HttpClient {
    defaultRequest {
        header("X-Client", "kmp")   // survives regen; lives outside generated/
    }
    install(ContentNegotiation) { json() }
    install(Auth) { bearer { loadTokens { BearerTokens(tokenStorage.read(), "") } } }
}
// UserApi(buildHttpClient()) — generated class untouched
```

### 10. No single source of truth

```kotlin
// ❌ Two independent definitions of the same contract type
// shared/src/commonMain/kotlin/model/UserProfile.kt (hand-written in KMP)
data class UserProfile(
    val id: String,
    val displayName: String,   // backend renamed to 'name' last sprint — missed here
    val avatarUrl: String?,
)

// shared/src/commonMain/generated/.../models/UserProfile.kt (generated OR hand-written in a package)
data class UserProfile(
    val id: String,
    val name: String,          // current; KMP copy still says displayName
    val avatarUrl: String?,
)

// ✅ One generated definition; the app imports it directly
import com.example.api.models.UserProfile
// No hand-written shared/src/commonMain/kotlin/model/UserProfile.kt
// Schema change → regen → one place to update
```

---

## Regenerate workflow summary

```
schema change (backend PR)
       ↓
pull schema / bump version ref
       ↓
openapi-generator generate … (or ./gradlew generateApolloSources)
       ↓
git diff shared/src/commonMain/generated/  — review breaking changes
       ↓
update callers in the same PR
       ↓
./gradlew test  (contract tests in kmp-testing catch regressions)
       ↓
merge
```

Never commit a schema bump without the generated diff and the caller update in the same PR.
Generated files are the reviewable artifact of a schema change — they belong in version control
alongside the schema reference.

---

## References

- `SKILL.md` for rules, guard checklist, and halt conditions.
- openapi-generator kotlin: https://openapi-generator.tech/docs/generators/kotlin
- Apollo Kotlin: https://www.apollographql.com/docs/kotlin/
- kotlinx.serialization: https://github.com/Kotlin/kotlinx.serialization
- Ktor client (HttpClient): https://ktor.io/docs/client-create-new-application.html
- Ktor MockEngine (testing): https://ktor.io/docs/client-testing.html
- Contract tests: [kmp-testing](../kmp-testing/SKILL.md)
- Auth / TLS: [kmp-security](../kmp-security/SKILL.md)
