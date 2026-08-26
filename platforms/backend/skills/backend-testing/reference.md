# backend-testing — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code per guard rule, plus Mode-A
generation examples. JVM/Kotlin first (dominant stack), Python and Go alongside where instructive.
Decision criteria live in `SKILL.md`.

---

## Mode A — Generation examples

### Good unit test: injected clock (Kotlin / JUnit 5 + MockK)

```kotlin
// Production code — clock injected, never calls LocalDateTime.now() directly
class TokenService(private val clock: Clock) {
    fun isExpired(token: Token): Boolean =
        token.expiresAt.isBefore(LocalDateTime.now(clock))
}

// Test — clock is fixed; no real-time dependency
class TokenServiceTest {
    private val fixedClock = Clock.fixed(
        Instant.parse("2024-06-01T12:00:00Z"), ZoneOffset.UTC
    )
    private val sut = TokenService(fixedClock)

    @Test
    fun `token expiring in the past is expired`() {
        val token = Token(expiresAt = LocalDateTime.of(2024, 5, 31, 12, 0))
        assertTrue(sut.isExpired(token))
    }

    @Test
    fun `token expiring in the future is not expired`() {
        val token = Token(expiresAt = LocalDateTime.of(2024, 6, 2, 12, 0))
        assertFalse(sut.isExpired(token))
    }
}
```

### Good unit test: faked HTTP client + error path (Python / pytest)

```python
# Production code — client injected
class PaymentGateway:
    def __init__(self, client: httpx.Client):
        self._client = client

    def charge(self, amount: int) -> dict:
        resp = self._client.post("/charge", json={"amount": amount})
        resp.raise_for_status()
        return resp.json()

# Tests — no live network; both success and failure paths covered
def test_charge_returns_parsed_response():
    fake_response = httpx.Response(200, json={"id": "ch_123", "status": "ok"})
    client = MagicMock(spec=httpx.Client)
    client.post.return_value = fake_response

    result = PaymentGateway(client).charge(500)

    assert result == {"id": "ch_123", "status": "ok"}

def test_charge_raises_on_4xx():
    client = MagicMock(spec=httpx.Client)
    client.post.return_value = httpx.Response(422, json={"error": "invalid amount"})

    with pytest.raises(httpx.HTTPStatusError):
        PaymentGateway(client).charge(-1)
```

### Good integration test: Testcontainers (Kotlin)

```kotlin
@SpringBootTest
@Testcontainers
class OrderRepositoryIT {

    companion object {
        @Container
        @JvmStatic
        val postgres = PostgreSQLContainer<Nothing>("postgres:16-alpine").apply {
            withDatabaseName("testdb")
        }

        @DynamicPropertySource
        @JvmStatic
        fun props(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }

    @Autowired lateinit var repo: OrderRepository

    @Test
    fun `saved order is retrievable by id`() {
        val saved = repo.save(Order(userId = 42L, total = 1000))
        val found = repo.findById(saved.id!!).orElse(null)
        assertNotNull(found)
        assertEquals(42L, found.userId)
    }
}
```

---

## Guard rules — bad → good

### 1. Assertion-free test

```kotlin
// ❌ Assertion-free — proves only that the method does not crash
@Test
fun `create order`() {
    val service = OrderService(mockk())
    service.create(OrderRequest(userId = 1L, total = 500))
    // nothing asserted
}

// ✅ Observable result is verified
@Test
fun `create order returns saved order with generated id`() {
    val repo = mockk<OrderRepository>()
    every { repo.save(any()) } answers { firstArg<Order>().copy(id = 99L) }

    val result = OrderService(repo).create(OrderRequest(userId = 1L, total = 500))

    assertEquals(99L, result.id)
    assertEquals(500, result.total)
}
```

```python
# ❌ Assertion-free
def test_process():
    svc = OrderService(repo=MagicMock())
    svc.process(order_id=1)   # no assert

# ✅
def test_process_returns_updated_status():
    repo = MagicMock()
    repo.find.return_value = Order(id=1, status="PENDING")
    result = OrderService(repo).process(order_id=1)
    assert result.status == "PROCESSED"
```

### 2. Mock-echo / tautological assertion

```kotlin
// ❌ Tautological — asserts the mock returns what the mock was told to return
@Test
fun `find order by id`() {
    val expected = Order(id = 1L, total = 200)
    val repo = mockk<OrderRepository>()
    every { repo.findById(1L) } returns expected

    val result = OrderService(repo).getOrder(1L)

    assertEquals(expected, result)   // trivially true — the mock IS the result
}

// ✅ Test what the service does with the repository value (e.g. applies a discount)
@Test
fun `getOrder applies member discount to total`() {
    val repo = mockk<OrderRepository>()
    every { repo.findById(1L) } returns Order(id = 1L, total = 200, memberTier = "GOLD")

    val result = OrderService(repo).getOrder(1L)

    assertEquals(180, result.discountedTotal)   // verifies the service's own logic
}
```

```go
// ❌ Tautological — Go
func TestGetUser_Tautological(t *testing.T) {
    mockRepo := new(MockUserRepo)
    user := &User{ID: 1, Name: "Alice"}
    mockRepo.On("FindByID", 1).Return(user, nil)

    got, _ := NewUserService(mockRepo).GetUser(1)
    assert.Equal(t, user, got) // just echoes the mock
}

// ✅ Verifies service-level transformation (e.g. masked email)
func TestGetUser_MasksEmail(t *testing.T) {
    mockRepo := new(MockUserRepo)
    mockRepo.On("FindByID", 1).Return(&User{ID: 1, Email: "alice@example.com"}, nil)

    got, _ := NewUserService(mockRepo).GetUser(1)
    assert.Equal(t, "a***@example.com", got.Email)
}
```

### 3. Over-mocking / mocking the SUT

```kotlin
// ❌ The service under test is mocked — no real code runs
class OrderServiceTest {
    private val sut = mockk<OrderService>()   // ← mocking the class this file tests

    @Test
    fun `cancel order`() {
        every { sut.cancel(any()) } returns CancelResult.OK
        val result = sut.cancel(1L)
        assertEquals(CancelResult.OK, result)   // tests only the mock
    }
}

// ✅ Real implementation; only its dependencies are mocked
class OrderServiceTest {
    private val repo = mockk<OrderRepository>()
    private val sut = OrderService(repo)        // ← real class under test

    @Test
    fun `cancel marks order as cancelled`() {
        every { repo.findById(1L) } returns Order(id = 1L, status = "ACTIVE")
        every { repo.save(any()) } answers { firstArg() }

        val result = sut.cancel(1L)

        assertEquals("CANCELLED", result.status)
    }
}
```

### 4. Implementation-detail coupling

```kotlin
// ❌ Verifies internal call count — breaks on refactor even if behavior is correct
@Test
fun `place order saves to repository`() {
    val repo = mockk<OrderRepository>(relaxed = true)
    OrderService(repo).place(OrderRequest(userId = 1L, total = 100))
    verify(exactly = 1) { repo.save(any()) }   // only tests internal wiring, not the result
}

// ✅ Asserts the observable outcome (persisted state + returned value)
@Test
fun `place order returns persisted order with id`() {
    val repo = mockk<OrderRepository>()
    every { repo.save(any()) } answers { firstArg<Order>().copy(id = 7L) }

    val result = OrderService(repo).place(OrderRequest(userId = 1L, total = 100))

    assertEquals(7L, result.id)
    assertEquals(1L, result.userId)
}
```

```python
# ❌ Brittle call-count assert on an internal collaborator
def test_notify_sends_email():
    notifier = MagicMock()
    svc = NotificationService(notifier)
    svc.notify(user_id=1, event="LOGIN")
    notifier.send.assert_called_once()   # implementation detail; passes even if message is wrong

# ✅ Assert the observable message content
def test_notify_sends_correct_subject():
    notifier = MagicMock()
    svc = NotificationService(notifier)
    svc.notify(user_id=1, event="LOGIN")
    notifier.send.assert_called_once_with(
        recipient_id=1,
        subject="New login detected",
        template="login_alert",
    )
```

### 5. Non-determinism / flakiness

```kotlin
// ❌ Real clock — test outcome depends on when CI runs it
@Test
fun `session is expired after one hour`() {
    val session = Session(createdAt = LocalDateTime.now().minusHours(2))
    assertTrue(SessionValidator().isExpired(session))   // passes "now" but may drift
}

// ✅ Injected clock — fully deterministic
@Test
fun `session created two hours ago is expired`() {
    val fixedNow = Instant.parse("2024-06-01T10:00:00Z")
    val clock = Clock.fixed(fixedNow, ZoneOffset.UTC)
    val session = Session(createdAt = LocalDateTime.ofInstant(fixedNow, ZoneOffset.UTC).minusHours(2))

    assertTrue(SessionValidator(clock).isExpired(session))
}
```

```go
// ❌ Real clock in Go test
func TestTokenExpiry(t *testing.T) {
    tok := Token{ExpiresAt: time.Now().Add(-time.Hour)}
    assert.True(t, tok.IsExpired())  // real time.Now() — races if clock skews
}

// ✅ Inject a time source
type Clock func() time.Time

func TestTokenExpiry_Injected(t *testing.T) {
    fixed := time.Date(2024, 6, 1, 12, 0, 0, 0, time.UTC)
    tok := Token{ExpiresAt: fixed.Add(-time.Hour)}
    assert.True(t, tok.IsExpiredAt(fixed))  // deterministic
}
```

### 6. Happy-path only

```kotlin
// ❌ Only the success case is tested
@Test
fun `create user`() {
    every { repo.existsByEmail(any()) } returns false
    every { repo.save(any()) } answers { firstArg<User>().copy(id = 1L) }
    val result = UserService(repo).create("alice@example.com")
    assertEquals(1L, result.id)
}
// missing: duplicate email, repo.save throws, empty email, invalid format

// ✅ Error paths covered
@Test
fun `create user with duplicate email throws`() {
    every { repo.existsByEmail("alice@example.com") } returns true
    assertThrows<DuplicateEmailException> {
        UserService(repo).create("alice@example.com")
    }
}

@Test
fun `create user with blank email throws`() {
    assertThrows<IllegalArgumentException> {
        UserService(repo).create("  ")
    }
}

@Test
fun `create user propagates repository failure`() {
    every { repo.existsByEmail(any()) } returns false
    every { repo.save(any()) } throws RuntimeException("DB down")
    assertThrows<RuntimeException> {
        UserService(repo).create("alice@example.com")
    }
}
```

```python
# ❌ Only success
def test_parse_amount():
    assert parse_amount("100") == 100

# ✅ Boundaries too
@pytest.mark.parametrize("raw,expected", [
    ("100", 100),
    ("0", 0),
    ("999999", 999999),
])
def test_parse_amount_valid(raw, expected):
    assert parse_amount(raw) == expected

@pytest.mark.parametrize("bad", ["-1", "abc", "", "99999999999"])
def test_parse_amount_invalid_raises(bad):
    with pytest.raises(ValueError):
        parse_amount(bad)
```

### 7. Snapshot abuse

```kotlin
// ❌ Entire 500-line JSON response snapshotted; no human reviewed the content
@Test
fun `order response snapshot`() {
    val response = controller.getOrder(1L)
    // SnapshotAssert.assertMatchesSnapshot(response)   ← 500-line .snap file committed blindly
}

// ✅ Assert the specific fields that carry business meaning
@Test
fun `order response contains correct total and status`() {
    val response = controller.getOrder(1L)
    assertEquals(HttpStatus.OK, response.statusCode)
    assertEquals(1000, response.body?.total)
    assertEquals("CONFIRMED", response.body?.status)
    // snapshot only the small, stable shape if needed — and review it
}
```

```typescript
// ❌ Giant auto-accepted snapshot
it("renders order card", () => {
  const { container } = render(<OrderCard order={mockOrder} />);
  expect(container).toMatchSnapshot(); // 300-line snap, updated with --updateSnapshot
});

// ✅ Assert the parts that matter to the user
it("renders order total and status", () => {
  render(<OrderCard order={mockOrder} />);
  expect(screen.getByText("$10.00")).toBeInTheDocument();
  expect(screen.getByRole("status")).toHaveTextContent("Confirmed");
});
```

### 8. Smuggled skip / disable

```kotlin
// ❌ Disabled with no justification — silently removes coverage
@Disabled
@Test
fun `refund calculates tax correctly`() {
    // ...
}

// ✅ Justification + ticket required
@Disabled("Tax refund logic pending backend API — JIRA-4821, re-enable by 2024-Q3")
@Test
fun `refund calculates tax correctly`() {
    // ...
}
```

```python
# ❌
@pytest.mark.skip
def test_retry_on_timeout():
    ...

# ✅
@pytest.mark.skip(reason="Retry logic under redesign — GH#892, re-enable when merged")
def test_retry_on_timeout():
    ...
```

```go
// ❌
func TestProcessPayment(t *testing.T) {
    t.Skip()
    // body
}

// ✅
func TestProcessPayment(t *testing.T) {
    t.Skip("Payment processor mock not yet available — TICKET-1234")
    // body
}
```

### 9. Copy-paste clone

```kotlin
// ❌ Three tests with different names but identical assertion bodies — only one behavior tested
@Test
fun `order is valid when total is positive`() {
    val order = Order(total = 100)
    assertTrue(order.isValid())
}

@Test
fun `order validation passes for standard order`() {
    val order = Order(total = 100)   // same input
    assertTrue(order.isValid())      // same assertion
}

@Test
fun `isValid returns true for normal orders`() {
    val order = Order(total = 100)   // same input
    assertTrue(order.isValid())      // same assertion
}

// ✅ Each test covers a distinct case
@Test
fun `order with positive total is valid`() {
    assertTrue(Order(total = 100).isValid())
}

@Test
fun `order with zero total is invalid`() {
    assertFalse(Order(total = 0).isValid())
}

@Test
fun `order with negative total is invalid`() {
    assertFalse(Order(total = -1).isValid())
}
```

### 10. Coverage theater

```kotlin
// ❌ High coverage, near-zero real verification
class ProductServiceTest {
    private val repo = mockk<ProductRepository>(relaxed = true)
    private val sut = ProductService(repo)

    @Test fun `create product`() { sut.create(ProductRequest("Widget", 500)); assertNotNull(sut) }
    @Test fun `update product`() { sut.update(1L, ProductRequest("Widget", 600)); assertNotNull(sut) }
    @Test fun `delete product`() { sut.delete(1L); assertNotNull(sut) }
    @Test fun `find product`() { sut.find(1L); assertNotNull(sut) }
    // 100% line coverage; 0% meaningful verification
}

// ✅ Assertions verify behavior, including error paths
class ProductServiceTest {
    private val repo = mockk<ProductRepository>()
    private val sut = ProductService(repo)

    @Test
    fun `create product returns saved product with id`() {
        every { repo.save(any()) } answers { firstArg<Product>().copy(id = 5L) }
        val result = sut.create(ProductRequest("Widget", 500))
        assertEquals(5L, result.id)
        assertEquals("Widget", result.name)
        assertEquals(500, result.price)
    }

    @Test
    fun `find product throws NotFoundException when missing`() {
        every { repo.findById(99L) } returns Optional.empty()
        assertThrows<NotFoundException> { sut.find(99L) }
    }

    @Test
    fun `create product with blank name throws`() {
        assertThrows<IllegalArgumentException> { sut.create(ProductRequest("  ", 500)) }
    }
}
```

---

## Quick reference: clock/network injection patterns per stack

| Stack | Clock | Network/IO |
|-------|-------|-----------|
| Kotlin/JVM | Inject `java.time.Clock`; `Clock.fixed(instant, zone)` in tests | Inject `HttpClient` or use MockWebServer (OkHttp) / WireMock |
| Python | Inject a callable `now: Callable[[], datetime]`; `unittest.mock.patch("module.datetime")` | Inject `httpx.Client`; `respx` or `responses` to intercept |
| Go | Inject `type Clock func() time.Time`; pass `func() time.Time { return fixedTime }` | Inject `http.Client`; use `httptest.NewServer` for a local stub |
| Node/TS | `vi.useFakeTimers()` / `jest.useFakeTimers()` for `Date.now()`; inject a `Clock` interface | `vi.fn()` on fetch; `msw` handlers for full request interception |

---

## Official references

- JUnit 5 User Guide: https://junit.org/junit5/docs/current/user-guide/
- MockK: https://mockk.io/
- Mockito: https://site.mockito.org/
- pytest: https://docs.pytest.org/en/stable/
- testify: https://github.com/stretchr/testify
- Testcontainers: https://testcontainers.com/
- WireMock: https://wiremock.org/
- PIT mutation testing: https://pitest.org/
- mutmut (Python mutation): https://github.com/boxed/mutmut
- Team baseline: [../../guidance.md](../../guidance.md)
