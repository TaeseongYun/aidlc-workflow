# android-viewmodel-state — reference

`SKILL.md`의 심화 자료. 코드 샘플·비교표·SavedStateHandle 패턴. 규칙 자체는
`SKILL.md`, 팀 기준선은 [`../../guidance.md`](../../guidance.md).

## UiState 모델링

### data class (필드가 서로 독립일 때)

```kotlin
data class NewsUiState(
    val isLoading: Boolean = false,
    val items: List<NewsItemUiState> = emptyList(),
    val userMessage: String? = null,   // 소비 후 ack 로 null
)
```

### sealed 계층 (loading/content/error 가 배타적일 때)

불법 상태를 표현 불가능하게. `isLoading=true`인데 `error!=null` 같은 조합이
컴파일 단에서 불가능해진다.

```kotlin
sealed interface DetailUiState {
    data object Loading : DetailUiState
    data class Content(val item: Item) : DetailUiState
    data class Error(val message: String) : DetailUiState
}
```

nullable 다발(`data? + error? + isLoading`)은 냄새. sealed 또는 명시적 모델로.

## StateFlow 노출

private mutable, public 읽기 전용:

```kotlin
@HiltViewModel
class DetailViewModel @Inject constructor(
    private val repo: ItemRepository,
    @IoDispatcher private val io: CoroutineDispatcher,
) : ViewModel() {

    private val _uiState = MutableStateFlow<DetailUiState>(DetailUiState.Loading)
    val uiState: StateFlow<DetailUiState> = _uiState.asStateFlow()

    fun load(id: String) = viewModelScope.launch {
        _uiState.value = DetailUiState.Loading
        runCatching { withContext(io) { repo.item(id) } }
            .onSuccess { _uiState.value = DetailUiState.Content(it) }
            .onFailure { _uiState.value = DetailUiState.Error(it.message.orEmpty()) }
    }
}
```

cold flow를 상태로 접을 때는 `stateIn`:

```kotlin
val uiState: StateFlow<DetailUiState> = repo.stream(id)
    .map { DetailUiState.Content(it) }
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = DetailUiState.Loading,
    )
```

## StateFlow vs SharedFlow

| | StateFlow | SharedFlow |
|---|---|---|
| 값 보유 | 항상 있음(`.value`), 초기값 필수 | 없음 |
| 성격 | conflated hot, 최신만 | replay·buffer 설정형 hot |
| 신규 구독자 | 현재 값 즉시 수신 | replay 개수만 수신(0이면 없음) |
| 쓰임 | 화면 상태(UiState) | 일회성 effect/이벤트 |
| 만드는 법 | `MutableStateFlow(init)` / `stateIn` | `MutableSharedFlow(replay=0, extraBufferCapacity=1)` / `shareIn` |
| 공개 변환 | `asStateFlow()` | `asSharedFlow()` |

effect는 `replay = 0`으로. 재구독 시 과거 이벤트를 다시 흘리지 않게 한다.
버퍼 넘침은 `extraBufferCapacity`와 `onBufferOverflow`로 조절.

## Effect 스트림 (진짜 일회성)

상태로 못 푸는 것만. 네비게이션 트리거, 1회 토스트 등.

```kotlin
sealed interface DetailEffect {
    data class NavigateTo(val route: String) : DetailEffect
    data class ShowToast(val message: String) : DetailEffect
}

// ViewModel
private val _effect = MutableSharedFlow<DetailEffect>(
    replay = 0,
    extraBufferCapacity = 1,
    onBufferOverflow = BufferOverflow.DROP_OLDEST,
)
val effect: SharedFlow<DetailEffect> = _effect.asSharedFlow()

fun onSaved() {
    _effect.tryEmit(DetailEffect.NavigateTo("home"))
}
```

`Channel(Channel.BUFFERED).receiveAsFlow()`도 단일 구독 effect에 적합.

주의: 공식 문서는 producer(ViewModel)가 consumer(UI)보다 오래 살 때
Channel/Flow 이벤트가 전달을 보장하지 못한다고 경고한다. 상태로 표현 가능한
신호는 UiState 플래그 + UI 소비 후 ack로 처리하고, effect는 최후 수단.
([events](https://developer.android.com/topic/architecture/ui-layer/events))

## 이벤트를 상태로 (권장 경로)

로그인 성공 → 네비게이션을 effect 대신 상태로:

```kotlin
data class LoginUiState(
    val isLoginInProgress: Boolean = false,
    val errorMessage: String? = null,
    val isUserLoggedIn: Boolean = false,
)

// UI: 상태를 관찰해 1회 처리, ack 로 되돌림
LaunchedEffect(uiState.isUserLoggedIn) {
    if (uiState.isUserLoggedIn) onLoggedIn()
}
```

## UI 수집 (lifecycle-aware)

Compose 권장:

```kotlin
@Composable
fun DetailRoute(viewModel: DetailViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    DetailScreen(uiState = uiState, onSave = viewModel::onSaved)
}
```

effect 수집:

```kotlin
val lifecycle = LocalLifecycleOwner.current.lifecycle
LaunchedEffect(viewModel, lifecycle) {
    viewModel.effect.flowWithLifecycle(lifecycle).collect { effect ->
        when (effect) {
            is DetailEffect.NavigateTo -> navController.navigate(effect.route)
            is DetailEffect.ShowToast -> /* show */ Unit
        }
    }
}
```

View 시스템이면 `repeatOnLifecycle(Lifecycle.State.STARTED)` 안에서 수집.
`launchIn`만 쓰는 비-lifecycle 수집은 금지.

## SavedStateHandle

프로세스 사망을 넘겨야 하는 가볍고 전이적인 상태만(입력값, 선택, 인자).
큰/복잡한 데이터는 로컬 영속화.

```kotlin
@HiltViewModel
class SearchViewModel @Inject constructor(
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {

    val query: StateFlow<String> =
        savedStateHandle.getStateFlow("query", "")

    fun setQuery(value: String) {
        savedStateHandle["query"] = value
    }
}
```

주요 API: `get`/`set`/`contains`/`remove`/`keys`,
`getStateFlow(key, initial)`(읽기 전용 StateFlow). Hilt에서는
`@HiltViewModel` 생성자에 `SavedStateHandle`을 그냥 주입하면 된다.

저장 타입: `Bundle`에 담기는 것 — 프리미티브/배열, `String`,
`Parcelable`, `Serializable` 등. 비-Parcelable은 kotlinx serialization
delegate(`saved { ... }`)나 `saveable`로.

생존/비생존: 시스템 주도 프로세스 사망·백그라운드는 생존. 강제 종료·recents
제거·재부팅은 비생존.

테스트: `SavedStateHandle(mapOf("id" to testId))`로 주입해 초기값 검증.

## 테스트 메모

ViewModel 상태 전이 테스트는 main-dispatcher 룰 + fake repository로.
value형 타입에 모킹 프레임워크를 쓰지 않는다(`guidance.md`).

## References

- [ViewModel](https://developer.android.com/topic/libraries/architecture/viewmodel)
- [SavedStateHandle (ViewModel Saved State)](https://developer.android.com/topic/libraries/architecture/viewmodel/viewmodel-savedstate)
- [UI layer](https://developer.android.com/topic/architecture/ui-layer)
- [State holders](https://developer.android.com/topic/architecture/ui-layer/stateholders)
- [UI events](https://developer.android.com/topic/architecture/ui-layer/events)
- [StateFlow and SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)
- [State in Compose](https://developer.android.com/jetpack/compose/state)
- 팀 기준선: [`../../guidance.md`](../../guidance.md)
