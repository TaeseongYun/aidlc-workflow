# flutter-security — Reference

Deep-dive material for `SKILL.md`. **Vulnerable (❌) vs safe (✅)** code samples per
failure mode. Flutter/Dart, with platform-manifest notes. Decision criteria live in `SKILL.md`.

## Why this guard is needed (evidence)

- A large share of AI-generated code contains security flaws (multiple empirical studies).
- AI-assisted commits leak secrets more often than human-only commits.
- Developers **overtrust** AI code, believing it safer than it is.
- Mobile twist: the app binary ships to the device — **anything embedded is
  extractable** (keys, endpoints, logic). The price of AI speed is a review gate;
  this guard is that gate.

## 1. Hardcoded secrets in the bundle

```dart
// ❌ Compiled into the app → extractable by anyone with the APK/IPA
const stripeSecret = 'sk_live_abcd1234';
final res = await dio.post('https://api.stripe.com/...', options: authHeader(stripeSecret));

// ✅ Privileged calls go through YOUR backend; the app holds no third-party secret
final res = await dio.post('$backend/api/charge', data: {'orderId': id}); // server holds the secret

// Non-secret build config via --dart-define (still readable — non-secrets only)
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
```

- `.env` in `.gitignore`; a committed secret is leaked → rotate. Obfuscation
  (`--obfuscate`) raises the bar but does **not** make an embedded secret safe.

## 2. Insecure local storage

```dart
// ❌ SharedPreferences is cleartext — not for tokens
final prefs = await SharedPreferences.getInstance();
await prefs.setString('auth_token', jwt);

// ✅ flutter_secure_storage → Keychain (iOS) / Keystore-backed (Android)
const storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: jwt);
final jwt2 = await storage.read(key: 'auth_token');
```

- Non-sensitive prefs (theme, last tab) in `SharedPreferences` are fine. Tokens,
  refresh tokens, credentials, PII are not.

## 3. Insecure networking / TLS bypass

```dart
// ❌ Trust-all "to fix an SSL error" — defeats TLS entirely
(dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final c = HttpClient();
  c.badCertificateCallback = (cert, host, port) => true; // NEVER
  return c;
};

// ❌ class MyOverrides extends HttpOverrides { ... badCertificateCallback => true }

// ✅ HTTPS + platform trust store (default). Pin only if you maintain the pins.
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com')); // no cert override
```

## 4. Unvalidated deep-link / channel input

```dart
// ❌ deep link mapped straight to a route / repo
GoRoute(path: '/u/:id', builder: (_, s) => ProfileScreen(id: s.pathParameters['id']!));

// ✅ validate & type before use; allowlist redirect targets → flutter-navigation-platform
final id = int.tryParse(s.pathParameters['id'] ?? '');
if (id == null || id <= 0) return const NotFoundScreen();
```

## 5. WebView misconfiguration

```dart
// ❌ Unrestricted JS on an arbitrary URL + a native bridge to a remote page
WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..addJavaScriptChannel('Native', onMessageReceived: (m) => runNativeThing(m.message))
  ..loadRequest(Uri.parse(userProvidedUrl));

// ✅ Load only trusted content; restrict navigation; no native bridge to untrusted pages
WebViewController()
  ..setJavaScriptMode(JavaScriptMode.disabled) // enable only for content you control
  ..setNavigationDelegate(NavigationDelegate(
    onNavigationRequest: (r) =>
        r.url.startsWith('https://app.example.com') ? NavigationDecision.navigate : NavigationDecision.prevent,
  ))
  ..loadRequest(Uri.parse('https://app.example.com/help'));
```

## 6. SQL injection (sqflite)

```dart
// ❌ String interpolation into raw SQL
final rows = await db.rawQuery('SELECT * FROM users WHERE name = "$name"');

// ✅ Placeholders + args
final rows = await db.rawQuery('SELECT * FROM users WHERE name = ?', [name]);
final rows2 = await db.query('users', where: 'name = ?', whereArgs: [name]);
```

## 7. Sensitive data in logs

```dart
// ❌ debugPrint('login token=$jwt');  print(userWithPii);  print(exceptionWithSecret);
// ✅ Redact; never log tokens/passwords/full PII. Strip logs from release.
debugPrint('login ok userId=${user.id}'); // id only, no token/PII
// wrap logging so it is a no-op in release (kReleaseMode) or use a logger with redaction
```

## 8. Weak crypto / randomness

```dart
// ❌ Random() is NOT cryptographic; md5/sha1 for security; home-rolled XOR "crypto"
final token = Random().nextInt(1 << 32).toString();
final h = md5.convert(utf8.encode(password));

// ✅ Random.secure() for tokens/salts/IVs; SHA-256+ for integrity; AES-GCM via a vetted lib
final rnd = Random.secure();
final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
final token = base64UrlEncode(bytes);
// encryption: package:cryptography AesGcm.with256bits() with a random nonce (never reuse)
```

## 9. Insecure platform config

```xml
<!-- ❌ AndroidManifest.xml -->
<application android:allowBackup="true" android:usesCleartextTraffic="true"> ...
<!-- ✅ no cleartext; allowBackup false (or exclude secure storage); exported set intentionally -->
<application android:allowBackup="false"> ...
```

```xml
<!-- ❌ ios/Runner/Info.plist — App Transport Security fully disabled -->
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
<!-- ✅ keep ATS on; add narrow, justified per-domain exceptions only if unavoidable -->
```

## 10. Vulnerable / hallucinated dependencies (slopsquatting)

```
- Verify an AI-suggested pub.dev package actually exists and is legitimate
  (publisher, likes/downloads, recent maintenance, pub points). Typo-similar ·
  brand-new · negligible downloads → suspect slopsquatting, do not add.
- Pin versions and commit pubspec.lock. Review the native permissions a plugin pulls in.
- Gate on advisories (dart pub outdated, GitHub/OSV advisories).
```

## Full vibe-guard review checklist

- [ ] No secrets in Dart / committed `.env`; privileged calls proxied server-side.
- [ ] Tokens/PII in `flutter_secure_storage`, not `SharedPreferences`/plain files.
- [ ] HTTPS only; no `badCertificateCallback`/trust-all; no `http://` endpoints.
- [ ] Deep-link/channel input validated; redirects allowlisted.
- [ ] WebView: no unrestricted JS on untrusted URLs; no native bridge to remote pages.
- [ ] Local-DB raw queries parameterized (`?` + `whereArgs`).
- [ ] No tokens/passwords/PII in logs; logs stripped from release.
- [ ] `Random.secure()`; no MD5/SHA1/ECB/fixed-IV/home-rolled crypto.
- [ ] No cleartext traffic / ATS arbitrary loads / unsafe `allowBackup`.
- [ ] Deps real · legitimate · maintained · version-pinned · advisory-free.

## Official references

- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS: https://mas.owasp.org/MASVS/
- OWASP MASTG: https://mas.owasp.org/MASTG/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- CWE Top 25: https://cwe.mitre.org/top25/
- Flutter security best practices: https://docs.flutter.dev/security
- flutter_secure_storage: https://pub.dev/packages/flutter_secure_storage
- Team baseline: [../../guidance.md](../../guidance.md)
