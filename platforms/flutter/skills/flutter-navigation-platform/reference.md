# flutter-navigation-platform — Reference

Deep-dive for `SKILL.md`. go_router config, deep-link validation, platform-channel
adapter patterns. Decision criteria live in `SKILL.md`.

## 1. Routes as data (go_router)

```dart
// Centralized route table; screens navigate by path/name, not ad-hoc routes.
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/order/:id',
      builder: (context, state) {
        final id = _parseOrderId(state.pathParameters['id']); // validate → below
        return id == null ? const NotFoundScreen() : OrderScreen(id: id); // invalid → defined fallback
      },
    ),
  ],
);

// ❌ elsewhere: Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(...)))
// ✅ context.go('/order/$id')  /  context.pushNamed('order', pathParameters: {'id': id})
```

## 2. Deep-link parameter validation (untrusted input)

```dart
// External links are untrusted. Parse, type-check, reject — never pass raw to a repo.
OrderId? _parseOrderId(String? raw) {
  final n = int.tryParse(raw ?? '');
  if (n == null || n <= 0) return null;   // reject bad input → caller renders NotFound (don't throw in a builder)
  return OrderId(n);
}

// Redirect targets from a link must be allowlisted — do not honor an arbitrary next=URL
String? _safeRedirect(String? next) {
  const allowed = {'/home', '/orders', '/profile'};
  return (next != null && allowed.contains(next)) ? next : null; // else fall back to default
}
```

- Do not trust a deep link to name an internal route or an external URL directly
  (open-redirect / unauthorized navigation) → [flutter-security].

## 3. Platform-channel adapter (MethodChannel isolated)

```dart
// Interface: domain language. The rest of the app depends only on this.
abstract interface class ShareService {
  Future<void> shareText(String text);
}

// Adapter: the ONLY place MethodChannel + Platform.isX live; errors mapped to domain.
class ShareServiceAdapter implements ShareService {
  static const _channel = MethodChannel('app/share');
  @override
  Future<void> shareText(String text) async {
    try {
      // single platform decision, here — not scattered through widgets
      final method = Platform.isIOS ? 'shareSheet' : 'shareIntent';
      await _channel.invokeMethod(method, {'text': text});
    } on PlatformException catch (e) {
      throw ShareFailure(e.code);           // domain failure, not a raw PlatformException
    }
  }
}
```

```dart
// ❌ Anti-pattern: widget/controller touching the channel directly
onPressed: () => const MethodChannel('app/share').invokeMethod('shareIntent', {...});
// ❌ Platform.isAndroid ? ... : ...  sprinkled in a build method
```

## 4. Navigation / platform review checklist

- [ ] All navigation goes through the project router (no scattered ad-hoc routes).
- [ ] Deep-link params validated/typed before mapping to a route.
- [ ] Redirect targets from links are allowlisted (no open redirect).
- [ ] `MethodChannel`/plugin calls only inside a project-owned adapter.
- [ ] `Platform.isX` decided once in the adapter, not in widgets.
- [ ] `PlatformException` mapped to a domain failure at the adapter boundary.
- [ ] One routing paradigm in the app.

## Official references

- Navigation & routing: https://docs.flutter.dev/ui/navigation
- go_router: https://pub.dev/packages/go_router
- Deep linking: https://docs.flutter.dev/ui/navigation/deep-linking
- Platform channels: https://docs.flutter.dev/platform-integration/platform-channels
- Writing platform-specific code: https://docs.flutter.dev/platform-integration/platform-adaptations
- Team baseline: [../../guidance.md](../../guidance.md)
