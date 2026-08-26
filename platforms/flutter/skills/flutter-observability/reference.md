# flutter-observability — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code samples per failure mode.
Flutter/Dart, using `dart:developer log()`, the `logging` package, Firebase Crashlytics, and
Sentry. Decision criteria live in `SKILL.md`.

---

## Do examples — structured log with correlation ID + redaction; metric + crash reporter wiring

### Structured log with correlation ID and redaction

```dart
// ✅ Structured, correlated, redacted — using the logging package
import 'package:logging/logging.dart';

final _log = Logger('AuthService');

Future<User> signIn(String email, String password, {required String traceId}) async {
  _log.info('signIn.start traceId=$traceId'); // no email — PII
  try {
    final user = await _repo.signIn(email, password);
    _log.info('signIn.success traceId=$traceId userId=${user.id}'); // id only, not email
    return user;
  } catch (e, st) {
    _log.severe('signIn.failed traceId=$traceId', e, st); // exception + stack always
    rethrow;
  }
}
```

### Metric + crash reporter wiring in main()

```dart
// ✅ main.dart — crash reporter + error zone + FlutterError override
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Forward Flutter framework errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Forward async/platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );
}
```

### Metric emission alongside logging

```dart
// ✅ Payment flow: log + metric together; logs alone are not alertable
import 'package:firebase_analytics/firebase_analytics.dart';

final _log = Logger('PaymentService');
final _analytics = FirebaseAnalytics.instance;

Future<void> processPayment(Order order, {required String traceId}) async {
  final stopwatch = Stopwatch()..start();
  try {
    await _gateway.charge(order);
    stopwatch.stop();
    _log.info('payment.success traceId=$traceId orderId=${order.id} ms=${stopwatch.elapsedMilliseconds}');
    await _analytics.logEvent(
      name: 'payment_success',
      parameters: {'order_id': order.id, 'amount_cents': order.amountCents},
    );
  } catch (e, st) {
    stopwatch.stop();
    _log.severe('payment.failed traceId=$traceId orderId=${order.id}', e, st);
    await _analytics.logEvent(name: 'payment_failure', parameters: {'order_id': order.id});
    await FirebaseCrashlytics.instance.recordError(e, st);
    rethrow;
  }
}
```

---

## 1. Debug print left in prod

```dart
// ❌ print/debugPrint shipped in release — visible in adb logcat / Xcode console
class UserRepository {
  Future<User> fetchUser(String id) async {
    final user = await _api.getUser(id);
    print('fetched user: $user');        // ships in release
    debugPrint('user data: ${user.toJson()}'); // also ships in release
    return user;
  }
}

// ✅ dart:developer log() (stripped by tree-shaking in release) or logging package
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class UserRepository {
  Future<User> fetchUser(String id) async {
    final user = await _api.getUser(id);
    dev.log('fetchUser id=$id', name: 'UserRepository'); // dev-tool only; stripped in release
    // OR: gate explicitly
    if (kDebugMode) debugPrint('fetchUser response: ${user.toJson()}');
    return user;
  }
}
```

---

## 2. PII / secrets in logs

```dart
// ❌ Logging full user object, JWT, and response body — PII + secret in device logs
Future<void> login(String email, String password) async {
  final resp = await _api.login(email, password);
  log('login response: ${resp.body}');       // full body may contain token
  log('user: ${resp.user.toJson()}');        // email, phone, address...
  log('token=${ resp.token}');               // JWT in plain log
}

// ✅ Log only non-sensitive IDs; redact everything else
Future<void> login(String email, String password) async {
  _log.info('login.start');                  // no email
  final resp = await _api.login(email, password);
  _log.info('login.success userId=${resp.user.id}'); // id only
  // token never logged; stored via flutter_secure_storage (see flutter-security)
}
```

---

## 3. Unstructured logging

```dart
// ❌ Concatenated string — one unindexable blob; nothing is filterable
log('user ' + userId + ' performed action ' + action + ' result: ' + result);
log('request to ' + endpoint + ' failed after ' + retries.toString() + ' retries');

// ✅ Structured fields — each key is queryable in a log aggregator
// Using dart:developer log with a JSON error payload:
import 'dart:convert';
import 'dart:developer' as dev;

dev.log(
  'action.result',
  name: 'ActionService',
  error: jsonEncode({'userId': userId, 'action': action, 'result': result}),
);

// ✅ Using the logging package — Logger records carry the structured error object
_log.info('request.failed', {'endpoint': endpoint, 'retries': retries, 'error': e.toString()});
// Or pass the exception directly as the second positional arg (logged as error object):
_log.warning('request.failed endpoint=$endpoint retries=$retries', e, st);
```

---

## 4. Missing correlation / trace ID

```dart
// ❌ Disconnected logs — impossible to reconstruct a single request's journey
Future<void> placeOrder(Cart cart) async {
  log('validating cart');
  await _cartService.validate(cart);
  log('charging payment');
  await _paymentService.charge(cart);
  log('sending confirmation');
  await _notificationService.confirm(cart);
}

// ✅ Shared traceId threaded through every call and every log line
import 'package:uuid/uuid.dart';

Future<void> placeOrder(Cart cart) async {
  final traceId = const Uuid().v4();
  _log.info('order.validate traceId=$traceId cartId=${cart.id}');
  await _cartService.validate(cart, traceId: traceId);
  _log.info('order.charge traceId=$traceId cartId=${cart.id}');
  await _paymentService.charge(cart, traceId: traceId);
  _log.info('order.confirm traceId=$traceId cartId=${cart.id}');
  await _notificationService.confirm(cart, traceId: traceId);
}
```

---

## 5. Wrong log level

```dart
// ❌ Expected failures at SEVERE — alert fatigue; debug noise at INFO
import 'package:logging/logging.dart';

Future<User?> findUser(String id) async {
  final user = await _repo.find(id);
  if (user == null) {
    _log.severe('user not found id=$id');  // expected case; not a system error
  }
  _log.info('checking cache key=$id value=${_cache[id]}'); // verbose, not a milestone
  return user;
}

// ✅ Level matches severity
Future<User?> findUser(String id) async {
  final user = await _repo.find(id);
  if (user == null) {
    _log.warning('user.notFound id=$id'); // recoverable, expected
    return null;
  }
  _log.fine('cache.check key=$id hit=${_cache.containsKey(id)}'); // verbose/debug → FINE
  _log.info('user.found id=$id');         // normal milestone → INFO
  return user;
}
```

Level ladder: `Level.FINEST/FINER/FINE` → verbose debug. `Level.CONFIG/INFO` → milestones.
`Level.WARNING` → recoverable. `Level.SEVERE/SHOUT` → real errors needing action.

---

## 6. Swallowed error

```dart
// ❌ Empty catch — exception vanishes; production failure is invisible
Future<void> syncData() async {
  try {
    await _api.sync();
  } catch (e) {} // silent failure — nobody knows sync broke

// ❌ Logging a string message but dropping the exception object and stack trace
  try {
    await _api.sync();
  } catch (e) {
    log('sync failed'); // no exception object, no stack trace — useless in prod
  }
}

// ✅ Log exception + stack trace; forward to crash reporter for fatal paths
Future<void> syncData() async {
  try {
    await _api.sync();
  } catch (e, st) {
    _log.severe('sync.failed', e, st);                          // e + st always
    await FirebaseCrashlytics.instance.recordError(e, st);      // forward to tracker
    rethrow; // or handle deliberately, never silently drop
  }
}
```

The `logging` package `Logger.severe(message, error, stackTrace)` signature is: second arg =
exception object, third arg = `StackTrace`. Always pass both.

---

## 7. Logging in hot path / loop

```dart
// ❌ Log inside build() — fires on every rebuild
@override
Widget build(BuildContext context) {
  log('building ProductCard productId=$productId'); // O(repaints) log calls
  return Card(child: Text(product.name));
}

// ❌ Log inside animation/frame callback — fires at 60 fps
_controller.addListener(() {
  log('animation value=${_controller.value}'); // 60 logs/second
});

// ❌ Log inside a loop over a large collection
for (final item in thousandItems) {
  log('processing item=${item.id}'); // 1 000 log lines per call
}

// ✅ Log once before/after, not per-iteration or per-frame
_log.fine('ProductCard.build productId=$productId'); // if truly needed, FINE level; but prefer removing entirely
// animation: log only on state transitions, not per tick
_controller.addStatusListener((status) {
  _log.fine('animation.status status=$status'); // fires only on status change
});
// loop: log summary, not per-item
_log.info('batch.start count=${thousandItems.length}');
for (final item in thousandItems) { /* process */ }
_log.info('batch.done count=${thousandItems.length}');
```

---

## 8. No metrics (logs only)

```dart
// ❌ Auth flow logs events but emits no metric — success rate is not alertable
Future<void> signIn(String email, String password) async {
  try {
    await _auth.signIn(email, password);
    log('sign in success');   // logged, not measured
  } catch (e, st) {
    log('sign in failed: $e'); // logged, not measured
  }
}

// ✅ Log + metric: success/failure counters make this alertable
Future<void> signIn(String email, String password, {required String traceId}) async {
  try {
    await _auth.signIn(email, password);
    _log.info('signIn.success traceId=$traceId');
    await FirebaseAnalytics.instance.logEvent(name: 'auth_signin_success');
  } catch (e, st) {
    _log.severe('signIn.failed traceId=$traceId', e, st);
    await FirebaseAnalytics.instance.logEvent(name: 'auth_signin_failure');
    await FirebaseCrashlytics.instance.recordError(e, st);
    rethrow;
  }
}
```

If Firebase Analytics is not suitable, a lightweight custom counter or an OTel span works too.
The key: something that can drive a dashboard or alert — a log line alone cannot.

---

## 9. Missing crash / error reporting

```dart
// ❌ main.dart with no crash reporter, no error zone, no FlutterError override
void main() {
  runApp(const MyApp()); // unhandled exceptions → crash with no report
}

// ❌ Caught fatal error forwarded nowhere
try {
  await _db.migrate();
} catch (e) {
  log('migration failed: $e'); // logged but not sent to crash tracker
}

// ✅ Full wiring — Crashlytics (same pattern with Sentry shown below)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runZonedGuarded(
    () => runApp(const MyApp()),
    (e, st) => FirebaseCrashlytics.instance.recordError(e, st, fatal: true),
  );
}

// ✅ Sentry alternative
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) => options.dsn = const String.fromEnvironment('SENTRY_DSN'),
    appRunner: () => runApp(const MyApp()),
  );
}
// Forward caught errors: await Sentry.captureException(e, stackTrace: st);
```

---

## 10. Non-actionable message

```dart
// ❌ Bare messages — useless in production; no entity, no operation, no state
_log.severe('error occurred');
_log.warning('failed');
log('something went wrong');
_log.info('null');

// ✅ Every message answers: which entity, which operation, what happened, what state
_log.severe(
  'payment.capture.failed orderId=${order.id} amount=${order.amountCents} attempt=$attempt',
  e,
  st,
);
_log.warning('cart.validate.itemUnavailable cartId=${cart.id} skuId=${item.skuId}');
_log.info('auth.tokenRefresh.success userId=${user.id} expiresAt=${token.expiresAt.toIso8601String()}');
```

Pattern: `<component>.<operation>.<outcome> <key>=<value> ...` — parseable, filterable, actionable.

---

## Official References

- dart:developer log API: https://api.dart.dev/stable/dart-developer/log.html
- logging package (pub.dev): https://pub.dev/packages/logging
- Firebase Crashlytics for Flutter: https://firebase.google.com/docs/crashlytics/get-started?platform=flutter
- Sentry for Flutter: https://docs.sentry.io/platforms/flutter/
- Firebase Analytics for Flutter: https://firebase.google.com/docs/analytics/get-started?platform=flutter
- Flutter error handling docs: https://docs.flutter.dev/testing/errors
- Team baseline: [../../guidance.md](../../guidance.md)
