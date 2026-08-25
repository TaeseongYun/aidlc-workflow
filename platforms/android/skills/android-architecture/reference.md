# android-architecture — 참조 자료 (reference)

`SKILL.md`의 심화 부록. 레이어별 책임 상세 표, MVI/reducer 샘플, Modern Android
Development(MAD) 구성요소, 공식 권장사항 우선순위 표를 담는다. 규칙의 근거가
아니라 규칙을 적용할 때 참조하는 세부 사항이다.

관련 개념 링크: [android-viewmodel-state](../android-viewmodel-state/SKILL.md),
[android-module-structure](../android-module-structure/SKILL.md).

## 1. 레이어별 책임 상세 표

공식 권장 아키텍처는 최소 2개 레이어(UI, 데이터), 선택적 3번째(도메인)로 구성.
의존은 위→아래 단방향: `UI → 도메인(선택) → 데이터`. 데이터 레이어는 상위
레이어를 절대 의존하지 않는다.

| 레이어 | 구성요소 | 하는 일 | 하지 않는 일 |
|--------|----------|---------|--------------|
| **UI** | Composable, 상태 홀더(`ViewModel`) | `UiState` 렌더, 사용자 이벤트 수신, UI 로직(리소스로 텍스트 표시, 네비게이션, 스낵바) | 비즈니스 로직, 리포지토리/DataSource 직접 호출, `UiState` 직접 변경 |
| **도메인**(선택) | UseCase/Interactor | 복잡한 비즈니스 로직 캡슐화, 여러 ViewModel이 재사용하는 규칙, 다중 리포지토리 조합 | 가변 상태 보유, 단순 위임을 위한 존재, 자체 생명주기 |
| **데이터** | 리포지토리, DataSource | 앱 데이터 노출, 변경 중앙화, 소스 충돌 해소, 소스 추상화, SSOT 정의 | 상위 레이어 의존, 가변 데이터 노출, 구현 세부(`SharedPreferences`)로 명명 |

### UI 레이어 세부
- **UI State**: 화면이 보여줄 것의 불변 스냅샷. `data class`, 명명 규칙
  `[기능]UiState`(예: `NewsUiState`). 관련 데이터는 단일 스트림으로 노출.
- **상태 홀더**: 화면 수준은 `ViewModel`. 재사용 UI 컴포넌트는 평범한 상태 홀더
  클래스(plain state holder). 상태 홀더는 대상 UI 요소와 같은 수명을 가진다.
- **노출**: `StateFlow` + `stateIn(scope, SharingStarted.WhileSubscribed(5_000),
  initialValue)`. UI는 `collectAsStateWithLifecycle()`로 생명주기 인지 소비.
- **UI 로직 vs 비즈니스 로직**: 리소스로 텍스트 표시·네비게이션·토스트는 UI
  레이어. 북마크 토글 같은 규칙은 도메인/데이터. `Context` 필요한 코드는
  ViewModel에 넣지 않는다.
- 자세한 상태/이펙트 설계 → [android-viewmodel-state](../android-viewmodel-state/SKILL.md).

### 도메인 레이어 세부
- **언제 추가**: 복잡한 로직 처리 또는 여러 ViewModel의 재사용이 필요할 때만.
  단순 데이터 위임에는 만들지 않는다(과설계 회피). 큰 앱에서 권장.
- **명명**: `현재형 동사 + 명사(선택) + UseCase` → `FormatDateUseCase`,
  `GetLatestNewsWithAuthorsUseCase`, `LogOutUserUseCase`.
- **호출 가능**: `operator fun invoke()`(또는 `suspend operator fun invoke`)로
  함수처럼 호출.
- **의존**: 리포지토리, 다른 UseCase. **가변 상태 없음** — 의존성으로 넘길 때마다
  새 인스턴스. 자체 생명주기 없음(사용하는 클래스에 스코프).
- **스레딩**: main-safe. 블로킹 작업은 `withContext(defaultDispatcher)`로 이동.

### 데이터 레이어 세부
- **진입점**: 리포지토리만이 진입점. UI/도메인은 DataSource에 직접 접근 금지.
- **SSOT**: 리포지토리마다 단일 진실 소스 정의. 오프라인 우선이면 로컬 DataSource.
- **노출 API**: 1회성은 `suspend fun`, 지속 변경은 `Flow<T>`. 노출 데이터는 불변.
- **도메인 모델 반환**: API/DTO를 트림한 도메인 모델을 반환. 매핑은 데이터 레이어
  경계에서. 복잡 앱은 레이어별 모델 분리(권장).
- **명명**: 리포지토리 `[Data]Repository`, DataSource `[Data][Remote/Local]DataSource`.
  구현 세부로 명명 금지(스왑 가능성 유지). 인터페이스 구현체는 `Default` 프리픽스.
- **main-safe**: Room/Retrofit/Ktor의 main-safe API 활용. 스레드 안전 캐시는 `Mutex`.

## 2. MVI / Reducer 샘플

MVI는 결정 표의 최상단 슬라이스 — 낙관적 업데이트나 복잡한 동시성 신호가 있을 때만
MVVM 위에 얹는다. 단일 `Intent`(사용자 의도)를 순수 `reduce(state, intent)`로
접어 새 상태를 만든다. 상태는 UDF로 한 방향으로만 흐른다.

```kotlin
// 상태: 화면이 보여줄 것의 불변 스냅샷
data class CartUiState(
    val items: List<CartItem> = emptyList(),
    val isCheckingOut: Boolean = false,
    val error: CartError? = null,
)

// 의도: 사용자/시스템이 일으키는 이벤트 (반대 방향으로 흐름)
sealed interface CartIntent {
    data class Add(val item: CartItem) : CartIntent
    data class Remove(val id: String) : CartIntent
    data object Checkout : CartIntent
}

// 리듀서: 순수 함수. 부작용 없음, 안드로이드 타입 없음 → 테스트 용이
fun reduce(state: CartUiState, intent: CartIntent): CartUiState = when (intent) {
    is CartIntent.Add    -> state.copy(items = state.items + intent.item)      // 낙관적
    is CartIntent.Remove -> state.copy(items = state.items.filterNot { it.id == intent.id })
    CartIntent.Checkout  -> state.copy(isCheckingOut = true)
}

@HiltViewModel
class CartViewModel @Inject constructor(
    private val checkoutCart: CheckoutCartUseCase,   // 부작용은 UseCase/Repository로
) : ViewModel() {
    private val _state = MutableStateFlow(CartUiState())
    val state: StateFlow<CartUiState> = _state.asStateFlow()

    fun onIntent(intent: CartIntent) {
        _state.update { reduce(it, intent) }          // 동기 상태 전이
        if (intent is CartIntent.Checkout) launchCheckout()  // 비동기 부작용 분리
    }

    private fun launchCheckout() = viewModelScope.launch {
        runCatching { checkoutCart(_state.value.items) }
            .onFailure { _state.update { s -> s.copy(isCheckingOut = false, error = CartError.Network) } }
    }
}
```

핵심: `reduce`는 순수(상태 전이만) → 부작용/네트워크는 UseCase·Repository로 분리.
1회성 이벤트(토스트, 네비게이션)는 상태가 아니라 별도 이펙트 스트림으로.
상세 설계는 [android-viewmodel-state](../android-viewmodel-state/SKILL.md) 참조.

## 3. Modern Android Development (MAD) 구성요소

공식이 현재 권장하는 기술 스택. 새 코드는 최신·최고 성능 컴포넌트를 기본값으로.

- **Kotlin** — 상위 1000개 앱의 95%+ 사용. 언어 기본값.
- **Jetpack Compose** — 선언형 UI 툴킷. 적응형 레이아웃 지원.
- **Jetpack** — 모범 사례를 구현한 라이브러리 모음(ViewModel, Navigation, Room,
  WorkManager, Lifecycle 등).
- **Coroutines / Flow** — 비동기·스트림의 기본(강력 권장).
- **Hilt** — 의존성 주입(권장). 컴파일 타임 의존성 검증.
- **Android Studio** — 공식 IDE(Compose 도구, Gradle 빌드, 에뮬레이터).
- **최신 SDK 타깃** — 최신 API/기술 사용.
- **아키텍처·테스트 모범 사례** — 모듈화·테스트 가능·확장 가능 설계.

폼팩터(폰/태블릿/폴더블/ChromeOS/차량/XR) 전반에서 동작하는 적응형 레이아웃 지향.

## 4. 공식 권장사항 우선순위 표

`강력 권장(Strongly Recommended)` vs `권장(Recommended)` vs `선택(Optional)`.

### 레이어드 아키텍처
| 권장 | 우선순위 |
|------|----------|
| 명확한 데이터 레이어 사용 | 강력 권장 |
| 명확한 UI 레이어 사용 | 강력 권장 |
| 리포지토리로 앱 데이터 노출 | 강력 권장 |
| 코루틴·플로우 사용 | 강력 권장 |
| 도메인 레이어 사용 | 권장(큰 앱) |

### UI 레이어 / ViewModel
| 권장 | 우선순위 |
|------|----------|
| UDF(단방향 데이터 흐름) 따르기 | 강력 권장 |
| AAC ViewModel 사용 | 강력 권장 |
| `collectAsStateWithLifecycle`로 생명주기 인지 수집 | 강력 권장 |
| ViewModel→UI로 이벤트 보내지 않기 | 강력 권장 |
| 단일 Activity 앱 | 강력 권장 |
| Jetpack Compose 사용 | 강력 권장 |
| ViewModel을 안드로이드 생명주기와 독립 유지 | 강력 권장 |
| ViewModel은 화면 수준에서 사용 | 강력 권장 |
| 재사용 UI 컴포넌트는 평범한 상태 홀더 클래스 | 강력 권장 |
| `AndroidViewModel` 사용 안 함 | 권장 |
| UI State 노출 | 권장 |

### 생명주기 / DI / 테스트 / 모델
| 권장 | 우선순위 |
|------|----------|
| Activity 콜백 오버라이드 대신 생명주기 인지 이펙트 사용 | 강력 권장 |
| 의존성 주입 사용 | 강력 권장 |
| 필요 시 컴포넌트에 스코프 지정 | 강력 권장 |
| Hilt 사용 | 권장 |
| 무엇을 테스트할지 알기 | 강력 권장 |
| mock보다 fake 선호 | 강력 권장 |
| StateFlow 테스트 | 강력 권장 |
| 복잡 앱은 레이어별 모델 생성 | 권장 |

생명주기 이펙트/메모리 상세 → [android-lifecycle-memory](../android-lifecycle-memory/SKILL.md).
백그라운드 작업 규칙 → [android-background-rules](../android-background-rules/SKILL.md).
보안·신뢰 경계 → [android-security](../android-security/SKILL.md).

## References

공식 문서(리다이렉트/404 없음, 최종 URL 유지):

- 앱 아키텍처 개요: https://developer.android.com/topic/architecture
- UI 레이어: https://developer.android.com/topic/architecture/ui-layer
- 도메인 레이어: https://developer.android.com/topic/architecture/domain-layer
- 데이터 레이어: https://developer.android.com/topic/architecture/data-layer
- 아키텍처 권장사항: https://developer.android.com/topic/architecture/recommendations
- Modern Android Development: https://developer.android.com/modern-android-development

프로젝트 문서:

- 팀 가이드라인(상위 문서): [../../guidance.md](../../guidance.md)
- 상위 스킬: [SKILL.md](./SKILL.md)
