---
name: flutter-security
description: Flutter security guard — a safety guard that reviews and blocks the vulnerable patterns that commonly slip into AI-generated Flutter/Dart code produced by "vibe coding". Covers hardcoded secrets/API keys compiled into the app bundle, insecure local storage of tokens (SharedPreferences vs flutter_secure_storage/Keychain/Keystore), insecure networking (cleartext http, disabled/bypassed TLS certificate validation), unvalidated deep-link and platform-channel input, WebView misconfiguration (unrestricted JS + untrusted content, native bridges), SQL injection in sqflite raw queries, sensitive data in logs (print/debugPrint of tokens/PII), weak crypto/randomness (non-secure Random, MD5/SHA1, home-rolled crypto), insecure platform config (Android allowBackup/cleartextTraffic, iOS ATS NSAllowsArbitraryLoads), and vulnerable/hallucinated (slopsquatting) pub.dev dependencies. Auto-loads when writing or reviewing Dart source, pubspec, or platform manifests. This is the vibe-coding security guard for AI-generated Flutter code.
when_to_use: When reviewing Flutter/Dart code before merge (especially AI/LLM-generated or quickly pasted), when touching secrets/token storage/network/TLS/deep links/platform channels/WebView/local DB/crypto/dependencies, or on requests like "security review", "is this app code safe", "vibe coding check".
paths: **/*.dart, **/pubspec.yaml, **/pubspec.lock, **/android/app/src/**/AndroidManifest.xml, **/ios/Runner/Info.plist, **/*.env, **/.env*
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-security — vibe-coding security guard

AI-generated app code is **fast but frequently vulnerable**, and mobile code ships
the secret to the device where anyone can extract it. Empirical studies find a
large share of AI-generated code contains security flaws, and AI-assisted commits
leak secrets more often than human-only commits. Developers also **overtrust** AI
code, believing it safer than it is. This skill is the **review gate**. The rules
here are **safety rules** and must not be relaxed. Project `ctx/` overrides this
document, but the security floor is never lowered.

## Scope

- Targets: Dart source, `pubspec.yaml`/`pubspec.lock`, platform manifests
  (`AndroidManifest.xml`, `Info.plist`), `.env` — especially AI-generated or
  quickly-pasted code.
- What it does: **detect vulnerable patterns → propose safe alternatives** for
  each failure mode below.
- Delegate to adjacent skills: deep-link/route handling → [flutter-navigation-platform],
  logging discipline in controllers/state → [flutter-state-management].
- Reality: a compiled Flutter app can be reverse-engineered — **anything baked
  into the binary (keys, endpoints, logic) is readable**. Secrets belong on a
  server, not in the app.

## Core Rules — by AI-generated-code failure mode (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Hardcoded secrets in the app bundle (CWE-798 · OWASP MASVS-STORAGE)

- **Rule**: API keys · tokens · passwords are **not** compiled into the app. Use a
  backend proxy for privileged calls; inject non-secret config via `--dart-define`.
  Never commit `.env`. No secret is safe client-side — treat a shipped key as public.
- **Common AI failure**: `const apiKey = 'sk-live-...'`, committing `.env`,
  putting a third-party secret in Dart to "call the API directly from the app".
- **red-flag**: string-literal keys in `.dart`, tracked `.env`, private API called
  directly from the client with an embedded secret.

### 2. Insecure local storage of sensitive data (CWE-312/922 · MASVS-STORAGE)

- **Rule**: tokens · credentials · PII go in **`flutter_secure_storage`**
  (Keychain / Android Keystore-backed). `SharedPreferences`/plain files are
  cleartext — non-sensitive prefs only.
- **Common AI failure**: saving the auth token/refresh token in
  `SharedPreferences`, writing credentials to a plain file/`sqflite` unencrypted.
- **red-flag**: `SharedPreferences` holding a token/password, plaintext credential files.

### 3. Insecure networking / TLS bypass (CWE-295/319 · OWASP A02/A05 · MASVS-NETWORK)

- **Rule**: **HTTPS only.** Never disable certificate validation. Do not override
  `badCertificateCallback => true`. If pinning, pin correctly; otherwise use the
  platform default trust store.
- **Common AI failure**: `http://` endpoints, `badCertificateCallback = (cert, host, port) => true`,
  a custom `HttpOverrides` that trusts all certs "to fix an SSL error".
- **red-flag**: `badCertificateCallback` returning true, `http://` in an API base
  URL, a global trust-all `HttpOverrides`.

### 4. Unvalidated deep-link / platform-channel input (CWE-20/601 · OWASP A01)

- **Rule**: deep-link params, universal/app-link data, and `MethodChannel` args
  are **untrusted**. Validate/type-check before mapping to a route or a
  repository call; allowlist redirect targets. Details → [flutter-navigation-platform].
- **Common AI failure**: mapping a deep link straight to a route, honoring an
  arbitrary `next=`/URL, passing a link param into a query unchecked.
- **red-flag**: raw deep-link value into a route/repo/redirect with no validation.

### 5. WebView misconfiguration (CWE-79/749 · MASVS-PLATFORM)

- **Rule**: don't load untrusted content with JavaScript enabled; restrict
  navigation to an allowlist; do **not** expose native capability through a
  `JavaScriptChannel` to untrusted pages; never enable file access for remote content.
- **Common AI failure**: `JavaScriptMode.unrestricted` on an arbitrary URL, a
  `JavaScriptChannel` bridging native code to a remote page.
- **red-flag**: unrestricted JS + external/user URL, native bridge exposed to untrusted content.

### 6. SQL injection in local DB (CWE-89 · OWASP A03)

- **Rule**: `sqflite`/`drift` raw queries use **parameter placeholders**
  (`?` + `whereArgs`). Never interpolate input into the SQL string.
- **Common AI failure**: `db.rawQuery('SELECT * FROM t WHERE name = "$name"')`,
  building `where:` with string concatenation.
- **red-flag**: `$var`/`+` inside a raw SQL string, `where:` built by concatenation.

### 7. Sensitive data in logs (CWE-532 · OWASP A09 · MASVS-STORAGE)

- **Rule**: never `print`/`debugPrint`/log **tokens · passwords · full PII**.
  Logs persist in device/OS logs. Redact; strip logs from release builds.
- **Common AI failure**: `debugPrint('token=$jwt')`, logging the full response
  body/user object, `print(exception)` exposing secrets in a crash path.
- **red-flag**: tokens/passwords/PII in `print`/`debugPrint`/logger calls.

### 8. Weak crypto / randomness (CWE-327/338 · OWASP A02)

- **Rule**: security tokens/salts/IVs use **`Random.secure()`** (`Random()` is not
  cryptographic). Hashing for integrity is SHA-256+. No MD5/SHA1 for security, no
  home-rolled crypto — use `cryptography`/`pointycastle` correctly (AES-GCM).
- **Common AI failure**: `Random().nextInt(...)` for a token, `md5`/`sha1`,
  ECB / fixed IV, inventing an XOR "encryption".
- **red-flag**: `Random()` (non-secure) for security values, `md5(`/`sha1(`, ECB, fixed IV.

### 9. Insecure platform config (OWASP A05 · MASVS-PLATFORM)

- **Rule**: Android — no `android:allowBackup="true"` for sensitive apps, no
  `cleartextTrafficPermitted`/`usesCleartextTraffic`, keep `exported` correct.
  iOS — no ATS `NSAllowsArbitraryLoads`. Don't weaken platform defaults "to make it work".
- **Common AI failure**: adding `usesCleartextTraffic="true"`, ATS arbitrary loads,
  broad `allowBackup` including token storage.
- **red-flag**: cleartext-traffic flags, ATS arbitrary loads, `allowBackup=true` with secrets on device.

### 10. Vulnerable / hallucinated dependencies — slopsquatting (OWASP A06 · LLM supply chain)

- **Rule**: verify an AI-suggested pub.dev package **actually exists and is the
  legitimate, maintained package** (hallucination/slopsquatting). Pin versions,
  commit `pubspec.lock`, watch platform-plugin permissions the package pulls in.
- **Common AI failure**: adding a nonexistent or typo-similar package, an
  abandoned plugin with a known CVE, a package requesting excessive permissions.
- **red-flag**: a package name you've never seen · negligible likes/downloads ·
  no recent maintenance · a version with a known advisory.

## Vibe-guard review checklist

For Flutter code that AI generated or was pasted in quickly, before merge:

- [ ] No secrets/keys compiled into Dart or committed `.env`. Privileged calls proxied server-side.
- [ ] Tokens/credentials/PII in `flutter_secure_storage`, not `SharedPreferences`/plain files.
- [ ] HTTPS only; `badCertificateCallback`/trust-all never used; no `http://` endpoints.
- [ ] Deep-link/channel input validated before routing/queries; redirects allowlisted.
- [ ] WebView: no unrestricted JS on untrusted URLs; no native bridge to remote pages.
- [ ] Local-DB raw queries use `?` + `whereArgs` (no string interpolation).
- [ ] No tokens/passwords/PII in `print`/`debugPrint`/logs.
- [ ] `Random.secure()` for security values; no MD5/SHA1/ECB/home-rolled crypto.
- [ ] No cleartext-traffic / ATS-arbitrary-loads / unsafe `allowBackup` in manifests.
- [ ] Added pub.dev deps are real · legitimate · maintained · version-pinned · CVE-free.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (vulnerable vs safe code samples): [reference.md](./reference.md)
- Umbrella: [flutter-architecture](../flutter-architecture/SKILL.md)
- Adjacent: [flutter-navigation-platform](../flutter-navigation-platform/SKILL.md), [flutter-state-management](../flutter-state-management/SKILL.md)
- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS / MASTG: https://mas.owasp.org/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- CWE Top 25: https://cwe.mitre.org/top25/
