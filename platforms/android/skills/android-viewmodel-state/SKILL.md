---
name: android-viewmodel-state
description: 안드로이드 뷰모델 상태 관리 규칙 (Android ViewModel/UiState state management). ViewModel이 화면 상태를 단일 UiState로 소유하고 StateFlow로 노출, 일회성 이벤트/effect는 SharedFlow·Channel로 분리, SavedStateHandle로 프로세스 사망 대비, 단방향 데이터 흐름(UDF) 유지, ViewModel의 Android UI 타입(View/Activity/Fragment/Compose) 참조 금지, UI에서 lifecycle-aware 수집(collectAsStateWithLifecycle). *ViewModel.kt 또는 ui/ 계층을 작성·리뷰·리팩터할 때, 상태를 어디에 두고 어떻게 노출·수집할지 판단할 때 사용.
when_to_use: ViewModel/UiState/effect를 설계·구현·리뷰할 때, 상태 대 이벤트를 가를 때, nullable 필드 남발이나 Android 타입 참조 같은 냄새를 잡을 때.
paths: **/*ViewModel.kt, **/ui/**/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# android-viewmodel-state

ViewModel의 상태·이벤트 처리 규칙. `guidance.md`의 ViewModel/UiState 항목을
집행 가능한 수준으로 펼친 것. 프로젝트 `ctx/`가 이 문서를 덮어쓴다.

## Scope

- 대상: `*ViewModel.kt`, `ui/` 하위 Composable/화면 코드.
- 다루는 것: UiState 모델링, StateFlow 노출, effect 스트림, SavedStateHandle,
  UDF, lifecycle-aware 수집.
- 안 다루는 것: 모듈 경계·DI 조립·Intent 계약·Repository 매핑은
  `guidance.md`를 따른다.

## Core rules

Do:

- 화면당 UiState 하나. `MutableStateFlow`는 private, 공개는 읽기 전용
  `StateFlow` (`asStateFlow()` 또는 `stateIn(...)`).
- 상태 변경은 `_uiState.update { it.copy(...) }`. UiState는 불변 data class.
- 불법 상태를 표현 불가능하게 모델링. loading/content/error가 배타적이면
  sealed 계층. nullable 필드 나열(`isLoading` + `data?` + `error?`) 금지.
- 일회성 이벤트(네비게이션, 스낵바 1회, 토스트)는 `SharedFlow`/`Channel`
  기반 effect 스트림으로 분리. 상태에 실어 보내지 않는다.
- 가능하면 이벤트도 상태로 모델링하고, effect는 상태로 못 푸는 진짜
  일회성만. (공식 문서는 "ViewModel 이벤트는 항상 상태 갱신으로 귀결"을
  권장 — [events](https://developer.android.com/topic/architecture/ui-layer/events).)
- 모든 코루틴은 `viewModelScope`. I/O는 주입 디스패처(`@IoDispatcher`),
  하드코딩된 `Dispatchers.IO` 금지.
- UI는 `collectAsStateWithLifecycle()`로 수집(권장). 상태를 stateless
  Composable로 내려보내고 액션은 콜백으로 올린다(UDF).
- 프로세스 사망을 넘겨야 하는 최소 상태만 `SavedStateHandle`
  (`getStateFlow(key, default)`).

Don't:

- ViewModel에서 `View`/`Activity`/`Fragment`/`Context`/Compose 타입 참조.
  (`Application`/`SavedStateHandle`은 허용.)
- `MutableStateFlow`/`MutableSharedFlow`를 그대로 public 노출.
- effect를 UiState 필드로 두고 소비 후 null 리셋하는 우회.
- Composable에서 Repository/SDK 직접 호출, UiState를 UI에서 mutate.
- 하나의 화면에 여러 UiState를 흩뿌리기(관련 상태는 단일 스트림).

## Decision table

상태 vs 이벤트 — 각 타입이 어디에 사는가:

| 데이터 성격 | 어디에 | API |
|---|---|---|
| 화면이 렌더하는 지속 상태(목록, 폼 값, 로딩/에러) | ViewModel UiState | `StateFlow<UiState>` |
| 프로세스 사망을 넘겨야 하는 입력·선택·인자 | SavedStateHandle | `getStateFlow(key, default)` |
| 상태로 모델 가능한 "1회" 신호(로그인 성공→네비) | UiState 플래그 + UI가 소비 후 ack | `isLoggedIn` + `LaunchedEffect` |
| 상태로 못 푸는 진짜 일회성 effect | effect 스트림 | `SharedFlow`(replay=0)/`Channel` |
| Composition 수명의 UI 요소 상태(스크롤, 다이얼로그 열림) | UI 로컬 | `remember`/`rememberSaveable`, `LazyListState` |
| UI 로직 상태 홀더(bottom bar 표시 여부 등) | plain state holder 클래스 | `remember { ... }` |

## Refactor / red-flag signals

- ViewModel이 `android.view`·Compose 타입을 import.
- public `MutableStateFlow`/`MutableSharedFlow`.
- UiState가 서로 독립적인 nullable 다발 → sealed/모델링으로 교체.
- effect를 상태 필드로 밀어넣고 null로 리셋.
- `Dispatchers.IO` 하드코딩, `viewModelScope` 밖에서 launch.
- UI가 `collect { }`를 lifecycle 없이 수집(`launchIn` 단독) — 대신
  `collectAsStateWithLifecycle()` 또는 `repeatOnLifecycle`.
- Composable이 Repository/SDK 직접 호출 또는 UiState mutate.
- 하나의 화면에 UiState가 둘 이상.

## References

- [ViewModel](https://developer.android.com/topic/libraries/architecture/viewmodel)
- [SavedStateHandle (ViewModel Saved State)](https://developer.android.com/topic/libraries/architecture/viewmodel/viewmodel-savedstate)
- [UI layer](https://developer.android.com/topic/architecture/ui-layer)
- [State holders](https://developer.android.com/topic/architecture/ui-layer/stateholders)
- [UI events](https://developer.android.com/topic/architecture/ui-layer/events)
- [StateFlow and SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)
- [State in Compose](https://developer.android.com/jetpack/compose/state)
- 팀 기준선: [`../../guidance.md`](../../guidance.md)
- 코드 샘플·비교표·SavedStateHandle 패턴: [`reference.md`](reference.md)
