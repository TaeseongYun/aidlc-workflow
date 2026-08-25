---
name: ios-security
description: iOS security guard — a safety guard that reviews and blocks the vulnerable patterns that commonly slip into AI-generated Swift/iOS code produced by "vibe coding". Covers secrets in UserDefaults/plist/source instead of Keychain, secrets compiled into the app binary (extractable), insecure networking / App Transport Security bypass (NSAllowsArbitraryLoads, disabled TLS/cert validation), unvalidated URL-scheme / Universal Link / user-activity input and force-unwraps on trust-boundary data, WebView (WKWebView) misconfiguration and native message-handler bridges to untrusted content, sensitive data in logs and the pasteboard, weak crypto/randomness (no CryptoKit, home-rolled crypto, insecure Random), insecure at-rest storage (missing Data Protection / file protection class), and vulnerable/hallucinated Swift Package dependencies (slopsquatting). Auto-loads when writing or reviewing Swift source, Info.plist, entitlements, or Package manifests. This is the vibe-coding security guard for AI-generated iOS code.
when_to_use: When reviewing Swift/iOS code before merge (especially AI/LLM-generated or quickly pasted), when touching Keychain/UserDefaults/secrets/networking/ATS/URL handling/WebView/crypto/pasteboard/dependencies, or on requests like "security review", "is this app code safe", "vibe coding check".
paths: **/*.swift, **/Info.plist, **/*.entitlements, **/Package.swift, **/Package.resolved, **/.env*
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-security — vibe-coding security guard

AI-generated app code is **fast but frequently vulnerable**, and an iOS app ships
its binary to the device where anything embedded can be extracted. Empirical
studies find a large share of AI-generated code contains security flaws, and
AI-assisted commits leak secrets more often than human-only ones. Developers also
**overtrust** AI code. This skill is the **review gate**. The rules here are
**safety rules** and must not be relaxed. Project `ctx/` overrides this document,
but the security floor is never lowered.

## Scope

- Targets: Swift source, `Info.plist`, `.entitlements`, `Package.swift`/
  `Package.resolved`, `.env` — especially AI-generated or quickly-pasted code.
- What it does: **detect vulnerable patterns → propose safe alternatives** for
  each failure mode below.
- Delegate: deep-link validation detail → [ios-navigation-deeplink], secret
  storage & Keychain placement → [ios-platform-adapters].
- Reality: the app binary ships to the device — **anything embedded (keys,
  endpoints, logic) is extractable**. Secrets belong on a server, not in the app.

## Core Rules — by AI-generated-code failure mode (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Secrets in UserDefaults / plist / source (CWE-312/798 · OWASP Mobile M9 · MASVS-STORAGE)

- **Rule**: tokens · credentials · keys go in the **Keychain** (with an
  appropriate accessibility class). Never `UserDefaults`, never a plist, never
  hardcoded in source.
- **Common AI failure**: `UserDefaults.standard.set(token, forKey:)`, an API key
  in a `.plist`, `let apiKey = "sk-..."`.
- **red-flag**: token/secret in `UserDefaults`/plist, string-literal keys in `.swift`.

### 2. Secrets compiled into the binary (CWE-798 · OWASP Mobile M7 · MASVS-RESILIENCE)

- **Rule**: no privileged secret is safe client-side — the binary is extractable.
  Proxy privileged third-party calls through **your backend**; the app holds no
  third-party secret. Don't commit `.env`.
- **Common AI failure**: calling a privileged/third-party API with an embedded key straight from
  the app, committing `.env`/config with secrets.
- **red-flag**: a privileged/third-party API called directly with an embedded key, a tracked `.env`.

### 3. Insecure networking / ATS bypass (CWE-295/319 · OWASP Mobile M5 · MASVS-NETWORK)

- **Rule**: **HTTPS only.** Don't set `NSAllowsArbitraryLoads` in ATS. Never
  return `.useCredential` / disable validation in
  `urlSession(_:didReceive:completionHandler:)` to accept any cert.
- **Common AI failure**: ATS arbitrary loads "to fix an SSL error", a
  `URLSessionDelegate` that trusts all certs, `http://` endpoints.
- **red-flag**: `NSAllowsArbitraryLoads` true, a trust-all auth challenge handler, `http://` base URL.

### 4. Unvalidated URL / activity input · trust-boundary force-unwraps (CWE-20/601 · OWASP Mobile M4)

- **Rule**: URL-scheme / Universal Link / `NSUserActivity` / extension input is
  **untrusted** — validate before mapping to a route or a query; **no
  force-unwraps** on trust-boundary data. Details → [ios-navigation-deeplink].
- **Common AI failure**: `UUID(uuidString: comps.queryItems!.first!.value!)!`,
  mapping an unvalidated URL onto navigation state.
- **red-flag**: force-unwrapped deep-link params, an unvalidated URL driving navigation.

### 5. WKWebView misconfiguration (CWE-79/749 · OWASP Mobile M8 · MASVS-PLATFORM)

- **Rule**: don't load untrusted content with script bridges; a
  `WKScriptMessageHandler` / `injectedJavaScript` bridge is **native capability
  exposed to the page** — only for content you control. Restrict navigation.
- **Common AI failure**: a message handler bridging native code to an arbitrary
  remote URL, loading user-provided URLs with full script access.
- **red-flag**: `WKScriptMessageHandler` reachable by untrusted content, remote/user URL in a bridged WebView.

### 6. Sensitive data in logs / pasteboard (CWE-532/200 · OWASP Mobile M6 · MASVS-STORAGE)

- **Rule**: never `print`/`os_log` **tokens · passwords · full PII**; mark
  sensitive `os_log` interpolation `.private`. Don't copy secrets to the general
  `UIPasteboard` (system-wide, other apps read it).
- **Common AI failure**: `print("token=\(jwt)")`, logging full responses,
  `UIPasteboard.general.string = secret`.
- **red-flag**: tokens/PII in logs, secrets on the general pasteboard.

### 7. Weak crypto / randomness (CWE-327/338 · OWASP Mobile M10 · MASVS-CRYPTO)

- **Rule**: use **CryptoKit** (AES-GCM, SHA-256+, HKDF). Security tokens use
  `SystemRandomNumberGenerator` / `SecRandomCopyBytes`. No MD5/SHA1 for security,
  no ECB, no home-rolled crypto.
- **Common AI failure**: CommonCrypto MD5, AES-ECB / fixed IV, `Int.random` from a
  seeded generator for a token, inventing an XOR cipher.
- **red-flag**: MD5/SHA1 for security, ECB/fixed IV, non-secure RNG for secrets.

### 8. Insecure at-rest storage / Data Protection (CWE-311 · OWASP Mobile M9 · MASVS-STORAGE)

- **Rule**: sensitive files use a **Data Protection** class
  (`.completeFileProtectionUnlessOpen`/`.completeFileProtection`); Keychain items use an appropriate
  accessibility (`...ThisDeviceOnly` for non-synced secrets). Don't disable file
  protection.
- **Common AI failure**: writing sensitive data with `.none` protection, syncing
  device-only secrets, storing PII in an unprotected DB/file.
- **red-flag**: `NSFileProtectionNone` on sensitive data, over-permissive Keychain accessibility.

### 9. Vulnerable / hallucinated Swift Package deps — slopsquatting (OWASP Mobile M2 · LLM supply chain)

- **Rule**: verify an AI-suggested Swift Package **actually exists and is the
  legitimate, maintained package** (hallucination/slopsquatting). Pin exact
  versions, commit `Package.resolved`, review what a package does.
- **Common AI failure**: adding a nonexistent or typo-similar package, an
  abandoned package with a known CVE.
- **red-flag**: a package name you've never seen · negligible stars · no recent
  maintenance · a version with a known advisory.

## Vibe-guard review checklist

For iOS code that AI generated or was pasted in quickly, before merge:

- [ ] Secrets/tokens in the Keychain (right accessibility), never `UserDefaults`/plist/source.
- [ ] No privileged secret embedded in the binary; privileged calls proxied server-side; no committed `.env`.
- [ ] HTTPS only; no `NSAllowsArbitraryLoads`; no trust-all URLSession challenge handler.
- [ ] URL-scheme/activity input validated before routing; no force-unwraps on trust-boundary data.
- [ ] WKWebView: no native message-handler bridge to untrusted content; navigation restricted.
- [ ] No tokens/PII in logs; sensitive `os_log` marked `.private`; secrets off the general pasteboard.
- [ ] CryptoKit for crypto; secure RNG for tokens; no MD5/SHA1/ECB/home-rolled crypto.
- [ ] Sensitive files use a Data Protection class; Keychain accessibility scoped.
- [ ] Added Swift Packages are real · legitimate · maintained · version-pinned · CVE-free.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (vulnerable vs safe code samples): [reference.md](./reference.md)
- Umbrella: [ios-architecture](../ios-architecture/SKILL.md)
- Adjacent: [ios-navigation-deeplink](../ios-navigation-deeplink/SKILL.md), [ios-platform-adapters](../ios-platform-adapters/SKILL.md)
- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS / MASTG: https://mas.owasp.org/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- Apple — Keychain & Data Protection: https://developer.apple.com/documentation/security/keychain_services
- CWE Top 25: https://cwe.mitre.org/top25/
