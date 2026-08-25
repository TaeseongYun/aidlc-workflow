# Android 모듈 구조 — 상세 참조 (reference)

`SKILL.md`의 심화 자료. 규칙의 근거와 손에 잡히는 예시를 담는다. 규칙 자체는
`SKILL.md`가 정본이다.

## 1. 전체 의존 매트릭스

행이 열에 의존할 수 있는지. `O` 허용, `–` 금지(역류/순환), 공란 무관.

| 의존 →<br>모듈 ↓ | app | feature/* | core:domain | core:data | core:model | core:designsystem |
|---|---|---|---|---|---|---|
| **app** | – | O | O | O | O | O |
| **feature/\<n>** | – | –¹ | O | O | O | O |
| **feature/\<n>:api** | – | –¹ | | | O | |
| **feature/\<n>:impl** | – | –¹ | O | O | O | O |
| **core:domain** | – | – | – | O | O | |
| **core:data** | – | – | – | – | O | |
| **core:model** | – | – | – | – | – | – |
| **core:designsystem** | – | – | – | – | | – |

¹ feature는 다른 feature를 직접 참조하지 않는다. 필요하면 그 feature의
`api`(인터페이스·모델만) 또는 공유 `core:data`를 경유하고, app이 `impl`을 배선/주입한다.

핵심 불변식:
- 의존은 **위에서 아래로만** 흐른다: `app → feature → core:domain → core:data → core:model`.
- `core:model`은 잎(leaf) — 아무것에도 의존하지 않고 Android 의존이 없다.
- app만이 feature와 impl을 아는 유일한 모듈이다(중재자/조립자 역할).

## 2. api|impl 분리와 의존성 역전

`SKILL.md` 결정 테이블의 배경.

- **언제**: (a) 두 번째 feature가 이 feature의 무언가에 의존, (b) 빌드 변형/
  플랫폼별로 구현을 갈아끼워야 함, (c) 독립 팀이 계약만 보고 병렬 개발.
- **`api` 모듈**: 인터페이스·모델(계약)만. Android 의존 최소.
- **`impl` 모듈**: 구체 구현. `api`에 의존.
- **app**: 빌드 변형별로 구현을 DI로 주입.

```kotlin
// app/build.gradle.kts — 변형별 구현 주입
dependencies {
    implementation(project(":feature:checkout:api"))
    releaseImplementation(project(":database:impl:firestore"))
    debugImplementation(project(":database:impl:room"))
    androidTestImplementation(project(":database:impl:mock"))
}
```

소비자(feature)는 `api`에만 의존하고 구체 구현을 모른다.

## 3. Convention plugin (build-logic)

per-module 빌드 구성 중복을 없앤다. Now in Android과 동일한 패턴.

`build-logic/`은 별도 included build로 두고, 재사용 구성을 plugin으로 뽑아
각 모듈이 `plugins { }`에서 id로 적용한다.

```kotlin
// build-logic/convention/build.gradle.kts
plugins { `kotlin-dsl` }

gradlePlugin {
    plugins {
        register("androidLibrary") {
            id = "myapp.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidFeature") {
            id = "myapp.android.feature"
            implementationClass = "AndroidFeatureConventionPlugin"
        }
        register("androidHilt") {
            id = "myapp.android.hilt"
            implementationClass = "HiltConventionPlugin"
        }
    }
}
```

```kotlin
// build-logic/.../AndroidFeatureConventionPlugin.kt (요지)
class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("myapp.android.library")
        pluginManager.apply("myapp.android.hilt")
        dependencies {
            "implementation"(project(":core:designsystem"))
            "implementation"(project(":core:data"))
            "implementation"(project(":core:model"))
            // Compose, ViewModel, Navigation 등 feature 공통 의존
        }
    }
}
```

```kotlin
// feature/<name>/build.gradle.kts — 소비 측은 이만큼만
plugins {
    alias(libs.plugins.myapp.android.feature)
}
```

규칙: 새 모듈은 알맞은 convention plugin을 적용만 한다. plugin이 이미 덮는
구성(compileSdk, Compose 설정, Hilt 배선, 공통 의존)을 모듈에서 다시 쓰지 않는다.

## 4. 버전 카탈로그 (gradle/libs.versions.toml)

버전·좌표·플러그인의 단일 진실 원천. Gradle 기본 위치는
루트의 `gradle/libs.versions.toml`.

```toml
[versions]
androidGradlePlugin = "8.5.0"
kotlin = "2.0.0"
hilt = "2.51"
androidxCore = "1.13.1"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "androidxCore" }
hilt-android      = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler     = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }

[bundles]
# 자주 함께 쓰는 의존을 묶음으로
compose = ["androidx-core-ktx"]

[plugins]
android-application = { id = "com.android.application", version.ref = "androidGradlePlugin" }
android-library     = { id = "com.android.library", version.ref = "androidGradlePlugin" }
hilt                = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
```

모듈 빌드에서의 참조(하드코딩 대신):

```kotlin
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.hilt)
}
dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.hilt.android)
    // kapt/ksp(libs.hilt.compiler)
}
```

kebab-case 키(`androidx-core-ktx`)는 타입세이프 접근자에서 점 표기
(`libs.androidx.core.ktx`)로 노출된다. 마이그레이션은 점진적으로: 카탈로그에
항목 추가 → 싱크 → 문자열 선언을 접근자로 교체.

## 5. 모듈 타입 선택

- **Kotlin/Java 모듈**: Android 리소스·매니페스트 불필요할 때(예: `core:model`,
  순수 도메인/유틸). 오버헤드가 가장 낮다 — 우선 고려.
- **Android 라이브러리 모듈(AAR)**: 리소스·매니페스트가 필요한 재사용 모듈
  (`core:designsystem`, feature).
- **Android 앱 모듈(APK/AAB)**: 진입점. 플랫폼별(Auto/Wear/TV)로 나눠 플랫폼
  의존을 격리.

## 6. 근거 요약 (Android 공식)

- 고응집·저결합: 두 모듈이 서로의 내부를 자주 알아야 하면 한 시스템이다.
  한 모듈 안에서 서로 거의 상호작용 안 하면 나눈다.
- 너무 잘게 쪼개면(fine-grained) 빌드 복잡도·보일러플레이트 과다, 너무 크면
  (coarse-grained) 다시 모놀리스. 소형 프로젝트엔 모듈화가 과할 수 있다.
- feature 간 통신은 공유 data 모듈을 매개로, 네비게이션엔 객체가 아니라 원시
  ID를 넘긴다.
- 구성 일관성은 버전 카탈로그 + convention plugin으로 강제한다.

출처:
- https://developer.android.com/topic/modularization
- https://developer.android.com/topic/modularization/patterns
- https://developer.android.com/build/migrate-to-catalogs
- https://github.com/android/nowinandroid
- 팀 베이스라인: [../../guidance.md](../../guidance.md)
