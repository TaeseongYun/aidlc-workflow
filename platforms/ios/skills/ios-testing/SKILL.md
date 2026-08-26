---
name: ios-testing
description: iOS test generation + test-quality guard — write real, deterministic tests and
  detect/block the fake or flaky tests AI commonly produces (assertion-free, mock-echo/tautological,
  over-mocking the unit under test, implementation-detail coupling, non-determinism/flakiness,
  happy-path-only, snapshot abuse, smuggled skips, copy-paste clones, coverage theater). Covers the
  iOS test pyramid and frameworks (XCTest, Swift Testing @Test, ViewInspector/snapshot for SwiftUI,
  XCUITest for UI). Auto-loads when writing or reviewing tests.
when_to_use: When writing tests, reviewing AI/LLM-generated tests before merge, touching test files,
  or on requests like "write tests", "is this test real", "why is this test flaky", "test review".
paths: "**/*Tests/**", "**/*Test*.swift", "**/*Tests.swift", "**/*UITests/**"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# ios-testing — test generation + test-quality guard

AI-generated tests are **fast but frequently fake.** Common failures: tests that assert nothing,
tests that only re-assert what a stub was told to return, tests that mock away the very unit under
test, and non-deterministic tests that flake in CI. Coverage looks green while nothing is actually
verified — "coverage theater." This skill is both a **generator** (write real tests) and a **guard**
(detect and block fake/flaky AI tests). Guard rules are safety rules; project `ctx/` may tighten
them but the floor is never lowered.

## Scope

- Targets: `**/*Tests/**`, `**/*Test*.swift`, `**/*Tests.swift`, `**/*UITests/**` — especially
  AI-generated test files or tests pasted in without review.
- What it does: **generate real, deterministic tests** (Mode A) and **detect bad AI test patterns**
  (Mode B) for each failure mode below.
- Delegate: security vulnerabilities in test code → [ios-security]; testability seams / DI design →
  [ios-architecture]; state management test strategy → [ios-state-concurrency].
- Reality: a test that passes every run while asserting nothing is worse than no test — it actively
  misleads. Every test must make a falsifiable claim.

## Mode A — Generate: Write Real, Deterministic Tests

### Test pyramid

Write **many unit tests, some integration tests, few UI tests.** Unit tests run fast and catch
regressions early. XCUITest is slow, brittle, and costly to maintain — reserve it for critical user
flows only.

```
Unit (XCTest / Swift Testing @Test)   ← most tests live here
Integration (XCTest, URLProtocol stub or in-process server)
UI (XCUITest)                         ← fewest; critical paths only
```

### Behavior, not implementation

Test **what the unit does** (its public contract), not **how it does it** (private calls, call
order, internal state). One logical assertion per test. Use AAA (Arrange-Act-Assert) or
Given-When-Then naming to make intent clear.

```swift
// ✅ tests observable behavior
func test_login_withValidCredentials_returnsUser() async throws {
    // Arrange
    let sut = LoginViewModel(authService: StubAuthService(result: .success(User.fixture())))
    // Act
    await sut.login(email: "a@b.com", password: "secret")
    // Assert
    XCTAssertEqual(sut.state, .loggedIn)
}
```

### Determinism — the calibration knob

A test that touches the real clock, real network, real filesystem, or depends on execution order
**is flaky by construction.** Inject the abstraction; fake the dependency in tests.

| Non-deterministic source | iOS solution |
|---|---|
| `Date()` / `Date.now` | Inject a `Clock` protocol; stub returns a fixed date |
| `URLSession.shared` | Swap in a `URLProtocol` subclass that returns canned data |
| `FileManager.default` | Inject a file I/O abstraction |
| `DispatchQueue.main` | Inject `@MainActor` or a dispatch-queue abstraction |
| `Task.sleep` in test | Use `Task.sleep` in production, never in tests to "wait for it" |
| Shared global state | Reset in `tearDown` / `tearDownWithError` |

Never use `sleep()`, `Thread.sleep()`, or a fixed `Task.sleep` delay in a test to wait for async
work. Use `await` on the async production API directly, or `XCTestExpectation` for delegate-based
callbacks.

### Error paths and boundary coverage

Every function with a failure branch needs at least one error-path test. Boundaries: nil/empty/zero/
max-value/invalid-format. Use `XCTAssertThrowsError` (XCTest) or `#expect(throws:)` (Swift Testing)
to verify thrown errors, not just that the happy path works.

```swift
// XCTest error path
func test_fetchUser_whenNetworkFails_throwsNetworkError() async {
    let sut = UserRepository(session: .stubbedFailing(with: URLError(.notConnectedToInternet)))
    await XCTAssertThrowsError(try await sut.fetchUser(id: "1")) { error in
        XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }
}

// Swift Testing error path
@Test func fetchUser_whenNetworkFails_throwsURLError() async {
    let sut = UserRepository(session: .stubbedFailing(with: URLError(.notConnectedToInternet)))
    await #expect(throws: URLError.self) {
        try await sut.fetchUser(id: "1")
    }
}
```

### Framework map

| Layer | Framework | Notes |
|---|---|---|
| Unit — logic/ViewModels | `XCTest` or `Swift Testing (@Test)` | Prefer Swift Testing for new code |
| Unit — SwiftUI views | `ViewInspector` | Inspect view hierarchy without a host app |
| Snapshot / golden | `swift-snapshot-testing` | Review every committed snapshot; small scope |
| UI / end-to-end | `XCUITest` | Reserve for critical happy paths |
| Network stub | `URLProtocol` subclass | Register on a custom `URLSession`, not `.shared` |
| Clock injection | Protocol wrapping `Date()` | Trivial protocol; implement in production init |

## Mode B — Guard: Detect and Block Fake AI Tests

Each item: **rule → common AI failure → red-flag.** Code examples in [reference.md](./reference.md).

### 1. Assertion-free test

- **Rule**: every test must make at least one falsifiable claim via `XCTAssert*` or `#expect`.
  A test that runs code but asserts nothing proves nothing and misleads.
- **Common AI failure**: a test method that calls production code, sets up stubs, but contains
  zero `XCTAssert*` / `#expect` / `XCTAssertThrowsError` calls.
- **red-flag**: test body has method calls but zero assertion statements.

### 2. Mock-echo / tautological assertion

- **Rule**: assertions must verify real behavior, not simply confirm what the stub was programmed
  to return. `stub.returns(X)` … `XCTAssertEqual(X, result)` verifies the stub, not the unit.
- **Common AI failure**: stub `authService` to return `User.fixture()`, call `sut.login(...)`,
  then `XCTAssertEqual(user.id, User.fixture().id)` — the production path is never exercised
  in a meaningful way.
- **red-flag**: the asserted value is identical to the literal stub return value with no
  transformation by the SUT.

### 3. Over-mocking / mocking the SUT

- **Rule**: only **dependencies** of the unit under test are stubbed — not the unit itself.
  If the class being tested is a mock/stub, nothing about the real implementation is verified.
- **Common AI failure**: creating a `MockLoginViewModel` and asserting on it, effectively
  testing the mock's behavior rather than `LoginViewModel`.
- **red-flag**: a `Mock*` / `Fake*` / `Stub*` of the class named in the test's "sut" variable.

### 4. Implementation-detail coupling

- **Rule**: assert on **observable output and state** — not on which private methods were called,
  internal call counts, or private property values. Tests that couple to internals break on every
  refactor even when behavior is preserved.
- **Common AI failure**: using a spy to verify that an internal private method was called exactly
  twice, or asserting on a `private var` via `@testable import`.
- **red-flag**: `verify` on private/internal methods; call-count assertions on internal collaborators;
  assertions on `private` / `internal` properties that have no public observable effect.

### 5. Non-determinism / flakiness

- **Rule**: unit tests must not touch the real clock (`Date()`, `.now`), real network (live
  `URLSession.shared`), real filesystem, or shared global state. These make tests order-dependent
  and intermittently fail in CI.
- **Common AI failure**: `XCTAssertGreaterThan(result.timestamp, Date())` (real clock),
  live `URLSession.shared` calls, `sleep(1)` to wait for async work, accessing
  `UserDefaults.standard` without resetting.
- **red-flag**: `Date()` / `Date.now` in a unit test; `URLSession.shared`; `sleep` / `Thread.sleep`;
  shared mutable global state not reset in `tearDown`.

### 6. Happy-path only

- **Rule**: any function with error handling, optional returns, or failure branches requires at
  least one test exercising each meaningful failure mode. Happy-path-only coverage on error-prone
  code is incomplete by definition.
- **Common AI failure**: `fetchUser` has a network-failure path and a decoding-failure path, but
  only a success test is generated.
- **red-flag**: a function with `catch` / `guard let` / `throw` / `Result.failure` coverage blocks
  but only one test (the success case).

### 7. Snapshot abuse

- **Rule**: snapshots are a valid tool for catching unintended visual regressions, not a
  substitute for behavioral assertions. Every committed snapshot must have been reviewed by a
  human. Auto-updating snapshots in CI masks regressions.
- **Common AI failure**: replacing all `ViewInspector` behavioral assertions with a single
  snapshot; running `swift test --record` (record mode) without reviewing the output; a
  500-line `.txt` snapshot of a full view hierarchy.
- **red-flag**: snapshot as the **only** assertion for a test; record/update mode enabled in CI;
  snapshot files larger than a focused component warrants.

### 8. Smuggled skip / disable

- **Rule**: `XCTSkip` / `XCTSkipIf` / `withKnownIssue` / `@Test(.disabled(...))` are acceptable
  only with a documented reason **and** a tracking issue reference. A skip with no justification
  silently removes coverage.
- **Common AI failure**: adding `try XCTSkip("TODO")` or `@Test(.disabled("flaky"))` with no
  ticket reference, or commenting out the test body.
- **red-flag**: `XCTSkip` / `.disabled` without a justification comment that includes a tracking
  reference; entire test body commented out.

### 9. Copy-paste clone

- **Rule**: each test must exercise a distinct scenario. Duplicated tests with different names but
  identical arrange/assert blocks verify the same thing twice and obscure real coverage gaps.
- **Common AI failure**: generating `test_login_success` and `test_loginWithUser_succeeds` whose
  bodies are character-for-character identical, or slight variations that assert the same value.
- **red-flag**: two or more tests with identical assertion expressions and identical act steps
  but different names.

### 10. Coverage theater

- **Rule**: line coverage is not a quality metric. A test that instantiates a class and calls
  a method without asserting on the result inflates coverage while verifying nothing.
  Use mutation testing or manual inspection to audit assertion density.
- **Common AI failure**: generating one test per public method that calls the method and asserts
  `XCTAssertNotNil(result)` regardless of what `result` is, inflating line coverage to 80%+
  while the mutation score is near zero.
- **red-flag**: `XCTAssertNotNil` as the sole assertion on a value-returning function; tests that
  call many methods but assert only on trivially non-nil wrapper results.

## Vibe-guard review checklist

For iOS tests that AI generated or were pasted in quickly, before merge:

- [ ] Every test has at least one `XCTAssert*` / `#expect` that would fail if the logic broke.
- [ ] Assertions verify a real transformation by the SUT, not the stub's return value.
- [ ] The unit under test is the real implementation, not a mock of itself.
- [ ] Assertions target public, observable output — not private methods or call counts.
- [ ] No `Date()`, `URLSession.shared`, `sleep`, or unresettable global state in unit tests.
- [ ] Error paths, `nil` inputs, and boundary values each have at least one dedicated test.
- [ ] Snapshots are small, human-reviewed, and paired with behavioral assertions.
- [ ] Every `XCTSkip` / `.disabled` has a reason and a tracking issue reference.
- [ ] No two tests with different names that assert exactly the same thing.
- [ ] Assertion density is meaningful — `XCTAssertNotNil` alone does not count.

## Halt conditions

Halt and report (do not proceed) when:

- The file under test cannot be read (missing, inaccessible).
- No XCTest / Swift Testing framework import is present in a claimed test file.
- A guard failure is ambiguous enough that auto-fixing would alter test intent.

**Output on halt:**

```markdown
## Test Review Halted

Halt reason:
- (specific reason)

Items requiring human review:
1. ...
```

Do NOT propose alternatives or explain how to fix on halt. Output only the halt reason.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code examples (bad → good per rule): [reference.md](./reference.md)
- Umbrella: [ios-architecture](../ios-architecture/SKILL.md)
- Adjacent: [ios-security](../ios-security/SKILL.md), [ios-state-concurrency](../ios-state-concurrency/SKILL.md)
- Apple — XCTest: https://developer.apple.com/documentation/xctest
- Apple — Swift Testing: https://developer.apple.com/documentation/testing
- Apple — XCUITest: https://developer.apple.com/documentation/xctest/user_interface_tests
- ViewInspector: https://github.com/nalexn/ViewInspector
- swift-snapshot-testing: https://github.com/pointfreeco/swift-snapshot-testing
