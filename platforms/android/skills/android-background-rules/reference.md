# android-background-rules — Detailed Reference

Tables, permissions, and edge cases that back the rules in SKILL.md. For the
rules themselves, see SKILL.md.

## 1. Work classification and API mapping

Android splits background work into three categories.

| Category | Characteristic | Recommended API |
|------|------|----------|
| Asynchronous work | Fine to end once the app leaves its valid lifecycle | Kotlin Coroutines, `ListenableFuture` |
| Task scheduling (persistent) | Must continue after leaving the app | `WorkManager` (recommended), `JobScheduler` |
| Foreground service | Immediate, non-interruptible, user-perceived work | `Service.startForeground()` |

Definition of "running in the background": no activity of the app is visible
and there is no running foreground service.

## 2. WorkManager work types

| Type | Periodicity | Approach |
|------|--------|------|
| Immediate | one-time | `OneTimeWorkRequest` + `Worker`, `setExpedited()` when urgent |
| Long Running | one-time / periodic | any `WorkRequest`, `setForeground()` when a notification is needed |
| Deferrable | one-time / periodic | `PeriodicWorkRequest` + `Worker` |

Key APIs: `Worker`, `CoroutineWorker`, `RxWorker`, `ListenableWorker`,
`OneTimeWorkRequest`, `PeriodicWorkRequest`, `Constraints`,
`WorkManager.getInstance(context).enqueue(...)`, `beginUniqueWork(...).then(...)`.

- Constraints: unmetered network, charging, device idle, sufficient battery, etc.
- Retry: built-in exponential backoff.
- Persists across reboots via internal SQLite and respects Doze.
- Do not use WorkManager for: in-process async that can vanish on app kill
  (→ coroutines), or as a general-purpose immediate-execution catch-all.
- A single task over 10 minutes is likely to be interrupted — split into sub-tasks.

### CoroutineWorker skeleton

```kotlin
class SyncWorker(
    ctx: Context,
    params: WorkerParameters,
) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        return try {
            repository.sync()   // @IoDispatcher lives inside the repository
            Result.success()
        } catch (e: IOException) {
            Result.retry()      // retry with exponential backoff
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

## 3. Foreground service declaration

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<service
    android:name=".TrackingService"
    android:foregroundServiceType="location"
    android:exported="false" />
```

- The `FOREGROUND_SERVICE` permission is required for every FGS. Each type adds a
  further permission (`FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_CAMERA`,
  `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_DATA_SYNC`, ...).
- If started with `startForegroundService(Intent)`, you must call
  `startForeground(int, Notification)` within 5 seconds. Otherwise ANR + the
  service is stopped.
- Android 12+: the notification can be delayed up to 10 seconds before it
  actually shows.
- `shortService`: forces completion within 3 minutes, with lighter per-type
  permission burden.
- Better alternatives to FGS: user-initiated data transfer (large transfers),
  Companion Device Manager (BT), Picture-in-Picture (video), Geofencing
  (location triggers).

## 4. FGS background-start exemptions (Android 12+ / API 31+)

The restriction applies only when **both** the calling app and the target app
target API 31+. Violation throws `ForegroundServiceStartNotAllowedException`.

Exempt cases:

1. Transitioning from a user-visible state (e.g. an activity)
2. A situation that can start an activity from the background
3. High-priority FCM received — verify `RemoteMessage.getPriority()` is `PRIORITY_HIGH`
4. User interaction with a bubble, notification, widget, or activity
5. An exact-alarm call to complete a user request
6. The app is the current device input method
7. Receiving a geofencing / activity-recognition transition event
8. Boot broadcasts: `ACTION_BOOT_COMPLETED`, `ACTION_LOCKED_BOOT_COMPLETED`,
   `ACTION_MY_PACKAGE_REPLACED`
9. System broadcasts: `ACTION_TIMEZONE_CHANGED`, `ACTION_TIME_CHANGED`,
   `ACTION_LOCALE_CHANGED`
10. NFC `ACTION_TRANSACTION_DETECTED`
11. System roles/permissions such as device owner / profile owner
12. Companion Device Manager: declaring `REQUEST_COMPANION_START_FOREGROUND_SERVICES_FROM_BACKGROUND` (recommended)
    or `REQUEST_COMPANION_RUN_IN_BACKGROUND`
13. The user turned off battery optimization
14. Holding `SYSTEM_ALERT_WINDOW` (Android 15+ also requires a visible overlay window)

### Android 14+ while-in-use additional restriction

An FGS that requires a while-in-use permission such as
location/camera/microphone/`BODY_SENSORS` throws a `SecurityException` when
**created** from the background even with the exemptions above. The permission is
checked at service-creation time.

while-in-use exceptions:
1. A system component starts the service
2. Started by app-widget interaction
3. Started by notification interaction
4. Started by another (visible) app's `PendingIntent`
5. Started by a device policy controller (device-owner mode)
6. Started by an app providing a `VoiceInteractionService`
7. Started by an app holding the `START_ACTIVITIES_FROM_BACKGROUND` permission

Additionally: with the `location` type + `ACCESS_BACKGROUND_LOCATION`, continuous
location access is possible even from the background.

Logcat diagnostic:
```
Foreground service started from background can not have
location/camera/microphone access: service SERVICE_NAME
```

## 5. Doze & App Standby

Entering Doze: the device is unplugged, stationary, and the screen has been off
for a long time.

What halts in Doze:
- Network access suspended
- Wakelocks ignored (including `PARTIAL_WAKE_LOCK`)
- `JobScheduler` / `WorkManager` (JobScheduler internally) / sync adapters do not run
- Wi-Fi scans disabled

Alarms that still fire in Doze:
- `setAndAllowWhileIdle(int, long, PendingIntent)`
- `setExactAndAllowWhileIdle(int, long, PendingIntent)`
- `setAlarmClock(AlarmClockInfo, PendingIntent)` (leaves Doze before firing)

The first two are limited to **once per 9 minutes per app**. Plain `setExact()` /
`setWindow()` are delayed until the maintenance window.

Maintenance window: the system periodically leaves Doze briefly to run pending
syncs, jobs, and alarms and grants temporary network. The longer inactivity
lasts, the rarer the windows. Fully released when the user wakes the device,
turns on the screen, or plugs in a charger.

App Standby: if the user does not touch the app, there is no foreground process,
and there is no lock-screen/notification-tray notification, the app is
considered idle. In the idle state (unplugged), network is allowed roughly once
a day. Released while charging.

FCM:
- high-priority: for real-time user-facing notifications. Wakes the app even
  during Doze/Standby and grants temporary network + a partial wakelock. For
  chat, calls, and time-sensitive alerts.
- normal-priority: for background content refresh / data sync. During Doze it is
  delayed until the maintenance window / device wake.

Battery-optimization exemption:
- Check state: `PowerManager.isIgnoringBatteryOptimizations(packageName)`
- `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`: routes to the settings screen (available to most apps)
- `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: a direct prompt, requires the
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission, for allowed use cases only
- Even when exempt, plain alarms still do not fire — you must use the
  `...AllowWhileIdle` family
- Play policy: a direct exemption request is allowed only when a core feature is
  actually broken

Allowed use cases in brief: messengers/VOIP with a technical constraint that
prevents using FCM, safety apps, task-automation apps, always-connected
peripheral companions. Simple real-time messaging can be replaced by
high-priority FCM, so a direct exemption is inappropriate.

### Testing Doze

```bash
adb shell dumpsys deviceidle force-idle     # force enter Doze
adb shell dumpsys deviceidle unforce        # release
adb shell dumpsys battery reset             # reset battery state
adb shell dumpsys battery unplug            # set to unplugged
adb shell am set-inactive <pkg> true        # force App Standby
adb shell am set-inactive <pkg> false
adb shell am get-inactive <pkg>
```

## 6. Android 8.0 (API 26) background execution limits

Conditions considered foreground (any one true): a visible activity, a
foreground service, another foreground app bound to this app's service/provider
(IME, wallpaper service, notification listener, voice/text service). Everything
else is background.

- A background app has only a **several-minute window** to create/use a service;
  when the window ends the service is auto-stopped via `Service.stopSelf()`.
- `startService()` from the background throws `IllegalStateException`. Instead
  use `startForegroundService(Intent)` → `startForeground()` within 5 seconds.
- Temporary allowlist (can start a service without restriction): high-priority
  FCM, SMS/MMS broadcasts, a notification's `PendingIntent`, `VpnService` before
  its foreground promotion.
- `IntentService` is subject to this restriction → replace with `WorkManager`
  (`JobIntentService` from older docs also moves to WorkManager now).
- Manifest implicit broadcast receiver registration is restricted — exceptions
  only for app-specific or signature-permission cases. Runtime `registerReceiver()`
  still works.

## 7. Background location

- `ACCESS_BACKGROUND_LOCATION` is required for background location on API 29+.
- Request order: first obtain foreground (`ACCESS_FINE_LOCATION` or
  `ACCESS_COARSE_LOCATION`) at runtime, then obtain background in a **separate
  request**. They cannot be bundled into one request.
- Manifest:
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
  ```
- On API 26+, background location updates are limited to a few times per hour.
- Under Play policy, remove the permission if background location is not a core
  feature. Approval is not guaranteed even if the policy is followed.
- Continuous tracking: `location` foreground service + `FOREGROUND_SERVICE_LOCATION` +
  `ACCESS_BACKGROUND_LOCATION`.

## 8. Migration summary

| Old | Replacement |
|------|------|
| Background `Service` / `IntentService` | `WorkManager` |
| `FirebaseJobDispatcher`, `GcmNetworkManager` | `WorkManager` (the old ones do not work on Android 6.0+) |
| Manifest implicit broadcast receiver | Runtime `registerReceiver()` |
| Direct wakelock + polling | `WorkManager` constraints / high-priority FCM |

## Sources

- https://developer.android.com/develop/background-work/background-tasks
- https://developer.android.com/develop/background-work/services/foreground-services
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/topic/libraries/architecture/workmanager
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://developer.android.com/about/versions/oreo/background
- https://developer.android.com/develop/sensors-and-location/location/background
