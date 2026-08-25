---
name: android-security
description: 안드로이드 보안(Android security) 규칙 — exported 컴포넌트/Intent·extras 검증(exported component & Intent/extras validation), 권한(permissions), 데이터 암호화·저장(data-at-rest encryption), 네트워크 보안 구성(network security config), Android Keystore, Play Integrity를 다룬다. AndroidManifest.xml·network_security_config.xml·*.kt를 작성·리뷰하거나, exported 컴포넌트/딥링크(deep link)의 신뢰 경계(trust boundary)를 설계·검증할 때, 또는 키·비밀·자격증명(key/secret/credential) 저장 방식을 정할 때 사용한다.
when_to_use: exported 컴포넌트를 추가·수정할 때, intent-filter/딥링크 라우팅을 만들 때, extras를 읽는 Activity/Service/Receiver/Provider를 손댈 때, HTTP/cleartext·인증서 핀닝(certificate pinning)을 다룰 때, EncryptedSharedPreferences/Keystore/암호화 코드를 볼 때
paths: **/AndroidManifest.xml, **/network_security_config.xml, **/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android Security

팀 Android 앱의 보안 기준. `../../guidance.md`의 "Intent-first external surface"를 보안 관점에서
확장한 것이다. 여기 규칙은 **안전 규칙(safety rule)** 이며 축소·완화하지 않는다.

## Scope

- 대상: `AndroidManifest.xml`, `network_security_config.xml`, Kotlin 소스.
- 다루는 것: exported 컴포넌트 · Intent/extras 검증, 딥링크, 권한, 데이터 저장 암호화,
  네트워크 보안 구성, Android Keystore, Play Integrity, WebView.
- guidance.md가 상위 기준. 프로젝트 `ctx/`가 이 문서를 override 한다.

## Core Rules

### 신뢰 경계 (exported = trust boundary) — 절대 완화 금지

- **모든 exported 컴포넌트는 신뢰 경계다.** 들어오는 모든 extras와 호출자(caller) 데이터를
  사용 전에 검증한다. 없는 extra · 잘못된 타입 · 악의적 값은 **정의된 fallback**으로 떨어지고,
  절대 크래시나 조용한 권한 상승(silent privilege)으로 이어지지 않는다.
- Activity/Service/Receiver/Provider 모두 `android:exported`를 **명시적으로** 선언한다
  (targetSdk 31+에서 intent-filter가 있으면 필수). intent-filter가 있다고 자동으로
  export 되지 않는다 — export 여부는 설계 시점에 정하고 기술 설계 문서에 기록한다.
- intent-filter는 라우팅 힌트일 뿐 **보안 장치가 아니다.** 필터가 걸렀다고 가정하지 말고
  코드에서 다시 검증한다.
- 딥링크: Activity가 Intent 수신 → host/scheme 검증 → extras 검증 → feature route 계약 →
  back stack 구성 → Compose 진입. 검증 안 된 URI를 라우트에 바로 주입하지 않는다.
- 다른 앱과 공유할 필요가 없으면 `android:exported="false"`. Provider도 기본 false로 두고
  필요한 접근만 허용한다. "나중에 하드닝하려고" false를 임의로 붙이는 것과는 다르다 —
  contract 진입점은 설계 시점에 surface를 명시한다.

### 자체 앱 간 IPC / 권한

- 자체 앱끼리의 IPC는 `android:protectionLevel="signature"` 커스텀 권한으로 보호한다.
- Binder/Messenger는 민감 작업 전에 코드에서 `checkCallingPermission()`으로 호출자 권한을
  확인한다. 외부 프로세스 호출을 대신 수행할 때만 `clearCallingIdentity()`/`restoreCallingIdentity()`.
- 권한은 최소로 요청한다. 가능하면 권한 대신 다른 앱에 인텐트로 위임한다
  (연락처 추가는 `READ_CONTACTS` 대신 `Intent.ACTION_INSERT`).
- 민감 IPC에 localhost/네트워크 소켓 사용 금지, `INADDR_ANY` 바인딩 금지.

### 데이터 저장 (data at rest)

- 민감 데이터는 내부 저장소(`Context.getFilesDir()`, `MODE_PRIVATE`)에만 둔다. 외부 저장소는
  전역 읽기/쓰기 가능하므로 비민감 데이터만. SharedPreferences는 항상 `MODE_PRIVATE`.
- 암호화 키는 **Android Keystore**에 둔다. 키를 앱 메모리로 꺼내지 않는다.
- **EncryptedSharedPreferences / EncryptedFile (Jetpack Security `androidx.security:security-crypto`)는
  deprecated다.** 신규 코드에서 쓰지 말 것. 대체: 내부 저장소 + Android Keystore로 관리하는
  키로 직접 암호화(권장 도구 **Tink**), 설정값은 **DataStore**. 기존 사용처는 마이그레이션 대상.
- 비밀번호/사용자 ID를 기기에 저장하지 않는다 — 수명이 짧은 인증 토큰을 쓴다.
- API 키/비밀을 소스·VCS에 커밋하지 않는다. 자체 암호 알고리즘 구현 금지 — `Cipher`/`KeyGenerator`
  프레임워크 사용, `SecureRandom`으로 초기화, AES 256-bit.
- 파일 공유는 `file://` 금지, `FileProvider`의 `content://` + URI 권한 플래그로.

### 네트워크 보안 구성

- `res/xml/network_security_config.xml`을 두고 매니페스트에 `android:networkSecurityConfig`로 연결.
- cleartext(HTTP)는 기본 차단. 프로덕션 도메인에 `cleartextTrafficPermitted="true"` 금지.
  base-config에 전역으로 켜지 않는다.
- 인증서 핀닝은 `<pin-set>` + SHA-256. **백업 핀 필수**, `expiration` 필수.
- 커스텀 CA는 `<debug-overrides>`에서 debug 빌드만. 릴리즈 빌드에 debug CA·`android:debuggable="true"` 금지.
- 커스텀 `TrustManager`/`HostnameVerifier`로 검증을 무력화하지 않는다.

### Android Keystore / Play Integrity

- 키 생성은 `AndroidKeyStore` provider + `KeyGenParameterSpec`. purpose·digest·padding을 명시해
  용도를 제한한다(생성 후 불변).
- 민감 작업 키는 사용자 인증 바인딩: `setUserAuthenticationParameters(timeout, types)`
  (구 `setUserAuthenticationRequired(true)`는 deprecated). 사용 시 `BiometricPrompt`.
- 가능하면 StrongBox(`FEATURE_STRONGBOX_KEYSTORE` 확인 후 `setIsStrongBoxBacked(true)`),
  하드웨어 보증이 필요하면 key attestation(`setAttestationChallenge`).
- Play Integrity: 무결성 토큰은 **반드시 서버에서 검증**한다(클라이언트 검증 금지). 신규는
  Standard 요청(`StandardIntegrityManager`), 재생 공격 방지 nonce를 요청·서버에서 검증.

### WebView

- 필요 없으면 JavaScript 비활성(기본값 유지). `addJavascriptInterface()`는 APK 내 신뢰 콘텐츠에만.
- 신뢰 URL만 로드(allowlist), HTTPS만. Android 6.0+는 `createWebMessageChannel()`로 통신.

## Exported-component 검증 체크리스트

exported Activity/Service/Receiver/Provider(또는 딥링크)를 손댈 때 순서대로:

| # | 확인 | 실패 시 |
|---|------|---------|
| 1 | `android:exported`가 명시적으로 선언됐는가 | 명시. intent-filter 있으면 export 여부 결정 |
| 2 | 이 컴포넌트가 정말 외부 공개 대상인가 | 아니면 `exported="false"` |
| 3 | 필수 extra가 존재·타입 일치하는가 | 정의된 fallback (크래시 금지) |
| 4 | extra 값이 유효 범위·화이트리스트에 드는가 | 정의된 fallback |
| 5 | 딥링크면 host/scheme를 검증했는가 | 거부 후 fallback |
| 6 | URI/route를 검증 없이 back stack에 넣지 않는가 | 검증 후 route 계약 경유 |
| 7 | 민감 IPC면 호출자 권한을 확인했는가 | `checkCallingPermission()` |
| 8 | 계약(action·extras·result)이 설계 문서에 기록됐는가 | 기록 |

## Refactor / Red-flag 신호

- exported Activity가 extras를 검증 없이 사용 → 신뢰 경계 위반.
- intent-filter가 있는데 `android:exported`가 미선언.
- 검증 안 된 딥링크 URI를 라우트/back stack에 직접 주입.
- `EncryptedSharedPreferences`/`EncryptedFile`/`androidx.security.crypto` import (deprecated).
- 하드코딩된 키·비밀·`file://` 공유, 외부 저장소의 민감 데이터.
- `network_security_config.xml` 부재, cleartext 전역 허용, 백업/expiration 없는 핀.
- 커스텀 `TrustManager`/`HostnameVerifier`가 검증을 무력화.
- Play Integrity 토큰을 클라이언트에서 검증.

## References

- [../../guidance.md](../../guidance.md) — 팀 Android 기준 (Intent-first external surface)
- [reference.md](reference.md) — 코드 샘플 · 매니페스트/XML 예시 · 상세 체크리스트
