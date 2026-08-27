# kmp-security — Reference

Deep-dive material for `SKILL.md`. **Vulnerable (❌) vs safe (✅)** code samples per
failure mode. Kotlin/KMP, with platform-manifest notes. Decision criteria live in `SKILL.md`.

## Why this guard is needed (evidence)

- A large share of AI-generated code contains security flaws (multiple empirical studies).
- AI-assisted commits leak secrets more often than human-only commits.
- Developers **overtrust** AI code, believing it safer than it is.
- Mobile twist: the compiled KMP app binary ships to the device — **anything embedded is
  extractable** (keys, endpoints, logic). The price of AI speed is a review gate;
  this guard is that gate.

## 1. Hardcoded secrets in the bundle

```kotlin
// ❌ Compiled into the app → extractable by anyone with the APK/IPA
private const val STRIPE_SECRET = "sk_live_abcd1234"

suspend fun charge(order: Order) {
    client.post("https://api.stripe.com/v1/charges") {
        header("Authorization", "Bearer $STRIPE_SECRET") // NEVER
    }
}

// ❌ buildConfigField leaks secret into BuildConfig.java — still in the binary
// build.gradle.kts
buildConfigField("String", "API_KEY", "\"sk_live_abcd1234\"")

// ✅ Privileged calls go through YOUR backend; the app holds no third-party secret
suspend fun charge(order: Order) {
    client.post("$backendBaseUrl/api/charge") {
        setBody(ChargeRequest(orderId = order.id)) // server holds the Stripe secret
    }
}

// Non-secret build config (still readable — non-secrets only)
// build.gradle.kts
buildConfigField("String", "API_BASE_URL", "\"https://api.example.com\"")
```

- `.env` in `.gitignore`; a committed secret is leaked → rotate immediately. ProGuard/R8
  obfuscation raises the bar but does **not** make an embedded secret safe.

## 2. Insecure local storage

```kotlin
// ❌ SharedPreferences is cleartext — not for tokens
val prefs = context.getSharedPreferences("auth", Context.MODE_PRIVATE)
prefs.edit().putString("auth_token", jwt).apply()

// ❌ DataStore (unencrypted) — same problem
dataStore.edit { it[AUTH_TOKEN_KEY] = jwt }

// ✅ expect/actual secure storage — EncryptedSharedPreferences (Android) / Keychain (iOS)

// commonMain
expect class SecureStorage {
    fun write(key: String, value: String)
    fun read(key: String): String?
    fun delete(key: String)
}

// androidMain
actual class SecureStorage(private val context: Context) {
    private val prefs = EncryptedSharedPreferences.create(
        context, "secure_prefs",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )
    actual fun write(key: String, value: String) { prefs.edit().putString(key, value).apply() }
    actual fun read(key: String): String? = prefs.getString(key, null)
    actual fun delete(key: String) { prefs.edit().remove(key).apply() }
}

// iosMain
actual class SecureStorage {
    actual fun write(key: String, value: String) { KeychainHelper.set(key, value) }
    actual fun read(key: String): String? = KeychainHelper.get(key)
    actual fun delete(key: String) { KeychainHelper.delete(key) }
}
```

- Non-sensitive prefs (theme, last tab) in plain `SharedPreferences` / `DataStore` are fine.
  Tokens, refresh tokens, credentials, PII are not.

## 3. Insecure networking / TLS bypass

```kotlin
// ❌ Trust-all TrustManager "to fix an SSL error" — defeats TLS entirely
val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
    override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
    override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {} // NEVER empty
    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
})
val sslContext = SSLContext.getInstance("SSL").apply { init(null, trustAllCerts, SecureRandom()) }

// ❌ Hostname verifier that trusts everything
val client = HttpClient(Android) {
    engine {
        sslManager = { conn ->
            conn.hostnameVerifier = HostnameVerifier { _, _ -> true } // NEVER
            conn.sslSocketFactory = sslContext.socketFactory
        }
    }
}

// ✅ HTTPS + platform trust store (default). Pin only if you maintain the pins.
val client = HttpClient(CIO) {
    defaultRequest {
        url("https://api.example.com") // https only; no cert override
    }
    install(ContentNegotiation) { json() }
}
```

## 4. Unsafe kotlinx.serialization defaults

```kotlin
// ❌ isLenient = true accepts malformed/injected JSON — production footgun
val json = Json { isLenient = true }

// ❌ Deserializing untrusted user-controlled input with no field validation
@Serializable data class RedirectConfig(val next: String) // unvalidated URL

val config = json.decodeFromString<RedirectConfig>(userInput)
// 'next' could be "javascript:..." or "https://evil.com"

// ✅ Explicit, deliberate Json config; validate deserialized values before use
val json = Json {
    ignoreUnknownKeys = true  // explicit — safe for forward-compatible APIs
    // isLenient NOT set → defaults to false (strict)
}

@Serializable data class RedirectConfig(val next: String)

val config = json.decodeFromString<RedirectConfig>(serverPayload)
// Validate before use:
val target = Uri.parse(config.next)
require(target.host == "app.example.com") { "Invalid redirect host" }
```

## 5. SQL injection in SQLDelight

```kotlin
// ❌ String interpolation into raw SQL
sqlDriver.execute(null, "SELECT * FROM user WHERE name = '$name'", 0)

// ❌ Stepping outside the generated Queries API
val cursor = sqlDriver.executeQuery(
    null,
    "SELECT * FROM session WHERE token = '${userInput}'", // injection
    mapper = { it },
    parameters = 0,
)

// ✅ Named parameters in .sq files — SQLDelight generates safe query methods
// user.sq:
// selectByName:
// SELECT * FROM user WHERE name = :name;

// Generated usage in Kotlin:
val user = queries.selectByName(name = userSuppliedName).executeAsOneOrNull()
// SQLDelight binds :name as a parameter — never interpolated into the SQL string
```

## 6. Kermit / Napier log leakage

```kotlin
// ❌ Logging JWT, full user object, or raw response body
suspend fun login(email: String, password: String) {
    val resp = api.login(email, password)
    Napier.d("login response: ${resp.body}")   // full body may contain token
    Napier.i("user: ${resp.user}")             // email, phone, address...
    Logger.d("token=${resp.token}")            // JWT in plain log
}

// ✅ Log only non-sensitive IDs; redact everything else
suspend fun login(email: String, password: String) {
    Napier.i("login.start")                    // no email
    val resp = api.login(email, password)
    Napier.i("login.success userId=${resp.user.id}") // id only
    // token never logged; stored via SecureStorage (see kmp-security rule 2)
}
```

## 7. Weak crypto / randomness

```kotlin
// ❌ kotlin.random.Random is NOT cryptographic; MD5/SHA1 for security; home-rolled XOR
import kotlin.random.Random
val token = Random.nextInt().toString()            // NOT secure

val digest = MessageDigest.getInstance("MD5")      // broken for security
val hash = digest.digest(password.encodeToByteArray())

// ❌ AES in ECB mode — deterministic, leaks patterns
val cipher = Cipher.getInstance("AES/ECB/PKCS5Padding") // NEVER for security

// ✅ SecureRandom for tokens/salts/IVs; SHA-256+ for integrity; AES-GCM via javax.crypto
import java.security.SecureRandom
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

val secureRandom = SecureRandom()
val tokenBytes = ByteArray(32).also { secureRandom.nextBytes(it) }
val token = Base64.encodeToString(tokenBytes, Base64.URL_SAFE or Base64.NO_WRAP)

// AES-GCM: random IV per encryption, never reuse
val iv = ByteArray(12).also { secureRandom.nextBytes(it) }
val cipher = Cipher.getInstance("AES/GCM/NoPadding")
cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(keyBytes, "AES"), GCMParameterSpec(128, iv))
val ciphertext = cipher.doFinal(plaintext)
```

## 8. Deep-link / expect-actual input validation

```kotlin
// ❌ Deep-link path parameter mapped straight to a repository call — no validation
// In navigation setup (Compose Navigation):
composable("profile/{userId}") { backStackEntry ->
    val userId = backStackEntry.arguments?.getString("userId") ?: return@composable
    ProfileScreen(userId = userId)  // userId is untrusted input from a deep link
}

// ❌ Intent extra passed directly to a query
val orderId = intent.getStringExtra("order_id") ?: ""
val order = queries.selectById(orderId).executeAsOneOrNull() // no validation

// ✅ Validate and type-check before use; allowlist redirect targets
composable("profile/{userId}") { backStackEntry ->
    val rawId = backStackEntry.arguments?.getString("userId") ?: return@composable
    val userId = rawId.toLongOrNull()?.takeIf { it > 0 }
        ?: run { navController.navigate("error"); return@composable }
    ProfileScreen(userId = userId) // Long — validated
}

// ✅ actual return value validated in commonMain before use
// commonMain
expect fun getRedirectUrl(): String

// commonMain call site:
val redirectUrl = getRedirectUrl()
val host = Uri.parse(redirectUrl).host
require(host == "app.example.com") { "Untrusted redirect host: $host" }
```

## 9. Insecure platform config

```xml
<!-- ❌ AndroidManifest.xml -->
<application
    android:allowBackup="true"
    android:usesCleartextTraffic="true">
    <activity android:name=".InternalActivity" android:exported="true" />  <!-- unintended -->
</application>

<!-- ✅ No cleartext; allowBackup false (or exclude secure storage); exported set intentionally -->
<application
    android:allowBackup="false"
    android:usesCleartextTraffic="false"
    android:networkSecurityConfig="@xml/network_security_config">
    <activity android:name=".InternalActivity" android:exported="false" />
    <activity android:name=".MainActivity" android:exported="true">
        <intent-filter><action android:name="android.intent.action.MAIN" /></intent-filter>
    </activity>
</application>
```

```xml
<!-- ❌ ios/Runner/Info.plist — App Transport Security fully disabled -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><true/>
</dict>

<!-- ✅ Keep ATS on; add narrow, justified per-domain exceptions only if unavoidable -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><false/>
</dict>
```

## 10. Vulnerable / hallucinated Gradle dependencies (slopsquatting)

```
- Verify an AI-suggested Maven/Gradle artifact actually exists and is legitimate
  (group ID, artifact ID, Maven Central presence, recent activity, download count).
  Typo-similar · brand-new · negligible downloads → suspect slopsquatting, do not add.

- Use libs.versions.toml for centralized version pinning:
  [libraries]
  ktor-client-core = { module = "io.ktor:ktor-client-core", version.ref = "ktor" }
  # Never: implementation("io.ktor:ktor-client-core:+")

- Commit gradle.lockfile for reproducible builds.
- Gate on advisories: ./gradlew dependencyCheckAnalyze (OWASP DependencyCheck) or
  review the OSV database at https://osv.dev/ for the artifact.
- Review the Android permissions a transitive dependency pulls in:
  ./gradlew :app:dependencies | grep -i "permission"
```

## Full vibe-guard review checklist

- [ ] No secrets in Kotlin / `buildConfigField` / committed `.env`; privileged calls proxied server-side.
- [ ] Tokens/PII behind `expect`/`actual` secure storage (EncryptedSharedPreferences / Keychain).
- [ ] HTTPS only; no trust-all `TrustManager` / hostname verifier; no `http://` Ktor base URLs.
- [ ] `Json { isLenient = false }` (default) in production; deserialized values validated before use.
- [ ] SQLDelight named parameters (`:param`) everywhere; no string-interpolated SQL.
- [ ] No tokens/passwords/PII in `Napier.*` / `Logger.*` / `Kermit.*` calls.
- [ ] `SecureRandom` for security values; no MD5/SHA1/ECB/fixed-IV/home-rolled crypto.
- [ ] Deep-link / intent / `actual` values validated before routing or repo calls; redirects allowlisted.
- [ ] No cleartext traffic / ATS arbitrary loads / unsafe `allowBackup` / unintended `exported`.
- [ ] Deps real · legitimate · maintained · version-pinned in `libs.versions.toml` · advisory-free.

## Official references

- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS: https://mas.owasp.org/MASVS/
- OWASP MASTG: https://mas.owasp.org/MASTG/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- CWE Top 25: https://cwe.mitre.org/top25/
- Android security best practices: https://developer.android.com/topic/security/best-practices
- EncryptedSharedPreferences: https://developer.android.com/reference/androidx/security/crypto/EncryptedSharedPreferences
- Team baseline: [../../guidance.md](../../guidance.md)
