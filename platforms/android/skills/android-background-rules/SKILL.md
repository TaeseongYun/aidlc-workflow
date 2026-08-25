---
name: android-background-rules
description: 안드로이드 백그라운드 작업(background work) 규칙 — WorkManager, 코루틴(coroutines), 포그라운드 서비스(foreground service), Doze/App Standby, 백그라운드 위치(background location)를 다룰 때 적용. Worker/Service/AndroidManifest 편집 시 자동 로드되며, 백그라운드 실행 제한·API 선택·권한을 판단할 때 참조한다.
when_to_use: 백그라운드 작업, 백그라운드 실행 제한, 포그라운드 서비스, WorkManager, 주기 작업, 예약 작업, 백그라운드 위치, Doze, 배터리 최적화, background task, foreground service, WorkManager, background location, doze standby 관련 작업
paths: **/*Worker.kt, **/*Service.kt, **/AndroidManifest.xml
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android 백그라운드 작업 규칙

`guidance.md`의 "Background work: WorkManager for deferrable-guaranteed work,
coroutines for in-session work. No Service unless the platform requires it."를
상세 규칙으로 확장한 것. 이 문서가 에이전트 일반 지식을 override 한다.

## 적용 범위

백그라운드에서 실행되는 모든 작업 — 데이터 동기화, 업로드, 주기 작업,
위치 추적, 재생, 알림 트리거. 화면이 살아 있는 동안의 async 처리와,
앱을 떠난 뒤에도 이어져야 하는 지속 작업을 구분해서 다룬다.

## 핵심 규칙 (do / don't)

### API 선택
- 세션 내 async 작업(화면이 살아 있을 때만 의미)은 **코루틴**으로. 앱이
  백그라운드로 가면 끝나도 되는 일이면 여기에 둔다. `WorkManager` 쓰지 마라.
- 앱을 떠나거나 재부팅 후에도 **보장되어야 하는 지연 가능(deferrable) 작업**은
  `WorkManager`. 예: 서버 동기화, 로그/분석 업로드, 사진 업로드.
- `JobScheduler`·`FirebaseJobDispatcher`·`GcmNetworkManager`·`IntentService`를
  직접 쓰지 마라 — `WorkManager`가 대체한다.
- 정확한 시각 트리거(알람/캘린더)만 `AlarmManager`. 그 외에는 쓰지 마라.

### Service / 포그라운드 서비스
- **플랫폼이 강제하지 않으면 `Service`를 만들지 마라.** 대안 API를 먼저 확인:
  대용량 전송은 user-initiated data transfer, Bluetooth는 Companion Device
  Manager, 영상은 Picture-in-Picture, 위치 트리거는 Geofencing.
- 포그라운드 서비스는 **사용자에게 명백히 인지되는 작업**(재생 중 알림, 운동
  기록)에만. 저중요도 작업에 쓰지 마라 — `WorkManager`로.
- 시작하면 `startForeground(id, notification)`로 상태바 알림을 반드시 띄운다.
  Android 12+에서는 알림이 10초 뒤 표시된다 — 짧은 작업에 기대지 마라.
- 매니페스트에 `foregroundServiceType`을 선언하고 `FOREGROUND_SERVICE`
  권한 + 타입별 권한(예: `FOREGROUND_SERVICE_LOCATION`)을 함께 추가한다.
- 3분 이내에 끝나는 작업은 `shortService` 타입으로.

### 백그라운드 시작 제한 (Android 12+ / API 31+)
- 백그라운드 상태의 앱은 포그라운드 서비스를 시작할 수 없다. 위반하면
  `ForegroundServiceStartNotAllowedException`이 던져진다.
- 면제되는 경우(요약): 화면에서 방금 전환, high-priority FCM 수신, 알림·위젯·
  버블 상호작용, exact alarm, geofencing 전환, 부팅 브로드캐스트,
  배터리 최적화 해제, Companion Device Manager 선언. 전체 표는 `reference.md`.
- **Android 14+**: 위치/카메라/마이크/BODY_SENSORS 같은 while-in-use 권한이
  필요한 포그라운드 서비스는 위 면제가 있어도 백그라운드에서 생성하면
  `SecurityException`. (예외: `location` 타입 + `ACCESS_BACKGROUND_LOCATION`)

### Doze & App Standby
- Doze에서는 네트워크·wakelock·`JobScheduler`·`WorkManager`·동기화가 모두
  멈추고 유지보수 창(maintenance window)에서만 실행된다. 즉시 실행을 가정하지 마라.
- 지연 가능 작업은 `WorkManager`에 맡기면 Doze를 알아서 존중한다 — 직접
  wakelock 잡거나 폴링하지 마라.
- 진짜 즉시 처리가 필요한 사용자 대면 이벤트는 **high-priority FCM**으로
  앱을 깨운다. 알림으로 이어지는 메시지에만 high-priority를 쓴다.
- Doze를 뚫어야 하는 정확한 알람만 `setAndAllowWhileIdle()` /
  `setExactAndAllowWhileIdle()` (앱당 9분에 1회 제한). 시계 알람은 `setAlarmClock()`.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`(배터리 최적화 면제)를 습관적으로
  요구하지 마라 — Play 정책상 core 기능이 훼손될 때만 허용된다.

### 백그라운드 위치
- 앱이 백그라운드일 때 위치가 필요하면 `ACCESS_BACKGROUND_LOCATION`
  (API 29+). foreground 위치(`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`)를
  먼저 부여받은 뒤 **별도 단계**로 요청한다 — 한 번에 묶지 마라.
- 백그라운드 위치가 core 기능이 아니면 권한을 아예 넣지 마라(Play 정책).
- 상시 위치 추적은 `location` 포그라운드 서비스 +
  `FOREGROUND_SERVICE_LOCATION` + `ACCESS_BACKGROUND_LOCATION` 조합으로.

## 결정 표

| 상황 | 선택 |
|------|------|
| 화면 살아 있을 때만 의미 있는 async | 코루틴 |
| 앱 떠나도/재부팅 후에도 보장돼야 하는 지연 작업 | `WorkManager` (`OneTime`/`Periodic`) |
| 위 작업 중 긴급하게 곧 실행 | `WorkManager` `setExpedited()` |
| 사용자에게 보이는 즉시·비중단 작업 | 포그라운드 서비스 (+ `foregroundServiceType`) |
| 3분 내 끝나는 짧은 즉시 작업 | 포그라운드 서비스 `shortService` |
| 정확한 시각 트리거 | `AlarmManager` (idle 필요 시 `...AllowWhileIdle`) |
| Doze 중 사용자 대면 즉시 전달 | high-priority FCM |
| 대용량 다운로드/업로드 | user-initiated data transfer (FGS 대신) |

## Refactor / red-flag 신호

- 세션 내 일회성 async에 `WorkManager`를 쓴 곳 → 코루틴으로.
- 플랫폼 요구 없이 `Service`를 새로 만든 코드 → 대안 API 확인.
- 포그라운드 서비스인데 `startForeground()` / 알림이 없는 곳.
- 매니페스트에 `foregroundServiceType`이나 타입별 권한이 빠진 FGS.
- 백그라운드에서 포그라운드 서비스를 조건 없이 시작하는 호출
  (`ForegroundServiceStartNotAllowedException` 위험).
- foreground 권한 없이, 혹은 같은 요청에 묶어서 `ACCESS_BACKGROUND_LOCATION`을 요청.
- Doze를 무시하려 직접 wakelock을 잡거나 폴링 루프를 도는 코드.
- core 기능 근거 없이 `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`를 요구.
- 10분 넘는 단일 `WorkManager` 작업 (중단 위험 — 잘게 쪼갤 것).

## References

- 백그라운드 작업 개요: https://developer.android.com/develop/background-work/background-tasks
- 포그라운드 서비스: https://developer.android.com/develop/background-work/services/foreground-services
- FGS 백그라운드 시작 제한: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
  (기존 `.../fgs/launch-restrictions` 는 404 — 이 URL로 대체됨)
- WorkManager: https://developer.android.com/topic/libraries/architecture/workmanager
- Doze & App Standby: https://developer.android.com/training/monitoring-device-state/doze-standby
- Android 8.0 백그라운드 실행 제한: https://developer.android.com/about/versions/oreo/background
- 백그라운드 위치: https://developer.android.com/develop/sensors-and-location/location/background
- 팀 Android 베이스라인: [../../guidance.md](../../guidance.md)
- 상세 규칙·표·엣지 케이스: [reference.md](reference.md)
