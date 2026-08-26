# flutter-contract-codegen — Reference

Deep-dive for `SKILL.md`. Mode-A codegen commands + wiring examples, and a
bad → good Dart pair for each of the 10 guard rules. Decision criteria live in
`SKILL.md`.

---

## Mode A — Codegen end to end

### OpenAPI → dart-dio

```bash
# 1. Install (once per machine / CI image)
dart pub global activate openapi_generator_cli

# 2. Generate — run from repo root
openapi-generator generate \
  -i api/openapi.yaml \
  -g dart-dio \
  -o lib/generated/api \
  --additional-properties=pubName=my_api,nullSafe=true,serializationLibrary=json_serializable

# 3. Regenerate build_runner artifacts (*.g.dart) inside the generated output
cd lib/generated/api && dart pub get && dart run build_runner build --delete-conflicting-outputs
```

Output layout:
```
lib/generated/api/
  lib/
    api/          # UserApi, OrderApi … — generated client classes
    model/        # User, Order, CreateOrderRequest … — generated models
  pubspec.yaml    # generated; add as path dependency in the host app
```

Add the generated package as a `path` dependency:

```yaml
# pubspec.yaml (host app)
dependencies:
  my_api:
    path: lib/generated/api
```

### OpenAPI → swagger_parser + retrofit + json_serializable

```yaml
# swagger_parser.yaml (config file at repo root)
schema_path: api/openapi.yaml
output_directory: lib/api
client_postfix: Client
put_clients_in_folder: true
```

```bash
dart run swagger_parser            # generates lib/api/*.dart stubs
dart run build_runner build --delete-conflicting-outputs
# produces lib/api/*.g.dart (json_serializable) + retrofit *.g.dart
```

### GraphQL → ferry

```bash
dart pub add ferry ferry_generator gql_build source_gen build_runner
# place *.graphql files alongside lib/features/.../queries/
dart run build_runner build
# → *.req.gql.dart, *.data.gql.dart, *.var.gql.dart
```

### GraphQL → artemis

```yaml
# pubspec.yaml
dev_dependencies:
  artemis: ^7.x
  build_runner: ^2.x
  json_serializable: ^6.x
```

```yaml
# build.yaml
targets:
  $default:
    builders:
      artemis:
        options:
          schema_mapping:
            - schema: api/schema.graphql
              queries_glob: lib/**/*.graphql
              output: lib/generated/graphql/
```

```bash
dart run build_runner build
```

### Wiring a generated call with typed error handling

```dart
// lib/data/remote/user_remote_data_source.dart
// ✅ Uses the generated UserApi from dart-dio output; error bodies are typed.

import 'package:my_api/api/user_api.dart';
import 'package:my_api/model/user.dart';
import 'package:my_api/model/error_response.dart';
import 'package:dio/dio.dart';

class UserRemoteDataSource {
  UserRemoteDataSource(this._api);
  final UserApi _api;

  Future<User> fetchUser(int id) async {
    try {
      final response = await _api.getUser(id);   // generated method, typed return
      return response.data!;                      // User — not Map<String,dynamic>
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      if (status == 404) {
        throw UserNotFoundException(id);
      }
      if (status == 422 && body != null) {
        final err = ErrorResponse.fromJson(body as Map<String, dynamic>);
        throw ValidationException(err.message);   // typed, from generated ErrorResponse
      }
      throw ApiException.fromDioError(e);
    }
  }
}
```

---

## Guard rule bad → good pairs

### 1. Hand-written DTO instead of generated

```dart
// ❌ Manual class mirroring the schema — will drift on every schema change
class CreateOrderRequest {
  final String userId;
  final List<String> itemIds;
  final double total;

  CreateOrderRequest({required this.userId, required this.itemIds, required this.total});

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'item_ids': itemIds,
    'total': total,
  };
}

// ✅ Use the generated model — run codegen, then import
import 'package:my_api/model/create_order_request.dart';

// CreateOrderRequest is already defined; just construct it:
final req = CreateOrderRequest(
  userId: userId,
  itemIds: selectedIds,
  total: cartTotal,
);
await _api.createOrder(req);
```

### 2. Untyped boundary

```dart
// ❌ dynamic / Map<String,dynamic> at the response boundary
final response = await dio.get('/api/v1/users/$id');
final data = response.data as Map<String, dynamic>;
final name = data['name'] as String;         // crashes if field renamed/missing
final email = data['email'] as String?;

// ✅ Generated client returns a typed model
final response = await _api.getUser(id);     // Response<User>
final user = response.data!;                 // User — typed, IDE-navigable
final name = user.name;                      // String
final email = user.email;                    // String? — nullability from schema
```

### 3. Stringly-typed endpoint

```dart
// ❌ Raw URL string duplicates the spec path — diverges on rename or version bump
final response = await dio.post(
  '/api/v1/orders',
  data: {'user_id': userId, 'item_ids': itemIds},
);

// ✅ Generated client method encodes path + verb + parameters
final response = await _api.createOrder(
  CreateOrderRequest(userId: userId, itemIds: itemIds, total: total),
);
```

### 4. Unmodeled error/status responses

```dart
// ❌ Only 200 happy path — error body silently dropped
try {
  final res = await _api.createOrder(req);
  return res.data!;
} catch (e) {
  print(e);           // logs the DioException string, loses the typed error body
  rethrow;
}

// ✅ Spec-declared error schemas typed and handled
try {
  final res = await _api.createOrder(req);
  return res.data!;
} on DioException catch (e) {
  final status = e.response?.statusCode;
  final body = e.response?.data as Map<String, dynamic>?;
  if (status == 422 && body != null) {
    final err = ValidationErrorResponse.fromJson(body);  // generated model
    throw OrderValidationException(fields: err.errors);
  }
  if (status == 409) throw DuplicateOrderException();
  throw ApiException.fromDioError(e);
}
```

### 5. Manual (de)serialization drift

```dart
// ❌ Hand-rolled parsing — field name mismatch silently returns null
User fromJson(Map<String, dynamic> json) {
  return User(
    id: json['id'] as int,
    name: json['user_name'] as String,       // schema says 'userName' — mismatch
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

// ✅ Generated fromJson (json_serializable) handles @JsonKey mappings
// user.dart is generated — do not edit; the codec is in user.g.dart
import 'package:my_api/model/user.dart';

final user = User.fromJson(responseBody);    // field names, nullability, dates: all from schema
```

### 6. Nullable/required mismatch

```dart
// ❌ Force-unwrap on a field the schema marks optional (required: false)
// Schema: email is not in the required[] array
final user = await _api.getUser(id).then((r) => r.data!);
final email = user.email!;   // crashes when backend legally omits email

// ❌ Non-null Dart type for an optional field in a hand-written model
class User {
  final String email;   // schema says optional — should be String?
}

// ✅ Nullability mirrors the schema; handle the absent case
final email = user.email;        // String? — from generated model
if (email != null) {
  _emailController.text = email;
}
```

### 7. Enum as raw string

```dart
// ❌ Raw string literal — no exhaustiveness, breaks on schema rename
if (order.status == 'PENDING') {
  showPendingBanner();
} else if (order.status == 'SHIPPED') {
  showTrackingButton();
}
// New status 'PROCESSING' added to schema → silently unhandled

// ✅ Generated enum type — switch is exhaustive; analyzer flags missing cases
switch (order.status) {           // OrderStatus enum from generated model
  case OrderStatus.pending:
    showPendingBanner();
  case OrderStatus.shipped:
    showTrackingButton();
  case OrderStatus.processing:    // forced to handle when added to schema
    showProcessingIndicator();
  // Dart 3 exhaustive switch — compiler error if a case is missing
}
```

### 8. Regen without diffing

```dart
// ❌ Schema bumped, codegen re-run, committed without reviewing the generated diff
// PR description: "Bump API to v2.1"
// git diff shows lib/generated/api/lib/model/order.dart changed:
//   - final double total;
//   + final int totalCents;    // ← breaking: callers using .total now fail to compile

// ✅ After regen, check the generated diff before merging
// In the PR:
// 1. Run: git diff lib/generated/
// 2. Note breaking changes (field type, removed field, renamed operation)
// 3. Update callers in the same PR
// 4. Add a note in the PR description: "Breaking: Order.total → Order.totalCents (cents)"
```

```bash
# Useful one-liner to surface generated-only changes
git diff HEAD lib/generated/ -- '*.dart' | grep '^[+-]' | grep -v '^---\|^+++' | head -60
```

### 9. Hand-edited generated file

```dart
// ❌ Direct edit inside lib/generated/ to "fix" a missing header
// lib/generated/api/lib/api/user_api.dart (GENERATED CODE — DO NOT EDIT)
Future<Response<User>> getUser(int id) async {
  final response = await _dio.fetch<Map<String, dynamic>>(
    _setStreamType<User>(Options(
      method: 'GET',
+     headers: {'X-Client': 'flutter'},   // hand-added — wiped by next regen
    ).compose(_dio.options, '/users/$id')),
  );
  // ...
}

// ✅ Customizations go in a wrapper outside the generated directory
class ApiClientFactory {
  static Dio buildDio() {
    final dio = Dio(BaseOptions(baseUrl: Env.apiBase));
    dio.interceptors.add(ClientHeaderInterceptor());  // 'X-Client: flutter' here
    dio.interceptors.add(AuthInterceptor(tokenStorage));
    return dio;
  }
}
// UserApi(_apiClient) — generated class untouched; customization survives regen
```

### 10. No single source of truth

```dart
// ❌ Two independent definitions of the same contract type
// lib/models/user_profile.dart (hand-written in Flutter)
class UserProfile {
  final String id;
  final String displayName;   // backend renamed this to 'name' last sprint — missed here
  final String? avatarUrl;
}

// packages/api_client/lib/model/user_profile.dart (generated OR hand-written in a separate package)
class UserProfile {
  final String id;
  final String name;          // current; Flutter copy still says displayName
  final String? avatarUrl;
}

// ✅ One generated definition; the app imports it directly
import 'package:my_api/model/user_profile.dart';
// No lib/models/user_profile.dart; no duplication; schema change → regen → one place to update
```

---

## Regenerate workflow summary

```
schema change (backend PR)
       ↓
pull schema / bump version
       ↓
openapi-generator generate … (or dart run swagger_parser + build_runner)
       ↓
git diff lib/generated/  — review breaking changes
       ↓
update callers in the same PR
       ↓
dart test  (contract tests in flutter-testing catch regressions)
       ↓
merge
```

Never commit a schema bump without the generated diff and the caller update in
the same PR. Generated files are the reviewable artifact of a schema change —
they belong in version control alongside the schema reference.

---

## References

- `SKILL.md` for rules, guard checklist, and halt conditions.
- openapi-generator dart-dio: https://openapi-generator.tech/docs/generators/dart-dio
- swagger_parser: https://pub.dev/packages/swagger_parser
- json_serializable: https://pub.dev/packages/json_serializable
- retrofit (Dart): https://pub.dev/packages/retrofit
- ferry (GraphQL): https://ferrygraphql.com/docs/
- artemis: https://pub.dev/packages/artemis
- build_runner: https://pub.dev/packages/build_runner
- Contract tests: [flutter-testing](../flutter-testing/SKILL.md)
- Auth / TLS: [flutter-security](../flutter-security/SKILL.md)
