# backend-contract-codegen — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code pairs per drift failure mode,
plus Mode-A codegen examples. JVM/Kotlin, Python, and Go examples — mix varies by rule.
Decision criteria and the guard checklist live in `SKILL.md`.

---

## Mode A — Codegen examples

### A1. OpenAPI-first: generate Kotlin-Spring server interface, implement it

```yaml
# src/main/resources/openapi.yaml (excerpt)
paths:
  /users/{id}:
    get:
      operationId: getUser
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: integer, format: int64 }
      responses:
        "200":
          content:
            application/json:
              schema: { $ref: "#/components/schemas/UserResponse" }
        "404":
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorEnvelope" }
components:
  schemas:
    UserResponse:
      required: [id, email]
      properties:
        id:   { type: integer, format: int64 }
        email: { type: string }
        name:  { type: string, nullable: true }
    ErrorEnvelope:
      required: [code, message]
      properties:
        code:    { type: string }
        message: { type: string }
```

```bash
# Generate (Maven plugin — runs on every compile):
# pom.xml:
# <plugin>
#   <groupId>org.openapitools</groupId>
#   <artifactId>openapi-generator-maven-plugin</artifactId>
#   <version>7.x</version>
#   <configuration>
#     <inputSpec>src/main/resources/openapi.yaml</inputSpec>
#     <generatorName>kotlin-spring</generatorName>
#     <configOptions>
#       <interfaceOnly>true</interfaceOnly>
#       <useSpringBoot3>true</useSpringBoot3>
#       <useTags>true</useTags>
#     </configOptions>
#   </configuration>
# </plugin>
```

```kotlin
// build/generated/.../UsersApi.kt  (generated — do not edit)
interface UsersApi {
    fun getUser(@PathVariable("id") id: Long): ResponseEntity<UserResponse>
}

// src/main/kotlin/.../UserController.kt  (hand-written implementation)
@RestController
class UserController(private val svc: UserService) : UsersApi {
    override fun getUser(id: Long): ResponseEntity<UserResponse> {
        val user = svc.find(id) ?: throw UserNotFoundException(id)
        return ResponseEntity.ok(user.toGeneratedResponse())  // maps to generated UserResponse type
    }
}

// Global exception handler maps typed errors to the generated ErrorEnvelope:
@RestControllerAdvice
class GlobalExceptionHandler {
    @ExceptionHandler(UserNotFoundException::class)
    fun handleNotFound(ex: UserNotFoundException): ResponseEntity<ErrorEnvelope> =
        ResponseEntity.status(404).body(ErrorEnvelope(code = "USER_NOT_FOUND", message = ex.message ?: ""))
}
```

### A2. GraphQL schema-first (DGS, JVM)

```graphql
# src/main/resources/schema/schema.graphqls
type Query {
  order(id: ID!): Order
}

type Order {
  id: ID!
  status: OrderStatus!
  total: Float!
  note: String          # nullable
}

enum OrderStatus { PENDING CONFIRMED SHIPPED CANCELLED }
```

```bash
# build.gradle.kts — DGS codegen generates types + data fetcher interfaces:
plugins { id("com.netflix.dgs.codegen") version "6.x" }
generateJava { schemaPaths = ["src/main/resources/schema"] }
# Run: ./gradlew generateJava
# Output: build/generated/sources/dgs/...
```

```kotlin
// Generated: types/Order.kt, types/OrderStatus.kt — do not edit.

// Hand-written data fetcher implements the generated interface:
@DgsComponent
class OrderDataFetcher(private val svc: OrderService) {
    @DgsQuery
    fun order(@InputArgument id: String): Order? =
        svc.find(id)?.toGeneratedType()   // returns generated Order, not a hand-written class
}
```

### A3. Go — oapi-codegen

```bash
# Generate server interface + types from openapi.yaml:
oapi-codegen -package api \
  -generate types,server,spec \
  openapi.yaml > internal/api/generated.go

# Wire via Echo or chi:
oapi-codegen -package api -generate chi-server openapi.yaml >> internal/api/generated.go
```

```go
// internal/api/generated.go (generated — do not edit)
type UserResponse struct {
    Id    int64   `json:"id"`
    Email string  `json:"email"`
    Name  *string `json:"name,omitempty"`  // nullable: true → pointer
}

// ServerInterface generated — implement it:
type ServerInterface interface {
    GetUser(w http.ResponseWriter, r *http.Request, id int64)
}

// internal/handler/user_handler.go (hand-written)
type UserHandler struct { svc *UserService }

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request, id int64) {
    u, err := h.svc.Find(id)
    if err != nil {
        render.JSON(w, r, api.ErrorEnvelope{Code: "USER_NOT_FOUND", Message: err.Error()})
        return
    }
    render.JSON(w, r, u.ToGeneratedResponse())
}
```

---

## Guard rule code pairs

### Rule 1 — Hand-written DTO instead of generated

```kotlin
// ❌ Parallel hand-written class — drifts from openapi.yaml independently
data class UserResponse(
    val id: Long,
    val email: String,
    val name: String?    // spec says nullable: true — correct today, will diverge tomorrow
)

// ✅ Use the generated type directly; only write the mapping from your domain entity
fun User.toGeneratedResponse(): UserResponse =
    UserResponse(id = this.id, email = this.email, name = this.displayName)
// UserResponse is generated by openapi-generator — not declared by hand
```

```python
# ❌ Pydantic model duplicating what FastAPI already derives from the openapi schema
class UserResponse(BaseModel):
    id: int
    email: str
    name: Optional[str] = None   # maintainer must keep this in sync with the spec manually

# ✅ FastAPI derives the response schema from the type — define it once in one place
# (or use datamodel-codegen to generate the model from openapi.yaml)
# datamodel-codegen --input openapi.yaml --output app/models/generated.py
from app.models.generated import UserResponse   # generated, not hand-written
```

```go
// ❌ Hand-written struct alongside a generated one
type UserResp struct {  // lives in handlers/types.go — separate from generated.go
    ID    int64  `json:"id"`
    Email string `json:"email"`
}

// ✅ Use api.UserResponse from generated.go everywhere
import "myapp/internal/api"
func toResponse(u *User) api.UserResponse {
    return api.UserResponse{Id: u.ID, Email: u.Email, Name: &u.DisplayName}
}
```

---

### Rule 2 — Untyped boundary

```kotlin
// ❌ Map<String, Any> at the controller — no type safety, no schema enforcement
@GetMapping("/users/{id}")
fun getUser(@PathVariable id: Long): ResponseEntity<Map<String, Any>> {
    val user = repo.findById(id).orElseThrow()
    return ResponseEntity.ok(mapOf("id" to user.id, "email" to user.email))
}

// ✅ Generated return type — compiler enforces the contract shape
@RestController
class UserController : UsersApi {
    override fun getUser(id: Long): ResponseEntity<UserResponse> =
        ResponseEntity.ok(svc.find(id).toGeneratedResponse())
}
```

```python
# ❌ dict return — no validation, no schema enforcement
@app.get("/users/{id}")
def get_user(id: int) -> dict:
    return {"id": id, "email": "a@b.com"}

# ✅ Typed return — FastAPI validates shape + generates accurate OpenAPI schema
@app.get("/users/{id}", response_model=UserResponse)
def get_user(id: int) -> UserResponse:
    return UserResponse(id=id, email="a@b.com", name=None)
```

```go
// ❌ interface{} or map[string]interface{} as handler response type
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request, id int64) {
    result := map[string]interface{}{"id": id, "email": "a@b.com"}
    json.NewEncoder(w).Encode(result)
}

// ✅ Generated api.UserResponse
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request, id int64) {
    u := h.svc.Find(id)
    render.JSON(w, r, u.ToGeneratedResponse())  // returns api.UserResponse
}
```

---

### Rule 3 — Stringly-typed endpoint

```kotlin
// ❌ Path string duplicated from the spec — a spec rename doesn't cascade
@GetMapping("/api/v1/users/{id}")   // also appears verbatim in openapi.yaml
fun getUser(@PathVariable id: Long) = ...

// ✅ Implement the generated interface — the path is defined exactly once (in the spec)
//    and the generator wires it to the interface. Rename it in the spec, regen, done.
@RestController
class UserController : UsersApi {          // UsersApi carries @RequestMapping generated from spec
    override fun getUser(id: Long): ResponseEntity<UserResponse> = ...
}
```

```python
# ❌ Hardcoded path in handler, duplicating the spec
@app.get("/api/v1/users/{id}")
def get_user(id: int): ...

# ✅ With FastAPI + openapi schema-first (using fastapi-code-generator or similar),
#    routes are generated from the spec. For code-first, the path in the decorator IS the spec —
#    the spec is always derived from the code annotation, not maintained separately.
#    Either way: one definition, not two.
```

```go
// ❌ Route registered by hand, also in openapi.yaml
r.Get("/api/v1/users/{id}", userHandler.GetUser)  // drift risk

// ✅ oapi-codegen chi-server generates the route registration:
//    api.HandlerFromMux(handler, r)   ← routes come from the spec, registered once
```

---

### Rule 4 — Unmodeled error/status

```kotlin
// ❌ Only the happy path — 404 falls through to framework default (stack trace or 500)
override fun getUser(id: Long): ResponseEntity<UserResponse> {
    val user = repo.findById(id).orElseThrow()   // throws EmptyResultDataAccessException → 500
    return ResponseEntity.ok(user.toGeneratedResponse())
}

// ✅ All declared status codes handled via typed responses + global exception mapper
override fun getUser(id: Long): ResponseEntity<UserResponse> {
    val user = repo.findById(id).orElseThrow { UserNotFoundException(id) }
    return ResponseEntity.ok(user.toGeneratedResponse())
}

@RestControllerAdvice
class ExceptionMapper {
    @ExceptionHandler(UserNotFoundException::class)
    fun notFound(ex: UserNotFoundException): ResponseEntity<ErrorEnvelope> =
        ResponseEntity.status(404).body(ErrorEnvelope("USER_NOT_FOUND", ex.message ?: ""))
    // ErrorEnvelope is generated from components/schemas/ErrorEnvelope in the spec
}
```

```python
# ❌ No 404 handling — FastAPI returns a 500 internal error or an undocumented shape
@app.get("/users/{id}", response_model=UserResponse)
def get_user(id: int):
    return db.find(id)   # returns None → validation error, not a 404

# ✅ All declared responses typed and raised explicitly
from fastapi import HTTPException
@app.get("/users/{id}", response_model=UserResponse,
         responses={404: {"model": ErrorEnvelope}})
def get_user(id: int) -> UserResponse:
    user = db.find(id)
    if user is None:
        raise HTTPException(status_code=404, detail=ErrorEnvelope(code="USER_NOT_FOUND", message="not found").dict())
    return user
```

---

### Rule 5 — Manual (de)serialization drift

```kotlin
// ❌ Hand-parsing JSON next to a generated model that already handles it
val json = JSONObject(responseBody)
val name = json.getString("user_name")    // manual, snake_case hardcoded

// ✅ Jackson + generated model with @JsonProperty — no hand-parsing
// Generated UserResponse already has:
//   @JsonProperty("user_name") val userName: String
// Just deserialize into the generated type:
val user = objectMapper.readValue(responseBody, UserResponse::class.java)
val name = user.userName   // field access, not string key
```

```python
# ❌ Manual dict access — field name hardcoded, bypasses Pydantic validation
raw = json.loads(body)
name = raw["user_name"]   # no validation, no type safety

# ✅ Pydantic model (generated or code-first) handles deserialization + alias mapping
class UserResponse(BaseModel):
    user_name: str = Field(alias="user_name")   # or generated by datamodel-codegen

user = UserResponse.model_validate_json(body)
name = user.user_name   # validated, typed
```

```go
// ❌ Hand-parsing struct fields from a map
var raw map[string]interface{}
json.Unmarshal(body, &raw)
name := raw["user_name"].(string)   // type assertion, no schema enforcement

// ✅ oapi-codegen generates struct tags; unmarshal directly into the generated type
var user api.UserResponse
json.Unmarshal(body, &user)   // struct tag: `json:"user_name,omitempty"` from spec
name := user.Name
```

---

### Rule 6 — Nullable/required mismatch

```kotlin
// ❌ Force-unwrap on a nullable field — schema has nullable: true, crashes on real data
val displayName = user.name!!.uppercase()   // NPE when name is absent

// ❌ Generated nullable type redeclared as non-null in a hand-written wrapper
data class UserWrapper(val name: String)    // drops the nullable; schema says Optional

// ✅ Respect nullability from the spec — handle the null branch explicitly
val displayName = user.name?.uppercase() ?: "Anonymous"

// ✅ Generated type preserves nullability: val name: String? = null
//    The compiler forces you to handle it. Do not add !! to bypass it.
```

```python
# ❌ Non-optional field when schema has required: false
class UserResponse(BaseModel):
    name: str   # crashes if server omits this field (schema allows omission)

# ✅ Match the schema's required annotation
class UserResponse(BaseModel):
    name: Optional[str] = None   # nullable: true, not required → Optional with default None
```

```go
// ❌ Value type for a nullable field — oapi-codegen emits *string for nullable: true
type UserResponse struct {
    Name string `json:"name"`   // loses nullability; unmarshals "" instead of nil
}

// ✅ Pointer type matches nullable: true in the spec (as generated by oapi-codegen)
type UserResponse struct {
    Name *string `json:"name,omitempty"`
}
// Check for nil before dereferencing:
if resp.Name != nil { fmt.Println(*resp.Name) }
```

---

### Rule 7 — Enum as raw string

```kotlin
// ❌ String literal where a generated enum exists
updateOrder(id, "PENDING")   // typo-prone, no exhaustiveness check

// ❌ when with else hiding new schema values silently
when (order.status) {
    "CONFIRMED" -> ship()
    "CANCELLED" -> refund()
    else -> {}   // silently ignores PENDING, SHIPPED — or new values added to the spec
}

// ✅ Use the generated enum; when is exhaustive (no else)
updateOrder(id, OrderStatus.PENDING)

when (order.status) {
    OrderStatus.PENDING   -> enqueue()
    OrderStatus.CONFIRMED -> ship()
    OrderStatus.SHIPPED   -> notify()
    OrderStatus.CANCELLED -> refund()
    // compiler error if a new value is added to the schema without handling it here
}
```

```python
# ❌ String comparison instead of the generated enum
if order.status == "PENDING":
    enqueue()

# ✅ Pydantic enum (generated or code-first) — exhaustive match via pattern match (3.10+)
from app.models.generated import OrderStatus
match order.status:
    case OrderStatus.PENDING:   enqueue()
    case OrderStatus.CONFIRMED: ship()
    case OrderStatus.SHIPPED:   notify()
    case OrderStatus.CANCELLED: refund()
    # no default — new enum values surface at parse time, not silently
```

```go
// ❌ String constant instead of generated iota/const type
const StatusPending = "PENDING"
if order.Status == StatusPending { ... }   // separate string, not linked to generated type

// ✅ Generated OrderStatus const block from oapi-codegen
// api/generated.go: type OrderStatus string; const (OrderStatusPending OrderStatus = "PENDING" ...)
switch order.Status {
case api.OrderStatusPending:   enqueue()
case api.OrderStatusConfirmed: ship()
case api.OrderStatusShipped:   notify()
case api.OrderStatusCancelled: refund()
default:
    return fmt.Errorf("unhandled status %q — schema may have added a new value", order.Status)
}
```

---

### Rule 8 — Regen without diffing

```bash
# ❌ Bump version + regen + commit wholesale with no review
echo "  version: 2.1.0" >> openapi.yaml
./gradlew generateJava
git add -A && git commit -m "regen"   # nobody sees what changed

# ✅ Review the generated diff before committing
# 1. Edit openapi.yaml — change or add a field/operation
# 2. Regen
./gradlew generateJava
# 3. Inspect what changed in the generated output
git diff build/generated/
# 4. Confirm: no removed operations, no changed required fields without a version bump
# 5. Stage selectively and annotate the PR with what the diff means for consumers
git add src/ build/generated/
git commit -m "feat: add note field to Order — additive, no breaking change (diff reviewed)"
```

```kotlin
// In CI: fail the build if committed generated code drifts from a fresh regen
// (ensures generated code in the repo always matches the spec):
// build.gradle.kts:
tasks.register("checkGeneratedUpToDate") {
    dependsOn("generateJava")
    doLast {
        val diff = exec { commandLine("git", "diff", "--exit-code", "build/generated") }
        if (diff.exitValue != 0) error("Generated code is out of date with openapi.yaml — run generateJava and commit.")
    }
}
tasks.named("check") { dependsOn("checkGeneratedUpToDate") }
```

---

### Rule 9 — Hand-edited generated file

```kotlin
// ❌ Editing the generated interface directly
// build/generated/src/main/kotlin/com/example/api/UsersApi.kt
interface UsersApi {
    fun getUser(id: Long): ResponseEntity<UserResponse>
    fun getUserAvatar(id: Long): ResponseEntity<ByteArray>   // ← hand-added, wiped on next regen
}

// ✅ Extend via a separate interface; do not touch the generated file
// src/main/kotlin/com/example/api/ExtendedUsersApi.kt
interface ExtendedUsersApi : UsersApi {
    fun getUserAvatar(id: Long): ResponseEntity<ByteArray>
}
// Or: add the operation to openapi.yaml and regen — that's the correct flow.
```

```python
# ❌ Editing a datamodel-codegen output file
# app/models/generated.py  ← generated
class UserResponse(BaseModel):
    id: int
    email: str
    nickname: str = ""   # ← hand-added field not in the schema — wiped on next regen

# ✅ Subclass if you need extra behavior; do not edit the generated file
from app.models.generated import UserResponse as _GeneratedUserResponse
class UserResponseWithNickname(_GeneratedUserResponse):
    nickname: str = ""
# Better: add the field to openapi.yaml and regen.
```

```go
// ❌ Adding a field to the generated struct
// internal/api/generated.go  (generated — do not edit)
type UserResponse struct {
    Id    int64   `json:"id"`
    Email string  `json:"email"`
    Extra string  `json:"extra"`   // hand-added — overwritten by next oapi-codegen run
}

// ✅ Use embedding or a wrapper; leave the generated file untouched
type UserResponseWithExtra struct {
    api.UserResponse
    Extra string `json:"extra"`
}
// Better: add the field to openapi.yaml and regen.
```

---

### Rule 10 — No single source of truth

```kotlin
// ❌ Server owns one definition, client team hand-maintains another
// server/openapi.yaml: components/schemas/UserResponse { id, email, name? }
// client/src/types/user.ts: interface UserResponse { id: number; email: string; displayName: string }
//   ^ different field name "displayName" vs "name" — silent drift, runtime misparse

// ✅ Publish the spec as an artifact; clients generate from it
// server publishes to an artifact registry or a well-known URL:
//   https://api.example.com/v1/openapi.yaml
// client runs:
//   npx openapi-typescript https://api.example.com/v1/openapi.yaml -o src/generated/api.d.ts
// One definition. Zero manual copies.
```

```python
# ❌ FastAPI service AND a separate Pydantic schema maintained by the data-science team
# service: class Order(BaseModel): status: str   (in app/models.py)
# DS team: class Order(BaseModel): order_status: str   (in notebooks/models.py)
# Diverged field names, undiscovered until someone runs the notebook against production

# ✅ Generate a shared schema from the canonical source and import it
# CI publishes openapi.json from the FastAPI service.
# DS team generates their models from the same spec:
#   datamodel-codegen --url https://api.example.com/openapi.json --output notebooks/generated.py
# One source. Both sides derive from it.
```

```go
// ❌ Two Go services each defining their own UserResponse — one for the producer, one for the consumer
// producer: internal/api/user.go { type UserResponse struct { Id int64; Email string } }
// consumer: internal/api/user.go { type UserResponse struct { Id int; Email string } }  // Id type mismatch

// ✅ Shared spec in a central repo; both sides run oapi-codegen against it
// producer publishes openapi.yaml → versioned artifact
// consumer's Makefile: oapi-codegen -package client openapi.yaml > internal/client/generated.go
// Type drift surfaces as a code diff, not a production deserialization error.
```

---

## Official references

- openapi-generator (kotlin-spring): https://openapi-generator.tech/docs/generators/kotlin-spring
- openapi-generator (general): https://openapi-generator.tech/
- oapi-codegen (Go): https://github.com/oapi-codegen/oapi-codegen
- springdoc-openapi: https://springdoc.org/
- FastAPI OpenAPI: https://fastapi.tiangolo.com/tutorial/first-steps/#openapi
- datamodel-codegen: https://docs.pydantic.dev/latest/integrations/datamodel_code_generator/
- Netflix DGS codegen: https://netflix.github.io/dgs/generating-code-from-schema/
- graphql-java: https://www.graphql-java.com/
- Strawberry GraphQL: https://strawberry.rocks/
- gqlgen: https://gqlgen.com/getting-started/
- Team baseline: [../../guidance.md](../../guidance.md)
- Contract definition: [../backend-api-contract/SKILL.md](../backend-api-contract/SKILL.md)
