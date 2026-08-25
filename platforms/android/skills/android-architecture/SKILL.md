---
name: android-architecture
description: 안드로이드 아키텍처 · 앱 아키텍처 가이드 · UI/도메인/데이터 레이어 · 단방향 데이터 흐름(UDF) · MVVM/MVI · 권장 아키텍처(Android app architecture)의 뼈대 참조. 의존 흐름(Screen/Composable → Action → ViewModel → UseCase(선택) → Repository → DataSource/Platform Adapter, 역방향 금지), 레이어 책임, 작은 능력 인터페이스 우선(ISP/DIP), 리포지토리는 도메인 모델 반환, 플랫폼 SDK는 어댑터 뒤로, Feature Slice 결정 표를 다룬다. 안드로이드 아키텍처를 설계·리뷰·리팩터할 때, 또는 어떤 슬라이스(Composable만/MVVM/UseCase/MVI)로 갈지 판단할 때 사용. 다른 다섯 개 안드로이드 스킬을 묶는 우산 스킬.
when_to_use: 안드로이드 앱 아키텍처 설계, 레이어 경계 판단, ViewModel/Repository 배치, UDF/MVVM/MVI 선택, 아키텍처 리팩터·리뷰, "어떤 feature slice를 쓸까" 결정 시. Android architecture / app architecture / clean architecture / layered architecture 요청에도.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# android-architecture — 앱 아키텍처 뼈대

안드로이드 아키텍처의 척추: 의존 흐름과 레이어 책임을 항상 참조하는 규칙으로
고정한다. 프로젝트 `ctx/`가 이 스킬을 덮고, 이 스킬이 에이전트 일반 지식을 덮는다.
심화 자료(레이어 책임 상세 표, MVI/reducer 샘플, MAD 구성요소, 공식 권장 우선순위
표)는 [reference.md](./reference.md)에.

## Scope

- 대상: 새 안드로이드 기능/앱의 레이어 배치, 의존 방향, 슬라이스 선택, 리팩터
  판단. Kotlin · Compose · ViewModel · Coroutines/Flow · Hilt 기준.
- 비대상: ViewModel 상태/이펙트 모델링 세부, 모듈 분리 규칙, 생명주기/메모리,
  백그라운드 작업, 보안 — 각각 아래 Related skills로 위임.

## Core rules — 의존 흐름과 레이어 책임

공식 권장 아키텍처: 최소 2개 레이어(UI, 데이터) + 선택적 도메인. 의존은 위→아래
단방향, **절대 역방향 금지**.

```
Screen/Composable → Action → ViewModel → UseCase(선택) → Repository → DataSource / Platform Adapter
```

### Do

- **Composable**: `UiState`를 렌더하고 액션을 방출한다. `StateFlow`는
  `collectAsStateWithLifecycle()`로 생명주기 인지 수집.
- **ViewModel**: 화면 상태를 하나의 `UiState`(data class 또는 sealed)로 소유하고
  `StateFlow`로 노출. 1회성 이벤트는 상태가 아니라 `SharedFlow`/`Channel` 이펙트
  스트림으로. UDF를 따른다(상태는 아래로, 이벤트는 위로).
- **작은 능력 인터페이스**를 delegate로 조합(예: `NoticeSink`, `RouteEventSink`).
  넓은 베이스 ViewModel 상속 트리보다 ISP/DIP.
- **UseCase(선택)**: 복잡한 로직 또는 여러 ViewModel이 재사용하는 규칙일 때만.
  `현재형동사+명사+UseCase`, `operator invoke`, 가변 상태 없음, main-safe.
- **Repository**: 도메인 모델을 반환한다. DTO/API/안드로이드 타입 금지. 매핑은
  데이터 레이어 경계에서. 리포지토리가 데이터 레이어의 유일한 진입점.
- **Platform Adapter**: 플랫폼 SDK 호출(카메라, 위치, 결제, 알림)은 프로젝트 소유
  어댑터 인터페이스 뒤에 두고, 필요한 레이어에 주입.
- I/O는 주입된 디스패처(`@IoDispatcher`)로. 하드코딩 `Dispatchers.IO` 금지.

### Don't

- Composable이 Repository/SDK를 직접 호출 → 금지.
- ViewModel이 `View`/`Activity`/`Fragment`/Compose 타입 참조 → 금지
  (`Application`/`SavedStateHandle`는 허용). `AndroidViewModel`도 피한다.
- Repository가 DTO나 안드로이드 타입을 그대로 노출 → 금지.
- `UiState`를 nullable 필드 뭉치로 → 금지. 불가능 상태를 표현 불가로 만든다
  (sealed loading/content/error).
- 하위 레이어가 상위 레이어를 의존 → 금지(역방향 의존).

## Feature Slice Decision Table

맞는 가장 **작은** 슬라이스에서 시작. 추측이 아니라 **실제 신호**가 있을 때만 위로
올린다.

| 상황 | 슬라이스 | 올리는 신호 |
|------|----------|-------------|
| 무상태 UI 또는 로컬 `remember`만 | Composable만, ViewModel 없음 | 화면 상태 or 비동기 데이터가 생김 |
| 화면 상태 + 비동기 데이터 | MVVM: Route → ViewModel → Screen | 다중 소스 조합 or 규칙 재사용 발생 |
| 다중 소스 조합 또는 재사용되는 비즈니스 규칙 | + UseCase → Repository → DataSource | 낙관적 업데이트 or 복잡한 동시성 |
| 낙관적 업데이트, 복잡한 동시성 | MVVM 위에 Reducer/MVI | — (최상단) |

- 시작은 최소 슬라이스. **먼저 만들지 말 것**: 두 번째 소비자나 플랫폼 의존이
  강제하기 전엔 `UseCase`·도메인 레이어를 넣지 않는다.
- 단순 데이터 위임만 하는 UseCase는 만들지 않는다(과설계).
- MVI/reducer 샘플은 [reference.md](./reference.md) §2.

## Refactor / red-flag signals

- Composable이 Repository나 SDK를 직접 호출.
- ViewModel이 `android.view`/Compose 타입을 import, 또는 Activity가 Intent
  파싱/검증을 넘어 비즈니스 로직 보유.
- `UiState`가 모델링된 상태 대신 독립 nullable 다수.
- 하위 레이어가 상위를 의존하거나, 한 기능이 다른 기능의 `impl`을 파고듦.
- Repository가 DTO/안드로이드 타입을 노출.
- Hilt가 이미 제공하는 것을 Activity에서 수동 생성.
- 단순 위임만 하는 UseCase, 또는 존재 이유 없는 넓은 베이스 ViewModel.

## Related skills

우산 스킬. 각 레이어/관심사 세부는 아래로 드릴다운:

- [android-viewmodel-state](../android-viewmodel-state/SKILL.md) — UiState/이펙트/StateFlow 모델링.
- [android-module-structure](../android-module-structure/SKILL.md) — 모듈 경계, `api`/`impl` 분리, Hilt/DI 배치.
- [android-lifecycle-memory](../android-lifecycle-memory/SKILL.md) — 생명주기 인지 수집, 누수·메모리.
- [android-background-rules](../android-background-rules/SKILL.md) — WorkManager vs 코루틴, 디스패처.
- [android-security](../android-security/SKILL.md) — exported 컴포넌트 신뢰 경계, extras 검증.

## References

- 팀 가이드라인(상위 문서): [../../guidance.md](../../guidance.md)
- 심화 자료: [reference.md](./reference.md)
- 앱 아키텍처: https://developer.android.com/topic/architecture
- UI 레이어: https://developer.android.com/topic/architecture/ui-layer
- 도메인 레이어: https://developer.android.com/topic/architecture/domain-layer
- 데이터 레이어: https://developer.android.com/topic/architecture/data-layer
- 아키텍처 권장사항: https://developer.android.com/topic/architecture/recommendations
- Modern Android Development: https://developer.android.com/modern-android-development
