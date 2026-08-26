# ios-contract-codegen — Reference

Deep-dive for `SKILL.md`. Mode-A pipeline examples and a bad→good Swift pair
for each of the 10 guard rules. Decision criteria live in `SKILL.md`.

## Mode A — Pipeline examples

### A1. swift-openapi-generator (build-plugin, SPM)

Full wiring from schema to typed call — no generated files committed:

```swift
// Package.swift (APIClient target)
// ponytail: build-plugin; generated code never hits source tree
.target(
    name: "APIClient",
    dependencies: [
        .product(name: "OpenAPIRuntime",    package: "swift-openapi-runtime"),
        .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
    ],
    plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
    ]
),
```

`openapi-generator-config.yaml` (sits next to `openapi.yaml` inside the target):

```yaml
generate:
  - types
  - client
```

Wiring a typed call with exhaustive error handling:

```swift
import OpenAPIURLSession

struct UserService {
    private let client: Client

    init() throws {
        client = Client(
            serverURL: try Servers.server1(),
            transport: URLSessionTransport()
        )
    }

    func getUser(id: String) async throws -> Components.Schemas.User {
        let response = try await client.getUser(
            .init(path: .init(userId: id))
        )
        switch response {
        case .ok(let ok):
            return try ok.body.json
        case .notFound(let nf):
            let body = try nf.body.json
            throw APIError.notFound(body.message)
        case .unauthorized:
            throw APIError.unauthorized
        case .undocumented(let status, _):
            throw APIError.unexpected(status)
        }
    }
}

enum APIError: Error {
    case notFound(String)
    case unauthorized
    case unexpected(Int)
}
```

### A2. openapi-generator swift5 (committed output)

```bash
# Regen — run after every schema change; review the diff before committing
openapi-generator generate \
  -i openapi.yaml \
  -g swift5 \
  -o Sources/GeneratedClient \
  --additional-properties=projectName=APIClient,responseAs=AsyncAwait,swiftUseApiNamespace=true
```

Add to `.gitignore` only the build artifacts, not the generated Swift:

```
# .gitignore — keep GeneratedClient in source; exclude only tool build products
.build/
*.o
```

### A3. Apollo iOS (GraphQL)

```bash
# Initialize once
apollo-ios-cli init \
  --schema-namespace MyAPI \
  --module-type swiftPackageManager \
  --target-name APIClient

# Regen after any .graphql operation or schema change
apollo-ios-cli generate
```

`apollo-codegen-config.json` (excerpt):

```json
{
  "schemaNamespace": "MyAPI",
  "input": {
    "operationSearchPaths": ["**/*.graphql"],
    "schemaSearchPaths": ["**/*.graphqls"]
  },
  "output": {
    "schemaTypes": { "path": "Sources/APIClient/Schema", "moduleType": { "swiftPackageManager": {} } },
    "operations": { "inSchemaModule": {} }
  }
}
```

Wiring a typed Apollo query:

```swift
import Apollo
import MyAPI

func fetchUser(id: String) async throws -> GetUserQuery.Data.User {
    try await withCheckedThrowingContinuation { continuation in
        Network.shared.apollo.fetch(query: GetUserQuery(userId: id)) { result in
            switch result {
            case .success(let graphQLResult):
                if let user = graphQLResult.data?.user {
                    continuation.resume(returning: user)
                } else if let errors = graphQLResult.errors {
                    continuation.resume(throwing: GraphQLError(errors))
                }
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
```

---

## Guard rules — bad→good Swift pairs

### Rule 1: Hand-written DTO instead of generated

```swift
// BAD — hand-written struct duplicating a schema component; will drift
struct UserResponse: Codable {
    let id: String
    let name: String
    let email: String      // schema later adds `role`; this struct misses it silently
}

func fetchUser() async throws -> UserResponse {
    let data = try await session.data(for: request).0
    return try JSONDecoder().decode(UserResponse.self, from: data)
}
```

```swift
// GOOD — generated type; schema changes propagate through regen + compiler
import OpenAPIRuntime   // or: import MyAPI (Apollo)

func fetchUser(id: String) async throws -> Components.Schemas.User {
    let response = try await client.getUser(.init(path: .init(userId: id)))
    switch response {
    case .ok(let ok): return try ok.body.json
    // ... other cases
    }
}
```

### Rule 2: Untyped boundary

```swift
// BAD — [String: Any] at the API boundary; no compiler enforcement
func fetchUser(id: String) async throws -> [String: Any] {
    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

// Caller
if let name = result["user_name"] as? String { … }   // wrong key, no error
```

```swift
// GOOD — generated type at the boundary; mismatched access is a compile error
func fetchUser(id: String) async throws -> Components.Schemas.User {
    let response = try await client.getUser(.init(path: .init(userId: id)))
    guard case .ok(let ok) = response else { throw APIError.unexpected }
    return try ok.body.json      // Components.Schemas.User — fully typed
}

// Caller
let user = try await fetchUser(id: id)
print(user.name)   // .name, not ["name"] — compile-time checked
```

### Rule 3: Stringly-typed endpoint

```swift
// BAD — URL path built by hand, duplicating the spec's /users/{userId}
func fetchUser(id: String) async throws {
    var comps = URLComponents(string: "https://api.example.com")!
    comps.path = "/users/\(id)"          // spec drift: no one checks this stays in sync
    let request = URLRequest(url: comps.url!)
    let (data, _) = try await URLSession.shared.data(for: request)
    …
}
```

```swift
// GOOD — generated client method owns the path; spec change = regen = compile error
func fetchUser(id: String) async throws -> Components.Schemas.User {
    let response = try await client.getUser(
        .init(path: .init(userId: id))   // path param, not a string
    )
    …
}
```

### Rule 4: Unmodeled error/status

```swift
// BAD — only 200 handled; spec declares 404 { message: string } — silently discarded
func fetchUser(id: String) async throws -> Components.Schemas.User {
    let response = try await client.getUser(.init(path: .init(userId: id)))
    guard case .ok(let ok) = response else {
        throw APIError.unknown    // 404 body thrown away; caller can't distinguish
    }
    return try ok.body.json
}
```

```swift
// GOOD — every declared response case handled with its typed body
func fetchUser(id: String) async throws -> Components.Schemas.User {
    let response = try await client.getUser(.init(path: .init(userId: id)))
    switch response {
    case .ok(let ok):
        return try ok.body.json
    case .notFound(let nf):
        let body = try nf.body.json          // Components.Schemas.ErrorBody
        throw APIError.notFound(body.message)
    case .unauthorized:
        throw APIError.unauthorized
    case .undocumented(let status, _):
        throw APIError.unexpected(status)
    }
}
```

### Rule 5: Manual (de)serialization drift

```swift
// BAD — hand-keyed JSON access; key is wrong ("user_name" vs schema "userName"); no error
func parseUser(data: Data) throws -> String {
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    return json["user_name"] as? String ?? ""   // schema says "userName"; silent empty
}
```

```swift
// GOOD — generated Codable conformance decodes correctly; key is enforced by the tool
func fetchUser(id: String) async throws -> Components.Schemas.User {
    let response = try await client.getUser(.init(path: .init(userId: id)))
    guard case .ok(let ok) = response else { throw APIError.unexpected }
    let user = try ok.body.json      // Codable mapping is generated from the schema
    print(user.userName)             // camelCase as the schema defines — correct
    return user
}
```

### Rule 6: Nullable/required mismatch

```swift
// BAD — schema marks `address` as optional (not in `required`); force-unwrap crashes
struct ProfileView: View {
    let user: Components.Schemas.User

    var body: some View {
        Text(user.address!)         // crash when server omits address
    }
}
```

```swift
// GOOD — generated type: address is `String?`; nil-coalesced or conditionally shown
struct ProfileView: View {
    let user: Components.Schemas.User   // address: String? (generated)

    var body: some View {
        if let address = user.address {
            Text(address)
        }
        // or:  Text(user.address ?? "No address")
    }
}
```

### Rule 7: Enum as raw string

```swift
// BAD — string compared to a schema enum field; no exhaustiveness, typo-prone
func label(for user: Components.Schemas.User) -> String {
    if user.status == "active" { return "Active" }     // schema has 3 cases; only 1 handled
    return "Inactive"
}
```

```swift
// GOOD — generated enum; switch is exhaustive; new case added to schema → compile error
func label(for user: Components.Schemas.User) -> String {
    switch user.status {                               // Components.Schemas.User.StatusPayload
    case .active:     return "Active"
    case .inactive:   return "Inactive"
    case .suspended:  return "Suspended"
    }
}
```

### Rule 8: Regen without diffing

```swift
// BAD — schema bumped from v1 to v2; `userName` renamed to `displayName`; regen committed
// without reviewing the diff; callers still reference .userName — runtime crash not caught
//
// Commit: "bump schema to v2"  ← no generated diff visible in PR
// Commit: "update generated"   ← diff committed separately; nobody reviewed breaking change
```

```swift
// GOOD — schema bump + regen + caller update in one PR; diff reviewed for breaking changes:
//
// PR includes:
//   openapi.yaml               (schema bump: userName → displayName)
//   Sources/GeneratedClient/   (regen output showing the rename — reviewed)
//   ProfileView.swift          (caller updated: user.userName → user.displayName)
//
// Compiler enforces completeness: .userName no longer exists → compile error at each caller.
```

### Rule 9: Hand-edited generated file

```swift
// BAD — computed property added inside a generated file; wiped on next regen
// File: Sources/GeneratedClient/Models/User.swift
// // GENERATED by openapi-generator — do not edit

public struct User: Codable {
    public var id: String
    public var name: String

    // ← hand-added; lost after next `openapi-generator generate`
    public var displayInitials: String { String(name.prefix(2)).uppercased() }
}
```

```swift
// GOOD — extension in a hand-written file imports the generated type; survives regen
// File: Sources/APIClient/Extensions/User+Display.swift

import GeneratedClient   // the generated target

extension User {
    var displayInitials: String {
        String(name.prefix(2)).uppercased()
    }
}
```

### Rule 10: No single source of truth

```swift
// BAD — iOS repo maintains its own User; backend maintains its schema's User;
// no codegen link; they diverge silently
//
// Backend schema:   User { id, name, email, role }
// iOS Models/User.swift (hand-written):
struct User: Codable {
    let id: String
    let name: String
    let email: String
    // `role` added to backend schema; iOS never knows; decoder silently drops it
}
```

```swift
// GOOD — iOS generates from the backend's schema; schema is the one source of truth
//
// Backend publishes: openapi.yaml (contains User component with id, name, email, role)
// iOS runs: openapi-generator generate -i openapi.yaml -g swift5 -o Sources/GeneratedClient
// Generated: Sources/GeneratedClient/Models/User.swift with id, name, email, role
// `role` added to backend → iOS regen picks it up → compiler flags every caller to handle it
```

---

## References

- `SKILL.md` for rules, scope, and checklist.
- apple/swift-openapi-generator: https://github.com/apple/swift-openapi-generator
- apple/swift-openapi-runtime: https://github.com/apple/swift-openapi-runtime
- apple/swift-openapi-urlsession: https://github.com/apple/swift-openapi-urlsession
- openapi-generator (swift5 generator): https://openapi-generator.tech/docs/generators/swift5
- Apollo iOS docs: https://www.apollographql.com/docs/ios/
- Apollo codegen CLI: https://www.apollographql.com/docs/ios/code-generation/codegen-cli
- Contract tests: [ios-testing](../ios-testing/SKILL.md)
- Auth/TLS: [ios-security](../ios-security/SKILL.md)
