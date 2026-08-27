---
name: kmp-security
description: KMP security guard — a safety guard that reviews and blocks the vulnerable patterns that commonly slip into AI-generated Kotlin Multiplatform code produced by "vibe coding". Covers hardcoded secrets/API keys compiled into the app, insecure local storage of tokens (expect/actual → EncryptedSharedPreferences/Keychain), insecure Ktor networking (cleartext http, disabled/bypassed TLS), unvalidated deep-link and expect/actual input, unsafe kotlinx.serialization defaults (isLenient/unvalidated), SQL injection in SQLDelight raw queries, sensitive data in Kermit/Napier logs, weak crypto/randomness, insecure platform config (AndroidManifest.xml/Info.plist), and vulnerable/hallucinated (slopsquatting) Gradle dependencies. Auto-loads when writing or reviewing Kotlin source, build.gradle.kts, or platform manifests. This is the vibe-coding security guard for AI-generated KMP code.
when_to_use: When reviewing KMP/Kotlin code before merge (especially AI/LLM-generated or quickly pasted), when touching secrets/token storage/network/TLS/deep links/expect-actual boundaries/local DB/serialization/crypto/dependencies, or on requests like "security review", "is this KMP code safe", "vibe coding check".
paths: "**/*.kt, **/build.gradle.kts, **/gradle/libs.versions.toml, **/AndroidManifest.xml, **/Info.plist, **/.env*"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-security — vibe-coding security guard

AI-generated KMP code is **fast but frequently vulnerable**, and mobile code ships
the secret to the device where anyone can extract it. Empirical studies find a
large share of AI-generated code contains security flaws, and AI-assisted commits
leak secrets more often than human-only commits. Developers also **overtrust** AI
code, believing it safer than it is. This skill is the **review gate**. The rules
here are **safety rules** and must not be relaxed. Project `ctx/` overrides this
document, but the security floor is never lowered.

## Scope

- Targets: Kotlin source (`commonMain`, `androidMain`, `iosMain`), `build.gradle.kts`,
  `libs.versions.toml`, platform manifests (`AndroidManifest.xml`, `Info.plist`), `.env`
  — especially AI-generated or quickly-pasted code.
- What it does: **detect vulnerable patterns → propose safe alternatives** for each
  failure mode below.
- Delegate to adjacent skills: deep-link/route handling → [kmp-navigation-platform],
  logging discipline in state holders → [kmp-state-management].
- Reality: a compiled KMP app can be reverse-engineered — **anything baked into the
  binary (keys, endpoints, logic) is readable**. Secrets belong on a server, not in
  the app.

## Core Rules — by AI-generated-code failure mode (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Hardcoded secrets in the app bundle (CWE-798 · OWASP MASVS-STORAGE)

- **Rule**: API keys · tokens · passwords are **not** compiled into the app. Use a
  backend proxy for privileged calls; inject non-secret config via `BuildConfig`
  fields or build-time properties. Never commit `.env`. No secret is safe
  client-side — treat a shipped key as public.
- **Common AI failure**: `const val apiKey = "sk-live-..."`, committing `.env`,
  putting a third-party secret in Kotlin to "call the API directly from the app",
  reading secrets from `local.properties` and embedding them via `buildConfigField`.
- **red-flag**: string-literal keys in `.kt`, `buildConfigField` containing a secret
  value, tracked `.env`, private API called directly from the client with an embedded
  secret.

### 2. Insecure local storage of sensitive data (CWE-312/922 · MASVS-STORAGE)

- **Rule**: tokens · credentials · PII go behind an **`expect`/`actual`** secure
  storage abstraction: `EncryptedSharedPreferences` on Android, `Keychain` on iOS.
  Plain `SharedPreferences` / `DataStore` (unencrypted) / plain files are cleartext
  — non-sensitive prefs only.
- **Common AI failure**: saving the auth token in plain `SharedPreferences` or
  unencrypted `DataStore`, writing credentials to a plain file, storing tokens in
  a SQLDelight table without encryption.
- **red-flag**: `SharedPreferences` / `DataStore` holding a `token` / `password`
  key, plaintext credential files, `INSERT INTO sessions` with a raw token field.

### 3. Insecure networking / TLS bypass (CWE-295/319 · OWASP A02/A05 · MASVS-NETWORK)

- **Rule**: **HTTPS only.** Never disable certificate validation in the Ktor engine
  config. Do not set `httpsURLConnection.setHostnameVerifier { _, _ -> true }` or
  use a trust-all `TrustManager`. If pinning, pin correctly; otherwise use the
  platform default trust store.
- **Common AI failure**: `http://` endpoints in the Ktor base URL, an
  `HttpsURLConnection` override that trusts all hosts, a custom `X509TrustManager`
  that accepts any certificate "to fix an SSL error", `CIO` engine config with
  `https { trustStore = null }`.
- **red-flag**: `trustAllCerts`, `hostnameVerifier { _, _ -> true }`, `http://` in a
  Ktor `HttpClient` base URL, any trust-manager whose `checkServerTrusted` is empty.

### 4. Unsafe kotlinx.serialization defaults (CWE-20 · OWASP A08)

- **Rule**: `Json { isLenient = true }` and `Json { ignoreUnknownKeys = false }` (the
  strict default) are the only safe starting points. Never set `isLenient = true` in
  production — it accepts malformed/injected JSON. Set `ignoreUnknownKeys = true`
  deliberately and explicitly; blind acceptance is fine, silent schema mismatch is not.
  Always validate deserialized values before use.
- **Common AI failure**: copy-pasting a `Json { isLenient = true }` config "to avoid
  parse errors", leaving out `ignoreUnknownKeys` documentation, deserializing
  user-controlled JSON directly into a data class without field validation.
- **red-flag**: `isLenient = true` in a non-test `Json { }` block, deserializing
  untrusted input directly into a model with no post-parse validation, a
  `@SerialName` field mapped to a raw `String` holding an unvalidated redirect URL.

### 5. SQL injection in SQLDelight (CWE-89 · OWASP A03)

- **Rule**: SQLDelight `.sq` files use **named parameters** (`:param`). Never
  concatenate user input into a raw `sqlDriver.execute()` string or a multiline
  string template inside a custom query. SQLDelight's generated queries are safe by
  default — stay inside the generated API.
- **Common AI failure**: `sqlDriver.execute(null, "SELECT * FROM user WHERE name = '$name'", 0)`,
  building a `WHERE` clause by string interpolation, stepping outside the generated
  `Queries` interface to run ad-hoc SQL.
- **red-flag**: `"SELECT … $variable"` or `"… ${input}"` inside an `execute` call,
  string concatenation inside a `.sq` file query body, raw `executeQuery` with
  interpolated user data.

### 6. Kermit / Napier log leakage (CWE-532 · OWASP A09 · MASVS-STORAGE)

- **Rule**: never log **tokens · passwords · full PII** via `Napier.d` / `Logger.d`
  / `Kermit`. Logs persist in device/OS logs and are readable via `adb logcat` or
  the Xcode console. Redact; strip or gate verbose logs in release builds.
- **Common AI failure**: `Napier.d("token=$jwt")`, logging the full serialized
  response object, `Logger.e("exception", e)` where `e.message` contains a
  credential, `Kermit.v { "user: $user" }` logging the full user model.
- **red-flag**: tokens / passwords / PII in `Napier.*` / `Logger.*` / `Kermit.*`
  calls; logging a full `@Serializable` data class that contains sensitive fields.

### 7. Weak crypto / randomness (CWE-327/338 · OWASP A02)

- **Rule**: security tokens / salts / IVs use `SecureRandom` (Java/Android) or the
  platform `expect`/`actual` equivalent — `kotlin.random.Random` is not
  cryptographic. Hashing for integrity is SHA-256+. No MD5/SHA1 for security, no
  home-rolled XOR "encryption". Use `javax.crypto` (AES-GCM) or a vetted
  multiplatform crypto library correctly.
- **Common AI failure**: `Random.nextInt(...)` (kotlin.random) for a token,
  `MessageDigest.getInstance("MD5")`, ECB mode, a fixed IV, an XOR cipher.
- **red-flag**: `kotlin.random.Random` for security values, `"MD5"` / `"SHA-1"` in a
  `MessageDigest.getInstance`, `"AES/ECB"` cipher mode, a zero or hardcoded IV byte
  array, any hand-rolled crypto function.

### 8. Deep-link / expect-actual input validation (CWE-20/601 · OWASP A01)

- **Rule**: deep-link params, universal/app-link data, and `expect`/`actual`
  platform-boundary values are **untrusted**. Validate and type-check before mapping
  to a route or a repository call; allowlist redirect targets. Details →
  [kmp-navigation-platform](../kmp-navigation-platform/SKILL.md).
- **Common AI failure**: mapping a deep-link path parameter straight to a repository
  call, honoring an arbitrary `next=` URL from the intent, passing a link param into
  a SQLDelight query unchecked, returning an `actual` value from platform code with
  no validation in `commonMain`.
- **red-flag**: raw deep-link / intent extra value passed directly to a route, repo,
  or query with no validation; `actual` return value used in `commonMain` without a
  range/type check.

### 9. Insecure platform config (OWASP A05 · MASVS-PLATFORM)

- **Rule**: Android — no `android:allowBackup="true"` for sensitive apps, no
  `cleartextTrafficPermitted` / `usesCleartextTraffic`, keep `exported` correct for
  all Activities / Services / Receivers. iOS — no ATS `NSAllowsArbitraryLoads`.
  Don't weaken platform defaults "to make it work".
- **Common AI failure**: adding `usesCleartextTraffic="true"` to pass HTTP traffic,
  ATS arbitrary loads, broad `allowBackup` including token storage, `android:exported="true"`
  on an internal Activity.
- **red-flag**: `usesCleartextTraffic="true"`, `NSAllowsArbitraryLoads`, `allowBackup="true"`
  with sensitive data on device, `exported="true"` on a non-launcher Activity without
  an intentional reason.

### 10. Vulnerable / hallucinated Gradle dependencies — slopsquatting (OWASP A06 · LLM supply chain)

- **Rule**: verify an AI-suggested Maven/Gradle dependency **actually exists and is
  the legitimate, maintained artifact** (hallucination / slopsquatting). Pin versions
  in `libs.versions.toml`, commit `gradle.lockfile`, watch platform permissions the
  library pulls in.
- **Common AI failure**: adding a nonexistent or typo-similar artifact coordinate, an
  abandoned library with a known CVE, a library requesting excessive Android
  permissions through a transitive dependency.
- **red-flag**: a `libs.versions.toml` entry you've never seen · no Maven Central
  presence · negligible downloads · no recent release · a version with a known
  advisory in the OSV database.

## Vibe-guard review checklist

For KMP code that AI generated or was pasted in quickly, before merge:

- [ ] No secrets/keys in Kotlin source or `buildConfigField`; no committed `.env`. Privileged calls proxied server-side.
- [ ] Tokens/credentials/PII behind `expect`/`actual` secure storage (EncryptedSharedPreferences / Keychain).
- [ ] HTTPS only; no trust-all `TrustManager` / hostname verifier; no `http://` Ktor base URLs.
- [ ] `Json { isLenient = false }` (default); `isLenient = true` never in production; deserialized values validated.
- [ ] SQLDelight queries use named parameters (`:param`); no string-interpolated SQL.
- [ ] No tokens/passwords/PII in `Napier.*` / `Logger.*` / `Kermit.*` calls.
- [ ] `SecureRandom` for security values; no MD5/SHA1/ECB/fixed-IV/home-rolled crypto.
- [ ] Deep-link / intent / `actual` values validated before routing or repo calls; redirects allowlisted.
- [ ] No cleartext-traffic / ATS-arbitrary-loads / unsafe `allowBackup` / unintended `exported` in manifests.
- [ ] Added Gradle deps are real · legitimate · maintained · version-pinned · CVE-free.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (vulnerable vs safe code samples): [reference.md](./reference.md)
- Umbrella: [kmp-architecture](../kmp-architecture/SKILL.md)
- Adjacent: [kmp-navigation-platform](../kmp-navigation-platform/SKILL.md), [kmp-state-management](../kmp-state-management/SKILL.md)
- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS / MASTG: https://mas.owasp.org/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- CWE Top 25: https://cwe.mitre.org/top25/
