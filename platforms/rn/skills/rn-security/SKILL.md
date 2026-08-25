---
name: rn-security
description: React Native security guard — a safety guard that reviews and blocks the vulnerable patterns that commonly slip into AI-generated RN code produced by "vibe coding". Covers hardcoded secrets/API keys bundled into the JS bundle, tokens/PII in AsyncStorage/MMKV instead of Keychain/Keystore secure storage, insecure networking (cleartext http, disabled/bypassed TLS certificate validation), unvalidated deep-link/linking-config input mapped to navigation or queries, WebView misconfiguration (JS enabled on untrusted content, injectedJavaScript, native bridges), sensitive data in logs (console.log of tokens/PII), weak crypto/randomness (Math.random for security, MD5/SHA1, home-rolled crypto), insecure platform config (Android usesCleartextTraffic/allowBackup, iOS ATS NSAllowsArbitraryLoads), and vulnerable/hallucinated npm/native (slopsquatting) dependencies. Auto-loads when writing or reviewing RN source, app config, or native manifests. This is the vibe-coding security guard for AI-generated React Native code.
when_to_use: When reviewing RN/TS code before merge (especially AI/LLM-generated or quickly pasted), when touching secrets/token storage/network/TLS/deep links/WebView/logging/crypto/dependencies/native config, or on requests like "security review", "is this app safe", "vibe coding check".
paths: **/*.ts, **/*.tsx, **/app.json, **/app.config.ts, **/app.config.js, **/Info.plist, **/AndroidManifest.xml, **/.env*
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-security — vibe-coding security guard

AI-generated app code is **fast but frequently vulnerable**, and a React Native
app ships its JS bundle and secrets to the device where they can be extracted.
Empirical studies find a large share of AI-generated code contains security
flaws, and AI-assisted commits leak secrets more often than human-only ones.
Developers also **overtrust** AI code. This skill is the **review gate**. The rules
here are **safety rules** and must not be relaxed. Project `ctx/` overrides this
document, but the security floor is never lowered.

## Scope

- Targets: RN source (TS/JS), app config (`app.json`/`app.config`), native
  manifests (`AndroidManifest.xml`, `Info.plist`), `.env` — especially
  AI-generated or quickly-pasted code.
- What it does: **detect vulnerable patterns → propose safe alternatives** for
  each failure mode below.
- Delegate: deep-link/route handling → [rn-navigation-lifecycle], secure vs
  plain storage detail → [rn-state-data], native module wrapping → [rn-native-modules].
- Reality: **the JS bundle and app package ship to the device** — anything
  embedded (keys, endpoints, logic) is extractable. Secrets belong on a server.

## Core Rules — by AI-generated-code failure mode (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Hardcoded secrets in the bundle (CWE-798 · OWASP MASVS-STORAGE)

- **Rule**: API keys · tokens · passwords are **not** bundled into the app. Proxy
  privileged calls through your backend; inject non-secret config via env at
  build. `.env`/`app.config` values shipped to JS are **not** secret.
- **Common AI failure**: `const KEY = 'sk-live-...'`, calling a third-party API
  with an embedded secret from the app, committing `.env`.
- **red-flag**: string-literal keys in `.ts`, a private API called directly from
  the app with an embedded secret, a tracked `.env`.

### 2. Tokens/PII in insecure storage (CWE-312/922 · MASVS-STORAGE)

- **Rule**: tokens · credentials · PII go to **Keychain/Keystore** via a
  secure-storage module (Expo SecureStore, react-native-keychain). AsyncStorage/
  MMKV are cleartext — non-sensitive only → [rn-state-data].
- **Common AI failure**: `AsyncStorage.setItem('token', jwt)`, refresh token in MMKV plain.
- **red-flag**: token/credential/PII in AsyncStorage or MMKV plaintext.

### 3. Insecure networking / TLS bypass (CWE-295/319 · MASVS-NETWORK)

- **Rule**: **HTTPS only.** Never disable certificate validation or ship a
  trust-all TLS setup. If pinning, pin correctly; otherwise use the platform
  trust store. No cleartext `http://` endpoints.
- **Common AI failure**: `http://` API base URL, a native trust-all override "to
  fix an SSL error", disabling ATS to load http.
- **red-flag**: `http://` endpoints, trust-all TLS, ATS/cleartext enabled to allow http.

### 4. Unvalidated deep-link input (CWE-20/601 · OWASP A01)

- **Rule**: deep-link / linking-config params and universal-link data are
  **untrusted**. Validate before mapping to a screen or a query; allowlist
  redirect targets; bad input → defined fallback → [rn-navigation-lifecycle].
- **Common AI failure**: mapping a link param straight to navigation, honoring an
  arbitrary redirect/URL from a link.
- **red-flag**: raw deep-link value into a screen/query/redirect with no validation.

### 5. WebView misconfiguration (CWE-79/749 · MASVS-PLATFORM)

- **Rule**: don't load untrusted content with JS enabled; restrict navigation to
  an allowlist (`onShouldStartLoadWithRequest`); don't `injectedJavaScript` or
  bridge native capability into untrusted pages; avoid `allowFileAccess`/`allowingReadAccessToURL` for remote content.
- **Common AI failure**: `<WebView source={{ uri: userUrl }} javaScriptEnabled />`,
  a message bridge exposing native APIs to a remote page.
- **red-flag**: JS enabled on an external/user URL, native bridge to untrusted content.

### 6. Sensitive data in logs (CWE-532 · OWASP A09)

- **Rule**: never `console.log` **tokens · passwords · full PII**; logs persist
  in device/Metro/crash logs. Strip verbose logging from release.
- **Common AI failure**: `console.log('token', jwt)`, logging the full response/user object.
- **red-flag**: tokens/passwords/PII in `console.log`/logger calls.

### 7. Weak crypto / randomness (CWE-327/338 · OWASP A02)

- **Rule**: security tokens/salts use a **CSPRNG** (`react-native-get-random-values`
  + `crypto.getRandomValues`, or a native module) — **`Math.random()` is not
  cryptographic**. No MD5/SHA1 for security, no home-rolled crypto.
- **Common AI failure**: `Math.random()` token/id, `md5`/`sha1`, an XOR "encryption".
- **red-flag**: `Math.random()` for a security value, `md5(`/`sha1(`, hand-rolled crypto.

### 8. Insecure platform config (OWASP A05 · MASVS-PLATFORM)

- **Rule**: Android — no `android:usesCleartextTraffic="true"`, no
  `allowBackup="true"` for sensitive apps, correct `exported`. iOS — no ATS
  `NSAllowsArbitraryLoads`. Don't weaken platform defaults "to make it work".
- **Common AI failure**: adding cleartext traffic, ATS arbitrary loads, broad allowBackup.
- **red-flag**: cleartext-traffic flags, ATS arbitrary loads, `allowBackup=true` with secrets on device.

### 9. Vulnerable / hallucinated dependencies — slopsquatting (OWASP A06 · LLM supply chain)

- **Rule**: verify an AI-suggested npm/native package **actually exists and is the
  legitimate, maintained package** (hallucination/slopsquatting). Pin versions,
  commit the lockfile, review native permissions the package pulls in and its postinstall.
- **Common AI failure**: adding a nonexistent/typo-similar package, an abandoned
  native module with a known CVE, a package requesting excessive permissions.
- **red-flag**: a package name you've never seen · negligible downloads · no recent
  maintenance · an advisory · a suspicious postinstall.

## Vibe-guard review checklist

For RN code that AI generated or was pasted in quickly, before merge:

- [ ] No secrets bundled into JS / committed `.env`; privileged calls proxied server-side.
- [ ] Tokens/credentials/PII in Keychain/Keystore, not AsyncStorage/MMKV plaintext.
- [ ] HTTPS only; no trust-all TLS; no cleartext `http://` endpoints.
- [ ] Deep-link/linking input validated before navigation/queries; redirects allowlisted.
- [ ] WebView: no JS on untrusted URLs; no native bridge to remote pages.
- [ ] No tokens/passwords/PII in `console.log`; verbose logging stripped from release.
- [ ] CSPRNG for security values; no `Math.random`/MD5/SHA1/home-rolled crypto.
- [ ] No cleartext-traffic / ATS-arbitrary-loads / unsafe `allowBackup` in manifests.
- [ ] Added deps are real · legitimate · maintained · version-pinned · CVE-free.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (vulnerable vs safe code samples): [reference.md](./reference.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md)
- Adjacent: [rn-navigation-lifecycle](../rn-navigation-lifecycle/SKILL.md), [rn-state-data](../rn-state-data/SKILL.md)
- React Native security: https://reactnative.dev/docs/security
- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS / MASTG: https://mas.owasp.org/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- CWE Top 25: https://cwe.mitre.org/top25/
