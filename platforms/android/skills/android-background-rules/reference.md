# android-background-rules — 상세 참조

SKILL.md의 규칙을 뒷받침하는 표·권한·엣지 케이스. 규칙 자체는 SKILL.md를 본다.

## 1. 작업 분류와 API 매핑

Android는 백그라운드 작업을 세 부류로 나눈다.

| 분류 | 특징 | 권장 API |
|------|------|----------|
| Asynchronous work | 앱이 유효 lifecycle을 벗어나면 끝나도 됨 | Kotlin Coroutines, `ListenableFuture` |
| Task scheduling (persistent) | 앱을 떠난 뒤에도 이어져야 함 | `WorkManager` (권장), `JobScheduler` |
| Foreground service | 즉시·비중단·사용자 인지 작업 | `Service.startForeground()` |

"백그라운드 실행 중"의 정의: 앱의 어떤 activity도 보이지 않고, 실행 중인
포그라운드 서비스도 없는 상태.

## 2. WorkManager 작업 타입

| 타입 | 주기성 | 접근 |
|------|--------|------|
| Immediate | one-time | `OneTimeWorkRequest` + `Worker`, 긴급 시 `setExpedited()` |
| Long Running | one-time / periodic | 임의 `WorkRequest`, 알림 필요 시 `setForeground()` |
| Deferrable | one-time / periodic | `PeriodicWorkRequest` + `Worker` |

주요 API: `Worker`, `CoroutineWorker`, `RxWorker`, `ListenableWorker`,
`OneTimeWorkRequest`, `PeriodicWorkRequest`, `Constraints`,
`WorkManager.getInstance(context).enqueue(...)`, `beginUniqueWork(...).then(...)`.

- 제약(Constraints): unmetered 네트워크, 충전 중, 기기 idle, 배터리 충분 등.
- 재시도: 지수 백오프(exponential backoff) 내장.
- 재부팅 후에도 내부 SQLite로 유지되며 Doze를 존중.
- WorkManager로 하지 말 것: 앱 종료 시 사라져도 되는 in-process async(→ 코루틴),
  단순 즉시 실행 범용 해법으로 남용.
- 단일 작업이 10분을 넘으면 중단될 확률이 높다 — sub-task로 분할.

### CoroutineWorker 골격

```kotlin
class SyncWorker(
    ctx: Context,
    params: WorkerParameters,
) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        return try {
            repository.sync()   // @IoDispatcher는 repository 안에서
            Result.success()
        } catch (e: IOException) {
            Result.retry()      // 지수 백오프로 재시도
        }
    }
}
```

```kotlin
val request = OneTimeWorkRequestBuilder<SyncWorker>()
    .setConstraints(
        Constraints.Builder()
            .setRequiredNetworkType(NetworkType.UNMETERED)
            .build()
    )
    .build()
WorkManager.getInstance(context).enqueue(request)
```

## 3. 포그라운드 서비스 선언

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<service
    android:name=".TrackingService"
    android:foregroundServiceType="location"
    android:exported="false" />
```

- 모든 FGS에 `FOREGROUND_SERVICE` 권한 필수. 타입별로 추가 권한이 붙는다
  (`FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_CAMERA`,
  `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_DATA_SYNC`, ...).
- `startForegroundService(Intent)`로 시작하면 5초 안에
  `startForeground(int, Notification)`을 호출해야 한다. 안 하면 ANR + 서비스 중지.
- Android 12+: 알림이 실제 표시까지 10초 지연될 수 있음.
- `shortService`: 3분 내 완료 강제, 타입별 권한 부담이 적음.
- FGS보다 나은 대안: user-initiated data transfer(대용량 전송), Companion
  Device Manager(BT), Picture-in-Picture(영상), Geofencing(위치 트리거).

## 4. FGS 백그라운드 시작 면제 (Android 12+ / API 31+)

호출 앱과 대상 앱이 **둘 다** API 31+를 타깃할 때만 제한이 적용된다.
위반 시 `ForegroundServiceStartNotAllowedException`.

면제되는 경우:

1. 사용자에게 보이는 상태(예: activity)에서 전환
2. 백그라운드에서 activity를 시작할 수 있는 상황
3. high-priority FCM 수신 — `RemoteMessage.getPriority()`가 `PRIORITY_HIGH`인지 검증
4. 버블·알림·위젯·activity와의 사용자 상호작용
5. 사용자 요청 완료를 위한 exact alarm 호출
6. 앱이 현재 기기의 입력기(input method)
7. geofencing / activity recognition 전환 이벤트 수신
8. 부팅 브로드캐스트: `ACTION_BOOT_COMPLETED`, `ACTION_LOCKED_BOOT_COMPLETED`,
   `ACTION_MY_PACKAGE_REPLACED`
9. 시스템 브로드캐스트: `ACTION_TIMEZONE_CHANGED`, `ACTION_TIME_CHANGED`,
   `ACTION_LOCALE_CHANGED`
10. NFC `ACTION_TRANSACTION_DETECTED`
11. 디바이스 오너/프로파일 오너 등 시스템 롤·권한
12. Companion Device Manager: `REQUEST_COMPANION_START_FOREGROUND_SERVICES_FROM_BACKGROUND`(권장)
    또는 `REQUEST_COMPANION_RUN_IN_BACKGROUND` 선언
13. 사용자가 배터리 최적화를 끔
14. `SYSTEM_ALERT_WINDOW` 보유 (Android 15+는 표시 중인 오버레이 창도 필요)

### Android 14+ while-in-use 추가 제한

위치·카메라·마이크·`BODY_SENSORS`처럼 while-in-use 권한이 필요한 FGS는
위 면제가 있어도 백그라운드에서 **생성**하면 `SecurityException`. 권한은
서비스 생성 시점에 검사된다.

while-in-use 예외:
1. 시스템 컴포넌트가 서비스 시작
2. 앱 위젯 상호작용으로 시작
3. 알림 상호작용으로 시작
4. 다른(표시 중인) 앱의 `PendingIntent`로 시작
5. device policy controller(디바이스 오너 모드)가 시작
6. `VoiceInteractionService` 제공 앱이 시작
7. `START_ACTIVITIES_FROM_BACKGROUND` 권한 앱이 시작

추가: `location` 타입 + `ACCESS_BACKGROUND_LOCATION` 보유 시 백그라운드에서도
상시 위치 접근 가능.

Logcat 진단:
```
Foreground service started from background can not have
location/camera/microphone access: service SERVICE_NAME
```

## 5. Doze & App Standby

Doze 진입: 기기가 뽑혀 있고, 정지 상태이고, 화면이 오랫동안 꺼짐.

Doze에서 멈추는 것:
- 네트워크 접근 정지
- wakelock 무시 (`PARTIAL_WAKE_LOCK` 포함)
- `JobScheduler` / `WorkManager`(내부적으로 JobScheduler) / 동기화 어댑터 미실행
- Wi-Fi 스캔 비활성

Doze에서도 발화하는 알람:
- `setAndAllowWhileIdle(int, long, PendingIntent)`
- `setExactAndAllowWhileIdle(int, long, PendingIntent)`
- `setAlarmClock(AlarmClockInfo, PendingIntent)` (발화 전 Doze 해제)

앞 둘은 **앱당 9분에 1회** 제한. 일반 `setExact()` / `setWindow()`는 유지보수
창까지 지연된다.

유지보수 창(maintenance window): 시스템이 주기적으로 잠깐 Doze를 빠져나와 밀린
동기화·잡·알람을 실행하고 임시 네트워크를 준다. 비활성이 길어질수록 창은
드물어진다. 사용자가 깨우거나 화면을 켜거나 충전기를 꽂으면 완전 해제.

App Standby: 사용자가 앱을 안 건드리고, 포그라운드 프로세스도 없고, 락스크린/
알림 트레이 알림도 없으면 idle로 간주. idle 상태(뽑힘)에서는 대략 하루에 한 번
정도 네트워크가 허용된다. 충전 중에는 해제.

FCM:
- high-priority: 실시간 사용자 대면 알림용. Doze/Standby 중에도 앱을 깨우고
  임시 네트워크 + partial wakelock을 준다. 채팅·통화·시간 민감 알림에.
- normal-priority: 배경 콘텐츠 갱신·데이터 동기화용. Doze 중이면 유지보수
  창/기기 깨어남까지 지연.

배터리 최적화 면제:
- 상태 확인: `PowerManager.isIgnoringBatteryOptimizations(packageName)`
- `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`: 설정 화면으로 유도(대부분 앱 가능)
- `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: 직접 프롬프트,
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 권한 필요, 허용 use case에만
- 면제되어도 일반 알람은 여전히 미발화 — `...AllowWhileIdle` 계열을 써야 함
- Play 정책: core 기능이 실제로 훼손될 때만 직접 면제 요청 허용

허용 use case 요지: FCM을 쓸 수 없는 기술적 제약이 있는 메신저/VOIP, 안전 앱,
작업 자동화 앱, 상시 연결이 필요한 주변기기 컴패니언. 단순 실시간 메시징은
high-priority FCM으로 대체 가능하므로 직접 면제는 부적합.

### Doze 테스트

```bash
adb shell dumpsys deviceidle force-idle     # Doze 강제 진입
adb shell dumpsys deviceidle unforce        # 해제
adb shell dumpsys battery reset             # 배터리 상태 리셋
adb shell dumpsys battery unplug            # 뽑힌 상태로
adb shell am set-inactive <pkg> true        # App Standby 강제
adb shell am set-inactive <pkg> false
adb shell am get-inactive <pkg>
```

## 6. Android 8.0 (API 26) 백그라운드 실행 제한

포그라운드로 간주되는 조건(하나라도 참): 보이는 activity, 포그라운드 서비스,
다른 포그라운드 앱이 이 앱의 서비스/프로바이더에 바인딩(IME, 배경화면 서비스,
알림 리스너, 음성/텍스트 서비스). 그 외는 백그라운드.

- 백그라운드 앱은 서비스 생성/사용에 **수 분(several-minute) 창**만 있고, 창이
  끝나면 `Service.stopSelf()`로 자동 중지.
- 백그라운드에서 `startService()`는 `IllegalStateException`.
  대신 `startForegroundService(Intent)` → 5초 내 `startForeground()`.
- 임시 allowlist(제한 없이 서비스 시작 가능): high-priority FCM, SMS/MMS
  브로드캐스트, 알림의 `PendingIntent`, foreground 승격 전 `VpnService`.
- `IntentService`는 이 제한을 받는다 → `WorkManager`로 대체(구식 문서의
  `JobIntentService`도 이제 WorkManager로).
- 매니페스트 암시적(implicit) 브로드캐스트 리시버 등록 제한 — 앱 전용이거나
  signature 권한인 경우만 예외. 런타임 `registerReceiver()`는 여전히 동작.

## 7. 백그라운드 위치

- `ACCESS_BACKGROUND_LOCATION`은 API 29+에서 백그라운드 위치에 필요.
- 요청 순서: foreground(`ACCESS_FINE_LOCATION` 또는 `ACCESS_COARSE_LOCATION`)를
  먼저 런타임에 받고, 그 다음 **별도 요청**으로 background를 받는다. 한 요청에
  묶을 수 없다.
- 매니페스트:
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
  ```
- API 26+에서는 백그라운드 위치 업데이트가 시간당 몇 회로 제한.
- Play 정책상 백그라운드 위치가 core 기능이 아니면 권한을 제거할 것. 승인은
  정책을 지켜도 보장되지 않는다.
- 상시 추적: `location` 포그라운드 서비스 + `FOREGROUND_SERVICE_LOCATION` +
  `ACCESS_BACKGROUND_LOCATION`.

## 8. 마이그레이션 요약

| 구식 | 대체 |
|------|------|
| 백그라운드 `Service` / `IntentService` | `WorkManager` |
| `FirebaseJobDispatcher`, `GcmNetworkManager` | `WorkManager` (Android 6.0+에서 구식은 동작 안 함) |
| 매니페스트 암시적 브로드캐스트 리시버 | 런타임 `registerReceiver()` |
| 직접 wakelock + 폴링 | `WorkManager` 제약 / high-priority FCM |

## 출처

- https://developer.android.com/develop/background-work/background-tasks
- https://developer.android.com/develop/background-work/services/foreground-services
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/topic/libraries/architecture/workmanager
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://developer.android.com/about/versions/oreo/background
- https://developer.android.com/develop/sensors-and-location/location/background
