# Android Module Structure — detailed reference (reference)

Deeper material for `SKILL.md`. Holds the rationale for the rules and hands-on
examples. The rules themselves are canonical in `SKILL.md`.

## 1. Full dependency matrix

Whether a row may depend on a column. `O` allowed, `–` forbidden (reverse/cycle),
blank means N/A.

| depends →<br>module ↓ | app | feature/* | core:domain | core:data | core:model | core:designsystem |
|---|---|---|---|---|---|---|
| **app** | – | O | O | O | O | O |
| **feature/\<n>** | – | –¹ | O | O | O | O |
| **feature/\<n>:api** | – | –¹ | | | O | |
| **feature/\<n>:impl** | – | –¹ | O | O | O | O |
| **core:domain** | – | – | – | O | O | |
| **core:data** | – | – | – | – | O | |
| **core:model** | – | – | – | – | – | – |
| **core:designsystem** | – | – | – | – | | – |

¹ A feature does not reference another feature directly. If needed, go through that
feature's `api` (interfaces/models only) or shared `core:data`, and app wires/injects the `impl`.

Core invariants:
- Dependencies flow **top to bottom only**: `app → feature → core:domain → core:data → core:model`.
- `core:model` is a leaf — depends on nothing and has no Android deps.
- app is the only module that knows features and impls (mediator/assembler role).

## 2. api|impl split and dependency inversion

Background for the `SKILL.md` decision table.

- **When**: (a) a second feature depends on something in this feature, (b)
  implementation must be swapped per build variant/platform, (c) an independent team
  develops in parallel against the contract alone.
- **`api` module**: interfaces/models (the contract) only. Minimal Android deps.
- **`impl` module**: the concrete implementation. Depends on `api`.
- **app**: injects the implementation per build variant via DI.

```kotlin
// app/build.gradle.kts — inject implementation per variant
dependencies {
    implementation(project(":feature:checkout:api"))
    releaseImplementation(project(":database:impl:firestore"))
    debugImplementation(project(":database:impl:room"))
    androidTestImplementation(project(":database:impl:mock"))
}
```

The consumer (feature) depends only on `api` and doesn't know the concrete
implementation.

## 3. Convention plugin (build-logic)

Removes per-module build config duplication. The same pattern as Now in Android.

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
// build-logic/.../AndroidFeatureConventionPlugin.kt (gist)
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
// feature/<name>/build.gradle.kts — the consumer side is just this much
plugins {
    alias(libs.plugins.myapp.android.feature)
}
```

Rule: a new module just applies the appropriate convention plugin. Don't rewrite in
the module the config the plugin already covers (compileSdk, Compose setup, Hilt
wiring, common deps).

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

[bundles]
# group dependencies that are often used together
compose = ["androidx-core-ktx"]

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
(`libs.androidx.core.ktx`) in the type-safe accessors. Migrate incrementally: add an
entry to the catalog → sync → replace the string declaration with the accessor.

## 5. Module type selection

- **Kotlin/Java module**: when Android resources/manifest aren't needed (e.g.
  `core:model`, pure domain/util). Lowest overhead — consider first.
- **Android library module (AAR)**: reusable module that needs resources/manifest
  (`core:designsystem`, feature).
- **Android app module (APK/AAB)**: the entry point. Split per platform (Auto/Wear/TV)
  to isolate platform deps.

## 6. Rationale summary (Android official)

- High cohesion, low coupling: if two modules must often know each other's
  internals, they're one system. If parts within one module barely interact, split them.
- Too fine-grained produces excessive build complexity/boilerplate; too
  coarse-grained is a monolith again. Modularization can be overkill for a small project.
- Inter-feature communication goes through a shared data module; navigation passes a
  raw ID, not an object.
- Config consistency is enforced with a version catalog + convention plugins.

Sources:
- https://developer.android.com/topic/modularization
- https://developer.android.com/topic/modularization/patterns
- https://developer.android.com/build/migrate-to-catalogs
- https://github.com/android/nowinandroid
- Team baseline: [../../guidance.md](../../guidance.md)
