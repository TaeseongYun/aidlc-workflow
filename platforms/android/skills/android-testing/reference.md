# Android Testing — Reference

Deep-dive material for `SKILL.md`: bad → good Kotlin code pairs for all 10 guard rules, plus
Mode-A generation examples. For rule summaries and decision criteria, see `SKILL.md`.

---

## Guard rule code pairs

### Rule 1 — Assertion-free test

**Bad** — calls the function, sets up state, asserts nothing.

```kotlin
@Test
fun `loadUser does not crash`() = runTest {
    val repo = FakeUserRepository(stubbedUser = testUser)
    val viewModel = UserViewModel(repo, StandardTestDispatcher(testScheduler))

    viewModel.loadUser(42L)
    advanceUntilIdle()
    // No assertion. Green, verifies nothing.
}
```

**Good** — asserts the observable output.

```kotlin
@Test
fun `loadUser emits Success state with the loaded user`() = runTest {
    val repo = FakeUserRepository(stubbedUser = testUser)
    val viewModel = UserViewModel(repo, StandardTestDispatcher(testScheduler))

    viewModel.loadUser(42L)
    advanceUntilIdle()

    assertEquals(UiState.Success(testUser), viewModel.uiState.value)
}
```

---

### Rule 2 — Mock-echo / tautological assertion

**Bad** — stubs the mock to return `user` then asserts the result is `user`. The production code
does no transformation; the test verifies only that MockK works.

```kotlin
@Test
fun `getUser returns user`() = runTest {
    val repo = mockk<UserRepository>()
    every { repo.getUser(1L) } returns Result.success(testUser)

    val result = repo.getUser(1L)   // calling the mock directly — SUT not involved

    assertEquals(testUser, result.getOrNull())  // tautological
}
```

**Good** — the SUT (UseCase) performs real transformation; the test verifies that transformation.

```kotlin
@Test
fun `GetUserUseCase maps repository result to domain User`() = runTest {
    val repo = FakeUserRepository(stubbedUser = UserEntity(id = 1L, name = "Ada"))
    val useCase = GetUserUseCase(repo)

    val result = useCase(1L)

    // UseCase is expected to map UserEntity → domain User
    assertEquals(User(id = 1L, displayName = "Ada"), result.getOrThrow())
}
```

---

### Rule 3 — Over-mocking / mocking the SUT

**Bad** — the class under test is itself mocked; no production logic runs.

```kotlin
@Test
fun `UserViewModel load emits success`() = runTest {
    val viewModel = mockk<UserViewModel>()          // mocking the SUT
    every { viewModel.uiState } returns MutableStateFlow(UiState.Success(testUser))

    assertEquals(UiState.Success(testUser), viewModel.uiState.value)  // asserts mock setup
}
```

**Good** — the SUT is a real instance; mocks are used only for its dependencies.

```kotlin
@Test
fun `UserViewModel load emits Success when repository succeeds`() = runTest {
    val repo = FakeUserRepository(stubbedUser = testUser)
    val viewModel = UserViewModel(repo, StandardTestDispatcher(testScheduler)) // real instance

    viewModel.loadUser(1L)
    advanceUntilIdle()

    assertEquals(UiState.Success(testUser), viewModel.uiState.value)
}
```

---

### Rule 4 — Implementation-detail coupling

**Bad** — asserts internal call counts and private method invocations rather than observable
output. The test breaks on any internal refactoring even if behavior is correct.

```kotlin
@Test
fun `refreshToken calls repository exactly twice on failure`() = runTest {
    val repo = spyk(FakeUserRepository())

    val viewModel = UserViewModel(repo, StandardTestDispatcher(testScheduler))
    viewModel.refreshToken()
    advanceUntilIdle()

    verify(exactly = 2) { repo.getUser(any()) }   // internal retry count — not a contract
}
```

**Good** — asserts the observable contract: the user sees an error state after a failed refresh.

```kotlin
@Test
fun `refreshToken emits Error state when repository fails`() = runTest {
    val repo = FakeUserRepository(throwOn = true)
    val viewModel = UserViewModel(repo, StandardTestDispatcher(testScheduler))

    viewModel.refreshToken()
    advanceUntilIdle()

    assertTrue(viewModel.uiState.value is UiState.Error)
}
```

---

### Rule 5 — Non-determinism / flakiness

**Bad** — uses `Thread.sleep` to wait for a coroutine and `System.currentTimeMillis()` for a
time-sensitive assertion. Flakes on slow CI machines.

```kotlin
@Test
fun `session expires after timeout`() {
    val session = SessionManager()          // hardcodes Dispatchers.IO inside
    session.start()

    Thread.sleep(1_500)                     // real sleep — flaky

    val elapsed = System.currentTimeMillis() - session.startTime  // real clock
    assertTrue(elapsed >= 1_000)
}
```

**Good** — injects `StandardTestDispatcher` and a `FakeClock`; drives time forward
deterministically with `advanceTimeBy`.

```kotlin
@Test
fun `session expires after TOKEN_TTL_MS`() = runTest {
    val clock = FakeClock(now = Instant.EPOCH)
    val session = SessionManager(
        clock = clock,
        dispatcher = StandardTestDispatcher(testScheduler)
    )
    session.start()

    testScheduler.advanceTimeBy(SESSION_TTL_MS + 1)

    assertTrue(session.isExpired)
}
```

---

### Rule 6 — Happy-path only

**Bad** — only tests the success branch for a function that clearly handles errors.

```kotlin
@Test
fun `loadProfile returns user`() = runTest {
    val repo = FakeProfileRepository(stubbedProfile = testProfile)
    val viewModel = ProfileViewModel(repo, StandardTestDispatcher(testScheduler))

    viewModel.load(userId = 1L)
    advanceUntilIdle()

    assertEquals(UiState.Success(testProfile), viewModel.uiState.value)
    // The error branch (repo throws IOException) is never tested.
}
```

**Good** — adds an explicit error-path test.

```kotlin
@Test
fun `loadProfile emits Error when repository throws IOException`() = runTest {
    val repo = FakeProfileRepository(throwOn = true)
    val viewModel = ProfileViewModel(repo, StandardTestDispatcher(testScheduler))

    viewModel.load(userId = 1L)
    advanceUntilIdle()

    val state = viewModel.uiState.value
    assertTrue(state is UiState.Error)
    assertEquals("Network error", (state as UiState.Error).message)
}
```

---

### Rule 7 — Snapshot abuse

**Bad** — giant Paparazzi screenshot is the sole guard; auto-recorded in CI without review.

```kotlin
@Test
fun `UserScreen snapshot`() {
    paparazzi.snapshot {
        UserScreen(uiState = UiState.Success(testUser))
    }
    // 120 KB PNG committed. No assertion on text, accessibility, or state logic.
    // CI job runs `./gradlew recordPaparazziDebug` and commits the result automatically.
}
```

**Good** — snapshot used only for visual regression of a specific stable component; behavior
tested separately with `createComposeRule`.

```kotlin
// Behavior test — primary guard for logic
@get:Rule val composeRule = createComposeRule()

@Test
fun `UserScreen shows display name and avatar`() {
    composeRule.setContent { UserScreen(uiState = UiState.Success(testUser)) }
    composeRule.onNodeWithText("Ada Lovelace").assertIsDisplayed()
    composeRule.onNodeWithContentDescription("Profile photo").assertIsDisplayed()
}

// Snapshot test — narrow, reviewed manually, not the primary guard
@Test
fun `UserAvatar visual regression`() {
    paparazzi.snapshot { UserAvatar(imageUrl = null, contentDescription = "Profile photo") }
    // Small, bounded component. Diff reviewed in PR before merging.
}
```

---

### Rule 8 — Smuggled skip / disable

**Bad** — `@Ignore` added silently to stop a flaky test from failing CI; no explanation.

```kotlin
@Ignore          // no reason, no ticket
@Test
fun `checkout completes when payment succeeds`() = runTest {
    // This test was flaky in CI. Ignored "temporarily" six months ago.
}
```

**Good** — skip justified with reason and a tracking reference.

```kotlin
@Ignore(
    "Flakes under emulator API 30 due to race in FakePaymentGateway — " +
    "tracked in https://jira.example.com/PROJ-4321. Remove ignore once fixed."
)
@Test
fun `checkout completes when payment succeeds`() = runTest {
    // ...
}
```

---

### Rule 9 — Copy-paste clone

**Bad** — two tests with different names but identical assertion bodies; one name has drifted.

```kotlin
@Test
fun `login succeeds with valid credentials`() = runTest {
    val viewModel = LoginViewModel(FakeAuthRepo(success = true), testDispatcher)
    viewModel.login("user@example.com", "secret")
    advanceUntilIdle()
    assertTrue(viewModel.uiState.value is UiState.Success)
}

@Test
fun `login succeeds with remembered user`() = runTest {
    val viewModel = LoginViewModel(FakeAuthRepo(success = true), testDispatcher)
    viewModel.login("user@example.com", "secret")  // identical body — "remembered user" not exercised
    advanceUntilIdle()
    assertTrue(viewModel.uiState.value is UiState.Success)
}
```

**Good** — parameterize genuinely shared structure; keep distinct scenarios distinct.

```kotlin
@Test
fun `login with valid credentials emits Success`() = runTest {
    val viewModel = LoginViewModel(FakeAuthRepo(success = true), testDispatcher)
    viewModel.login("user@example.com", "secret")
    advanceUntilIdle()
    assertTrue(viewModel.uiState.value is UiState.Success)
}

@Test
fun `login with remembered user skips password field and emits Success`() = runTest {
    val repo = FakeAuthRepo(success = true, isRemembered = true)
    val viewModel = LoginViewModel(repo, testDispatcher)
    viewModel.loginWithRemembered()       // different method — actually tests the remembered path
    advanceUntilIdle()
    assertTrue(viewModel.uiState.value is UiState.Success)
    assertTrue(repo.passwordFieldSkipped)
}
```

---

### Rule 10 — Coverage theater

**Bad** — calls every public method, asserts only non-null at the end. High line coverage,
zero meaningful verification.

```kotlin
@Test
fun `CartViewModel coverage`() = runTest {
    val viewModel = CartViewModel(FakeCartRepo(), testDispatcher)
    viewModel.addItem(testItem)
    viewModel.removeItem(testItem.id)
    viewModel.applyPromo("SAVE10")
    viewModel.checkout()
    advanceUntilIdle()
    assertNotNull(viewModel.uiState.value)   // only non-null — anything passes
}
```

**Good** — one test per behavior; each assertion verifies a real contract.

```kotlin
@Test
fun `addItem increases cart total by item price`() = runTest {
    val viewModel = CartViewModel(FakeCartRepo(), StandardTestDispatcher(testScheduler))
    viewModel.addItem(Item(id = 1L, price = 1999))
    advanceUntilIdle()
    assertEquals(1999, (viewModel.uiState.value as CartState.Active).totalCents)
}

@Test
fun `applyPromo SAVE10 reduces total by 10 percent`() = runTest {
    val viewModel = CartViewModel(FakeCartRepo(preloaded = listOf(testItem)), StandardTestDispatcher(testScheduler))
    viewModel.applyPromo("SAVE10")
    advanceUntilIdle()
    val state = viewModel.uiState.value as CartState.Active
    assertEquals((testItem.price * 0.9).toInt(), state.totalCents)
}
```

---

## Mode-A generation examples

### Example 1 — ViewModel unit test with injected dispatcher + faked repository

Demonstrates: AAA structure, `StandardTestDispatcher`, `FakeRepository`, success + error paths,
`advanceUntilIdle()` instead of `Thread.sleep`.

```kotlin
// Production code (simplified for illustration)
class UserViewModel(
    private val repo: UserRepository,
    dispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {
    private val _uiState = MutableStateFlow<UiState>(UiState.Loading)
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    fun loadUser(id: Long) {
        viewModelScope.launch(dispatcher) {
            _uiState.value = UiState.Loading
            repo.getUser(id)
                .onSuccess { _uiState.value = UiState.Success(it) }
                .onFailure { _uiState.value = UiState.Error(it.message ?: "Unknown") }
        }
    }
}

// Fake (lives in src/test/)
class FakeUserRepository(
    private val stubbedUser: User? = null,
    private val throwOn: Boolean = false,
) : UserRepository {
    override suspend fun getUser(id: Long): Result<User> =
        if (throwOn) Result.failure(IOException("network error"))
        else Result.success(stubbedUser ?: error("stub not set"))
}

// Tests
class UserViewModelTest {
    @get:Rule val mainDispatcherRule = MainDispatcherRule()

    private val testUser = User(id = 1L, displayName = "Ada Lovelace")

    @Test
    fun `loadUser emits Loading then Success on repository success`() = runTest {
        // Arrange
        val repo = FakeUserRepository(stubbedUser = testUser)
        val viewModel = UserViewModel(repo, mainDispatcherRule.testDispatcher)

        // Act
        viewModel.loadUser(1L)
        mainDispatcherRule.testDispatcher.scheduler.advanceUntilIdle()

        // Assert
        assertEquals(UiState.Success(testUser), viewModel.uiState.value)
    }

    @Test
    fun `loadUser emits Error when repository throws`() = runTest {
        // Arrange
        val repo = FakeUserRepository(throwOn = true)
        val viewModel = UserViewModel(repo, mainDispatcherRule.testDispatcher)

        // Act
        viewModel.loadUser(1L)
        mainDispatcherRule.testDispatcher.scheduler.advanceUntilIdle()

        // Assert
        assertTrue(viewModel.uiState.value is UiState.Error)
    }
}
```

---

### Example 2 — Flow pipeline test with Turbine

Demonstrates: `turbine`, ordered emission verification, `cancelAndIgnoreRemainingEvents()`.

```kotlin
// Production code (simplified)
class SearchViewModel(
    private val repo: SearchRepository,
    dispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ViewModel() {
    private val _uiState = MutableStateFlow<SearchUiState>(SearchUiState.Idle)
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    fun search(query: String) {
        viewModelScope.launch(dispatcher) {
            _uiState.value = SearchUiState.Loading
            repo.search(query)
                .onSuccess { _uiState.value = SearchUiState.Results(it) }
                .onFailure { _uiState.value = SearchUiState.Error(it.message ?: "Error") }
        }
    }
}

// Test
class SearchViewModelTest {
    @get:Rule val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun `search emits Idle then Loading then Results in order`() = runTest {
        val repo = FakeSearchRepository(stubbedResults = listOf(SearchResult("Kotlin")))
        val viewModel = SearchViewModel(repo, mainDispatcherRule.testDispatcher)

        viewModel.uiState.test {
            assertEquals(SearchUiState.Idle, awaitItem())   // initial state

            viewModel.search("kotlin")
            mainDispatcherRule.testDispatcher.scheduler.advanceUntilIdle()

            assertEquals(SearchUiState.Loading, awaitItem())
            val results = awaitItem()
            assertTrue(results is SearchUiState.Results)
            assertEquals("Kotlin", (results as SearchUiState.Results).items.first().title)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `search emits Error when repository fails`() = runTest {
        val repo = FakeSearchRepository(throwOn = true)
        val viewModel = SearchViewModel(repo, mainDispatcherRule.testDispatcher)

        viewModel.uiState.test {
            awaitItem()  // Idle

            viewModel.search("kotlin")
            mainDispatcherRule.testDispatcher.scheduler.advanceUntilIdle()

            awaitItem()  // Loading
            assertTrue(awaitItem() is SearchUiState.Error)

            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

---

### Example 3 — Time-sensitive test with FakeClock (no Thread.sleep)

Demonstrates: injected clock, `advanceTimeBy`, deterministic expiry check.

```kotlin
// Minimal FakeClock for tests
class FakeClock(var now: Instant) : Clock() {
    override fun instant(): Instant = now
    override fun withZone(zone: ZoneId): Clock = this
    override fun getZone(): ZoneId = ZoneOffset.UTC
}

// Production code (simplified)
class SessionManager(
    private val clock: Clock = Clock.systemUTC(),
    private val ttlMs: Long = 30 * 60 * 1_000L,
    private val dispatcher: CoroutineDispatcher = Dispatchers.Default,
) {
    private var startTime: Instant? = null
    val isExpired: Boolean
        get() = startTime?.let { clock.instant().toEpochMilli() - it.toEpochMilli() >= ttlMs } ?: false

    fun start() { startTime = clock.instant() }
}

// Test
@Test
fun `session is expired after ttl milliseconds`() = runTest {
    val clock = FakeClock(now = Instant.EPOCH)
    val manager = SessionManager(clock = clock, ttlMs = 60_000L)

    manager.start()
    assertFalse(manager.isExpired)   // not yet expired

    clock.now = Instant.EPOCH.plusMillis(60_001L)

    assertTrue(manager.isExpired)   // deterministic — no sleep
}
```

---

### Example 4 — Compose UI test with createComposeRule

Demonstrates: JVM Compose test, semantic node assertions, interaction via `performClick`.

```kotlin
@get:Rule val composeRule = createComposeRule()

@Test
fun `UserScreen shows display name`() {
    composeRule.setContent {
        UserScreen(uiState = UiState.Success(User(id = 1L, displayName = "Ada Lovelace")))
    }
    composeRule.onNodeWithText("Ada Lovelace").assertIsDisplayed()
}

@Test
fun `UserScreen shows error message when state is Error`() {
    composeRule.setContent {
        UserScreen(uiState = UiState.Error("User not found"))
    }
    composeRule.onNodeWithText("User not found").assertIsDisplayed()
    composeRule.onNodeWithText("Ada Lovelace").assertDoesNotExist()
}

@Test
fun `retry button triggers onRetry callback`() {
    var retryCalled = false
    composeRule.setContent {
        UserScreen(
            uiState = UiState.Error("Network error"),
            onRetry = { retryCalled = true },
        )
    }
    composeRule.onNodeWithText("Retry").performClick()
    assertTrue(retryCalled)
}
```

---

## MainDispatcherRule (shared test utility)

Standard pattern for replacing `Dispatchers.Main` in JVM unit tests. Place in `src/test/`.

```kotlin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.runner.Description
import org.junit.rules.TestWatcher

class MainDispatcherRule : TestWatcher() {
    val testDispatcher = StandardTestDispatcher()

    override fun starting(description: Description) {
        Dispatchers.setMain(testDispatcher)
    }

    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}
```

## Official references

- Kotlin coroutines test: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/
- Turbine: https://github.com/cashapp/turbine
- MockK: https://mockk.io/
- Robolectric: https://robolectric.org/
- Compose testing: https://developer.android.com/develop/ui/compose/testing
- Android testing fundamentals: https://developer.android.com/training/testing/fundamentals
- Team baseline: [../../guidance.md](../../guidance.md)
