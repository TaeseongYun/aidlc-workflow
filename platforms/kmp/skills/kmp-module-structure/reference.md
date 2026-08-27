# kmp-module-structure — Reference

Deep-dive for `SKILL.md`. Source-set trees, Koin DI scoping, Gradle module
split timing. Decision criteria live in `SKILL.md`.

## 1. Source-set tree (grow layers on demand)

```
shared/
  src/
    commonMain/kotlin/com/example/
      core/
        theme/          # MaterialTheme, ColorScheme, Typography, CompositionLocals
        widgets/        # shared, reusable Composables
        utils/          # pure Kotlin utilities
      data/             # shared Ktor clients, repositories, DTOs
      features/
        home/
          presentation/ # HomeScreen.kt, HomeViewModel.kt, HomeState.kt, HomeEffect.kt
          # domain/  — omitted: this feature has no use cases yet
          data/         # HomeRepository.kt (home-specific)
        checkout/
          presentation/
          domain/       # CheckoutUseCase.kt (exists → folder exists)
          data/
    androidMain/kotlin/com/example/
      # actual implementations for Android (BiometricAuth, SecureStorage, etc.)
    iosMain/kotlin/com/example/
      # actual implementations for iOS
    commonTest/kotlin/
    androidUnitTest/kotlin/
    iosTest/kotlin/
androidApp/             # Android host (Activity, Application)
iosApp/                 # iOS host (Swift/Xcode project)
```

- A layer folder appears **only when it has a file**. Empty `domain/`/`data/`
  scaffolding is over-engineering — add it when the first file lands.

## 2. Koin module scoping

```kotlin
// ✅ App-wide singletons in the root Koin module (config, Ktor client, auth)
val appModule = module {
    single { HttpClient(/* Ktor engine config */) }
    single { AuthRepository(get()) }
}

// ✅ Feature state in a feature-scoped Koin module — not global
val checkoutModule = module {
    // scoped: created when the feature scope opens, released when it closes
    scope<CheckoutScope> {
        scoped { CheckoutViewModel(get()) }
    }
}

// androidApp/Application.kt
startKoin {
    modules(appModule, homeModule, checkoutModule)
}
```

- Global everything → memory held for the app's life + hidden coupling. Scope
  feature state to where it's used.

## 3. Cross-feature dependencies

```
✅ features/checkout → core/widgets, core/domain/Money      (downward, via shared layers)
❌ features/checkout → features/home/presentation/...         (feature→feature internals)
```

- When two features need the same thing, lift it into `core` (has UI Composables)
  or `core/` domain models (pure Kotlin). Don't reach into another feature's folders.

## 4. expect/actual placement

```
commonMain/kotlin/
  core/platform/
    SecureStorage.kt        # expect class SecureStorage { ... }
    Logger.kt               # expect fun log(tag: String, msg: String)

androidMain/kotlin/
  core/platform/
    SecureStorage.android.kt   # actual class SecureStorage — EncryptedSharedPreferences
    Logger.android.kt          # actual fun log — Logcat / Kermit

iosMain/kotlin/
  core/platform/
    SecureStorage.ios.kt       # actual class SecureStorage — Keychain
    Logger.ios.kt              # actual fun log — NSLog / Kermit
```

- One `expect` per platform boundary; zero platform APIs in `commonMain`.

## 5. When to split into Gradle modules

Single `shared` module until a **real** second consumer:

| Trigger | Action |
|--------|--------|
| One app, growing feature count | stay single `shared` module, feature-first folders |
| A second app (e.g. companion/admin) shares KMP code | extract shared code to a new Gradle module |
| Publishing a KMP library / SDK | separate library Gradle module |
| Independent build/test/versioning genuinely needed | multi-module Gradle project |

```kotlin
// settings.gradle.kts — only once a second consumer exists
include(":shared", ":shared-auth", ":androidApp", ":iosApp-framework")
```

- Do not start multi-module "to be scalable". The split has real cost (wiring,
  Gradle sync overhead, CI) and pays off only with a second consumer.

## 6. Structure review checklist

- [ ] Layer folders exist only where they hold files (no empty scaffolding).
- [ ] `commonMain` domain models import no `android.*`, `androidx.*`, iOS platform, or Compose types.
- [ ] App-wide clients/config/auth at app scope; feature state in feature-scoped Koin modules.
- [ ] No feature→feature internal imports; shared code lives in `core`.
- [ ] Platform-specific code in `androidMain`/`iosMain` behind `expect`/`actual`.
- [ ] Single `shared` Gradle module unless a second app/library consumer exists.

## Official references

- KMP project structure: https://kotlinlang.org/docs/multiplatform-discover-project.html
- Source set hierarchy: https://kotlinlang.org/docs/multiplatform-hierarchy.html
- expect/actual: https://kotlinlang.org/docs/multiplatform-expect-actual.html
- Koin multiplatform: https://insert-koin.io/docs/reference/koin-mp/kmp
- Team baseline: [../../guidance.md](../../guidance.md)
