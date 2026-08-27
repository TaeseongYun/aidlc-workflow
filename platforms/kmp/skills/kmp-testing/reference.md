# kmp-testing — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** Kotlin code pairs per guard rule,
plus Mode-A generation examples. Decision criteria live in `SKILL.md`.

---

## Mode A — Generation examples

### Example 1: unit test with injected clock and Ktor MockEngine

```kotlin
// commonMain/kotlin/data/remote/WeatherRepository.kt
class WeatherRepository(
    private val httpClient: HttpClient,
    private val clock: Clock,           // kotlinx-datetime Clock — injectable
) {
    suspend fun fetchWeather(city: String): Weather {
        val response = httpClient.get("https://api.example.com/weather") {
            parameter("city", city)
        }
        if (!response.status.isSuccess()) throw WeatherException(response.status.value)
        return response.body<Weather>().copy(fetchedAt = clock.now())
    }
}

// commonTest/kotlin/data/remote/WeatherRepositoryTest.kt
import io.ktor.client.engine.mock.*
import io.ktor.http.*
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.*
import kotlin.test.*

class WeatherRepositoryTest {

    private val fixedClock = object : Clock {
        override fun now() = Instant.parse("2024-01-15T10:00:00Z")
    }

    @Test
    fun `returns parsed weather with fetchedAt from injected clock`() = runTest {
        // Arrange: MockEngine — no real network
        val engine = MockEngine { _ ->
            respond(
                content = """{"city":"London","temp":20}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val client = HttpClient(engine) { install(ContentNegotiation) { json() } }
        val sut = WeatherRepository(client, fixedClock)

        // Act
        val result = sut.fetchWeather("London")

        // Assert: SUT output, not the stub value
        assertEquals("London", result.city)
        assertEquals(20, result.temp)
        assertEquals(Instant.parse("2024-01-15T10:00:00Z"), result.fetchedAt)
    }

    @Test
    fun `throws WeatherException on non-200 response`() = runTest {
        // Arrange: server error path
        val engine = MockEngine { _ -> respond("", HttpStatusCode.ServiceUnavailable) }
        val client = HttpClient(engine)
        val sut = WeatherRepository(client, fixedClock)

        // Act + Assert: error branch covered
        assertFailsWith<WeatherException> {
            sut.fetchWeather("London")
        }.also { assertEquals(503, it.statusCode) }
    }
}
```

### Example 2: ViewModel Flow test with Turbine

```kotlin
// commonTest/kotlin/presentation/WeatherViewModelTest.kt
import app.cash.turbine.test
import kotlinx.coroutines.test.runTest
import kotlin.test.*

class WeatherViewModelTest {

    @Test
    fun `emits Loading then Loaded on successful fetch`() = runTest {
        // Arrange
        val repo = FakeWeatherRepository()
        repo.setNextResult(Weather(city = "London", temp = 20))
        val vm = WeatherViewModel(repo)

        vm.uiState.test {
            // Assert initial state
            assertIs<WeatherUiState.Idle>(awaitItem())

            // Act
            vm.fetchWeather("London")

            // Assert sequence
            assertIs<WeatherUiState.Loading>(awaitItem())
            val loaded = assertIs<WeatherUiState.Loaded>(awaitItem())
            assertEquals("London", loaded.weather.city)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `emits Error when repository throws`() = runTest {
        val repo = FakeWeatherRepository()
        repo.setNextError(WeatherException(503))
        val vm = WeatherViewModel(repo)

        vm.uiState.test {
            assertIs<WeatherUiState.Idle>(awaitItem())
            vm.fetchWeather("London")
            assertIs<WeatherUiState.Loading>(awaitItem())
            val error = assertIs<WeatherUiState.Error>(awaitItem())
            assertEquals(503, error.statusCode)
            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

### Example 3: Compose UI test

```kotlin
// androidUnitTest or commonTest with runComposeUiTest
import androidx.compose.ui.test.*

class WeatherScreenTest {

    @Test
    fun showsLoadingIndicator_whileLoading() = runComposeUiTest {
        setContent {
            WeatherScreen(uiState = WeatherUiState.Loading)
        }
        onNodeWithContentDescription("Loading").assertIsDisplayed()
    }

    @Test
    fun showsErrorAndRetryButton_onFailure() = runComposeUiTest {
        setContent {
            WeatherScreen(uiState = WeatherUiState.Error(message = "No connection"))
        }
        onNodeWithText("No connection").assertIsDisplayed()
        onNodeWithText("Retry").assertIsDisplayed()
    }
}
```

---

## Guard rule 1 — Assertion-free test

```kotlin
// ❌ Runs the SUT; asserts nothing — CI stays green, bugs stay hidden
@Test
fun `fetchWeather completes`() = runTest {
    val repo = FakeWeatherRepository()
    repo.fetchWeather("London") // no assertion
}

// ✅ Asserts the actual output
@Test
fun `fetchWeather returns weather for valid city`() = runTest {
    val engine = MockEngine { _ ->
        respond("""{"city":"London","temp":20}""", HttpStatusCode.OK,
            headersOf(HttpHeaders.ContentType, "application/json"))
    }
    val sut = WeatherRepository(HttpClient(engine) { install(ContentNegotiation) { json() } }, FixedClock)

    val result = sut.fetchWeather("London")

    assertEquals("London", result.city)
    assertEquals(20, result.temp)
}
```

---

## Guard rule 2 — Mock-echo / tautological assertion

```kotlin
// ❌ Asserts the stub value — verifies nothing the SUT did
@Test
fun `getUser returns user`() = runTest {
    val fakeUser = User(id = 1, name = "Alice")
    val repo = mockk<UserRepository>()
    every { repo.getUser(1) } returns fakeUser
    val sut = UserService(repo)

    val result = sut.getUser(1)

    assertEquals(fakeUser, result) // tautological: SUT could be removed and this still passes
}

// ✅ Assert something the SUT transforms or enriches
@Test
fun `getUser returns display-formatted name`() = runTest {
    val repo = mockk<UserRepository>()
    every { repo.getUser(1) } returns User(id = 1, name = "alice")
    val sut = UserService(repo) // SUT capitalizes the name

    val result = sut.getUser(1)

    assertEquals("Alice", result.displayName) // SUT's transformation, not the stub value
}
```

---

## Guard rule 3 — Over-mocking / mocking the SUT

```kotlin
// ❌ mockk<WeatherViewModel>() is the SUT — the real implementation is never exercised
@Test
fun `WeatherViewModel emits loaded state`() = runTest {
    val vm = mockk<WeatherViewModel>() // mocking the class under test
    every { vm.uiState } returns MutableStateFlow(WeatherUiState.Loaded(Weather("London", 20)))

    vm.uiState.test {
        assertIs<WeatherUiState.Loaded>(awaitItem())
    }
    // This tests mockk, not WeatherViewModel
}

// ✅ Use the real SUT; mock/fake only its dependencies
@Test
fun `WeatherViewModel emits Loaded after successful fetch`() = runTest {
    val repo = FakeWeatherRepository()
    repo.setNextResult(Weather(city = "London", temp = 20))
    val vm = WeatherViewModel(repo) // real implementation

    vm.uiState.test {
        assertIs<WeatherUiState.Idle>(awaitItem())
        vm.fetchWeather("London")
        assertIs<WeatherUiState.Loading>(awaitItem())
        val loaded = assertIs<WeatherUiState.Loaded>(awaitItem())
        assertEquals("London", loaded.weather.city)
        cancelAndIgnoreRemainingEvents()
    }
}
```

---

## Guard rule 4 — Implementation-detail coupling

```kotlin
// ❌ Asserts on a private helper — breaks on any refactor, even a no-op one
@Test
fun `parse calls normalizeCity`() {
    val sut = WeatherParser()
    verify { sut["normalizeCity"]("London") } // private internals via reflection
}

// ✅ Assert on the observable output; internal refactors don't break the test
@Test
fun `parse trims and lowercases city name`() {
    val sut = WeatherParser()
    val result = sut.parse("  LONDON  ")
    assertEquals("london", result.city) // public output, not how it got there
}
```

---

## Guard rule 5 — Non-determinism / flakiness

```kotlin
// ❌ Thread.sleep in a test — flaky in slow CI, slow everywhere
@Test
fun `loader disappears after fetch`() = runTest {
    val vm = WeatherViewModel(SlowFakeRepository())
    vm.fetchWeather("London")
    Thread.sleep(300) // real wall-clock wait — never do this
    assertIs<WeatherUiState.Loaded>(vm.uiState.value)
}

// ✅ runTest auto-advances virtual time — deterministic and instant
@Test
fun `loader disappears when fetch completes`() = runTest {
    val repo = FakeWeatherRepository()
    repo.setNextResult(Weather("London", 20))
    val vm = WeatherViewModel(repo)

    vm.uiState.test {
        assertIs<WeatherUiState.Idle>(awaitItem())
        vm.fetchWeather("London")
        assertIs<WeatherUiState.Loading>(awaitItem())
        assertIs<WeatherUiState.Loaded>(awaitItem()) // no real wait
        cancelAndIgnoreRemainingEvents()
    }
}

// ❌ Clock.System.now() in Arrange — result depends on when the test runs
@Test
fun `token is not expired`() {
    val token = Token(expiresAt = Clock.System.now().plus(1.hours)) // flaky near boundaries
    assertTrue(token.isValid)
}

// ✅ Fixed Instant via injected Clock
@Test
fun `token is valid when expiry is in the future`() {
    val now = Instant.parse("2024-06-01T12:00:00Z")
    val token = Token(expiresAt = now.plus(1.hours))
    assertTrue(token.isValidAt(now))
}
```

---

## Guard rule 6 — Happy-path only

```kotlin
// ❌ Only the success case — the error/empty branches are unverified
@Test
fun `fetchWeather returns weather`() = runTest {
    val engine = MockEngine { _ ->
        respond("""{"city":"London","temp":20}""", HttpStatusCode.OK,
            headersOf(HttpHeaders.ContentType, "application/json"))
    }
    val result = WeatherRepository(HttpClient(engine) { install(ContentNegotiation) { json() } }, FixedClock)
        .fetchWeather("London")
    assertEquals("London", result.city)
}

// ✅ Success + error + boundary all covered
class WeatherRepositoryTests {
    @Test fun `returns parsed weather on 200`() = runTest {
        val engine = MockEngine { _ ->
            respond("""{"city":"London","temp":20}""", HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val result = WeatherRepository(HttpClient(engine) { install(ContentNegotiation) { json() } }, FixedClock)
            .fetchWeather("London")
        assertEquals("London", result.city)
    }

    @Test fun `throws WeatherException on 503`() = runTest {
        val engine = MockEngine { _ -> respond("", HttpStatusCode.ServiceUnavailable) }
        assertFailsWith<WeatherException> {
            WeatherRepository(HttpClient(engine), FixedClock).fetchWeather("London")
        }
    }

    @Test fun `throws SerializationException on malformed JSON`() = runTest {
        val engine = MockEngine { _ ->
            respond("not-json", HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"))
        }
        assertFailsWith<Exception> {
            WeatherRepository(HttpClient(engine) { install(ContentNegotiation) { json() } }, FixedClock)
                .fetchWeather("London")
        }
    }
}
```

---

## Guard rule 7 — Snapshot / golden abuse

```kotlin
// ❌ Screenshot regenerated without review — the assertion becomes whatever renders now
@Test
fun weatherCard_golden() = runComposeUiTest {
    setContent { WeatherCard(temp = 20) }
    // run screenshot update on every PR to "fix" failures — meaningless baseline
    assertScreenshot("weather_card") // updated blindly
}

// ✅ Behavior assertions first; screenshot only for intentional visual regression detection
@Test
fun weatherCard_rendersCorrectly() = runComposeUiTest {
    setContent {
        MaterialTheme { WeatherCard(temp = 20, description = "Sunny") }
    }

    // Behavior assertions — catch logic bugs regardless of pixel changes
    onNodeWithText("20°").assertIsDisplayed()
    onNodeWithText("Sunny").assertIsDisplayed()

    // Screenshot for visual regression — only update after deliberate review
    assertScreenshot("weather_card_sunny_20")
    // ponytail: update screenshots only after explicit review of the diff image
}
```

---

## Guard rule 8 — Smuggled @Ignore / skip

```kotlin
// ❌ Silent skip — this broken test will never run again
@Ignore("TODO")
@Test
fun `fetchWeather handles timeout`() = runTest {
    // ...
}

// ❌ Return as first statement — silently short-circuits
@Test
fun `WeatherViewModel renders on iOS`() = runTest {
    return // nothing tested; counts toward coverage
    // ...
}

// ✅ @Ignore with reason + ticket — tracked and time-boxed
@Ignore(
    // Blocked: MockEngine does not yet expose request timeout simulation.
    // Remove when https://github.com/org/repo/issues/4321 is resolved.
    "Blocked on MockEngine timeout support — see #4321"
)
@Test
fun `fetchWeather throws on timeout`() = runTest {
    // ...
}
```

---

## Guard rule 9 — Copy-paste clone

```kotlin
// ❌ Identical assertions, different names — neither adds unique coverage
@Test fun `fetchWeather with London returns weather`() = runTest {
    val result = repo.fetchWeather("London")
    assertEquals("London", result.city)
    assertEquals(20, result.temp)
}

@Test fun `fetchWeather with Paris returns weather`() = runTest {
    // copy-pasted — still returns London/20 from the same fake
    val result = repo.fetchWeather("Paris")
    assertEquals("London", result.city) // wrong assertion; went unnoticed in copy-paste
    assertEquals(20, result.temp)
}

// ✅ Parameterize differing inputs — each case is distinct and correct
@Test
fun `fetchWeather returns correct data for each city`() = runTest {
    data class Case(val city: String, val responseJson: String, val expectedTemp: Int)
    val cases = listOf(
        Case("London", """{"city":"London","temp":20}""", 20),
        Case("Paris",  """{"city":"Paris","temp":15}""",  15),
        Case("Tokyo",  """{"city":"Tokyo","temp":28}""",  28),
    )

    for ((city, json, expected) in cases) {
        val engine = MockEngine { _ ->
            respond(json, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val result = WeatherRepository(
            HttpClient(engine) { install(ContentNegotiation) { json() } }, FixedClock
        ).fetchWeather(city)
        assertEquals(city, result.city, "city mismatch for $city")
        assertEquals(expected, result.temp, "temp mismatch for $city")
    }
}
```

---

## Guard rule 10 — Coverage theater

```kotlin
// ❌ Calls every method; asserts nothing; line coverage is 100%, value is 0%
@Test
fun `WeatherService smoke test`() = runTest {
    val svc = WeatherService(FakeWeatherRepository())
    // only checks "it didn't throw"
    svc.refresh("Berlin")
    svc.clear()
    svc.lastCity // read — no assertion
}

// ✅ Assert on actual output and state transitions — mutations fail
class WeatherServiceTest {
    @Test
    fun `refresh updates lastCity`() = runTest {
        val repo = FakeWeatherRepository()
        repo.setNextResult(Weather(city = "Berlin", temp = 18))
        val svc = WeatherService(repo)

        svc.refresh("Berlin")

        assertEquals("Berlin", svc.lastCity) // a mutant returning null would fail this
    }

    @Test
    fun `clear resets lastCity to null`() = runTest {
        val repo = FakeWeatherRepository()
        val svc = WeatherService(repo).also { it.refresh("Berlin") }

        svc.clear()

        assertNull(svc.lastCity) // asserts the state mutation
    }
}
```

---

## Official references

- kotlin.test API: https://kotlinlang.org/api/latest/kotlin.test/
- kotlinx-coroutines-test: https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/
- Turbine: https://github.com/cashapp/turbine
- Ktor MockEngine: https://ktor.io/docs/client-testing.html
- Compose Multiplatform testing: https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-test.html
- mockk: https://mockk.io/
- Team baseline: [../../guidance.md](../../guidance.md)
