# Android Security — Reference

`SKILL.md`의 심화 자료. 코드 샘플·매니페스트/XML 예시·상세 체크리스트.
규칙 요약과 판단 기준은 `SKILL.md`를 본다.

## 1. Exported 컴포넌트 & Intent/extras 검증

### 매니페스트: export 명시

```xml
<!-- feature 진입점: contract 이면 명시적으로 exported="true" -->
<activity
    android:name=".DetailActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="com.example.action.OPEN_DETAIL" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</activity>

<!-- 내부 전용: intent-filter 없어도 명시 -->
<activity android:name=".InternalActivity" android:exported="false" />

<!-- Provider 는 기본 false, 필요한 접근만 권한으로 -->
<provider
    android:name=".MyProvider"
    android:authorities="com.example.provider"
    android:exported="false" />
```

- targetSdk 31+ (Android 12): intent-filter가 있는 activity/service/receiver는
  `android:exported`를 **반드시** 선언해야 한다. 없으면 설치/빌드 실패.
- intent-filter 없으면 기본 `false`. 있으면 다른 앱이 시작하려면 `true`를 명시해야 한다.

### extras 검증 — 신뢰 경계 패턴

들어온 값을 신뢰하지 않는다. 없거나·타입이 틀리거나·악의적이면 **정의된 fallback**으로.

```kotlin
// Activity.onCreate: exported 진입점
private data class DetailArgs(val itemId: Long, val source: Source)

private fun parseArgs(intent: Intent): DetailArgs? {
    val id = intent.getLongExtra(EXTRA_ITEM_ID, -1L)
    if (id <= 0L) return null                       // 없음/잘못된 타입 기본값 → 거부
    val raw = intent.getStringExtra(EXTRA_SOURCE)
    val source = Source.entries.firstOrNull { it.key == raw }
        ?: return null                              // 화이트리스트 밖 → 거부
    return DetailArgs(id, source)
}

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val args = parseArgs(intent) ?: run {
        routeToFallback()                            // 크래시 금지, 조용한 권한 상승 금지
        finish()
        return
    }
    // args 는 이제 검증됨 → route 계약으로
}
```

### 딥링크 검증 순서

Activity가 Intent 수신 → host/scheme 검증 → extras 검증 → feature route 계약 →
back stack 구성 → Compose 진입. 검증 안 된 URI를 라우트에 바로 넣지 않는다.

```kotlin
private val ALLOWED_HOSTS = setOf("example.com", "app.example.com")

private fun routeFromDeepLink(uri: Uri): Route? {
    if (uri.scheme != "https") return null           // scheme 검증
    if (uri.host !in ALLOWED_HOSTS) return null       // host 화이트리스트
    val id = uri.getQueryParameter("id")?.toLongOrNull()
        ?: return null                                // extras 검증
    return Route.Detail(id)                           // 검증된 값만 route 계약으로
}
```

### 자체 앱 간 IPC — signature 권한 + 호출자 확인

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
// Binder/Messenger 내부: 민감 작업 전 호출자 권한 확인
if (checkCallingPermission("com.example.permission.PRIVATE_IPC")
    != PackageManager.PERMISSION_GRANTED) {
    throw SecurityException("caller lacks permission")
}
```

## 2. 데이터 저장 (data at rest)

### Jetpack Security 는 deprecated

`androidx.security:security-crypto` (EncryptedSharedPreferences, EncryptedFile,
MasterKey)는 deprecated다. 신규 코드에서 사용하지 않는다.

권장 대안:

- 대부분의 민감 데이터: 내부 저장소(`MODE_PRIVATE`)만으로 앱 샌드박스 격리가 충분.
- 추가 암호화가 필요하면: **Android Keystore**로 키를 관리하고 **Tink**로 데이터 암호화.
- 설정/키-값: **DataStore** (SharedPreferences 대체).
- 비밀번호 대신 수명이 짧은 토큰. 키는 앱 메모리로 꺼내지 않는다.

```kotlin
// Keystore 키로 직접 AES-GCM (Tink 미사용 시 최소 예시)
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
val key = keyGen.generateKey()   // 키는 Keystore 에 머무름
```

## 3. 네트워크 보안 구성

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
            <!-- 백업 핀 필수 -->
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>

    <!-- debug 빌드에서만 신뢰, 릴리즈에는 포함되지 않음 -->
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

- cleartext는 Android 9+(API 28+) 기본 차단. 프로덕션 도메인에 다시 켜지 않는다.
- 핀은 백업 핀과 `expiration`이 없으면 키 로테이션 시 접속 불능이 된다.
- 커스텀 `TrustManager`/`HostnameVerifier`로 검증을 우회하지 않는다.

## 4. Android Keystore

```kotlin
// 서명 키 생성 + 사용자 인증 바인딩
val spec = KeyGenParameterSpec.Builder(
    "signing_key",
    KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
)
    .setDigests(KeyProperties.DIGEST_SHA256)
    .setUserAuthenticationParameters(          // 구 setUserAuthenticationRequired 대체
        0,                                     // 0 = 작업마다 인증
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

- 인증이 걸린 키를 쓸 때는 `BiometricPrompt.authenticate(cryptoObject, ...)`.
- purpose/digest/padding 등 authorization은 생성 시 정해지고 이후 불변 — 넓게 열지 않는다.
- 하드웨어 보증이 필요하면 `setAttestationChallenge(...)`로 key attestation.

## 5. Play Integrity

- 무결성 토큰은 **서버에서만 검증**한다. 클라이언트 판정 금지.
- 신규 통합은 Standard 요청(`StandardIntegrityManager` + `StandardIntegrityTokenRequest`).
  Classic(`IntegrityManager`)은 레거시.
- 재생 공격 방지 nonce를 요청에 포함하고 서버에서 요청과 일치하는지 검증.
- 로그인·결제 등 민감 시점에 호출.

```
Client (requestToken) → Play Integrity API → token → Backend (verify + nonce) → verdict
```

## 6. WebView

```kotlin
webView.settings.javaScriptEnabled = false   // 필요 없으면 끈다(기본값)
// addJavascriptInterface 는 APK 내 신뢰 콘텐츠에만. 웹 콘텐츠에는 금지.
```

- HTTPS만 로드, URL allowlist. Android 6.0+는 `createWebMessageChannel()`로 안전 통신.

## 전체 리뷰 체크리스트

- [ ] 모든 activity/service/receiver/provider에 `android:exported` 명시.
- [ ] exported 진입점이 extras를 검증하고 없음/오타입/악성값을 fallback으로 처리(크래시 없음).
- [ ] 딥링크가 host/scheme + extras를 검증한 뒤 route 계약을 거친다.
- [ ] 자체 앱 IPC는 signature 권한 + `checkCallingPermission()`.
- [ ] 민감 데이터는 내부 저장소, SharedPreferences는 `MODE_PRIVATE`.
- [ ] `androidx.security.crypto`(EncryptedSharedPreferences 등) 미사용 — Keystore+Tink/DataStore.
- [ ] 키는 Android Keystore, `SecureRandom`/AES-256, 자체 암호 구현 없음.
- [ ] 하드코딩 비밀/키 없음, VCS 커밋 없음, `file://` 공유 없음.
- [ ] `network_security_config.xml` 존재, cleartext 차단, 핀에 백업+expiration.
- [ ] 커스텀 TrustManager/HostnameVerifier로 검증 무력화 없음.
- [ ] Play Integrity 토큰 서버 검증, nonce 포함.
- [ ] WebView: 불필요 JS off, JS interface는 신뢰 콘텐츠만, HTTPS.
- [ ] 각 exported 진입점의 계약(action·extras·result)이 설계 문서에 기록.

## Official references

- Security tips: https://developer.android.com/privacy-and-security/security-tips
- Security best practices: https://developer.android.com/privacy-and-security/security-best-practices
- Data-at-rest security: https://developer.android.com/topic/security/data
- Network security config: https://developer.android.com/privacy-and-security/security-config
- Android Keystore: https://developer.android.com/training/articles/keystore
- Play Integrity API: https://developer.android.com/google/play/integrity
- `android:exported`: https://developer.android.com/guide/topics/manifest/activity-element#exported
- 팀 기준: [../../guidance.md](../../guidance.md)
