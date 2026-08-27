# kmp-architecture — Reference

Deeper material for `SKILL.md`. Detailed layer responsibilities · expect/actual
adapter · feature-slice samples. See `SKILL.md` for the rule summary and
decision criteria.

## 1. Detailed layer responsibilities

| Layer | Owns | Forbidden | Returns/Exposes |
|-------|------|-----------|-----------------|
| Composable | render `UiState`, dispatch actions | business logic, repo/client/platform calls, platform-check branches in `commonMain` | UI |
| ViewModel/ScreenModel | `UiState`, action→state, effect emission | `Context`/`Activity`, Compose UI types, DTO mapping | `StateFlow<UiState>` + `Flow<Effect>` |
| UseCase (optional) | business rules across repositories | platform imports, HTTP/DTO detail | domain result |
| Repository | domain-shaped data ops, DTO↔domain mapping | business rules, platform types | domain model / typed `Result` |
| expect/actual platform adapter | platform calls, error mapping, platform decision | business rules | domain model / adapter result |
| Domain model | invariants, value rules | `android.*`, `androidx.*`, iOS platform types, Compose types | pure Kotlin |

## 2. expect/actual platform adapter (the KMP platform boundary)

Platform functionality goes behind an `expect` declaration in `commonMain`.
`commonMain` code knows only the `expect` interface, never a platform API.

```kotlin
// commonMain — expect declaration: domain language, no platform API here
expect class BiometricAuth {
    suspend fun authenticate(): Boolean
}

// androidMain — actual for Android
actual class BiometricAuth {
    // BiometricPrompt lives here, invisible to commonMain
    actual suspend fun authenticate(): Boolean {
        return withContext(Dispatchers.Main) {
            try {
                AndroidBiometricHelper.prompt() // platform detail stays here
            } catch (e: BiometricException) {
                throw BiometricFailure(e.errorCode) // map platform error → domain failure
            }
        }
    }
}

// iosMain — actual for iOS
actual class BiometricAuth {
    actual suspend fun authenticate(): Boolean {
        return suspendCoroutine { cont ->
            LAContext().evaluatePolicy(...) { success, error ->
                if (success) cont.resume(true)
                else cont.resumeWithException(BiometricFailure(error?.localizedDescription))
            }
        }
    }
}
```

## 3. Repository returns domain, maps failures

```kotlin
// Repository maps DTO→domain and exception→typed failure.
// ViewModel never sees raw exceptions.
class OrderRepository(private val api: OrderApi) {
    suspend fun fetch(id: OrderId): Result<Order> = runCatching {
        api.getOrder(id.value).toDomain()   // DTO→domain mapping in the data layer
    }.mapFailure { e ->
        when (e) {
            is HttpException -> OrderFailure.Http(e.code)
            is SerializationException -> OrderFailure.Parse
            else -> OrderFailure.Unknown
        }
    }
}
```

- Domain `Order` imports no Compose or platform types. The ViewModel maps
  `OrderFailure` into its sealed `UiState` → [kmp-state-management](../kmp-state-management/SKILL.md).

## 4. Where state lives (summary)

| Situation | State home |
|-----------|-----------|
| Composable-local, ephemeral | `remember` / `rememberSaveable` |
| Screen state + async data | ViewModel/ScreenModel (`StateFlow<UiState>`) per screen |
| Shared/business state across screens | ViewModel scoped at feature/app level (Koin scope) |
| Remote data | Repository behind the ViewModel — Composables never call clients |

Full modeling detail → [kmp-state-management](../kmp-state-management/SKILL.md).

## 5. Module baseline

Feature-first within `commonMain`; follow the project's layout when one exists:

```
shared/src/
  commonMain/kotlin/
    core/               # shared domain models, utilities, expect declarations
    data/               # Ktor clients, repositories, DTOs
    features/<name>/
      presentation/     # Composables, ViewModel/ScreenModel, UiState, Effect
      domain/           # feature use cases / models (when they exist)
      data/             # feature repositories / sources (when they exist)
  androidMain/kotlin/   # actual implementations for Android
  iosMain/kotlin/       # actual implementations for iOS
```

Split into additional Gradle modules only when a second app or independent
consumer exists → [kmp-module-structure](../kmp-module-structure/SKILL.md).

## 6. Architecture review checklist

- [ ] No business logic / repo / client / platform calls in a Composable.
- [ ] ViewModel holds no `Context`, `Activity`, or Compose UI types.
- [ ] Domain models import no `android.*`, `androidx.*`, iOS platform, or Compose types.
- [ ] Repository returns domain models + typed failures (no raw exceptions to Composables).
- [ ] Platform capability behind an `expect`/`actual` boundary (no bare platform API in `commonMain`).
- [ ] Exactly one ViewModel/ScreenModel/navigation/DI approach in the codebase.
- [ ] Slices promoted on a real signal (no preemptive UseCase/module split).

## Official references

- Kotlin Multiplatform: https://kotlinlang.org/docs/multiplatform.html
- Compose Multiplatform: https://www.jetbrains.com/compose-multiplatform/
- expect/actual: https://kotlinlang.org/docs/multiplatform-expect-actual.html
- androidx.lifecycle.ViewModel (KMP): https://developer.android.com/topic/libraries/architecture/viewmodel
- Koin multiplatform: https://insert-koin.io/docs/reference/koin-mp/kmp
- Team baseline: [../../guidance.md](../../guidance.md)
