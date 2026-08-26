# ios-testing — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** Swift code pairs per guard rule,
plus Mode-A generation examples. Decision criteria live in `SKILL.md`.

---

## Guard rules — bad → good pairs

### 1. Assertion-free test

```swift
// ❌ Runs code, asserts nothing — proves nothing
func test_login_callsAuthService() async {
    let stub = StubAuthService()
    let sut = LoginViewModel(authService: stub)
    await sut.login(email: "a@b.com", password: "pw")
    // no XCTAssert* anywhere — test always passes
}

// ✅ Makes a falsifiable claim about observable state
func test_login_withValidCredentials_setsStateToLoggedIn() async {
    let stub = StubAuthService(result: .success(User.fixture()))
    let sut = LoginViewModel(authService: stub)
    await sut.login(email: "a@b.com", password: "pw")
    XCTAssertEqual(sut.state, .loggedIn)
}
```

---

### 2. Mock-echo / tautological assertion

```swift
// ❌ Asserts the stub's own return value — verifies the stub, not the SUT
func test_fetchUser_returnsUser() async throws {
    let expected = User(id: "42", name: "Alice")
    let stub = StubUserService(user: expected)
    let sut = UserRepository(service: stub)

    let result = try await sut.fetchUser(id: "42")

    // This asserts exactly what the stub was told to return. If the repository
    // swallowed the result and returned a hardcoded fixture, this still passes.
    XCTAssertEqual(result.id, expected.id)  // tautology
}

// ✅ Asserts a transformation the SUT actually performs on the stub's output
func test_fetchUser_mapsServiceUserToDisplayModel() async throws {
    let stub = StubUserService(user: User(id: "42", name: "alice mcgee"))
    let sut = UserRepository(service: stub)

    let display = try await sut.fetchUser(id: "42")

    // The repository capitalises the name — assert that real transformation
    XCTAssertEqual(display.name, "Alice Mcgee")
}
```

---

### 3. Over-mocking / mocking the SUT

```swift
// ❌ Tests the mock, not the real LoginViewModel
func test_login_success() async {
    // MockLoginViewModel is a hand-rolled fake of the class under test
    let sut = MockLoginViewModel()
    sut.stubbedLoginResult = true

    await sut.login(email: "x@y.com", password: "pw")

    XCTAssertTrue(sut.didCallLogin)  // only proves the mock was called
}

// ✅ Uses the real LoginViewModel; only its dependency is stubbed
func test_login_withValidCredentials_setsStateToLoggedIn() async {
    let stub = StubAuthService(result: .success(User.fixture()))
    let sut = LoginViewModel(authService: stub)  // real SUT

    await sut.login(email: "x@y.com", password: "pw")

    XCTAssertEqual(sut.state, .loggedIn)
}
```

---

### 4. Implementation-detail coupling

```swift
// ❌ Asserts on private call count — breaks on any internal refactor
func test_save_callsRepositorySaveOnce() async {
    let spy = SpyUserRepository()
    let sut = ProfileViewModel(repository: spy)

    await sut.saveProfile(name: "Bob")

    // Tightly coupled to the number of internal calls
    XCTAssertEqual(spy.saveCallCount, 1)
    // Worse: accessing a private property via @testable import
    XCTAssertEqual(sut._internalSaveAttempts, 1)
}

// ✅ Asserts on the observable outcome — resilient to refactors
func test_save_persistsNameToRepository() async throws {
    let repository = InMemoryUserRepository()
    let sut = ProfileViewModel(repository: repository)

    await sut.saveProfile(name: "Bob")

    let saved = try await repository.fetchUser(id: sut.userID)
    XCTAssertEqual(saved.name, "Bob")
}
```

---

### 5. Non-determinism / flakiness

```swift
// ❌ Real clock, real network, sleep to wait for async work
func test_session_hasNotExpired() {
    let sut = SessionManager()
    // Real clock — test will start failing as soon as `expiresAt` is in the past
    XCTAssertGreaterThan(sut.expiresAt, Date())
}

func test_fetchPosts_returnsData() async throws {
    let sut = PostRepository(session: URLSession.shared) // live network
    let posts = try await sut.fetchPosts()
    XCTAssertFalse(posts.isEmpty)
}

func test_imageLoad_completesWithinTimeout() {
    let sut = ImageLoader()
    sut.load(url: URL(string: "https://example.com/img.png")!)
    sleep(2)  // flaky: may be too short or too long
    XCTAssertNotNil(sut.image)
}

// ✅ Injected clock; URLProtocol stub; no sleep
protocol ClockProtocol { var now: Date { get } }
struct FixedClock: ClockProtocol { let now: Date }

func test_session_hasNotExpired_withInjectedClock() {
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    let sut = SessionManager(clock: FixedClock(now: fixedNow),
                             expiresAt: fixedNow.addingTimeInterval(3600))
    XCTAssertTrue(sut.isValid)
}

final class StubURLProtocol: URLProtocol {
    static var responseData: Data = Data()
    static var responseCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.responseCode,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func test_fetchPosts_returnsDecodedPosts() async throws {
    StubURLProtocol.responseData = try JSONEncoder().encode([Post.fixture()])
    StubURLProtocol.responseCode = 200

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)

    let sut = PostRepository(session: session)
    let posts = try await sut.fetchPosts()
    XCTAssertEqual(posts.count, 1)
}
```

---

### 6. Happy-path only

```swift
// ❌ Only the success case is tested; the error branch has zero coverage
func test_fetchWeather_success() async throws {
    let stub = StubWeatherService(result: .success(Weather.fixture()))
    let sut = WeatherViewModel(service: stub)
    await sut.refresh()
    XCTAssertEqual(sut.state, .loaded(Weather.fixture()))
    // fetchWeather also has a network-error branch and a decoding-error branch —
    // neither is tested
}

// ✅ One test per meaningful branch
func test_fetchWeather_whenNetworkFails_setsErrorState() async {
    let stub = StubWeatherService(result: .failure(URLError(.notConnectedToInternet)))
    let sut = WeatherViewModel(service: stub)
    await sut.refresh()
    XCTAssertEqual(sut.state, .error(.networkUnavailable))
}

func test_fetchWeather_whenDecodingFails_setsErrorState() async {
    let stub = StubWeatherService(result: .failure(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))))
    let sut = WeatherViewModel(service: stub)
    await sut.refresh()
    XCTAssertEqual(sut.state, .error(.invalidResponse))
}
```

---

### 7. Snapshot abuse

```swift
// ❌ Snapshot is the only assertion; committed in record mode; covers entire screen
func test_homeScreen() {
    let view = HomeView(viewModel: .preview)
    // Record mode left on — silently accepts any output as correct
    assertSnapshot(of: view, as: .image(precision: 1.0), record: true)
    // No behavioral assertions alongside it
}

// ✅ Snapshot scoped to one component; paired with a behavioral assertion;
//    record mode off (default); snapshot reviewed before commit
func test_errorBanner_appearsWhenStateIsError() throws {
    let sut = ErrorBannerView(message: "No connection")

    // Behavioral assertion first
    let inspector = try sut.inspect()
    let text = try inspector.find(text: "No connection")
    XCTAssertNotNil(text)

    // Narrow snapshot for regression only — record: false (the default)
    assertSnapshot(of: sut, as: .image)
}
```

---

### 8. Smuggled skip / disable

```swift
// ❌ Skipped with no reason and no tracking reference
func test_checkout_handlesPaymentTimeout() throws {
    try XCTSkip("TODO")  // coverage silently disappears
}

// ❌ Swift Testing equivalent — no tracking reference
@Test(.disabled("flaky"))
func checkout_handlesPaymentTimeout() async { }

// ✅ XCTest skip with documented reason + tracking reference
func test_checkout_handlesPaymentTimeout() throws {
    // Skipped until the payment SDK exposes a timeout simulation API.
    // Tracking: https://linear.app/myteam/issue/PAY-412
    try XCTSkip("PAY-412: PaymentKit does not expose timeout injection yet")
}

// ✅ Swift Testing with .disabled and a justification comment
@Test(.disabled("PAY-412: PaymentKit does not expose timeout injection — remove when SDK ≥ 3.2"))
func checkout_handlesPaymentTimeout() async { }
```

---

### 9. Copy-paste clone

```swift
// ❌ Two tests with different names but identical arrange/act/assert — cover the same thing
func test_formatPrice_returnsFormattedString() {
    let sut = PriceFormatter()
    let result = sut.format(9.99, currency: "USD")
    XCTAssertEqual(result, "$9.99")
}

func test_priceFormatter_formatsCorrectly() {
    let sut = PriceFormatter()
    let result = sut.format(9.99, currency: "USD")
    XCTAssertEqual(result, "$9.99")  // identical assertion, identical scenario
}

// ✅ Each test covers a distinct, meaningfully different scenario
func test_formatPrice_USD_prependsDollarSign() {
    XCTAssertEqual(PriceFormatter().format(9.99, currency: "USD"), "$9.99")
}

func test_formatPrice_EUR_appendsEuroSign() {
    XCTAssertEqual(PriceFormatter().format(9.99, currency: "EUR"), "9,99 €")
}

func test_formatPrice_zero_returnsZeroWithSymbol() {
    XCTAssertEqual(PriceFormatter().format(0, currency: "USD"), "$0.00")
}
```

---

### 10. Coverage theater

```swift
// ❌ Calls many methods; asserts only XCTAssertNotNil — mutation score near zero
func test_cartViewModel_coverage() async {
    let sut = CartViewModel(repository: StubCartRepository())
    await sut.loadCart()
    XCTAssertNotNil(sut.items)   // passes even if items is always []
    sut.removeItem(at: 0)
    XCTAssertNotNil(sut.items)   // passes even if remove did nothing
    await sut.checkout()
    XCTAssertNotNil(sut.checkoutResult)  // passes even if result is always nil
}

// ✅ Asserts specific, meaningful values that would fail if the logic broke
func test_loadCart_populatesItems() async {
    let repo = StubCartRepository(items: [CartItem.fixture(id: "A"), CartItem.fixture(id: "B")])
    let sut = CartViewModel(repository: repo)
    await sut.loadCart()
    XCTAssertEqual(sut.items.map(\.id), ["A", "B"])
}

func test_removeItem_atIndex_removesCorrectItem() async {
    let repo = StubCartRepository(items: [CartItem.fixture(id: "A"), CartItem.fixture(id: "B")])
    let sut = CartViewModel(repository: repo)
    await sut.loadCart()
    sut.removeItem(at: 0)
    XCTAssertEqual(sut.items.map(\.id), ["B"])
}
```

---

## Mode A — Generation examples

### Example 1: Unit test with injected clock and URLProtocol network stub

This example shows a `TokenRefreshService` that must not refresh tokens whose expiry is more than
5 minutes away. The clock is injected so the test is deterministic; the network is stubbed via
`URLProtocol` so no live connection is needed.

```swift
// Production code (abbreviated)
protocol ClockProtocol {
    var now: Date { get }
}

struct SystemClock: ClockProtocol {
    var now: Date { Date() }
}

final class TokenRefreshService {
    private let session: URLSession
    private let clock: ClockProtocol

    init(session: URLSession, clock: ClockProtocol = SystemClock()) {
        self.session = session
        self.clock = clock
    }

    /// Returns a new access token only if the current one expires within 5 minutes.
    func refreshIfNeeded(token: Token) async throws -> Token {
        let threshold = clock.now.addingTimeInterval(5 * 60)
        guard token.expiresAt < threshold else { return token }
        return try await refresh(token: token)
    }

    private func refresh(token: Token) async throws -> Token {
        let (data, _) = try await session.data(from: URL(string: "https://api.example.com/refresh")!)
        return try JSONDecoder().decode(Token.self, from: data)
    }
}

// Test
final class TokenRefreshServiceTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: config)
    }

    // Arrange: token expires in 2 minutes (within the 5-minute threshold)
    // → network should be called; decoded token returned
    func test_refreshIfNeeded_whenTokenExpiresSoon_fetchesNewToken() async throws {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let expiringToken = Token(value: "old", expiresAt: fixedNow.addingTimeInterval(2 * 60))
        let freshToken   = Token(value: "new", expiresAt: fixedNow.addingTimeInterval(3600))

        StubURLProtocol.responseData = try JSONEncoder().encode(freshToken)
        StubURLProtocol.responseCode = 200

        let sut = TokenRefreshService(
            session: session,
            clock: FixedClock(now: fixedNow)
        )

        // Act
        let result = try await sut.refreshIfNeeded(token: expiringToken)

        // Assert — SUT decoded a new token from the stubbed response
        XCTAssertEqual(result.value, "new")
    }

    // Arrange: token expires in 30 minutes (outside the threshold)
    // → original token should be returned without a network call
    func test_refreshIfNeeded_whenTokenHasTimeLeft_returnsOriginalToken() async throws {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let validToken = Token(value: "still-valid", expiresAt: fixedNow.addingTimeInterval(30 * 60))

        // No stubbed response — if a network call is made, the test will throw
        StubURLProtocol.responseCode = 500

        let sut = TokenRefreshService(
            session: session,
            clock: FixedClock(now: fixedNow)
        )

        let result = try await sut.refreshIfNeeded(token: validToken)

        XCTAssertEqual(result.value, "still-valid")
    }
}
```

### Example 2: Error-path test with XCTAssertThrowsError and Swift Testing #expect(throws:)

This example shows both XCTest and Swift Testing syntax for verifying that the right error type
and code are thrown when a network request fails.

```swift
// XCTest style — error path
final class UserRepositoryTests: XCTestCase {
    func test_fetchUser_whenNotConnected_throwsURLError() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.responseCode = 0  // triggers connection error simulation
        StubURLProtocol.responseData = Data()

        // Configure the stub to throw instead of returning data
        StubURLProtocol.shouldThrow = URLError(.notConnectedToInternet)

        let session = URLSession(configuration: config)
        let sut = UserRepository(session: session)

        await XCTAssertThrowsError(try await sut.fetchUser(id: "1")) { error in
            guard let urlError = error as? URLError else {
                return XCTFail("Expected URLError, got \(error)")
            }
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        }
    }

    func test_fetchUser_whenServerReturns404_throwsNotFoundError() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.responseCode = 404
        StubURLProtocol.responseData = Data()

        let session = URLSession(configuration: config)
        let sut = UserRepository(session: session)

        await XCTAssertThrowsError(try await sut.fetchUser(id: "99")) { error in
            XCTAssertEqual(error as? RepositoryError, .notFound)
        }
    }
}

// Swift Testing style — same scenarios
struct UserRepositorySwiftTestingTests {
    @Test func fetchUser_whenNotConnected_throwsURLError() async {
        let session = makeStubbedSession(throwing: URLError(.notConnectedToInternet))
        let sut = UserRepository(session: session)

        await #expect(throws: URLError.self) {
            try await sut.fetchUser(id: "1")
        }
    }

    @Test func fetchUser_whenServerReturns404_throwsNotFound() async {
        let session = makeStubbedSession(statusCode: 404, data: Data())
        let sut = UserRepository(session: session)

        await #expect(throws: RepositoryError.notFound) {
            try await sut.fetchUser(id: "99")
        }
    }
}
```

---

## StubURLProtocol — reusable test helper

```swift
/// Lightweight URLProtocol stub for unit tests. Register on a custom URLSessionConfiguration;
/// never use URLSession.shared in tests.
final class StubURLProtocol: URLProtocol {
    static var responseData: Data = Data()
    static var responseCode: Int = 200
    static var shouldThrow: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.shouldThrow {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.responseCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

## Official references

- Apple — XCTest: https://developer.apple.com/documentation/xctest
- Apple — Swift Testing: https://developer.apple.com/documentation/testing
- Apple — XCUITest: https://developer.apple.com/documentation/xctest/user_interface_tests
- ViewInspector: https://github.com/nalexn/ViewInspector
- swift-snapshot-testing: https://github.com/pointfreeco/swift-snapshot-testing
- Team baseline: [../../guidance.md](../../guidance.md)
