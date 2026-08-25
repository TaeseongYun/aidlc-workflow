---
name: android-background-rules
description: Android background-work rules — apply when dealing with WorkManager, coroutines, foreground service, Doze/App Standby, or background location. Auto-loads when editing a Worker/Service/AndroidManifest, and is the reference for deciding background execution limits, API choice, and permissions.
when_to_use: Background work, background execution limits, foreground service, WorkManager, periodic work, scheduled work, background location, Doze, battery optimization, background task, foreground service, WorkManager, background location, doze standby related work
paths: **/*Worker.kt, **/*Service.kt, **/AndroidManifest.xml
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android Background-Work Rules

The detailed-rule expansion of `guidance.md`'s "Background work: WorkManager for
deferrable-guaranteed work, coroutines for in-session work. No Service unless
the platform requires it." This document overrides the agent's general
knowledge.

## Scope

Every task that runs in the background — data sync, uploads, periodic work,
location tracking, playback, notification triggers. Handle async work that runs
while the screen is alive and persistent work that must continue after the user
leaves the app as two separate cases.

## Core rules (do / don't)

### API choice
- Put in-session async work (meaningful only while the screen is alive) on
  **coroutines**. If it is fine for the work to end when the app goes to the
  background, put it here. Do not use `WorkManager`.
- Use `WorkManager` for **deferrable work that must be guaranteed** even after
  leaving the app or after a reboot. Examples: server sync, log/analytics
  upload, photo upload.
- Do not use `JobScheduler`, `FirebaseJobDispatcher`, `GcmNetworkManager`, or
  `IntentService` directly — `WorkManager` replaces them.
- Use `AlarmManager` only for exact-time triggers (alarms/calendar). Do not use
  it otherwise.

### Service / foreground service
- **Do not create a `Service` unless the platform forces it.** Check for an
  alternative API first: user-initiated data transfer for large transfers,
  Companion Device Manager for Bluetooth, Picture-in-Picture for video,
  Geofencing for location triggers.
- Use a foreground service only for **work the user clearly perceives** (a
  now-playing notification, workout tracking). Do not use it for low-importance
  work — use `WorkManager`.
- Once started, you must show a status-bar notification with
  `startForeground(id, notification)`. On Android 12+ the notification appears
  after 10 seconds — do not rely on it for short work.
- Declare `foregroundServiceType` in the manifest and add the
  `FOREGROUND_SERVICE` permission plus the per-type permission (e.g.
  `FOREGROUND_SERVICE_LOCATION`).
- For work that finishes within 3 minutes, use the `shortService` type.

### Background-start restrictions (Android 12+ / API 31+)
- An app in the background cannot start a foreground service. Violating this
  throws `ForegroundServiceStartNotAllowedException`.
- Exempt cases (summary): just transitioned from a screen, high-priority FCM
  received, notification/widget/bubble interaction, exact alarm, geofencing
  transition, boot broadcast, battery-optimization exemption, Companion Device
  Manager declaration. Full table in `reference.md`.
- **Android 14+**: a foreground service requiring a while-in-use permission such
  as location/camera/microphone/BODY_SENSORS throws a `SecurityException` if
  created from the background even with an exemption above. (Exception: `location`
  type + `ACCESS_BACKGROUND_LOCATION`)

### Doze & App Standby
- In Doze, network, wakelocks, `JobScheduler`, `WorkManager`, and sync all halt
  and run only in the maintenance window. Do not assume immediate execution.
- Leave deferrable work to `WorkManager` and it respects Doze on its own — do
  not grab a wakelock or poll yourself.
- For a user-facing event that truly needs immediate handling, wake the app with
  **high-priority FCM**. Use high-priority only for messages that lead to a
  notification.
- Use `setAndAllowWhileIdle()` / `setExactAndAllowWhileIdle()` only for exact
  alarms that must punch through Doze (limited to once per 9 minutes per app).
  Use `setAlarmClock()` for clock alarms.
- Do not habitually request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
  (battery-optimization exemption) — Play policy allows it only when it breaks a
  core feature.

### Background location
- If location is needed while the app is in the background, use
  `ACCESS_BACKGROUND_LOCATION` (API 29+). Request it as a **separate step**
  after foreground location (`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`)
  is already granted — do not bundle them into one request.
- If background location is not a core feature, do not include the permission at
  all (Play policy).
- For continuous location tracking, use the combination of a `location`
  foreground service + `FOREGROUND_SERVICE_LOCATION` + `ACCESS_BACKGROUND_LOCATION`.

## Decision table

| Situation | Choice |
|------|------|
| async meaningful only while the screen is alive | coroutine |
| deferrable work that must be guaranteed after leaving/after reboot | `WorkManager` (`OneTime`/`Periodic`) |
| such work that must run soon, urgently | `WorkManager` `setExpedited()` |
| user-visible immediate, non-interruptible work | foreground service (+ `foregroundServiceType`) |
| short immediate work finishing within 3 minutes | foreground service `shortService` |
| exact-time trigger | `AlarmManager` (`...AllowWhileIdle` when idle needed) |
| user-facing immediate delivery during Doze | high-priority FCM |
| large download/upload | user-initiated data transfer (instead of FGS) |

## Refactor / red-flag signals

- `WorkManager` used for one-off in-session async → move to a coroutine.
- Code that creates a new `Service` without a platform requirement → check for
  an alternative API.
- A foreground service with no `startForeground()` / notification.
- An FGS missing `foregroundServiceType` or the per-type permission in the manifest.
- A call that starts a foreground service from the background unconditionally
  (risk of `ForegroundServiceStartNotAllowedException`).
- Requesting `ACCESS_BACKGROUND_LOCATION` without foreground permission, or
  bundled into the same request.
- Code that grabs a wakelock directly or runs a polling loop to bypass Doze.
- Requesting `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` without a core-feature justification.
- A single `WorkManager` task longer than 10 minutes (interruption risk — split it up).

## References

- Background work overview: https://developer.android.com/develop/background-work/background-tasks
- Foreground services: https://developer.android.com/develop/background-work/services/foreground-services
- FGS background-start restrictions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
  (the old `.../fgs/launch-restrictions` is 404 — replaced by this URL)
- WorkManager: https://developer.android.com/topic/libraries/architecture/workmanager
- Doze & App Standby: https://developer.android.com/training/monitoring-device-state/doze-standby
- Android 8.0 background execution limits: https://developer.android.com/about/versions/oreo/background
- Background location: https://developer.android.com/develop/sensors-and-location/location/background
- Team Android baseline: [../../guidance.md](../../guidance.md)
- Detailed rules / tables / edge cases: [reference.md](reference.md)
