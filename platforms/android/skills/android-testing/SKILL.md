---
name: android-testing
description: Android test generation + test-quality guard — write real, deterministic tests and
  detect/block the fake or flaky tests AI commonly produces (assertion-free, mock-echo/tautological,
  over-mocking the unit under test, implementation-detail coupling, non-determinism/flakiness,
  happy-path-only, snapshot abuse, smuggled skips, copy-paste clones, coverage theater). Covers the
  Android test pyramid and frameworks (JUnit + MockK + Robolectric for JVM unit, Turbine for Flow,
  createComposeRule for Compose UI, Espresso for instrumented tests). Auto-loads when writing or
  reviewing tests.
when_to_use: When writing tests, reviewing AI/LLM-generated tests before merge, touching test files,
  or on requests like "write tests", "is this test real", "why is this test flaky", "test review".
paths: "**/src/test/**", "**/src/androidTest/**", "**/*Test.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Android Testing

AI-generated Android tests are **fast but frequently fake.** Common failures: tests that assert
nothing, tests that only re-assert what a mock was told to return, tests that mock away the very
class under test, and tests wired to real clocks or the real network that flake in CI. Coverage
looks green while nothing is actually verified — "coverage theater." This skill is both a
**generator** (write real tests) and a **guard** (detect and block fake or flaky AI tests). Guard
rules are safety rules; project `ctx/` may tighten them but the floor is never lowered.

## Scope

- Applies to: `**/src/test/**`, `**/src/androidTest/**`, `**/*Test.kt`.
- Covers: JVM unit tests, Robolectric, Flow/StateFlow with Turbine, Compose UI with
  `createComposeRule`, Espresso instrumented tests.
- Delegate to adjacent skills:
  - **android-security** for permission/crypto/exported-component security tests.
  - **android-architecture** for testability seams and DI setup (Hilt test components, fake
    injection).
  - **android-viewmodel-state** for ViewModel/StateFlow contract questions beyond testing.
- Project `ctx/` may add platform-specific rules (e.g., mandatory coverage thresholds,
  approved fake/stub libraries) but must not relax the guard rules in Mode B.

## Mode A — Generate

### Test pyramid

Many JVM unit tests, some Robolectric/integration tests, few Espresso/UI instrumented tests.
Compose UI tests (`createComposeRule`) sit between integration and UI — use them for the
component-level behavior that JVM cannot cover.

| Layer | Framework | Scope |
|---|---|---|
| Unit | JUnit 4/5 + MockK | Pure Kotlin logic, ViewModel, UseCase, Repository |
| Robolectric | Robolectric + JUnit 4 | Android framework–dependent code without a device |
| Flow | Turbine + MockK | StateFlow, SharedFlow, Flow pipelines |
| Compose UI | `createComposeRule` (JVM) | Individual composables, component state machine |
| Instrumented | Espresso (androidTest) | Full-screen flows, real device/emulator only |

Keep instrumented tests in `src/androidTest/`. Keep JVM tests (including Robolectric and Turbine)
in `src/test/`. Do not mix.

### Test behavior, not implementation — AAA

Structure every test as **Arrange → Act → Assert**. Test observable behavior (returned value,
emitted state, thrown exception, published event) — not which private methods were called or how
many times an internal was invoked.

One logical assertion per test. Multiple `assertEquals`/`assertTrue` calls on the same result
object are fine; verifying a second, independent behavior belongs in a second test.

```kotlin
// Arrange
val repo = FakeUserRepository(user = testUser)
val viewModel = UserViewModel(repo, testDispatcher)

// Act
viewModel.loadUser(userId = 42L)
testDispatcher.advanceUntilIdle()

// Assert
assertEquals(UiState.Success(testUser), viewModel.uiState.value)
```

### Determinism — the calibration knob

A test that touches the real clock, real network, real filesystem, or shared mutable state is
**flaky by construction.** Inject every external dependency so tests can control it:

**Clock / time**

Inject `kotlinx.coroutines.test.TestCoroutineScheduler` (via `StandardTestDispatcher` or
`UnconfinedTestDispatcher`) instead of `Dispatchers.IO`/`Main`. Never call `Thread.sleep()` or
`delay()` with a real dispatcher. Use `advanceTimeBy()` or `advanceUntilIdle()` to drive time
forward deterministically.

```kotlin
@Test
fun `token refresh triggers after expiry`() = runTest {
    val scheduler = testScheduler          // from runTest's TestScope
    val clock = FakeClock(now = Instant.EPOCH)
    val repo = TokenRepository(clock = clock, dispatcher = backgroundScope.coroutineContext)

    repo.startRefreshLoop()
    scheduler.advanceTimeBy(TOKEN_TTL_MS + 1)

    assertTrue(repo.didRefresh)
}
```

**Coroutine dispatcher**

Replace `Dispatchers.Main` with `StandardTestDispatcher` via `Dispatchers.setMain()` in a
`@BeforeEach` / `@Before` and reset with `Dispatchers.resetMain()` in `@AfterEach` / `@After`.
Alternatively use the `MainDispatcherRule` pattern (a JUnit `TestWatcher`).

```kotlin
class MainDispatcherRule : TestWatcher() {
    val testDispatcher = StandardTestDispatcher()
    override fun starting(d: Description) = Dispatchers.setMain(testDispatcher)
    override fun finished(d: Description) = Dispatchers.resetMain()
}
```

**Faked network / IO**

Never hit a live network or filesystem in a unit test. Provide a fake implementation of your
repository/data-source interface, or use an OkHttp `MockWebServer` (for Robolectric or
instrumented tests that exercise the real HTTP layer).

```kotlin
class FakeUserRepository : UserRepository {
    var stubbedUser: User? = null
    var throwOn: Boolean = false

    override suspend fun getUser(id: Long): Result<User> =
        if (throwOn) Result.failure(IOException("network error"))
        else Result.success(stubbedUser ?: error("stub not set"))
}
```

No `sleep`, no `SystemClock.sleep`, no order-dependent shared state between tests.

### Always cover error paths + boundaries

For every function that has failure branches, an error case, or a boundary value — test it.
Never write only a happy-path test for code that clearly handles errors.

- Null / empty / zero / max-value inputs.
- Repository failure (`Result.failure`, thrown exception).
- Empty list / single-item / large-list behavior for collection operations.
- Flow that emits an error or completes early.

```kotlin
@Test
fun `loadUser emits Error state when repository throws`() = runTest {
    val repo = FakeUserRepository(throwOn = true)
    val viewModel = UserViewModel(repo, StandardTestDispatcher(testScheduler))

    viewModel.loadUser(42L)
    advanceUntilIdle()

    assertTrue(viewModel.uiState.value is UiState.Error)
}
```

### Flow / StateFlow testing with Turbine

Use `turbine` to collect Flow emissions in sequence without writing hand-rolled channel consumers.

```kotlin
@Test
fun `search emits Loading then Results`() = runTest {
    val viewModel = SearchViewModel(FakeSearchRepo(), StandardTestDispatcher(testScheduler))

    viewModel.uiState.test {
        assertEquals(UiState.Idle, awaitItem())
        viewModel.search("kotlin")
        advanceUntilIdle()
        assertEquals(UiState.Loading, awaitItem())
        assertTrue(awaitItem() is UiState.Results)
        cancelAndIgnoreRemainingEvents()
    }
}
```

### Compose UI tests with createComposeRule

Use `createComposeRule()` for JVM Compose tests (no device needed). Test user-visible state
and interaction — not internal recomposition counts or which composable called which.

```kotlin
@get:Rule val composeRule = createComposeRule()

@Test
fun `shows error message when state is Error`() {
    composeRule.setContent {
        UserScreen(uiState = UiState.Error("Not found"))
    }
    composeRule.onNodeWithText("Not found").assertIsDisplayed()
}
```

---

## Mode B — Guard

Block bad AI-generated tests before merge. Each item: **rule → the failure AI commonly produces
→ red-flag**. Code examples (bad → good) in [reference.md](./reference.md).

### 1. Assertion-free test

- **Rule**: every test must contain at least one `assert*`, `assertEquals`, `assertTrue`,
  `verify`, or `assertThat` call that checks an observable result.
- **Common AI failure**: generates a test body that calls the function, sets up mocks, and then
  returns — forgetting the assertion entirely. Looks like a test, fails at nothing.
- **red-flag**: test body contains function calls and mock setup, zero `assert*`/`verify`
  (non-interaction) calls.

### 2. Mock-echo / tautological assertion

- **Rule**: never stub a mock to return `V` and then assert that the result equals `V` with no
  real logic in between. The test verifies only that MockK works, not that the production code
  does anything.
- **Common AI failure**: `every { repo.getUser(1L) } returns user` followed immediately by
  `assertEquals(user, viewModel.user)` where ViewModel is also a mock or does no transformation.
- **red-flag**: the stubbed return value appears verbatim as the asserted expected value, with the
  system under test performing no transformation.

### 3. Over-mocking / mocking the SUT

- **Rule**: never create a `mockk<>()` of the class being tested. Mocks are for dependencies of
  the SUT, not the SUT itself.
- **Common AI failure**: `val viewModel = mockk<UserViewModel>()` in a ViewModel test; the test
  then stubs and asserts on the mock, exercising zero production logic.
- **red-flag**: a `mockk<>()` or `spyk<>()` of the class whose behavior the test claims to verify.

### 4. Implementation-detail coupling

- **Rule**: assert on observable behavior — returned values, emitted state, thrown exceptions,
  published events. Do not verify that a private method was called or that an internal call count
  matches.
- **Common AI failure**: `verify(exactly = 3) { repo.getUser(any()) }` where the call count is
  an internal detail; or `verify { viewModel.privateRefresh() }` on a spied ViewModel.
- **red-flag**: `verify` on a private/internal method; call-count assertions (`exactly = N`) on
  a method that is not part of the public contract; spying on the SUT to assert internals.

### 5. Non-determinism / flakiness

- **Rule**: no real clock (`System.currentTimeMillis()`, `LocalDateTime.now()`), no real RNG, no
  `Thread.sleep()`/`delay()` with a real dispatcher, no real network/filesystem, no shared mutable
  state between tests.
- **Common AI failure**: `Thread.sleep(500)` to wait for a coroutine, `System.currentTimeMillis()`
  in a time-dependent assertion, `Dispatchers.IO` hardcoded inside a ViewModel with no injection
  seam.
- **red-flag**: `Thread.sleep`, `SystemClock.sleep`, `System.currentTimeMillis()`,
  `LocalDateTime.now()`, `Math.random()`, `Dispatchers.IO`/`Main` without injection, live
  `HttpClient`/`OkHttpClient` constructed inside the test.

### 6. Happy-path only

- **Rule**: code with visible failure branches must have at least one test per meaningful failure
  mode. Do not write only the success scenario for code that clearly throws, catches, or branches
  on error.
- **Common AI failure**: a ViewModel that handles `Result.failure` from the repository, but the
  test only exercises the success branch; the error branch is never covered.
- **red-flag**: a function has an explicit error path (try/catch, `is Failure`, `onFailure`) but
  all tests use only the success scenario.

### 7. Snapshot abuse

- **Rule**: golden/screenshot snapshots must be small and manually reviewed before commit. An
  auto-regenerated snapshot committed without inspection is not a test — it only records the
  current (possibly broken) state. Snapshot must not be the sole assertion for logic that can be
  unit-tested directly.
- **Common AI failure**: checking in a giant Paparazzi or Roborazzi screenshot as the sole
  guard for a screen; re-running `./gradlew recordPaparazziDebug` to update the snapshot after
  every change without inspecting the diff.
- **red-flag**: snapshot image file committed alongside a code change with no visible review;
  snapshot the only assertion for behavior that could be tested with `assertEquals`; CI step that
  auto-records and commits snapshots.

### 8. Smuggled skip / disable

- **Rule**: `@Ignore` or `@Disabled` added to a test must include an explanatory comment and a
  tracking ticket. A skip with no justification is a hidden test regression.
- **Common AI failure**: `@Ignore` added to make a flaky test stop failing in CI, with no comment
  or ticket.
- **red-flag**: `@Ignore` / `@Disabled` with no comment; `@Test(enabled = false)` with no
  justification; a commented-out test body.

### 9. Copy-paste clone

- **Rule**: if two tests have the same assertions but different names, one of them has drifted.
  Either parameterize them or delete the duplicate.
- **Common AI failure**: generates `loginSuccess_withValidCredentials()` and
  `loginSuccess_withRememberedUser()` with identical assertion bodies — copy-pasted and
  name-changed, but not actually testing different behavior.
- **red-flag**: two or more test methods with identical `assert*` / `verify` calls but different
  names; test names that no longer describe what is actually being asserted.

### 10. Coverage theater

- **Rule**: line/branch coverage is a proxy metric, not a goal. A test that calls a function
  without asserting its output or side-effects inflates coverage while verifying nothing.
  Mutation testing (`pitest`) is a more honest signal.
- **Common AI failure**: generates a test that instantiates the class and calls every public
  method in sequence, asserting nothing — achieves 90%+ line coverage with zero real verification.
- **red-flag**: high line coverage on a class whose tests contain few or no `assert*` calls;
  tests that call multiple unrelated methods in a single `@Test` body with only a final
  non-null check.

---

## Guard review checklist

For test files that AI generated or were pasted in quickly, before merge:

- [ ] Every test has at least one meaningful assertion (not just a non-null check).
- [ ] No mock echoes: stubbed return value is transformed by the SUT before assertion.
- [ ] The SUT is a real instance, not a `mockk<>()` or `spyk<>()`.
- [ ] Assertions are on observable outputs, not internal call counts or private methods.
- [ ] No `Thread.sleep`, no real clock/RNG, no live network, no shared mutable state between tests.
- [ ] Error paths and boundary values are covered for code that has them.
- [ ] Snapshots are small, manually reviewed, and not the sole assertion.
- [ ] `@Ignore`/`@Disabled` includes a comment and a ticket reference.
- [ ] No copy-paste clones with drifted names.
- [ ] Coverage is not the primary metric — tests assert meaningful behavior.

## Halt conditions

Halt (do not generate or approve tests) when:

- The code under test has no DI seam for its dispatcher/clock/network — the production code must
  be fixed first. Delegate to **android-architecture** for the fix.
- The test file uses a framework not in the approved map (JUnit + MockK + Robolectric + Turbine +
  createComposeRule + Espresso). Flag the unknown framework and ask the user to confirm.
- More than 3 of the 10 guard rules are violated in a single file — return the guard checklist
  with failures marked rather than attempting to fix silently.

### Output on halt

```
## Test guard — halted

Halt reason:
- (specific rule(s) violated or missing seam)

Items requiring confirmation:
1. ...
```

Do NOT propose fixes inline. Do NOT silently skip failed rules. Output only the halt reason and
the items that need resolution.

## References

- [../../guidance.md](../../guidance.md) — team Android baseline
- [reference.md](reference.md) — bad → good Kotlin code pairs for all 10 guard rules + generation examples
- [android-architecture](../android-architecture/SKILL.md) — DI seams and testability
- [android-viewmodel-state](../android-viewmodel-state/SKILL.md) — ViewModel/StateFlow contract
- [android-security](../android-security/SKILL.md) — security-specific test concerns
- Kotlin coroutines test docs: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/
- Turbine: https://github.com/cashapp/turbine
- MockK: https://mockk.io/
- Robolectric: https://robolectric.org/
- Compose UI testing: https://developer.android.com/develop/ui/compose/testing
