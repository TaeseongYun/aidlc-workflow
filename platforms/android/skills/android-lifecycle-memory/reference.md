# android-lifecycle-memory — 상세 레퍼런스

`SKILL.md` 의 심화 자료. 누수 패턴 카탈로그, 수집 API 대조, `onTrimMemory`
레벨 표. API 이름은 공식 문서 기준.

## 1. 누수 패턴 카탈로그

라이프사이클 경계를 넘겨 참조가 살아남으면 누수다. GC 는 도달 가능한
(reachable) 객체를 회수하지 못한다 — 참조를 끊는 것만이 유일한 해제 수단.

| 패턴 | 왜 누수인가 | 고침 |
|---|---|---|
| static/companion 이 `Context`·`Activity` 보관 | 프로세스 수명 → 파괴된 Activity 영구 잔존 | `Application` 만 담거나 참조 제거 |
| ViewModel 이 `View`/`Context`/`Fragment` 보관 | ViewModel 이 UI 보다 오래 삶 | UI 타입 제거, `Application`/`SavedStateHandle` 만 |
| 익명 `Runnable`/`Handler`/리스너 | 바깥 `Activity` 를 암묵 참조 | static + `WeakReference`, 또는 `onDestroy`/`ON_STOP` 에서 제거 |
| 해제 안 한 리스너·`BroadcastReceiver`·콜백 | 시스템이 계속 참조 보유 | 등록의 짝이 되는 라이프사이클 이벤트에서 해제 |
| 라이프사이클 비인식 Flow 수집 | 백그라운드에서도 수집 지속, 자원·배터리 소모 | `repeatOnLifecycle`/`collectAsStateWithLifecycle` |
| 살아 있는 UI 를 잡는 장기 코루틴/`GlobalScope` | 취소 소유자 없음 | `viewModelScope`/`lifecycleScope` |
| 큰 비트맵/캐시를 백그라운드까지 보유 | UI 안 보여도 RAM 점유 → LMK 위험 | `onTrimMemory` 로 해제 |

빠른 확인: 디버그 빌드에 LeakCanary(`com.squareup.leakcanary:leakcanary-android:2.14`,
`debugImplementation`) — 코드 변경 없이 파괴된 Activity/Fragment 잔존 인스턴스를
자동 감지. Logcat 의 `"LeakCanary is running and ready to detect leaks"` 로 확인.

## 2. Flow 수집: repeatOnLifecycle vs collectAsStateWithLifecycle

### View (Activity/Fragment) — `repeatOnLifecycle`

`STARTED` 이상에서만 수집, 아래로 내려가면 코루틴 취소, 다시 올라오면 재시작.

```kotlin
class ConversationActivity : AppCompatActivity() {
    private val viewModel: ConversationViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { render(it) }
            }
        }
    }
}
```

- `repeatOnLifecycle(state) { }` 는 소유자가 `state` 에 도달하면 블록을
  실행하고, 아래로 내려가면 취소한다. `lifecycleScope.launch` 안에서 호출.
- 단일 Flow 만 필요하면 `flow.flowWithLifecycle(lifecycle, STARTED)` 도 가능.
- 금지: `lifecycleScope.launchWhenStarted { }`(deprecated 계열, 취소 아닌 일시정지),
  `repeatOnLifecycle` 없는 맨 `collect`.

### Compose — `collectAsStateWithLifecycle`

`androidx.lifecycle:lifecycle-runtime-compose` 아티팩트 제공.

```kotlin
@Composable
fun ConversationRoute(viewModel: ConversationViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    ConversationScreen(uiState = uiState, onSend = viewModel::sendMessage)
}
```

- 기본 활성 하한은 `Lifecycle.State.STARTED`, 아래로 내려가면 수집 중단.
  `minActiveState = Lifecycle.State.RESUMED` 로 조정 가능.
- 여러 Flow 는 각각 병렬 수집되어 별도 State 로.
- Compose 에서 `collectAsState()`(라이프사이클 비인식) 대신 항상 이것을 사용.

### ViewModel 쪽 노출

```kotlin
val uiState: StateFlow<UiState> = repository.stream()
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = UiState.Loading,
    )
```

`WhileSubscribed(5_000)` 은 구성 변경 등 짧은 구독 공백을 5초 버텨 업스트림
재시작을 막는다.

## 3. Compose 라이프사이클 side-effect

`androidx.lifecycle.compose` 의 라이프사이클 인식 이펙트로 짝 자원을 다룬다.

- `LifecycleStartEffect(key) { ...; onStopOrDispose { 해제 } }` — `ON_START`↔`ON_STOP`.
- `LifecycleResumeEffect(key) { ...; onPauseOrDispose { 해제 } }` — `ON_RESUME`↔`ON_PAUSE`.
- `LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { }` — 단일 이벤트.
- 일반 정리는 `DisposableEffect(key) { onDispose { 해제 } }`.
- `LocalLifecycleOwner.current` 로 현재 `LifecycleOwner` 접근.

## 4. onTrimMemory 레벨 표

`ComponentCallbacks2` 를 구현하고 `onTrimMemory(level: Int)` 에서 자원 해제.
level 은 `>=` 비교로 처리한다.

| 상수 | 의미 | 대응 |
|---|---|---|
| `TRIM_MEMORY_UI_HIDDEN` | 앱 UI 가 화면 밖으로 전환됨 | 비트맵 캐시·영상 재생 버퍼·복잡한 애니메이션 자원 해제 |
| `TRIM_MEMORY_BACKGROUND` | 프로세스가 백그라운드, 종료 후보 | 쉽게 재구성 가능한 자원 적극 해제 → cached 상태 연장, cold start 감소 |

> Android 14 부터 시스템은 위 두 알림만 전달하며 나머지 `TRIM_MEMORY_*`
> 상수(`RUNNING_MODERATE`/`RUNNING_LOW`/`RUNNING_CRITICAL`/`MODERATE`/`COMPLETE`)는
> Android 15 기준 deprecated. 이전 API 레벨 호환 시에만 참고.

```kotlin
class MainActivity : AppCompatActivity(), ComponentCallbacks2 {
    override fun onTrimMemory(level: Int) {
        if (level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            // UI 관련 메모리 해제 (캐시·버퍼)
        }
        if (level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND) {
            // 백그라운드 처리 메모리 해제
        }
    }
}
```

보조: 무거운 작업 전 `ActivityManager.getMemoryInfo()` 로 가용 메모리 확인,
`ActivityManager.getMemoryClass()` 로 앱 힙 한도(MB) 조회. 서비스는 작업이
끝나면 반드시 중지 — 실행 중 서비스는 LMK 우선순위와 메모리 압박을 키운다.

## 5. 참고

- 라이프사이클 인식 컴포넌트: https://developer.android.com/topic/libraries/architecture/lifecycle
  (현재 최종 URL: https://developer.android.com/topic/architecture/ui-layer/lifecycle)
- 라이프사이클 인식 코루틴: https://developer.android.com/topic/libraries/architecture/coroutines
- Compose side-effects: https://developer.android.com/jetpack/compose/side-effects
  (현재 최종 URL: https://developer.android.com/develop/ui/compose/side-effects)
- 메모리 개요: https://developer.android.com/topic/performance/memory-overview
- 앱 메모리 관리: https://developer.android.com/topic/performance/memory
- `ComponentCallbacks2`: https://developer.android.com/reference/android/content/ComponentCallbacks2
- LeakCanary: https://square.github.io/leakcanary/
- 팀 가이던스: [`../../guidance.md`](../../guidance.md)
