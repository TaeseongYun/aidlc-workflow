---
name: kmp-performance
description: KMP Compose Multiplatform performance and correctness rules (recomposition hygiene, coroutine/Flow safety, theme literals). @Stable/@Immutable on state objects, recomposition scope kept tight (derivedStateOf, remember, selective reads), no coroutine launched in composition without rememberCoroutineScope or LaunchedEffect, no business logic in composable functions, no expensive work in the composition phase, strings/colors/dimensions come from MaterialTheme and resources (no literals in feature composables), and optimization driven by evidence (Compose layout inspector / profiler) not speculation. Use when writing/reviewing/refactoring screens, composables, or when a recomposition/jank/coroutine-context issue is suspected.
when_to_use: When writing/reviewing composable functions, tightening recomposition scope, fixing jank, guarding coroutine/Flow context in composables, or removing literals in favor of theme/resources. Also for "composable rebuilds too much", "@Stable", "recomposition", "launched in composition", "no strings in composables".
paths: "**/*Screen.kt, **/*Composable*.kt, **/ui/**/*.kt, **/presentation/**/*.kt, **/commonMain/**/*.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-performance

Rules for composable recomposition hygiene, coroutine/Flow safety, and composition-phase
purity. The performance and correctness items from `guidance.md` expanded to an enforceable
level. Project `ctx/` overrides this document. Deeper material (stability samples,
`derivedStateOf`/`remember` patterns, profiling workflow) lives in [reference.md](./reference.md).

## Scope

- In scope: composable stability (`@Stable`/`@Immutable`), recomposition scope,
  `remember`/`derivedStateOf` usage, `LaunchedEffect`/`rememberCoroutineScope` discipline,
  composition-phase purity, theme/resource sourcing.
- Covers: keeping composition cheap and correct, tight recomposition, no side effects in composition.
- Doesn't cover: state modeling, module layout, navigation, security — follow the
  Related skills in [kmp-architecture](../kmp-architecture/SKILL.md).

## Core rules

Do:

- **Mark stable state with `@Stable` or `@Immutable`.** The Compose compiler skips
  recomposition for composables whose parameters are provably stable. Annotate `data class`
  `UiState` with `@Immutable`; annotate classes with `@Stable` when all public properties
  are `val` and are themselves stable types. Use `ImmutableList`/`ImmutableMap` from
  `kotlinx.collections.immutable` instead of `List`/`Map` in composable parameters.
- **Keep recomposition scope tight.** Read only the slice you render:
  `val counter by viewModel.uiState.map { it.counter }.collectAsState(initial = 0)` or
  `derivedStateOf { state.field }`. Split large composables so a small change rebuilds
  a small subtree.
- **Composable functions are pure and cheap.** No I/O, no `ViewModel` creation, no
  allocation of expensive objects, no business logic. Composition reads state and returns
  the UI description.
- **Launch coroutines only in `LaunchedEffect` or `rememberCoroutineScope`.** Never call
  `GlobalScope.launch` or create a bare `CoroutineScope` in a composable function body.
  Side effects go in `LaunchedEffect(key)` (scoped to the composable lifetime) or in
  the `ViewModel`.
- **Source strings/colors/dimensions from theme + resources.** Feature composables use
  `MaterialTheme.colorScheme`/`typography`, `LocalSpacing.current`, and `stringResource` /
  `MR.strings` — no hardcoded literals.
- **Optimize on evidence.** Profile with the Compose layout inspector or Android Studio
  profiler first; don't add `remember` churn or `key(…)` speculatively.

Don't:

- Business rules or data fetching in composable function bodies.
- Allocate objects, launch coroutines, or do I/O directly in composition.
- Read the whole `StateFlow` / `UiState` when you render one field (over-recomposition).
- Use `GlobalScope` or a non-remembered `CoroutineScope` in composition.
- Hardcode user-facing strings, hex colors, or magic dp dimensions in feature composables.
- Add `remember`/`key`/`ReusableContent` micro-opts without a measured problem.

## Decision table

| Symptom | Fix |
|---|---|
| Static subtree recomposing | hoist above the recomposing scope; use `remember { … }` for constant values |
| Whole screen recomposes on one field change | `derivedStateOf { state.field }` or map the Flow before `collectAsState` |
| Jank in a scroll/list | `LazyColumn`/`LazyRow`, stable item keys (`key = { item.id }`), `@Immutable` items |
| Coroutine launched in composition | move to `LaunchedEffect(key)` or `rememberCoroutineScope` |
| Literal string/color/size in a composable | theme token + `stringResource` |
| "Might be slow" hunch | measure in Compose layout inspector **before** optimizing |
| Unstable lambda causing recomposition | extract to `remember { … }` or use a `@Stable` wrapper |

## Refactor / red-flag signals

- Unstable class (mutable properties, `List`/`Map` parameter) passed to a composable that reads it.
- `collectAsState()` on the whole `UiState` where one field is rendered (every state update recomposes).
- `Flow.collectAsState()` called without `remember` — creates a new subscription on every recomposition.
- Data fetch / business logic in a composable function body.
- `GlobalScope.launch` or a bare `CoroutineScope(…)` created in composition.
- Hardcoded strings/colors/dimensions in feature composables.
- Speculative `remember`/`key`/`derivedStateOf` added without profiling.
- `LaunchedEffect` with an incorrect key (e.g. `Unit` when it should relaunch on a value change,
  or a fast-changing value when it should launch once).

## References

- Compose performance: https://developer.android.com/develop/ui/compose/performance
- Compose stability: https://developer.android.com/develop/ui/compose/performance/stability
- `@Stable`/`@Immutable`: https://developer.android.com/develop/ui/compose/performance/stability/strongskipping
- `derivedStateOf`: https://developer.android.com/develop/ui/compose/side-effects#derivedstateof
- `LaunchedEffect` / `rememberCoroutineScope`: https://developer.android.com/develop/ui/compose/side-effects
- `kotlinx.collections.immutable`: https://github.com/Kotlin/kotlinx.collections.immutable
- Compose layout inspector: https://developer.android.com/develop/ui/compose/tooling/layout-inspector
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Stability samples, derivedStateOf/remember patterns, profiling workflow: [`reference.md`](reference.md)
