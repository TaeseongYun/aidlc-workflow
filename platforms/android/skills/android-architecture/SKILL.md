---
name: android-architecture
description: Android architecture · app architecture guidance · UI/domain/data layer · unidirectional data flow (UDF) · MVVM/MVI · skeleton reference for recommended Android app architecture. Covers dependency flow (Screen/Composable → Action → ViewModel → UseCase (optional) → Repository → DataSource/Platform Adapter, reverse direction forbidden), layer responsibilities, small capability interfaces first (ISP/DIP), repositories return domain models, platform SDKs behind adapters, and the Feature Slice decision table. Use when designing, reviewing, or refactoring Android architecture, or deciding which slice to take (Composable-only/MVVM/UseCase/MVI). Umbrella skill grouping the other five Android skills.
when_to_use: Designing Android app architecture, judging layer boundaries, placing ViewModel/Repository, choosing UDF/MVVM/MVI, refactoring/reviewing architecture, deciding "which feature slice to use". Also for Android architecture / app architecture / clean architecture / layered architecture requests.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# android-architecture — app architecture skeleton

The spine of Android architecture: pins the dependency flow and layer
responsibilities as always-referenced rules. Project `ctx/` overrides this skill,
and this skill overrides the agent's general knowledge. Deeper material (detailed
layer-responsibility table, MVI/reducer sample, MAD components, official
recommendation priority table) lives in [reference.md](./reference.md).

## Scope

- In scope: layer placement, dependency direction, slice selection, and refactor
  judgment for new Android features/apps. Based on Kotlin · Compose · ViewModel ·
  Coroutines/Flow · Hilt.
- Out of scope: ViewModel state/effect modeling details, module split rules,
  lifecycle/memory, background work, security — each delegated to the Related
  skills below.

## Core rules — dependency flow and layer responsibilities

Official recommended architecture: at least 2 layers (UI, data) + an optional
domain layer. Dependencies flow top → bottom, one-directional; **reverse
direction is strictly forbidden**.

```
Screen/Composable → Action → ViewModel → UseCase(optional) → Repository → DataSource / Platform Adapter
```

### Do

- **Composable**: renders `UiState` and emits actions. Collect `StateFlow`
  lifecycle-aware with `collectAsStateWithLifecycle()`.
- **ViewModel**: owns screen state as a single `UiState` (data class or sealed)
  and exposes it via `StateFlow`. One-shot events go through a
  `SharedFlow`/`Channel` effect stream, not through state. Follow UDF (state
  flows down, events flow up).
- **Small capability interfaces** composed via delegates (e.g. `NoticeSink`,
  `RouteEventSink`). ISP/DIP over a broad base ViewModel inheritance tree.
- **UseCase(optional)**: only for complex logic or rules reused by multiple
  ViewModels. `PresentTenseVerb+Noun+UseCase`, `operator invoke`, no mutable
  state, main-safe.
- **Repository**: returns domain models. No DTO/API/Android types. Mapping happens
  at the data layer boundary. The repository is the data layer's only entry point.
- **Platform Adapter**: platform SDK calls (camera, location, billing,
  notifications) sit behind a project-owned adapter interface, injected into the
  layer that needs it.
- I/O on injected dispatchers (`@IoDispatcher`). No hardcoded `Dispatchers.IO`.

### Don't

- Composable calling Repository/SDK directly → forbidden.
- ViewModel referencing `View`/`Activity`/`Fragment`/Compose types → forbidden
  (`Application`/`SavedStateHandle` allowed). Also avoid `AndroidViewModel`.
- Repository exposing DTOs or Android types as-is → forbidden.
- `UiState` as a bag of nullable fields → forbidden. Make illegal states
  unrepresentable (sealed loading/content/error).
- A lower layer depending on a higher layer → forbidden (reverse dependency).

## Feature Slice Decision Table

Start at the smallest slice that fits. Move up only on a **real signal**, not
speculation.

| Situation | Slice | Signal to move up |
|------|----------|-------------|
| Stateless UI or local `remember` only | Composable only, no ViewModel | Screen state or async data appears |
| Screen state + async data | MVVM: Route → ViewModel → Screen | Multi-source orchestration or rule reuse appears |
| Multi-source orchestration or reused business rules | + UseCase → Repository → DataSource | Optimistic updates or complex concurrency |
| Optimistic updates, complex concurrency | Reducer/MVI on top of MVVM | — (top) |

- Start at the minimal slice. **Do not build ahead**: do not add `UseCase`/domain
  layers until a second consumer or platform dependency forces it.
- Don't create a UseCase that only delegates data (over-engineering).
- MVI/reducer sample in [reference.md](./reference.md) §2.

## Refactor / red-flag signals

- Composable calling a Repository or SDK directly.
- ViewModel importing `android.view`/Compose types, or an Activity holding
  business logic beyond Intent parsing/validation.
- `UiState` with many independent nullables instead of modeled states.
- A lower layer depending on a higher one, or a feature reaching into another
  feature's `impl`.
- Repository exposing DTO/Android types.
- Manual construction in an Activity of something Hilt already provides.
- A UseCase that only delegates, or a broad base ViewModel with no reason to exist.

## Related skills

Umbrella skill. Drill down into per-layer/concern detail below:

- [android-viewmodel-state](../android-viewmodel-state/SKILL.md) — UiState/effect/StateFlow modeling.
- [android-module-structure](../android-module-structure/SKILL.md) — module boundaries, `api`/`impl` split, Hilt/DI placement.
- [android-lifecycle-memory](../android-lifecycle-memory/SKILL.md) — lifecycle-aware collection, leaks/memory.
- [android-background-rules](../android-background-rules/SKILL.md) — WorkManager vs coroutines, dispatchers.
- [android-security](../android-security/SKILL.md) — exported component trust boundary, extras validation.

## References

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Deeper material: [reference.md](./reference.md)
- App architecture: https://developer.android.com/topic/architecture
- UI layer: https://developer.android.com/topic/architecture/ui-layer
- Domain layer: https://developer.android.com/topic/architecture/domain-layer
- Data layer: https://developer.android.com/topic/architecture/data-layer
- Architecture recommendations: https://developer.android.com/topic/architecture/recommendations
- Modern Android Development: https://developer.android.com/modern-android-development
