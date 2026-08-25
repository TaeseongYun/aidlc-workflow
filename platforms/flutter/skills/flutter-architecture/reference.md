# flutter-architecture — Reference

Deeper material for `SKILL.md`. Detailed layer responsibilities · adapter ·
feature-slice samples. See `SKILL.md` for the rule summary and decision criteria.

## 1. Detailed layer responsibilities

| Layer | Owns | Forbidden | Returns/Exposes |
|-------|------|-----------|-----------------|
| Widget | render state, dispatch actions | business logic, repo/client/channel calls, `Platform.isX` | UI |
| Controller (Notifier/Bloc) | screen state, action→state, effect emission | `BuildContext`, Flutter UI types, DTO mapping | immutable/sealed state + effect stream |
| UseCase (optional) | business rules across repositories | Flutter imports, HTTP/DTO detail | domain result |
| Repository | domain-shaped data ops, DTO↔domain mapping | business rules, Flutter types | domain model / typed failure |
| Platform Channel Adapter | native calls, error mapping, `Platform.isX` decision | business rules | domain model / adapter result |
| Domain model | invariants, value rules | `package:flutter/*` imports | pure Dart |

## 2. Platform-channel adapter (native capability)

Native functionality goes behind a project-owned interface. Callable code knows
only the interface, never `MethodChannel`. Details → [flutter-navigation-platform].

```dart
// Interface: domain language, no MethodChannel here
abstract interface class BiometricAuth {
  Future<bool> authenticate();
}

// Adapter: the only place MethodChannel lives; Platform.isX decided here
class BiometricAuthAdapter implements BiometricAuth {
  static const _channel = MethodChannel('app/biometric');
  @override
  Future<bool> authenticate() async {
    try {
      return await _channel.invokeMethod<bool>('authenticate') ?? false;
    } on PlatformException catch (e) {
      throw BiometricFailure(e.code); // map platform error → domain failure
    }
  }
}
```

## 3. Repository returns domain, maps failures

```dart
// Repository maps DTO→domain and exception→typed failure. Controller never sees raw exceptions.
class OrderRepository {
  final OrderApi _api;
  OrderRepository(this._api);

  // Result/Ok/Err: a project-defined sealed type (or dartz's Either)
  Future<Result<Order, OrderFailure>> fetch(OrderId id) async {
    try {
      final dto = await _api.getOrder(id.value);
      return Ok(dto.toDomain());          // DTO→domain mapping in the data layer
    } on DioException catch (e) {
      return Err(OrderFailure.fromHttp(e)); // typed failure, not a raw exception
    }
  }
}
```

- Domain `Order` imports no Flutter types. The controller maps `OrderFailure`
  into its sealed state → [flutter-state-management].

## 4. Where state lives (summary)

| Situation | State home |
|-----------|-----------|
| Widget-local, ephemeral | `StatefulWidget` / `setState` |
| Screen state + async data | Controller (AsyncNotifier / Bloc) per screen |
| Shared/business state across screens | Provider/Bloc scoped at feature or app level |
| Remote data | Repository behind the controller — widgets never call clients |

Full modeling detail → [flutter-state-management].

## 5. Module baseline

Feature-first; follow the project's layout when one exists:

```
lib/
  core/         # theme/tokens, shared widgets, utilities, router
  domain/       # shared domain models (no Flutter imports)
  data/         # API clients, repositories, DTOs
  features/<name>/
    presentation/  # screens, widgets, controllers
    domain/        # feature use cases/models (when they exist)
    data/          # feature repositories/sources (when they exist)
```

Split into packages (melos) only when a second app or plugin consumer exists →
[flutter-module-structure].

## 6. Architecture review checklist

- [ ] No business logic / repo / client / channel calls in a widget.
- [ ] Controller holds no `BuildContext` or Flutter UI types.
- [ ] Domain models import no Flutter types.
- [ ] Repository returns domain models + typed failures (no raw exceptions to widgets).
- [ ] Native capability behind a project-owned adapter (no bare `MethodChannel`).
- [ ] Exactly one state-management library in the codebase.
- [ ] Slices promoted on a real signal (no preemptive UseCase/melos split).

## Official references

- Flutter app architecture: https://docs.flutter.dev/app-architecture
- Architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Riverpod: https://riverpod.dev/
- Bloc: https://bloclibrary.dev/
- Team baseline: [../../guidance.md](../../guidance.md)
