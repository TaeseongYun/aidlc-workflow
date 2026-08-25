---
name: android-security
description: Android security rules — exported component & Intent/extras validation, permissions, data-at-rest encryption, network security config, Android Keystore, and Play Integrity. Use when writing or reviewing AndroidManifest.xml, network_security_config.xml, or *.kt, when designing or verifying the trust boundary of an exported component or deep link, or when deciding how to store a key/secret/credential.
when_to_use: When adding or modifying an exported component, building intent-filter/deep-link routing, touching an Activity/Service/Receiver/Provider that reads extras, dealing with HTTP/cleartext or certificate pinning, or looking at EncryptedSharedPreferences/Keystore/encryption code
paths: **/AndroidManifest.xml, **/network_security_config.xml, **/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android Security

The security baseline for the team's Android app. This expands `../../guidance.md`'s
"Intent-first external surface" from a security angle. The rules here are
**safety rules** and must not be weakened or relaxed.

## Scope

- Applies to: `AndroidManifest.xml`, `network_security_config.xml`, Kotlin sources.
- Covers: exported components & Intent/extras validation, deep links, permissions,
  data-at-rest encryption, network security config, Android Keystore, Play
  Integrity, WebView.
- guidance.md is the higher baseline. A project's `ctx/` overrides this document.

## Core Rules

### Trust boundary (exported = trust boundary) — never relax

- **Every exported component is a trust boundary.** Validate all incoming extras
  and caller data before use. A missing extra, wrong type, or malicious value
  must land on a **defined fallback** and must never lead to a crash or a silent
  privilege escalation.
- Declare `android:exported` **explicitly** for every Activity/Service/Receiver/Provider
  (required on targetSdk 31+ when an intent-filter is present). Having an
  intent-filter does not automatically export a component — decide whether to
  export at design time and record it in the technical design document.
- An intent-filter is only a routing hint, **not a security control.** Do not
  assume the filter screened the input; re-validate in code.
- Deep links: Activity receives Intent → validate host/scheme → validate extras →
  feature route contract → back stack construction → Compose entry. Do not inject
  an unvalidated URI straight into a route.
- Use `android:exported="false"` if there is no need to share with other apps.
  Keep Providers false by default too, granting only the access needed. This is
  different from arbitrarily adding false "to harden later" — a contract entry
  point makes its surface explicit at design time.

### Own-app IPC / permissions

- Protect IPC between your own apps with an `android:protectionLevel="signature"`
  custom permission.
- In Binder/Messenger, verify caller permission in code with
  `checkCallingPermission()` before a sensitive operation. Use
  `clearCallingIdentity()`/`restoreCallingIdentity()` only when performing an
  external-process call on the caller's behalf.
- Request permissions minimally. Where possible, delegate to another app via an
  intent instead of a permission (adding a contact via `Intent.ACTION_INSERT`
  instead of `READ_CONTACTS`).
- No localhost/network sockets for sensitive IPC, no `INADDR_ANY` binding.

### Data at rest

- Keep sensitive data only in internal storage (`Context.getFilesDir()`,
  `MODE_PRIVATE`). External storage is globally readable/writable, so use it only
  for non-sensitive data. SharedPreferences always with `MODE_PRIVATE`.
- Keep encryption keys in the **Android Keystore**. Do not pull keys out into app
  memory.
- **EncryptedSharedPreferences / EncryptedFile (Jetpack Security
  `androidx.security:security-crypto`) are deprecated.** Do not use them in new
  code. Alternatives: encrypt directly in internal storage with a key managed by
  the Android Keystore (recommended tool **Tink**), and use **DataStore** for
  settings. Existing usages are migration targets.
- Do not store passwords/user IDs on the device — use short-lived auth tokens.
- Do not commit API keys/secrets to source or VCS. Do not implement your own
  crypto algorithms — use the `Cipher`/`KeyGenerator` framework, seed with
  `SecureRandom`, AES 256-bit.
- No `file://` for file sharing — use a `FileProvider`'s `content://` + URI
  permission flags.

### Network security config

- Add `res/xml/network_security_config.xml` and link it in the manifest via
  `android:networkSecurityConfig`.
- Block cleartext (HTTP) by default. No `cleartextTrafficPermitted="true"` for
  production domains. Do not enable it globally in base-config.
- Certificate pinning with `<pin-set>` + SHA-256. **Backup pin required**,
  `expiration` required.
- Custom CAs in `<debug-overrides>` for debug builds only. No debug CA or
  `android:debuggable="true"` in release builds.
- Do not neutralize validation with a custom `TrustManager`/`HostnameVerifier`.

### Android Keystore / Play Integrity

- Generate keys with the `AndroidKeyStore` provider + `KeyGenParameterSpec`.
  Constrain the use by specifying purpose/digest/padding (immutable after creation).
- Bind sensitive-operation keys to user authentication:
  `setUserAuthenticationParameters(timeout, types)` (the old
  `setUserAuthenticationRequired(true)` is deprecated). Use `BiometricPrompt` when
  using them.
- Use StrongBox where possible (after checking `FEATURE_STRONGBOX_KEYSTORE`, call
  `setIsStrongBoxBacked(true)`), and key attestation (`setAttestationChallenge`)
  when hardware attestation is needed.
- Play Integrity: integrity tokens **must be verified on the server** (no
  client-side verification). For new integrations use Standard requests
  (`StandardIntegrityManager`), and request/verify a replay-prevention nonce on
  the server.

### WebView

- Disable JavaScript unless needed (keep the default). `addJavascriptInterface()`
  only for trusted content bundled in the APK.
- Load only trusted URLs (allowlist), HTTPS only. On Android 6.0+ communicate via
  `createWebMessageChannel()`.

## Exported-component validation checklist

When touching an exported Activity/Service/Receiver/Provider (or a deep link),
in order:

| # | Check | On failure |
|---|------|---------|
| 1 | Is `android:exported` declared explicitly | Declare it. If an intent-filter is present, decide whether to export |
| 2 | Is this component really meant to be exposed externally | If not, `exported="false"` |
| 3 | Does the required extra exist and match its type | Defined fallback (no crash) |
| 4 | Is the extra value within a valid range / whitelist | Defined fallback |
| 5 | For a deep link, is host/scheme validated | Reject, then fallback |
| 6 | Is a URI/route not put on the back stack without validation | Validate, then go through the route contract |
| 7 | For sensitive IPC, is caller permission checked | `checkCallingPermission()` |
| 8 | Is the contract (action, extras, result) recorded in the design document | Record it |

## Refactor / Red-flag signals

- An exported Activity using extras without validation → trust-boundary violation.
- An intent-filter present but `android:exported` undeclared.
- Injecting an unvalidated deep-link URI directly into a route / back stack.
- `EncryptedSharedPreferences`/`EncryptedFile`/`androidx.security.crypto` import (deprecated).
- Hardcoded keys/secrets, `file://` sharing, sensitive data in external storage.
- Missing `network_security_config.xml`, cleartext allowed globally, pins without backup/expiration.
- A custom `TrustManager`/`HostnameVerifier` neutralizing validation.
- Play Integrity token verified on the client.

## References

- [../../guidance.md](../../guidance.md) — team Android baseline (Intent-first external surface)
- [reference.md](reference.md) — code samples, manifest/XML examples, detailed checklist
