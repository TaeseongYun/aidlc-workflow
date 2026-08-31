# Android Module Structure — detailed reference (reference)

Deeper material for `SKILL.md`. Holds the rationale for the rules and hands-on
examples. The rules themselves are canonical in `SKILL.md`.

## 1. Full dependency matrix

Whether a row may depend on a column. `O` allowed, `–` forbidden (reverse/cycle),
blank means N/A.

| depends →<br>module ↓ | app | feature:\<n>:api | feature:\<n>:impl | core:domain | core:data | core:model | core:designsystem |
|---|---|---|---|---|---|---|---|
| **app** | – | O | O | O | O | O | O |
| **feature:\<n>:api** | – | –¹ | – | – | – | O | – |
| **feature:\<n>:impl** | – | O² | –³ | O | O | O | O |
| **core:domain** | – | – | – | – | O | O | |
| **core:data** | – | – | – | – | – | O | |
| **core:model** | – | – | – | – | – | – | – |
| **core:designsystem** | – | – | – | – | – | O | – |

¹ An `api` module never depends on another feature's `api` — contracts stay
independent. A payload type two contracts need lives in `core:model`.
² A feature's `impl` depends on its own `api` and on **other features' `api`**
(to navigate into them).
³ `impl` → another feature's `impl` is forbidden everywhere except `app`.

Core invariants:
- Dependencies flow **top to bottom only**: `app → feature → core:domain → core:data → core:model`.
- `core:model` is a leaf — depends on nothing and has no Android deps.
- `app` is the only module that knows every `impl` (mediator/assembler role): it
  wires DI and merges manifests.

## 2. The api/impl pair

Every feature is created as the pair — `settings.gradle.kts`:

```kotlin
include(":feature:home:api")
include(":feature:home:impl")
include(":feature:search:api")
include(":feature:search:impl")
```

### What goes in `api`

Only the navigation surface. A complete `:feature:home:api` is typically 2–4 files:

```kotlin
// feature/home/api/src/main/kotlin/.../HomeNavigation.kt
const val HOME_ROUTE = "home"                       // navigation key / route contract

data class HomeArgs(val userId: String)             // Intent extras, typed

fun createHomeIntent(context: Context, args: HomeArgs): Intent =
    Intent(ACTION_HOME).apply {
        setPackage(context.packageName)
        putExtra(EXTRA_USER_ID, args.userId)
    }

class HomeResultContract : ActivityResultContract<HomeArgs, HomeResult?>() { /* … */ }
```

A caller depends only on `:feature:home:api` and can launch the feature —
`api` carries the Intent factory, so it is an Android library, but its
dependency list stays at `core:model` plus the minimal AndroidX core it needs
for `Intent`/`Context`.

### What goes in `impl`

Everything else: the exported entry `Activity` (with its `intent-filter` and
extras validation per `guidance.md`), screens, ViewModels, UiState, in-feature
Compose navigation, and Hilt bindings.

```kotlin
// feature/home/impl/build.gradle.kts
plugins { alias(libs.plugins.myapp.android.feature) }
dependencies {
    implementation(project(":feature:home:api"))     // its own contract
    implementation(project(":feature:search:api"))   // navigates into search — api only
}
```

```kotlin
// app/build.gradle.kts — the only module that sees impls
dependencies {
    implementation(project(":feature:home:impl"))
    implementation(project(":feature:search:impl"))
    // variant-swapped implementations also live here:
    debugImplementation(project(":core:database:impl-room"))
    releaseImplementation(project(":core:database:impl-firestore"))
}
```

### Why always the pair

- Uniform shape: every feature looks the same, so navigation wiring, reviews,
  and codegen never special-case "is this one split yet?".
- The contract boundary exists from day one, so a second consumer never forces
  a wedge refactor through a feature's internals.
- The compile-time firewall (`impl` invisible outside `app`) makes the
  Intent-first convention in `guidance.md` structurally enforceable.

## 3. Convention plugin (build-logic)

Removes per-module build config duplication.

Keep `build-logic/` as a separate included build, extract reusable config into
plugins, and have each module apply them by id in `plugins { }`.

```kotlin
// build-logic/convention/build.gradle.kts
plugins { `kotlin-dsl` }

gradlePlugin {
    plugins {
        register("androidLibrary") {
            id = "myapp.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidFeatureApi") {
            id = "myapp.android.feature.api"      // minimal: android lib + core:model
            implementationClass = "AndroidFeatureApiConventionPlugin"
        }
        register("androidFeature") {
            id = "myapp.android.feature"          // impl: compose + hilt + core deps
            implementationClass = "AndroidFeatureConventionPlugin"
        }
    }
}
```

```kotlin
// build-logic/.../AndroidFeatureConventionPlugin.kt (gist — applied by impl modules)
class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("myapp.android.library")
        pluginManager.apply("myapp.android.hilt")
        dependencies {
            "implementation"(project(":core:designsystem"))
            "implementation"(project(":core:data"))
            "implementation"(project(":core:model"))
            // Compose, ViewModel, Navigation, etc. — common feature deps
        }
    }
}
```

```kotlin
// feature/<name>/impl/build.gradle.kts — the consumer side is just this much
plugins { alias(libs.plugins.myapp.android.feature) }
// feature/<name>/api/build.gradle.kts
plugins { alias(libs.plugins.myapp.android.feature.api) }
```

Rule: a new module just applies the appropriate convention plugin. Don't rewrite
in the module the config the plugin already covers (compileSdk, Compose setup,
Hilt wiring, common deps).

## 4. Version catalog (gradle/libs.versions.toml)

The single source of truth for versions/coordinates/plugins. Gradle's default
location is `gradle/libs.versions.toml` at the root.

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

[plugins]
android-application = { id = "com.android.application", version.ref = "androidGradlePlugin" }
android-library     = { id = "com.android.library", version.ref = "androidGradlePlugin" }
hilt                = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
```

Reference from a module build (instead of hardcoding):

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

kebab-case keys (`androidx-core-ktx`) are exposed as dot notation
(`libs.androidx.core.ktx`) in the type-safe accessors. Migrate incrementally:
add an entry to the catalog → sync → replace the string declaration with the
accessor.

## 5. Module type selection

- **Kotlin/Java module**: when Android resources/manifest aren't needed (e.g.
  `core:model`, pure domain/util). Lowest overhead — consider first.
- **Android library module (AAR)**: needs resources/manifest or Android types —
  `core:designsystem`, every `feature:*:api` (Intent factories) and
  `feature:*:impl`.
- **Android app module (APK/AAB)**: the entry point. Split per platform
  (Auto/Wear/TV) to isolate platform deps.

## 6. Rationale summary

- High cohesion, low coupling: if two modules must often know each other's
  internals, they're one system. If parts within one module barely interact,
  split them.
- The api/impl pair keeps coupling at the navigation contract — the narrowest
  surface two features can share — and makes everything else invisible at
  compile time.
- Inter-feature data goes through a shared `core:data` module; navigation
  passes a raw ID, not an object.
- Config consistency is enforced with a version catalog + convention plugins.

Sources:
- https://developer.android.com/topic/modularization
- https://developer.android.com/topic/modularization/patterns
- https://developer.android.com/build/migrate-to-catalogs
- Team baseline: [../../guidance.md](../../guidance.md)
