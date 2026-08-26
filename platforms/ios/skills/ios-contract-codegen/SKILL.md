---
name: ios-contract-codegen
description: iOS API contract codegen — generate typed Swift client code from the OpenAPI/GraphQL
  contract (the single source of truth) instead of hand-writing types, and detect/block the drift AI
  commonly produces (hand-written DTO duplicating the schema, any/[String:Any] at the boundary,
  stringly-typed endpoints, unmodeled error/status responses, manual Codable drift, nullable/required
  mismatch, enum-as-raw-string, regen without diffing, hand-edited generated files, no single source
  of truth). Covers swift-openapi-generator (+ URLSession transport), openapi-generator swift5, and
  Apollo iOS for GraphQL. Auto-loads when generating Swift clients from a schema or wiring typed API calls.
when_to_use: When generating or wiring a Swift API client from OpenAPI/GraphQL, adding an endpoint,
  reviewing hand-written Swift models, or on requests like "generate the client", "types from the
  schema", "why is the client out of sync", "add an endpoint", "wire the API call".
paths: "**/openapi*.{yaml,yml,json}, **/*.graphql, **/*.graphql.swift, **/openapi-generator-config.*, **/apollo-codegen-config.json, **/Generated/**/*.swift, **/Sources/GeneratedClient/**"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# ios-contract-codegen

AI codegen ignores the API contract. It hand-writes a `Codable` struct that
mirrors a schema component and will silently drift, types responses as
`[String: Any]`, hardcodes URL path strings, models only the 200 happy path,
and hand-edits generated files that the next regen wipes. The result is
client/server drift and runtime surprises. This skill is a **generator** (run
the platform codegen tool, wire the typed Swift client) plus a **guard** (block
hand-written contract drift). Project `ctx/` overrides this document. Code
examples — bad→good Swift pairs for every rule — live in
[reference.md](./reference.md).

## Scope

- **In scope**: pointing at the schema (single source of truth), running the
  iOS codegen tool, wiring the generated typed client, regenerating on schema
  change, and guarding against the 10 contract-drift failure modes below.
- **Delegate**:
  - Contract definition and review → there is no `ios-api-contract` skill; the
    server owns the schema. Cross-link your backend's OpenAPI/GraphQL source.
  - Client/data-layer architecture (where the generated client lives in the
    module graph) → [ios-architecture], [ios-module-structure].
  - Contract tests (snapshot, integration) → [ios-testing].
  - Auth headers, TLS, certificate pinning → [ios-security].
- **Reality**: the schema is the contract. Hand-writing a parallel Swift model
  is a second contract that nobody enforces.

## Mode A — Generate

### 1. Find the schema (single source of truth)

The server owns the schema. Locate the canonical file before writing any Swift:

```bash
# OpenAPI
find . -name "openapi*.yaml" -o -name "openapi*.yml" -o -name "openapi*.json"

# GraphQL
find . -name "*.graphql" -o -name "*.graphqls"
```

If the schema lives in a backend repo, fetch or vendor it — don't hand-copy
types. Pin the version you consumed (a git submodule, a downloaded artifact, or
the URL + SHA in a comment).

### 2a. OpenAPI → swift-openapi-generator (preferred for SPM projects)

Apple's [swift-openapi-generator](https://github.com/apple/swift-openapi-generator)
runs as an SPM build plugin: the generated code is produced at build time,
never committed to source.

**Package.swift** — add the plugin and runtime:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.3.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime",   from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
],
targets: [
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
]
```

**openapi-generator-config.yaml** (next to `openapi.yaml` in the target's source dir):

```yaml
generate:
  - types
  - client
```

The plugin generates `Types.swift` and `Client.swift` into the build directory
on every build — never in your source tree. Add the build dir to `.gitignore`.

### 2b. OpenAPI → openapi-generator swift5 (alternative, generates into source)

```bash
openapi-generator generate \
  -i openapi.yaml \
  -g swift5 \
  -o Sources/GeneratedClient \
  --additional-properties=projectName=APIClient,responseAs=AsyncAwait
```

Generated files land in `Sources/GeneratedClient/`. Mark that directory with a
`// GENERATED — do not edit` header comment. Commit the generated output so the
build is reproducible without the CLI tool on CI.

### 2c. GraphQL → Apollo iOS

```bash
# Install (once)
brew install apollo-ios-cli   # or SPM: Apollo iOS SDK

# Initialize config (once)
apollo-ios-cli init --schema-namespace MyAPI --module-type swiftPackageManager

# Generate
apollo-ios-cli generate
```

`apollo-codegen-config.json` points at your schema source (URL or local file)
and your `.graphql` operation files. Generated Swift lives in the path specified
by `output.testMocks` / `output.operations`. Commit the generated Swift — it is
part of your reproducible build.

### 3. Wire a typed call with typed error handling

Never call the raw `URLSession`/`URLRequest` next to generated types. Use the
generated client's typed operation methods and handle every declared error case:

```swift
// swift-openapi-generator client wiring (URLSession transport)
import OpenAPIURLSession

let client = Client(
    serverURL: try Servers.server1(),
    transport: URLSessionTransport()
)

func fetchUser(id: String) async throws -> Components.Schemas.User {
    let response = try await client.getUser(.init(path: .init(userId: id)))
    switch response {
    case .ok(let ok):
        return try ok.body.json          // typed; no [String:Any] cast
    case .notFound(let nf):
        throw APIError.notFound(try nf.body.json.message)
    case .undocumented(let status, _):
        throw APIError.unexpected(status)
    }
}
```

For Apollo iOS:

```swift
Network.shared.apollo.fetch(query: GetUserQuery(userId: id)) { result in
    switch result {
    case .success(let graphQLResult):
        if let user = graphQLResult.data?.user {
            // user is GetUserQuery.Data.User — fully typed
        }
        if let errors = graphQLResult.errors {
            // handle GraphQL errors
        }
    case .failure(let error):
        // network-level error
    }
}
```

### 4. Regen discipline

- A new field or endpoint is a **schema change + regen** reviewed once in the
  generated diff — never a hand-written parallel model added next to the generated
  one.
- On schema bump: regenerate → review the generated diff for breaking changes →
  update callers → commit. Never skip the diff review.
- With swift-openapi-generator (build-plugin mode): schema change triggers
  regen automatically on next build. Review the compiler errors as the diff.
- With openapi-generator/Apollo (committed output): include the regen in the
  same commit as the schema bump. PR must show a generated-file diff.
- **Never hand-edit a generated file.** Place customizations in hand-written
  wrappers that import the generated types.

## Mode B — Guard

Each item: **rule → common AI failure → red-flag**. Code pairs in [reference.md](./reference.md).

### 1. Hand-written DTO instead of generated

- **Rule**: schema types are generated, not hand-written. A `Codable` struct or
  `class` whose fields mirror a schema component and is maintained by hand will
  drift.
- **Common AI failure**: writing a `struct UserResponse: Codable { let id: String; let name: String }` next to the schema component `User` — a duplicate that nobody keeps in sync.
- **red-flag**: a `Codable` model whose field names and types exactly mirror a schema component, living in hand-written source rather than a `Generated/` directory.

### 2. Untyped boundary

- **Rule**: API call results must be typed as generated schema types. Never use
  `[String: Any]`, `AnyObject`, or a manual `JSONSerialization` cast at the
  API boundary.
- **Common AI failure**: `let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]` followed by string-keyed access.
- **red-flag**: `[String: Any]`, `AnyObject`, or `as! [String: Any]` on an API response.

### 3. Stringly-typed endpoint

- **Rule**: use the generated client's typed operation methods. Never build a
  URL path string by hand next to a schema that already defines the operation.
- **Common AI failure**: `URLRequest(url: URL(string: "https://api.example.com/users/\(id)")!)` inline, duplicating a path the spec already defines.
- **red-flag**: a hardcoded URL path string or `URLComponents` path construction that mirrors a schema operation.

### 4. Unmodeled error/status

- **Rule**: every declared error response in the schema has a typed Swift case.
  Never handle only `200` and ignore `4xx`/`5xx` error schemas.
- **Common AI failure**: `guard response.statusCode == 200 else { throw SomeGenericError() }` — the spec declares a `404` body with a structured error, ignored.
- **red-flag**: a `switch response` / status-code check that has no cases for the spec's declared error responses; a single `catch` that discards typed error bodies.

### 5. Manual (de)serialization drift

- **Rule**: let generated `Codable` conformances decode/encode. Never write
  `init(from:)` / `encode(to:)` by hand for a generated type, and never access
  JSON keys by string literal.
- **Common AI failure**: `let name = json["user_name"] as? String` — the schema says `userName` (camelCase) and the generated type already maps it correctly; the hand-written key is wrong.
- **red-flag**: string-literal JSON key access (`json["key"]`), a hand-written `CodingKeys` enum for a generated type, snake/camel mismatch between a hand-written key and the schema's field name.

### 6. Nullable/required mismatch

- **Rule**: if the schema marks a field as optional (`required` array omits it,
  or `nullable: true`), the Swift property must be `Optional`. Never
  force-unwrap or use a non-optional type for a schema-optional field.
- **Common AI failure**: `let email: String` for a schema field marked optional → crash when the server omits it; `user.address!` where `address` is not in `required`.
- **red-flag**: a non-optional Swift property for a schema-optional field; force-unwrap (`!`) on a field not guaranteed by the schema.

### 7. Enum as raw string

- **Rule**: a schema `enum` field has a generated Swift enum with exhaustive
  cases. Never use a `String` where a generated enum type exists.
- **Common AI failure**: `if status == "active"` — the schema has an `enum: [active, inactive, suspended]`; the generated client produces a `Components.Schemas.Status` enum.
- **red-flag**: a string literal compared to a field the schema defines as an enum; a `String` property where the generated type is an enum.

### 8. Regen without diffing

- **Rule**: every schema/version bump must include a generated-code diff review
  for breaking changes before callers are updated.
- **Common AI failure**: bumping `openapi.yaml` and regenerating in a separate
  commit with message "update generated" — no diff reviewed, a renamed field
  silently breaks callers at runtime.
- **red-flag**: a schema version bump with no generated-file diff in the PR; regen committed separately from the schema change.

### 9. Hand-edited generated file

- **Rule**: generated files are owned by the tool. Any manual edit is lost on
  the next regen. Customizations go in hand-written wrappers that import the
  generated types.
- **Common AI failure**: adding a computed property directly inside `Sources/GeneratedClient/APIs/UsersAPI.swift` — wiped on next `openapi-generator generate`.
- **red-flag**: a diff inside a `Generated/`, `GeneratedClient/`, or Apollo-output directory that is not a regen output; a `// GENERATED` file with non-generated edits.

### 10. No single source of truth

- **Rule**: the server's schema is the one source of contract truth. The iOS
  client has no independent copy of the shape — it generates from the schema.
- **Common AI failure**: a `Models/User.swift` in the iOS repo maintained by hand in parallel with the backend's `User` schema component, with no codegen link between them.
- **red-flag**: two independent definitions of the same contract type — one in the iOS project source, one in the schema — with no codegen relationship.

## Guard checklist

Before merging any API-touching Swift code:

- [ ] Schema types are generated (swift-openapi-generator / openapi-generator / Apollo), not hand-written.
- [ ] No `[String: Any]`, `AnyObject`, or `JSONSerialization` cast at the API boundary.
- [ ] Endpoints called via generated client methods, not hand-built URL strings.
- [ ] All declared error responses (4xx/5xx) handled with typed Swift cases.
- [ ] No hand-written `CodingKeys` or string-keyed JSON access for generated types.
- [ ] Optional schema fields are `Optional` in Swift; no force-unwrap on schema-optional fields.
- [ ] Schema enum fields use the generated Swift enum type, not a `String`.
- [ ] Schema bump includes a generated-diff review in the same PR.
- [ ] No diffs inside `Generated/` or Apollo output directories except regen output.
- [ ] No hand-maintained Swift model duplicating a schema component.

## Halt conditions

Halt and report if:

- No schema file is locatable (no `openapi*.yaml`/`.yml`/`.json`, no `.graphql`).
- The schema is unreachable (a URL reference with no local copy and no network).
- Multiple conflicting schema files exist with no clear canonical source.

**Output on halt:**

```
## Contract Codegen — Halted

Halt reason:
- (specific reason)

Needs clarification:
1. ...
```

Do not propose alternatives. Do not explain how to fix. Output halt reason only.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Umbrella: [ios-architecture](../ios-architecture/SKILL.md)
- Module layout (where the generated client target lives): [ios-module-structure](../ios-module-structure/SKILL.md)
- Contract tests: [ios-testing](../ios-testing/SKILL.md)
- Auth/TLS/pinning: [ios-security](../ios-security/SKILL.md)
- apple/swift-openapi-generator: https://github.com/apple/swift-openapi-generator
- apple/swift-openapi-runtime: https://github.com/apple/swift-openapi-runtime
- apple/swift-openapi-urlsession: https://github.com/apple/swift-openapi-urlsession
- openapi-generator (swift5): https://openapi-generator.tech/docs/generators/swift5
- Apollo iOS: https://www.apollographql.com/docs/ios/
- Code examples — bad→good Swift pairs: [reference.md](./reference.md)
