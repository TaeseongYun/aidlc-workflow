---
name: android-module-structure
description: 안드로이드 모듈 구조/모듈화 (Android module structure) 참조 규칙 — app/core/feature 분리, api|impl 분리 시점, convention plugin과 버전 카탈로그(version catalog) 컨벤션을 판단할 때 사용. `platforms/android/guidance.md`의 Module Baseline과 DI 절을 상세 확장한다. 새 모듈을 만들거나, feature를 api|impl로 쪼갤지 결정하거나, core:domain을 도입할지 판단하거나, build.gradle.kts/settings.gradle.kts/libs.versions.toml을 손댈 때, 그리고 god-module·feature가 다른 feature의 impl을 참조하는 등 모듈 경계 리팩터 신호를 볼 때 참조. Use for Android modularization: deciding when to add a module, when to split api|impl, when to introduce a domain layer, convention-plugin and version-catalog conventions.
when_to_use: 안드로이드 모듈 경계를 신설/분리/병합하거나 Gradle 모듈 빌드 구성을 판단할 때
paths: **/build.gradle.kts, **/settings.gradle.kts, **/libs.versions.toml, **/*.gradle
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android 모듈 구조 (Module Structure)

`platforms/android/guidance.md`의 **Module Baseline**과 **DI** 절을 실행 판단이
가능한 수준으로 확장한 참조 규칙. 새 모듈을 만들지, feature를 `api|impl`로 쪼갤지,
`core:domain`을 도입할지, convention plugin과 버전 카탈로그를 어떻게 쓸지 판단할 때
읽는다. 항상 켜져 있는 참조 문서이며 단계별 절차서가 아니다.

## Scope

- 대상: 모듈 경계의 신설/분리/병합, 모듈 간 의존 방향, convention plugin과
  버전 카탈로그 컨벤션.
- 비대상: 레이어 내부 규칙(UiState·ViewModel·Hilt 바인딩 세부, Intent 계약).
  그건 `guidance.md`의 Boundaries / Feature Slice / DI 절이 담당한다.
- 기본은 제품 규모 앱을 위한 모듈 분리다. 소형 앱은 접어서 시작한다 — 필요 신호가
  올 때만 편다.

## 모듈 지도

```
app                      # 얇은 껍데기: manifest, DI 배선, 진입 Activity만
core/designsystem        # theme, tokens, 공용 composable
core/model               # 도메인 모델, Android 의존 없음(Kotlin/Java 모듈)
core/domain              # use case — 오케스트레이션이 실제로 존재할 때만
core/data                # repository, data source, DTO 매핑
feature/<name>           # 기본은 단일 모듈
feature/<name>/api|impl  # 다른 feature가 의존할 때만 분리
build-logic              # convention plugin
```

의존 방향(절대 역류 금지):

```
app -> feature/* -> core/domain(선택) -> core/data -> core/model
feature/*, core/data, core/domain -> core/designsystem/model 등 core 하위
```

전체 의존 매트릭스와 각 규칙의 근거는 [reference.md](reference.md) 참조.

## Core rules (do / don't)

- **DO** `app`을 최소로 유지 — manifest, DI 배선(Hilt), 진입 Activity, 최상위
  네비게이션 배선만. 화면 로직·비즈니스 로직·수동 객체 생성 금지.
- **DO** 새 모듈은 기존 convention plugin 셋업을 따른다. convention plugin이
  이미 덮는 per-module 빌드 구성을 손으로 다시 쓰지 않는다.
- **DO** 버전과 플러그인은 `gradle/libs.versions.toml` 한 곳에서 관리하고
  모듈 빌드는 `libs.*`/`alias(libs.plugins.*)`로만 참조한다. 하드코딩 금지.
- **DO** Android 리소스가 필요 없는 모듈(`core:model`, 순수 도메인)은 Android
  라이브러리가 아니라 Kotlin/Java 모듈로 만든다 — 빌드 오버헤드가 낮다.
- **DO** 노출은 최소로. 모듈 경계에서 구현은 `internal`/`private`로 숨기고,
  의존은 `api`보다 `implementation`을 기본으로 쓴다(전이 노출·빌드시간 감소).
- **DON'T** `api`/`impl`·`domain` 분리를 "나중을 위해" 선제 도입하지 않는다.
  두 번째 소비자나 플랫폼 의존이 강제할 때 편다.
- **DON'T** feature가 다른 feature를 직접 참조하지 않는다. feature 간 연결은
  Intent 계약(외부 노출) 또는 공유 `core:data`를 경유한다 — 원시 ID를 넘기고
  객체를 넘기지 않는다.
- **DON'T** 의존 방향을 역류시키지 않는다(`core`가 `feature`를, `data`가 `app`을
  참조하는 순환·역참조 금지).

## 모듈 결정 테이블

| 상황 | 판단 |
|------|------|
| 새 화면/기능이 하나 생김 | `feature/<name>` 단일 모듈. 아직 `api|impl` 나누지 않는다 |
| 두 번째 feature가 이 feature의 무언가에 의존 | 그 계약만 `feature/<name>/api`로 뽑고 나머지는 `impl`. api는 인터페이스·모델만 |
| 빌드 변형/플랫폼별로 구현을 갈아끼워야 함 | 의존성 역전: `api` 모듈 + `impl:xxx` 모듈들, app이 DI로 주입 |
| repository가 여러 데이터 소스를 조율/재사용 규칙 발생 | `core:data`에 repository 추가. data source는 `internal`로 은닉 |
| ViewModel을 넘는 멀티소스 오케스트레이션·재사용 비즈니스 규칙 | `core:domain`에 use case 도입 |
| 단순 상태 매핑뿐, 조율 없음 | `core:domain` 도입하지 않는다 — ViewModel이 repository 직접 사용 |
| 위젯·테마·포매터·분석 등 여러 모듈이 공유하는 횡단 코드 | `core/<name>`(designsystem/analytics/network 등) 공용 모듈 |
| Android Auto/Wear/TV 등 플랫폼별 진입점 | 별도 app 모듈로 플랫폼 의존 격리 |

새 모듈은 항상 "맞는 가장 작은 슬라이스"에서 시작하고, 추측이 아니라 실제 신호
(두 번째 소비자·플랫폼 의존·순환 회피)가 올 때만 승격한다.

## Refactor / red-flag 신호

- **god-module**: 한 모듈이 계속 커져 서로 자주 상호작용하지 않는 코드까지
  품는다 → 응집도 낮은 경계에서 쪼갠다.
- feature가 다른 feature의 `impl`을 참조 → Intent/`api` 계약으로 되돌린다.
- `feature/<name>` 경계가 있던 자리가 하나로 뭉개진 병합 god-module.
- 두 feature가 서로 통신하려고 순환/직접 의존 → 공유 `core:data`로 매개하고
  객체 대신 원시 ID 전달.
- convention plugin이 덮는 빌드 구성을 모듈마다 손으로 복붙.
- `core:model`/도메인 모듈에 Android 의존이 스며듦.
- 버전·좌표를 모듈 빌드에 하드코딩(버전 카탈로그 우회).
- 소비자가 하나뿐인데 존재하는 `api|impl` 분리나 use case 없는 `core:domain`
  → 접어서 오버헤드를 줄인다.

## References

- 상세 자료(전체 의존 매트릭스, convention plugin 예시, 버전 카탈로그 스니펫):
  [reference.md](reference.md)
- 팀 베이스라인: [../../guidance.md](../../guidance.md)
- 공식 문서:
  - Modularization 개요 — https://developer.android.com/topic/modularization
  - Modularization 패턴 — https://developer.android.com/topic/modularization/patterns
  - 버전 카탈로그 마이그레이션 — https://developer.android.com/build/migrate-to-catalogs
  - Now in Android 샘플 — https://github.com/android/nowinandroid
