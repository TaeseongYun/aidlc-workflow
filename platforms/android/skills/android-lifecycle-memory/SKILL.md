---
name: android-lifecycle-memory
description: 안드로이드 라이프사이클(Android lifecycle)에 맞춘 메모리 누수 방지(memory leak prevention) 레퍼런스. 라이프사이클 인식 컴포넌트(lifecycle-aware components), repeatOnLifecycle / collectAsStateWithLifecycle 로 Flow 를 수집하고, viewModelScope / lifecycleScope 로 코루틴을 취소하며, onTrimMemory 로 메모리 압박에 대응한다. Activity/Fragment/Composable 이 Context·View 를 라이프사이클 이후까지 붙잡거나, 라이프사이클 비인식 수집(non-lifecycle-aware collection)을 쓰거나, static/companion 이 Context 를 잡을 때 참조. Kotlin·Compose·ViewModel·Coroutines/Flow 코드를 작성·리뷰할 때 상시 적용.
when_to_use: Activity/Fragment/ViewModel/Composable 에서 Flow 수집, 코루틴 스코프 선택, Context/View 참조, onTrimMemory 처리 등 라이프사이클·메모리 결정이 필요할 때.
paths: **/*Activity.kt, **/*Fragment.kt, **/ui/**/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# android-lifecycle-memory

라이프사이클 경계를 넘겨 살아남는 참조를 없애고, UI 가 보이지 않을 때 자원을
놓는다. 수집·취소·해제를 라이프사이클에 묶어 누수를 구조적으로 막는다.
`../../guidance.md` 의 "collect flows lifecycle-aware in UI",
"All I/O on injected dispatchers", "ViewModel 은 Android UI 타입 금지" 규칙의
상세 확장이다.

## Scope

- 적용: `**/*Activity.kt`, `**/*Fragment.kt`, `**/ui/**/*.kt`.
- 대상: Flow 수집 위치, 코루틴 스코프 선택, `Context`/`View` 참조 수명,
  `onTrimMemory` 대응, static/companion 보관.
- 비대상: DI 배선·모듈 경계·Intent 계약 → `../../guidance.md`.

## Core rules

- **UI 는 라이프사이클 인식으로 수집한다.** Compose 는
  `collectAsStateWithLifecycle()`, View 는 `repeatOnLifecycle(STARTED)` 블록
  안에서 수집. 맨 `collect`/`collectAsState()`/`launchWhenStarted` 금지 —
  백그라운드에서도 계속 돌며 자원·배터리를 태운다.
- **스코프로 취소를 위임한다.** 코루틴은 소유자의 스코프에서 실행:
  ViewModel 은 `viewModelScope`, UI 는 `lifecycleScope`. 수동 `Job` 취소나
  `GlobalScope` 금지.
- **ViewModel 은 Android UI 타입을 붙잡지 않는다.** `View`·`Activity`·
  `Fragment`·`Context`(비-Application)·Compose 타입 참조 금지.
  `Application`·`SavedStateHandle` 만 허용. UI 는 화면 밖으로 나가도 ViewModel
  은 살아 있으므로 잡으면 누수다.
- **I/O 는 주입된 디스패처에서.** `@IoDispatcher` 를 주입받아 사용,
  하드코딩 `Dispatchers.IO` 금지 (테스트·취소 제어 불가).
- **콜백/리스너는 등록한 라이프사이클에서 해제한다.** `ON_START`↔`ON_STOP`,
  `ON_RESUME`↔`ON_PAUSE` 짝. Compose 는 `LifecycleStartEffect`/
  `LifecycleResumeEffect`(의 `onStopOrDispose`/`onPauseOrDispose`) 또는
  `DisposableEffect` 로 해제.
- **static/companion/object 는 `Context`·`View`·`Fragment` 를 담지 않는다.**
  프로세스 수명을 가지므로 무한 누수. 불가피하면 `Application` 만.
- **`Handler`·`Runnable`·리스너는 leak 방지 형태로.** 외부/익명 클래스가
  바깥 `Activity` 를 암묵 참조하지 않게 한다.
- **`onTrimMemory(level)` 에 응답해 UI 자원을 놓는다.** `TRIM_MEMORY_UI_HIDDEN`
  이상에서 비트맵 캐시·재생 버퍼·애니메이션 자원 해제 (아래 표·`reference.md`).
- **디버그 빌드에 LeakCanary 를 붙인다.**
  `debugImplementation 'com.squareup.leakcanary:leakcanary-android:2.14'` —
  파괴된 Activity/Fragment 의 잔존 인스턴스를 자동 감지.

## 스코프 → 수집/취소 메커니즘

| 소유자 / 라이프사이클 | 올바른 수집·실행 | 취소 시점 |
|---|---|---|
| ViewModel (화면 상태·비동기 데이터) | `viewModelScope.launch`, `stateIn(viewModelScope, WhileSubscribed(5_000), ...)` | ViewModel `onCleared()` |
| Compose Composable | `flow.collectAsStateWithLifecycle()` (기본 `STARTED` 에서 수집, `minActiveState` 로 조정) | 컴포지션 이탈 / 라이프사이클 하락 |
| Compose side-effect | `LaunchedEffect(key)`, `rememberCoroutineScope()` | 키 변경 / 컴포지션 이탈 |
| Activity/Fragment (View 계열) | `lifecycleScope.launch { repeatOnLifecycle(Lifecycle.State.STARTED) { flow.collect { } } }` | `STARTED` 아래로 내려가면 취소, 다시 올라오면 재시작 |
| 짝 있는 자원 (리스너·카메라) | `LifecycleStartEffect`/`LifecycleResumeEffect`, 또는 `DefaultLifecycleObserver` | 짝 이벤트(`ON_STOP`/`ON_PAUSE`)에서 해제 |

`Lifecycle.State`: `INITIALIZED` → `CREATED` → `STARTED` → `RESUMED` →
`DESTROYED`. `repeatOnLifecycle`·`collectAsStateWithLifecycle` 는 기본
`STARTED` 를 활성 하한으로 쓴다.

## Refactor / red-flag signals

- `Context`·`View`·`Activity`·`Fragment` 가 라이프사이클 이후까지 참조로 남음
  (ViewModel 필드, static, 콜백 클로저).
- 라이프사이클 비인식 수집: `repeatOnLifecycle` 없는 `lifecycleScope.launch { collect }`,
  Compose 의 `collectAsState()`, `launchWhenStarted`/`launchWhenResumed`.
- static/companion/`object` 가 `Context`·`View`·리스너를 보관.
- ViewModel 이 `android.view`·`android.widget`·Compose 타입을 import.
- 하드코딩 `Dispatchers.IO`/`Dispatchers.Main`, `GlobalScope`, 수동 `Job` 취소.
- 등록만 하고 해제하지 않는 리스너·`BroadcastReceiver`·콜백 (짝 없음).
- `onTrimMemory`/`onLowMemory` 미구현이면서 큰 비트맵·캐시를 UI 에 보유.
- 익명 `Handler`/`Runnable`/이너 클래스가 `Activity` 를 암묵 참조.

## References

- 상세 카탈로그(누수 패턴, `repeatOnLifecycle` vs `collectAsStateWithLifecycle`
  샘플, `onTrimMemory` 레벨 표): [`reference.md`](reference.md)
- 팀 아키텍처 가이던스: [`../../guidance.md`](../../guidance.md)
- 라이프사이클 인식 컴포넌트: https://developer.android.com/topic/libraries/architecture/lifecycle
- 라이프사이클 인식 코루틴(`viewModelScope`/`lifecycleScope`/`repeatOnLifecycle`): https://developer.android.com/topic/libraries/architecture/coroutines
- Compose side-effects: https://developer.android.com/jetpack/compose/side-effects
- 메모리 개요(GC·누수·LMK): https://developer.android.com/topic/performance/memory-overview
- 앱 메모리 관리(`onTrimMemory`): https://developer.android.com/topic/performance/memory
- `ComponentCallbacks2` / `onTrimMemory` 상수: https://developer.android.com/reference/android/content/ComponentCallbacks2
- LeakCanary: https://square.github.io/leakcanary/
