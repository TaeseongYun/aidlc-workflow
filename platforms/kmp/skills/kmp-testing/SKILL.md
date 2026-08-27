---
name: kmp-testing
description: KMP test generation + test-quality guard — write real, deterministic tests and detect/block the fake or flaky tests AI commonly produces (assertion-free, mock-echo/tautological, over-mocking the unit under test, implementation-detail coupling, non-determinism/flakiness, happy-path-only, snapshot abuse, smuggled @Ignore, copy-paste clones, coverage theater). Covers the KMP test pyramid (kotlin.test in commonTest, runTest with coroutines-test, Turbine for Flow, runComposeUiTest for Compose UI). Auto-loads when writing or reviewing KMP tests.
when_to_use: When writing tests, reviewing AI/LLM-generated tests before merge, touching test files, or on requests like "write tests", "is this test real", "why is this test flaky", "test review".
paths: "**/commonTest/**/*.kt, **/*Test.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# kmp-testing — test generation + test-quality guard

AI-generated tests are **fast but frequently fake**. Common failures: tests that assert nothing,
tests that only re-assert what a mock was told to return, tests that mock away the very unit under
test, and non-deterministic tests that flake in CI. Coverage looks green while nothing is actually
verified — "coverage theater". This skill is both a **generator** (write real tests) and a **guard**
(detect and block fake/flaky AI tests). Guard rules are safety rules; project `ctx/` may tighten
them but the floor is never lowered.

## Scope

- Targets: files in `commonTest/`, `androidUnitTest/`, `iosTest/`, and any `*Test.kt` file —
  especially AI-generated or quickly-copied test suites.
- What it does: **generate real, deterministic tests** (Mode A) and **detect/block fake or
  flaky test patterns** (Mode B).
- Delegate to adjacent skills: secure storage / crypto in tests → [kmp-security](../kmp-security/SKILL.md),
  routing test setup → [kmp-navigation-platform](../kmp-navigation-platform/SKILL.md), state-layer
  integration tests → [kmp-state-management](../kmp-state-management/SKILL.md), testability/DI seam
  design → [kmp-architecture](../kmp-architecture/SKILL.md).

## Mode A — Generate

### Test pyramid

Many unit, some Compose UI (`runComposeUiTest`), few integration. Keep the pyramid honest:

- **Unit tests** (`@Test` via `kotlin.test` in `commonTest`): pure Kotlin, fast, no platform
  binding. Cover use-cases, repositories, domain logic, parsers, helpers. The bulk of the suite.
  Use `runTest` from `kotlinx-coroutines-test` for any suspending code.
- **Flow tests** (`Turbine`): use `flow.test { ... }` to assert emissions from `StateFlow` /
  `SharedFlow` / `Flow` in a structured, cancellation-safe way. Never collect manually with
  a raw `launch` + list accumulation.
- **Compose UI tests** (`runComposeUiTest`): render a single composable or small subtree.
  Assert on semantic nodes (`onNodeWithText`, `onNodeWithContentDescription`). Keep them fast;
  use `advanceUntilIdle()` inside `runTest` when mixing coroutines.
- **Integration tests**: full-app smoke paths on a device/emulator. Few and slow — one or two
  critical user journeys, not a full regression suite.

### Behavior over implementation (AAA)

Structure every test as **Arrange → Act → Assert**. Test observable behavior (return values,
emitted `StateFlow` states, semantic UI nodes), never internal call order or private fields.
One logical assertion per test — use `@Nested` or top-level grouping to organize related cases.

```kotlin
// Arrange
val repo = FakeWeatherRepository()
repo.setNextResult(Weather(city = "London", temp = 20))
val viewModel = WeatherViewModel(repo)

// Act
viewModel.fetchWeather("London")

// Assert — Turbine for Flow
viewModel.uiState.test {
    assertIs<WeatherUiState.Loading>(awaitItem())
    val loaded = assertIs<WeatherUiState.Loaded>(awaitItem())
    assertEquals("London", loaded.weather.city)
    cancelAndIgnoreRemainingEvents()
}
```

### Determinism — the calibration knob

A test that touches the real clock, real network, or real filesystem is **flaky by construction**.
Inject every non-deterministic dependency:

- **Clock / time**: wrap `Clock.System.now()` (kotlinx-datetime) in an injectable `Clock`
  abstraction; pass a fixed `Instant` in tests. Use `TestCoroutineScheduler` /
  `advanceTimeBy` to advance virtual time without real waits.
- **Network**: stub the Ktor `HttpClient` with `MockEngine`; never hit a real endpoint in a
  unit test. Return canned `HttpResponseData`.
- **Randomness**: inject a `Random` instance; use `Random(seed = 42)` in tests for a
  deterministic sequence.
- **Coroutines / time**: wrap tests in `runTest { ... }` — this gives you a
  `TestCoroutineScheduler` and auto-advances virtual time. No `Thread.sleep` / bare
  `delay` workarounds.
- **Flow**: always use **Turbine** (`flow.test { }`) — it enforces cancellation, detects
  unconsumed events, and makes sequential emission assertions readable.

### Error paths and boundaries

Always cover the failure branch for any code that has one. For every happy-path test, ask:
what happens when the repository throws? When the list is empty? When input is null/zero/max?
Compose UI tests must cover error-state composables (error messages, retry buttons, empty states).

### KMP test framework map

| Layer | Framework | Notes |
|---|---|---|
| Unit | `kotlin.test` (`@Test`, `assertEquals`, `assertIs`) | In `commonTest`; no platform binding |
| Mocking | `mockk` (JVM/Android) or fake objects | Prefer fakes in `commonTest`; mockk in platform tests |
| Coroutines | `kotlinx-coroutines-test` (`runTest`, `TestScope`) | Replaces real dispatchers; auto-advances time |
| Flow | **Turbine** (`flow.test { awaitItem() }`) | Structured, cancellation-safe Flow assertions |
| Ktor stub | `MockEngine` (`HttpClient(MockEngine { ... })`) | Returns canned responses; no real network |
| Compose UI | `runComposeUiTest` + `onNodeWithText` / `performClick` | Multiplatform Compose test harness |
| Integration | Platform test runner (JUnit on Android, XCTest bridged on iOS) | On-device; use sparingly |

---

## Mode B — Guard

Detect and block these 10 AI test failure modes. Each item: **rule → common AI failure →
red-flag**. Code examples in [reference.md](./reference.md).

### 1. Assertion-free test

- **Rule**: every test body must contain at least one `assertEquals`, `assertIs`, `assertTrue`,
  or Turbine `awaitItem` assertion that can actually fail. A test that exercises code without
  asserting anything gives false confidence.
- **Common AI failure**: scaffolding a `@Test` that calls the SUT, sets up fakes, then returns
  without asserting the output or emitted state.
- **red-flag**: a `@Test` body with zero `assert*` / `expect*` / Turbine assertion calls, or only
  a `verify` that a mock method was called (with no output assertion).

### 2. Mock-echo / tautological assertion

- **Rule**: an assertion must verify something the SUT computed, not re-state what the fake/mock
  was told to return. `every { mock.x() } returns V` → `assertEquals(result, V)` verifies nothing
  real about the SUT.
- **Common AI failure**: stubbing a function to return `42`, calling the SUT, then asserting the
  result is `42` — the SUT could be removed and the test would still pass.
- **red-flag**: the expected value in `assertEquals` is the same literal/object used in `returns`
  or `answers`, with no transformation by the SUT in between.

### 3. Over-mocking / mocking the SUT

- **Rule**: mock or fake the **dependencies** of the unit under test, never the unit itself. If
  the class being tested is a mock, the test exercises nothing.
- **Common AI failure**: creating a `mockk<WeatherViewModel>()` or `mockk<MyUseCase>()` and
  then testing it, leaving the real implementation completely untested.
- **red-flag**: a `mockk<X>()` whose type `X` matches the class named in the test description,
  or a mock used as the object under `assert*`.

### 4. Implementation-detail coupling

- **Rule**: assert on observable outputs — returned values, emitted `StateFlow` states, rendered
  semantic nodes, written data. Do not assert on private method calls, internal call order, or
  interaction counts that are an artifact of the current implementation.
- **Common AI failure**: `verify { sut.transformCity(any()) }` — brittle; the private function
  may be inlined or renamed without changing behavior.
- **red-flag**: `verify` calls on functions that are not part of the public API, call-count
  assertions that are not meaningful to behavior, spying on private or internal members.

### 5. Non-determinism / flakiness

- **Rule**: unit tests must not touch the real clock (`Clock.System.now()`), real network, real
  filesystem, or `Thread.sleep`. Shared mutable state between tests causes order-dependence. All
  coroutine-time logic must run inside `runTest`.
- **Common AI failure**: `delay(100)` outside `runTest`, calling a real Ktor endpoint, using
  `System.currentTimeMillis()` in the Arrange step, a top-level `var` shared across tests.
- **red-flag**: `Thread.sleep` in a test, `kotlinx.coroutines.delay` outside `runTest`,
  `System.currentTimeMillis()` / `Clock.System.now()` in Arrange, shared top-level mutable state.

### 6. Happy-path only

- **Rule**: any function with error handling, null returns, empty-list branches, or exception
  paths requires at least one test per significant branch. A single success test for a
  repository that can throw is incomplete.
- **Common AI failure**: one test named `fetchWeather returns weather` for a repository method
  that can also throw `NetworkException`, return an empty list, or receive a server error.
- **red-flag**: a function with `try/catch`, nullable return, or conditional logic and only one
  test with no negative or boundary cases.

### 7. Snapshot / golden abuse

- **Rule**: screenshot / golden tests are for detecting **unintended** visual regressions. Every
  committed reference image must be reviewed. Running the update task without reviewing the diff
  is equivalent to deleting the assertion. A golden must not be the only assertion for logic.
- **Common AI failure**: generating a screenshot test for every composable, regenerating without
  review when a dependency bumps, using a screenshot as a proxy for behavior correctness.
- **red-flag**: a screenshot comparison as the only assertion for a composable whose behavior
  matters, committed reference images with no review comment, screenshot update in CI without
  a gate.

### 8. Smuggled @Ignore / skip

- **Rule**: `@Ignore` or any mechanism that silently disables a test is forbidden without a
  comment containing the reason and a tracking reference (issue URL or ticket ID).
- **Common AI failure**: adding `@Ignore("TODO")` to make a failing test pass CI, leaving it
  in permanently.
- **red-flag**: `@Ignore` without a comment explaining why and a ticket reference; a test method
  with `return` as its first statement to silently short-circuit.

### 9. Copy-paste clone

- **Rule**: two tests with different names but identical (or near-identical) assertion bodies
  are a maintenance liability and mask missing coverage. Extract shared setup into helper
  functions; parameterize with a loop or a `@ParameterizedTest` / data-driven table.
- **Common AI failure**: duplicating a test block and only changing the test name, leaving the
  assertions unchanged so neither test adds unique coverage.
- **red-flag**: two or more `@Test` blocks in the same file with identical `assert*` calls and
  no meaningful difference in Arrange.

### 10. Coverage theater

- **Rule**: high line coverage with near-zero meaningful assertions is not a passing test suite.
  Calling a function without asserting its output, or only asserting that it does not throw,
  inflates coverage while verifying nothing. Prefer mutation score over line coverage as the
  quality signal.
- **Common AI failure**: wrapping every public function in a `@Test` that calls it once and has
  no `assert*`, so the coverage tool marks those lines green.
- **red-flag**: tests where the only check is `assertDoesNotThrow { sut.method() }` (or
  equivalent), a file with 90%+ coverage but no state/output assertions, tests added solely to
  hit a coverage threshold.

---

## Halt conditions

Halt (do not generate or approve tests) if:

- The code under test has no injectable seams for dependencies — escalate to [kmp-architecture](../kmp-architecture/SKILL.md)
  for a DI fix before adding tests.
- The requested test requires hitting a real external service — request a Ktor `MockEngine` stub first.
- A screenshot test is requested but the composable tree is not yet stable — screenshot tests
  on in-progress UI lock in accidents as baselines.

### Output on halt

```
## Test generation halted

Reason:
- (specific reason)

Required before proceeding:
1. ...
```

Do NOT propose workarounds. Do NOT explain how to fix. Output only the halt reason and what is
needed.

---

## Test-quality review checklist

For AI-generated or quickly-copied KMP tests, before merge:

- [ ] Every `@Test` body contains at least one `assert*` / Turbine `awaitItem` / meaningful assertion.
- [ ] No assertion re-states only what a fake/mock was told to return (mock-echo).
- [ ] The class under test is NOT itself mocked.
- [ ] Assertions target observable behavior, not private method calls or call counts.
- [ ] No `Thread.sleep` / real network / `Clock.System.now()` in unit tests; coroutine time via `runTest`.
- [ ] Flow assertions use Turbine (`flow.test { awaitItem() }`), not raw `launch` + list.
- [ ] Error paths, empty results, and boundary inputs each have at least one test.
- [ ] Committed screenshots were reviewed; update task not run blindly.
- [ ] No `@Ignore` without a reason comment and a ticket reference.
- [ ] No copy-paste clones with identical assertions and different names.
- [ ] Tests have meaningful `assert*` calls on SUT output / state, not just coverage fill.

---

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code examples (bad → good per rule): [reference.md](./reference.md)
- Umbrella: [kmp-architecture](../kmp-architecture/SKILL.md)
- Adjacent: [kmp-security](../kmp-security/SKILL.md), [kmp-state-management](../kmp-state-management/SKILL.md), [kmp-navigation-platform](../kmp-navigation-platform/SKILL.md)
- kotlin.test docs: https://kotlinlang.org/api/latest/kotlin.test/
- kotlinx-coroutines-test: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/
- Turbine: https://github.com/cashapp/turbine
- Ktor MockEngine: https://ktor.io/docs/client-testing.html
- Compose Multiplatform testing: https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-test.html
