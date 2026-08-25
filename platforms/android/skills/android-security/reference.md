# Android Security — Reference

Deep-dive material for `SKILL.md`: code samples, manifest/XML examples,
detailed checklist. For the rule summary and decision criteria, see `SKILL.md`.

## 1. Exported components & Intent/extras validation

### Manifest: declare export explicitly

```xml
<!-- feature entry point: if it is a contract, explicitly exported="true" -->
<activity
    android:name=".DetailActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="com.example.action.OPEN_DETAIL" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</activity>

<!-- internal only: declare even without an intent-filter -->
<activity android:name=".InternalActivity" android:exported="false" />

<!-- Provider defaults to false, grant only the access needed via permissions -->
<provider
    android:name=".MyProvider"
    android:authorities="com.example.provider"
    android:exported="false" />
```

- targetSdk 31+ (Android 12): an activity/service/receiver with an intent-filter
  **must** declare `android:exported`. Otherwise install/build fails.
- Without an intent-filter, defaults to `false`. With one, you must declare
  `true` for another app to start it.

### extras validation — trust-boundary pattern

Do not trust incoming values. Missing, wrong-typed, or malicious → a **defined
fallback**.

```kotlin
// Activity.onCreate: exported entry point
private data class DetailArgs(val itemId: Long, val source: Source)

private fun parseArgs(intent: Intent): DetailArgs? {
    val id = intent.getLongExtra(EXTRA_ITEM_ID, -1L)
    if (id <= 0L) return null                       // missing / wrong-type default → reject
    val raw = intent.getStringExtra(EXTRA_SOURCE)
    val source = Source.entries.firstOrNull { it.key == raw }
        ?: return null                              // outside whitelist → reject
    return DetailArgs(id, source)
}

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val args = parseArgs(intent) ?: run {
        routeToFallback()                            // no crash, no silent privilege escalation
        finish()
        return
    }
    // args is now validated → to the route contract
}
```

### Deep-link validation order

Activity receives Intent → validate host/scheme → validate extras → feature route
contract → back stack construction → Compose entry. Do not put an unvalidated URI
straight into a route.

```kotlin
private val ALLOWED_HOSTS = setOf("example.com", "app.example.com")

private fun routeFromDeepLink(uri: Uri): Route? {
    if (uri.scheme != "https") return null           // scheme validation
    if (uri.host !in ALLOWED_HOSTS) return null       // host whitelist
    val id = uri.getQueryParameter("id")?.toLongOrNull()
        ?: return null                                // extras validation
    return Route.Detail(id)                           // only validated values to the route contract
}
```

### Own-app IPC — signature permission + caller check

```xml
<permission
    android:name="com.example.permission.PRIVATE_IPC"
    android:protectionLevel="signature" />
<service
    android:name=".PrivateService"
    android:exported="true"
    android:permission="com.example.permission.PRIVATE_IPC" />
```

```kotlin
// Inside Binder/Messenger: check caller permission before a sensitive operation
if (checkCallingPermission("com.example.permission.PRIVATE_IPC")
    != PackageManager.PERMISSION_GRANTED) {
    throw SecurityException("caller lacks permission")
}
```

## 2. Data at rest

### Jetpack Security is deprecated

`androidx.security:security-crypto` (EncryptedSharedPreferences, EncryptedFile,
MasterKey) is deprecated. Do not use it in new code.

Recommended alternatives:

- Most sensitive data: internal storage (`MODE_PRIVATE`) alone gives sufficient
  app-sandbox isolation.
- If extra encryption is needed: manage keys with the **Android Keystore** and
  encrypt data with **Tink**.
- Settings/key-value: **DataStore** (SharedPreferences replacement).
- Short-lived tokens instead of passwords. Do not pull keys out into app memory.

```kotlin
// Direct AES-GCM with a Keystore key (minimal example without Tink)
val keyGen = KeyGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
)
keyGen.init(
    KeyGenParameterSpec.Builder(
        "data_key",
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
    )
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setKeySize(256)
        .build()
)
val key = keyGen.generateKey()   // the key stays in the Keystore
```

## 3. Network security config

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2026-12-31">
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <!-- backup pin required -->
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>

    <!-- trusted in debug builds only, not included in release -->
    <debug-overrides>
        <trust-anchors>
            <certificates src="@raw/debug_cas" />
        </trust-anchors>
    </debug-overrides>
</network-security-config>
```

```xml
<application android:networkSecurityConfig="@xml/network_security_config" ... />
```

- Cleartext is blocked by default on Android 9+ (API 28+). Do not re-enable it for
  production domains.
- Without a backup pin and `expiration`, pins lock you out on key rotation.
- Do not bypass validation with a custom `TrustManager`/`HostnameVerifier`.

## 4. Android Keystore

```kotlin
// Signing-key generation + user-authentication binding
val spec = KeyGenParameterSpec.Builder(
    "signing_key",
    KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
)
    .setDigests(KeyProperties.DIGEST_SHA256)
    .setUserAuthenticationParameters(          // replaces the old setUserAuthenticationRequired
        0,                                     // 0 = authenticate per operation
        KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
    )
    .apply {
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)) {
            setIsStrongBoxBacked(true)
        }
    }
    .build()

KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
    .apply { initialize(spec) }
    .generateKeyPair()
```

- When using an auth-bound key, use `BiometricPrompt.authenticate(cryptoObject, ...)`.
- Authorizations such as purpose/digest/padding are fixed at creation and
  immutable afterward — do not open them up broadly.
- For hardware attestation, use key attestation via `setAttestationChallenge(...)`.

## 5. Play Integrity

- Verify integrity tokens **on the server only**. No client-side verdict.
- New integrations use Standard requests (`StandardIntegrityManager` +
  `StandardIntegrityTokenRequest`). Classic (`IntegrityManager`) is legacy.
- Include a replay-prevention nonce in the request and verify on the server that
  it matches the request.
- Call at sensitive moments such as login and payment.

```
Client (requestToken) → Play Integrity API → token → Backend (verify + nonce) → verdict
```

## 6. WebView

```kotlin
webView.settings.javaScriptEnabled = false   // turn off unless needed (default)
// addJavascriptInterface is only for trusted content in the APK. Forbidden for web content.
```

- HTTPS only, URL allowlist. On Android 6.0+ use `createWebMessageChannel()` for
  safe communication.

## Full review checklist

- [ ] `android:exported` declared on every activity/service/receiver/provider.
- [ ] Exported entry points validate extras and handle missing/wrong-type/malicious values via fallback (no crash).
- [ ] Deep links validate host/scheme + extras before going through the route contract.
- [ ] Own-app IPC uses a signature permission + `checkCallingPermission()`.
- [ ] Sensitive data in internal storage, SharedPreferences with `MODE_PRIVATE`.
- [ ] No `androidx.security.crypto` (EncryptedSharedPreferences, etc.) — Keystore+Tink/DataStore.
- [ ] Keys in the Android Keystore, `SecureRandom`/AES-256, no custom crypto implementation.
- [ ] No hardcoded secrets/keys, no VCS commits, no `file://` sharing.
- [ ] `network_security_config.xml` present, cleartext blocked, pins with backup + expiration.
- [ ] No custom TrustManager/HostnameVerifier neutralizing validation.
- [ ] Play Integrity token verified on the server, nonce included.
- [ ] WebView: unnecessary JS off, JS interface only for trusted content, HTTPS.
- [ ] The contract (action, extras, result) of each exported entry point recorded in the design document.

## Official references

- Security tips: https://developer.android.com/privacy-and-security/security-tips
- Security best practices: https://developer.android.com/privacy-and-security/security-best-practices
- Data-at-rest security: https://developer.android.com/topic/security/data
- Network security config: https://developer.android.com/privacy-and-security/security-config
- Android Keystore: https://developer.android.com/training/articles/keystore
- Play Integrity API: https://developer.android.com/google/play/integrity
- `android:exported`: https://developer.android.com/guide/topics/manifest/activity-element#exported
- Team baseline: [../../guidance.md](../../guidance.md)
