---
name: kmp-architecture
description: KMP architecture · app-architecture skeleton reference rules. Covers dependency flow (Composable → Action → ViewModel/ScreenModel (StateFlow) → UseCase (optional) → Repository → DataSource / expect-actual platform adapter, never reversed), layer responsibilities, where screen state lives, domain models importing no platform types, native capability behind an expect/actual adapter, and the Feature Slice decision table. Feature-first source-set structure with a single ViewModel/ScreenModel approach (never mixed). Umbrella skill linking all 12 other KMP skills.
when_to_use: Designing KMP app architecture, judging layer boundaries, placing ViewModel/Repository/Adapter, deciding where state lives, choosing a feature slice, architecture refactor/review. Also for KMP/Compose Multiplatform app architecture, feature-first/clean architecture, ViewModel-vs-ScreenModel placement requests.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-architecture — app-architecture skeleton

The spine of a KMP app: dependency flow, layer responsibilities, and where
state lives, pinned as always-referenced rules. Project `ctx/` overrides this
skill, and this skill overrides the agent's general knowledge. Deeper material
(detailed layer responsibilities, expect/actual adapter samples, feature-slice
examples) lives in [reference.md](./reference.md).

## Scope

- In scope: layer placement, dependency direction, state home, slice selection,
  and refactor judgment for new KMP features. Feature-first source-set
  structure, one ViewModel/ScreenModel approach (whichever the project already
  uses — never mix two).
- Out of scope: state modeling detail, module/DI layout, Compose recomposition
  performance, navigation/expect-actual detail, security vulnerability patterns
  — each delegated to the Related skills below.

## Core rules — dependency flow and layer responsibilities

Dependency flows top→down, one-way, **never reversed**.

```
Composable → Action → ViewModel/ScreenModel (StateFlow) → UseCase (optional) → Repository → DataSource / expect-actual platform adapter
```

### Do

- **Composable**: render state and dispatch actions only. No business logic, no
  repository/client calls, no platform API access, no `if (platform == ...)` branching
  in `commonMain` code → [kmp-performance].
- **ViewModel/ScreenModel**: owns screen state as a single sealed/immutable
  `UiState` exposed via `StateFlow`. One-shot effects (snackbar, navigation)
  are emitted via `Channel<Effect>` or `SharedFlow`, not persisted in state →
  [kmp-state-management].
- **UseCase** (optional): business rules spanning repositories/aggregates. Skip
  for simple screens; add only on a real signal.
- **Repository**: returns domain models. DTO ↔ domain mapping lives in the data
  layer. Domain models import **no** Compose or platform types.
- **expect/actual platform adapter**: platform-specific capability lives behind
  an `expect` declaration in `commonMain` with an `actual` per platform source
  set (`androidMain`, `iosMain`, etc.). `commonMain` code never touches a
  platform API directly. This is the KMP analog of Flutter's platform-channel
  adapter → [kmp-navigation-platform].

### Don't

- Composable calling a Repository, API client, or platform API directly → forbidden.
- ViewModel/ScreenModel holding a `Context`, `Activity`, or Compose UI type → forbidden.
- Domain model importing `androidx.*`, `android.*`, `platform.*`, or Compose types → forbidden.
- Raw exceptions from a repository reaching a Composable (map to typed `UiState`) → forbidden.
- Two ViewModel/navigation/DI approaches active in the same codebase → forbidden.
- `commonMain` code directly calling a platform API without an `expect`/`actual` boundary → forbidden.
- A lower layer depending on a higher layer → forbidden (reversed dependency).

## Feature Slice Decision Table

Start at the **smallest** slice that fits. Move up only on a **real signal**, not
speculation.

| Situation | Slice | Signal to move up |
|-----------|-------|-------------------|
| Composable-local, ephemeral UI state | `remember` / `rememberSaveable` | State outlives one Composable or feeds business logic |
| Screen state + async data | ViewModel/ScreenModel + Repository | Rule spans repositories, or a platform/native call appears |
| Business rules across repositories / platform capability | + explicit UseCase, expect/actual adapter | Shared business state needed across screens |
| Shared state across screens | ViewModel scoped at feature/app level (Koin scope) | — (do not add a second state approach or a global store framework) |

- **Don't build ahead**: no UseCase layer, no Gradle module split, no second
  state approach before a real requirement forces it (over-engineering).
- Do not create a UseCase/ViewModel that only delegates.

## Refactor / red-flag signals

- A Composable calling a repository, API client, or platform API directly.
- Platform-specific code in `commonMain` without an `expect`/`actual` boundary.
- `UiState` modeled as a bag of parallel nullable fields.
- One-shot effect stored as a state field (reset to null after consumption).
- Business rules in a `@Composable` function body.
- Two ViewModel/ScreenModel/Decompose approaches or two DI libraries active together.
- Domain models importing `androidx.*`, Compose, or iOS platform types.

## Related skills

Umbrella skill. Drill down into each concern's detail below:

- [kmp-state-management](../kmp-state-management/SKILL.md) — sealed `UiState` · effects via `Channel`/`SharedFlow` · `StateFlow` UDF · ViewModel/ScreenModel
- [kmp-module-structure](../kmp-module-structure/SKILL.md) — source-set layout · Koin scoping · Gradle module split timing
- [kmp-performance](../kmp-performance/SKILL.md) — `@Stable`/`@Immutable` · recomposition scope · `derivedStateOf` · optimize on evidence
- [kmp-navigation-platform](../kmp-navigation-platform/SKILL.md) — Compose Navigation/Decompose/Voyager · deep-link validation · expect/actual adapters
- [kmp-security](../kmp-security/SKILL.md) — **vibe-coding security guard**: blocks vulnerable patterns in AI-generated code
- [kmp-design-system](../kmp-design-system/SKILL.md) — DTCG tokens → `MaterialTheme` · `CompositionLocal` · one theme
- [kmp-figma-to-code](../kmp-figma-to-code/SKILL.md) — Figma → Compose Multiplatform via DTCG tokens
- [kmp-accessibility](../kmp-accessibility/SKILL.md) — semantics, content descriptions, focus order, screen reader support
- [kmp-i18n](../kmp-i18n/SKILL.md) — `stringResource`/moko-resources, ICU plurals, locale-aware formatting, RTL
- [kmp-testing](../kmp-testing/SKILL.md) — `commonTest`, kotlin.test, Turbine, `runTest`, `runComposeUiTest`
- [kmp-observability](../kmp-observability/SKILL.md) — Kermit/Napier, structured logging, expect/actual crash reporting
- [kmp-contract-codegen](../kmp-contract-codegen/SKILL.md) — OpenAPI → Ktor client, Apollo Kotlin (GraphQL), drift guard

## References

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Deeper material: [reference.md](./reference.md)
- Kotlin Multiplatform: https://kotlinlang.org/docs/multiplatform.html
- Compose Multiplatform: https://www.jetbrains.com/compose-multiplatform/
- Koin multiplatform: https://insert-koin.io/docs/reference/koin-mp/kmp
