---
name: flutter-contract-codegen
description: Flutter API contract codegen — generate typed Dart client code from the OpenAPI/GraphQL
  contract (the single source of truth) instead of hand-writing types, and detect/block the drift AI
  commonly produces (hand-written DTO duplicating the schema, dynamic at the boundary, stringly-typed
  endpoints, unmodeled error/status responses, manual (de)serialization drift, nullable/required mismatch,
  enum-as-raw-string, regen without diffing, hand-edited generated files, no single source of truth).
  Covers dart-dio (openapi-generator), swagger_parser + retrofit + json_serializable, and GraphQL ferry/artemis.
  Auto-loads when generating Dart clients from a schema or reviewing hand-written API models.
when_to_use: When generating or wiring a Dart API client from OpenAPI/GraphQL, adding an endpoint,
  reviewing hand-written models or DTOs, or on requests like "generate the client", "types from the
  schema", "why is the client out of sync", "add the API call".
paths: "**/openapi*.{yaml,yml,json}, **/*.graphql, **/*.g.dart, **/build.yaml, **/pubspec.yaml"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# flutter-contract-codegen — API contract → typed Dart client

The OpenAPI or GraphQL schema is the **single source of truth**. AI codegen
ignores it: it hand-writes a `class UserDto` that mirrors a schema component,
types the response as `dynamic` or `Map<String, dynamic>`, hardcodes the URL
string, models only the happy 200 path, and hand-edits a `*.g.dart` that the
next `build_runner` run silently overwrites. The result is client/server drift
and runtime type errors that only surface in production. This skill is both a
**generator** (run the codegen tool, wire the typed client) and a **guard**
(block hand-written drift before it merges). Project `ctx/` overrides this
document. Code samples in [reference.md](./reference.md).

## Scope

- In scope: running the Dart codegen tool, wiring the generated client, typed
  error handling, regenerate discipline, and the 10 guard rules below.
- Out of scope: defining or reviewing the contract itself → there is no
  `flutter-api-contract` skill; the contract is owned by the backend. The
  schema's source of truth lives server-side — cross-link `backend-api-contract`
  (where it exists) for contract ownership.
- Delegate to adjacent skills: overall client/data layer architecture →
  [flutter-architecture]; contract tests, mock server, golden responses →
  [flutter-testing]; auth headers, token storage, TLS → [flutter-security].

## Mode A — Generate: schema → typed Dart client

### 1. Locate the schema (the single source of truth)

Find the OpenAPI spec (`openapi.yaml` / `openapi.json`) or GraphQL schema
(`*.graphql` / `*.graphqls`) that the backend publishes. Never copy-paste type
shapes from a browser network tab or from another client's DTO — that is already
drift. The spec is what you run codegen against.

### 2. Run the codegen tool

**OpenAPI — dart-dio (openapi-generator):**

```bash
# Install once
dart pub global activate openapi_generator_cli

# Generate into lib/generated/ — commit the output OR generate in CI, pick one
openapi-generator generate \
  -i openapi.yaml \
  -g dart-dio \
  -o lib/generated/api \
  --additional-properties=pubName=my_api,nullSafe=true,serializationLibrary=json_serializable
```

**OpenAPI — swagger_parser + retrofit + json_serializable:**

```yaml
# pubspec.yaml dev_dependencies
dev_dependencies:
  swagger_parser: ^1.x
  retrofit_generator: ^8.x
  json_serializable: ^6.x
  build_runner: ^2.x
```

```bash
dart run swagger_parser  # generates .dart stubs from openapi.yaml configured in swagger_parser.yaml
dart run build_runner build --delete-conflicting-outputs
```

**GraphQL — ferry:**

```bash
dart pub add ferry ferry_generator gql_build source_gen
dart run build_runner build
# generates *.req.gql.dart / *.data.gql.dart / *.var.gql.dart from *.graphql
```

**GraphQL — artemis:**

```bash
dart pub add artemis
dart run build_runner build
# generates *.graphql.dart per schema operation
```

The calibration knob: a new field or endpoint is a **schema change + regen**,
reviewed once in the generated diff — never a hand-written parallel model.

### 3. Wire a typed call with typed error handling

Import the generated client; never re-declare its types:

```dart
// ✅ Generated client wired in the data layer
final api = UserApi(Dio(BaseOptions(baseUrl: Env.apiBase)));

Future<User> fetchUser(int id) async {
  try {
    final response = await api.getUser(id);      // generated operation method
    return response.data!;                        // typed: User, not Map<String,dynamic>
  } on DioException catch (e) {
    final body = e.response?.data;
    if (e.response?.statusCode == 404) {
      throw UserNotFoundException.fromJson(body as Map<String, dynamic>);
    }
    throw ApiException.fromDioError(e);           // typed error, not String
  }
}
```

### 4. Regenerate discipline

- When the schema changes, run the codegen command and commit the diff.
- Review the generated diff for breaking changes (removed fields, changed types,
  renamed operations) before merging — this is the schema-bump review, not a
  handwritten change.
- Never hand-edit a `*.g.dart` or any file inside the generated output directory.
  Put customizations (error mapping, retry logic, auth interceptors) in wrapper
  classes outside the generated tree.
- Decide once: commit generated files OR generate in CI. Mixed conventions cause
  the "why is the client out of sync" class of bugs.

## Mode B — Guard: 10 contract-drift failure modes (must not be relaxed)

Each item: **rule → common AI failure → red-flag**. Bad/good Dart pairs in
[reference.md](./reference.md).

### 1. Hand-written DTO instead of generated

- **Rule**: model classes for API types are generated from the schema, not
  hand-written. A `class UserDto` with fields mirroring a schema component is a
  duplicate that will drift.
- **Common AI failure**: writing `class CreateOrderRequest { final String userId;
  final List<Item> items; }` from memory or from a network-tab snapshot, instead
  of running codegen against the spec that already defines this shape.
- **red-flag**: a Dart model whose field names mirror a schema component, no
  `@JsonSerializable` / generated `fromJson` factory pointing at a `.g.dart`, and
  no generated file in the same package.

### 2. Untyped boundary

- **Rule**: API call results are typed to the generated model class, never to
  `dynamic`, `Map<String, dynamic>`, or `Object?` at the call site.
- **Common AI failure**: `final data = response.data as Map<String, dynamic>;
  final name = data['name'] as String;` — abandons the type system at the network
  boundary.
- **red-flag**: `dynamic`, `Map<String, dynamic>`, or `as Map` at the return
  type or first-use site of an API response.

### 3. Stringly-typed endpoint

- **Rule**: call API operations via the generated client method (which encodes the
  path, verb, and parameters). Do not hardcode URL path strings inline.
- **Common AI failure**: `final res = await dio.get('/api/v1/users/$id');` —
  duplicates the spec's path outside codegen, diverges on rename/version bump.
- **red-flag**: a raw `dio.get('/api/...')` / `dio.post('/api/...')` string literal
  at a call site where a generated client method exists.

### 4. Unmodeled error/status responses

- **Rule**: the spec's declared 4xx/5xx error schemas are typed and handled. Only
  modeling the 200 path leaves error bodies untyped and unhandled.
- **Common AI failure**: `try { final r = await api.createOrder(req); } catch (e)
  { print(e); }` — catches `DioException` but ignores the typed error body the spec
  defines for 400/422/500.
- **red-flag**: a `catch` block that ignores `e.response?.statusCode` and the
  typed error schema, or no `catch` at all on an API call that declares errors.

### 5. Manual (de)serialization drift

- **Rule**: JSON (de)serialization uses the generated `fromJson`/`toJson`
  (json_serializable, json_annotation, or the generated codec). Hand-rolled
  `json['field']` access drifts from the schema on field renames.
- **Common AI failure**: `final name = json['user_name'] as String;` where the
  schema field is `userName` (camelCase) and the generated codec would have applied
  the `@JsonKey(name: 'user_name')` annotation.
- **red-flag**: manual `json['key']` map access or string-keyed `Map` unpacking on
  an API response type that the schema defines.

### 6. Nullable/required mismatch

- **Rule**: nullability in Dart mirrors the schema. A field the schema marks
  optional (`required: false` / no `required` array entry) must be `T?` in Dart.
  Force-unwrapping an optional field crashes on any response that omits it.
- **Common AI failure**: `final email = user.email!;` where the schema marks
  `email` as optional — works in the happy path, crashes the moment the backend
  legally omits the field.
- **red-flag**: `!` (force-unwrap) or a non-null Dart type for a field the schema
  declares as optional; or `T?` (nullable) for a field the schema marks required.

### 7. Enum as raw string

- **Rule**: schema-defined enum values are used as the generated enum type, not as
  bare string literals. String literals have no exhaustiveness check — a new enum
  value added to the schema silently falls through.
- **Common AI failure**: `if (order.status == 'PENDING') { … }` where the spec and
  codegen produce `OrderStatus.pending` — the raw string is unchecked and breaks on
  a spec rename.
- **red-flag**: a string literal compared or assigned where a generated enum type
  exists in the same package.

### 8. Regen without diffing

- **Rule**: after bumping the schema version and regenerating, review the generated
  diff for breaking changes (removed fields, changed types, renamed operations)
  before merging. Regenerating silently and committing is how breaking changes slip
  through.
- **Common AI failure**: `openapi-generator generate …` → `git add lib/generated`
  → commit, with no review of what changed in the generated output.
- **red-flag**: a schema/version bump commit whose PR contains changed generated
  files but no comment or diff annotation noting what broke or changed in the client
  surface.

### 9. Hand-edited generated file

- **Rule**: files inside the generated output directory (`*.g.dart`, files under
  `lib/generated/`) carry `// GENERATED CODE — DO NOT EDIT` and must not be
  hand-modified. Edits are silently overwritten by the next `build_runner` run.
- **Common AI failure**: patching `lib/generated/api/user_api.dart` directly to
  add a missing header or fix a serialization bug — the fix evaporates on the next
  regen.
- **red-flag**: a diff that modifies lines inside a file containing `// GENERATED
  CODE — DO NOT EDIT` or inside the configured generated-output directory.

### 10. No single source of truth

- **Rule**: there is exactly one definition of each API type — the schema. The Dart
  client types are derived from it via codegen. A second hand-maintained copy of the
  same shape (a DTO in the Flutter app that mirrors a DTO in the backend) means two
  things to keep in sync manually.
- **Common AI failure**: defining `class UserProfile` in the Flutter app that
  mirrors `UserProfile` in the backend, both hand-maintained, diverging on every
  field addition.
- **red-flag**: two independent Dart class definitions of the same schema component
  — one in a `lib/models/` hand-written file and one generated, or two hand-written
  copies in different layers.

## Guard checklist

For any Dart API client code before merge:

- [ ] Model classes generated from the schema; no hand-written DTO duplicating a schema type.
- [ ] API call results typed to generated model, not `dynamic`/`Map<String,dynamic>`.
- [ ] Endpoint called via generated client method; no raw `dio.get('/path/...')` string.
- [ ] Spec-declared error schemas typed and handled in `catch`; not silently swallowed.
- [ ] JSON (de)serialization via generated codec; no manual `json['key']` map access.
- [ ] Dart nullability matches schema: no `!` on optional fields, no `T?` on required fields.
- [ ] Generated enum types used; no raw string literals where an enum exists.
- [ ] Schema bump + regen diff reviewed in PR for breaking changes.
- [ ] No edits inside `*.g.dart` or the generated output directory.
- [ ] One definition per schema type — no hand-maintained parallel copy.

## Halt conditions

Halt and report before proceeding if:

- The schema cannot be located — codegen has no source of truth to run against.
- The requested change adds a field or endpoint that is not yet in the schema —
  the schema must be updated first (backend), then regen; do not hand-write.
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
- Umbrella: [flutter-architecture](../flutter-architecture/SKILL.md)
- Contract tests, mock server: [flutter-testing](../flutter-testing/SKILL.md)
- Auth headers, token storage, TLS: [flutter-security](../flutter-security/SKILL.md)
- Bad/good Dart pairs for all 10 rules + codegen command examples: [reference.md](./reference.md)
- openapi-generator (dart-dio): https://openapi-generator.tech/docs/generators/dart-dio
- swagger_parser pub.dev: https://pub.dev/packages/swagger_parser
- json_serializable pub.dev: https://pub.dev/packages/json_serializable
- retrofit pub.dev: https://pub.dev/packages/retrofit
- ferry (GraphQL): https://ferrygraphql.com/docs/
- artemis (GraphQL): https://pub.dev/packages/artemis
- build_runner: https://pub.dev/packages/build_runner
