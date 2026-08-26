---
name: backend-testing
description: Backend test generation + test-quality guard — write real, deterministic tests and
  detect/block the fake or flaky tests AI commonly produces (assertion-free, mock-echo/tautological,
  over-mocking the unit under test, implementation-detail coupling, non-determinism/flakiness,
  happy-path-only, snapshot abuse, smuggled skips, copy-paste clones, coverage theater). Covers the
  backend test pyramid and frameworks (JUnit5 + MockK/Mockito, pytest, go test + testify, Vitest/Jest,
  Testcontainers for integration). Auto-loads when writing or reviewing tests.
when_to_use: When writing tests, reviewing AI/LLM-generated tests before merge, touching test files,
  or on requests like "write tests", "is this test real", "why is this test flaky", "test review".
paths: "**/src/test/**", "**/*Test.kt", "**/*Test.java", "**/test_*.py", "**/*_test.go", "**/*.test.ts", "**/*.spec.ts"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# backend-testing — test generation + test-quality guard

AI-generated tests are **fast but frequently fake.** The common failures are not subtle: tests that
call functions but assert nothing, tests that verify only what a mock was configured to return,
tests that mock away the very class under test, and tests that pass locally but flake in CI because
they touch the real clock or network. Coverage numbers look green while nothing is actually verified
— "coverage theater." This is especially dangerous because developers **overtrust AI-generated
tests**, assuming passing means correct.

This skill has two modes. **Mode A** guides writing real, deterministic, behavior-focused tests.
**Mode B** detects and blocks the 10 AI test failure modes before they merge. Guard rules are safety
rules and must not be relaxed. Project `ctx/` may tighten them but the floor is never lowered.

## Scope

- Targets: JVM test files (`src/test/`, `*Test.kt`, `*Test.java`), Python (`test_*.py`, `*_test.py`),
  Go (`*_test.go`), Node/TS (`*.test.ts`, `*.spec.ts`). All backend stacks.
- What it does: **generate real tests (Mode A)** and **detect fake/flaky AI tests (Mode B)**.
- Delegate to adjacent skills: security properties of test data → [backend-security-guard],
  testability seams and DI wiring → [backend-architecture], database/transaction test strategies →
  [backend-data-transactions], reliability and flakiness tracking → [backend-reliability].

## Framework map (backend — polyglot)

| Stack | Unit | Mocking | Integration |
|-------|------|---------|-------------|
| JVM (Kotlin) | JUnit 5 (`@Test`, `@ParameterizedTest`) | MockK (`mockk`, `every`, `verify`) | Testcontainers + Spring `@SpringBootTest` |
| JVM (Java) | JUnit 5 | Mockito (`@Mock`, `when`/`thenReturn`) | Testcontainers + Spring `@SpringBootTest` |
| Python | pytest (`def test_`, fixtures) | `unittest.mock` / `pytest-mock` (`mocker`) | pytest + Testcontainers-python / Docker |
| Go | `go test` + `testing.T` | `testify/mock` | `testcontainers-go` |
| Node/TS | Vitest / Jest (`it`, `describe`) | `vi.fn()` / `jest.fn()` | Testcontainers-node |

Real network and live databases are **not** used in unit tests. Integration tests use Testcontainers
or a real-but-isolated local DB; they never call external APIs.

---

## Mode A — Generate: writing real tests

### Test pyramid

- **Many unit tests**: test one function/class in isolation with fakes at the boundary. Fast, no I/O.
- **Some integration tests**: test a slice of the stack (repository + DB, HTTP handler + router)
  using Testcontainers. Slower; run in a dedicated CI stage.
- **Few e2e / contract tests**: test the deployed service from outside. Only for critical flows.

AI tends to write only happy-path unit tests. Push back and add error paths and integration coverage
before calling a feature "tested."

### Behavior, not implementation — AAA

Test **observable behavior**: return values, state changes, exceptions thrown, events emitted.
Never assert private method calls or internal call order — those are implementation details that
break on refactor even when behavior is correct.

Structure every test with **Arrange-Act-Assert** (AAA):

```
Arrange: build inputs and configure fakes
Act:     call the one function/method under test
Assert:  check the observable result (return value / exception / side effect on a test double)
```

One **logical assertion per test** (multiple `assertEquals` on fields of the same result object is
fine; asserting two unrelated behaviors in one test is not). Name the test after the behavior being
verified, not the method name.

### Determinism — the calibration knob

A test that passes sometimes is worse than no test; it burns CI time, trains developers to ignore
failures, and hides real regressions.

**What makes a test non-deterministic**:
- Reading the real clock (`new Date()`, `LocalDateTime.now()`, `time.Now()`, `datetime.now()`)
- Real random number generation (`Math.random()`, `random.random()`, `rand.Intn()`)
- Real network calls (any live HTTP/gRPC, any cloud SDK without a fake transport)
- Real filesystem with shared mutable state
- `Thread.sleep` / `time.Sleep` / `asyncio.sleep` for timing
- Test execution order dependency (shared mutable state between tests)

**Fix**: inject the clock, seed the RNG, fake or stub the network/IO. See reference.md for examples
per stack. This is the calibration knob: the real world drifts; tests must not.

### Error paths + boundaries — always cover them

If the production code has an `if`, a `catch`, a `null` check, or a validation branch, there must
be a test for it. AI almost never generates error-path tests unless prompted.

Minimum boundary set for any non-trivial function:
- null / None / nil / empty input
- zero / negative / max-value numeric inputs
- failure branch: the dependency throws, returns empty, returns an unexpected status
- invalid input that should be rejected

---

## Mode B — Guard: block fake and flaky AI tests

Each item: **rule → common AI failure → red-flag**. Code examples in [reference.md](./reference.md).

### 1. Assertion-free test

- **Rule**: every test must contain at least one assertion that can fail. A test with zero assertions
  provides zero verification — it only proves the code does not crash.
- **Common AI failure**: AI writes a test, calls the method, but forgets the `assertEquals` /
  `assert` / `expect`. Sometimes it just calls `assertNotNull(result)` on a mock that can never be
  null.
- **Red-flag**: test body contains method calls and zero `assert*` / `expect*` / `should*` statements;
  or the only assertion is `assertNotNull` on a value that a configured mock always returns.

### 2. Mock-echo / tautological assertion

- **Rule**: an assertion that merely verifies the mock returns what it was configured to return
  verifies nothing. The test passes by definition regardless of what the production code does.
- **Common AI failure**: `every { repo.findById(1L) } returns order` … `assertEquals(order, result)`.
  The result is the mock value. Nothing real is tested.
- **Red-flag**: the asserted value is the exact object passed to `returns` / `thenReturn` / `return_value`
  with no transformation in between; the production code's logic is bypassed.

### 3. Over-mocking / mocking the SUT

- **Rule**: never mock the class or function that is the subject under test. Mocking the SUT means
  you are testing the mock, not the code.
- **Common AI failure**: `val service = mockk<OrderService>()` at the top of `OrderServiceTest`,
  then calling methods on `service`. All behaviour is mock behaviour; the real code never runs.
- **Red-flag**: a `mockk<X>()` / `mock(X.class)` / `mocker.patch("module.X")` where `X` is the
  class/module whose test file this is; the test never instantiates the real implementation.

### 4. Implementation-detail coupling

- **Rule**: assert observable behavior (return values, thrown exceptions, DB state, emitted events).
  Do not assert the number of times an internal private method was called or the order of internal
  calls between collaborators.
- **Common AI failure**: `verify(exactly = 1) { repo.save(any()) }` as the only assertion, or
  spying on a private helper to check it was invoked. Breaks on refactor even when behavior is unchanged.
- **Red-flag**: `verify` / `verifyOrder` / `assert_called_once_with` on internal collaborators as
  the primary assertion; spy on private methods; brittle call-count asserts for non-side-effecting
  collaborators.

### 5. Non-determinism / flakiness

- **Rule**: unit tests must not touch the real clock, real RNG, real network, real filesystem, or
  shared mutable state. Any of those make the test potentially non-deterministic.
- **Common AI failure**: `val now = LocalDateTime.now()` inside the test or inside production code
  the test exercises without injecting a fake clock; `Thread.sleep(500)` to wait for an async
  operation; calling a live external API in a unit test.
- **Red-flag**: `now()` / `new Date()` / `time.Now()` / `datetime.now()` in a unit test body or in
  production code called by the test without clock injection; `sleep` calls; `http.Get` / `fetch` /
  `requests.get` against a real host inside a `src/test/` unit test.

### 6. Happy-path only

- **Rule**: every function with error handling, validation, or branching logic must have at least
  one test for each distinct failure branch, not just the success path.
- **Common AI failure**: a function that validates input and throws `IllegalArgumentException`, calls
  an external service that can fail, or returns `null` on not-found — AI writes only the success test.
- **Red-flag**: a test file with exactly one test per method, always providing valid inputs; the
  production code has `catch`, `?.`, `if (x == null)`, `raise`, `errors.New` but no test exercises
  those branches.

### 7. Snapshot abuse

- **Rule**: snapshots are appropriate for stable, human-reviewable structures (e.g., a JSON API
  response shape). They are not a substitute for real assertions. Snapshots committed without review,
  blindly auto-updated, or used as the only assertion for complex logic are a guard failure.
- **Common AI failure**: generating a test that takes a snapshot of the entire response body (1000+
  lines) and committing it without reviewing what it contains; adding `--updateSnapshot` to CI to
  auto-accept every change.
- **Red-flag**: snapshot file > ~50 lines for a unit test; `--updateSnapshot` or equivalent in CI
  config without a human-review gate; snapshot as the sole assertion for business logic.

### 8. Smuggled skip / disable

- **Rule**: `@Disabled` / `@Ignore` / `it.skip` / `xit` / `t.Skip()` / `@Test(enabled=false)` may
  only be added with a justification comment containing a ticket/issue reference and an expected
  re-enable date or condition.
- **Common AI failure**: AI skips a test that it cannot make pass without understanding the domain,
  adding `@Disabled` with no comment, or generating `it.skip("TODO")` stubs with no substance.
- **Red-flag**: any skip/disable annotation without a `// REASON:` / `# reason:` comment and a
  ticket reference on the same or adjacent line.

### 9. Copy-paste clone

- **Rule**: test names must accurately describe what the test verifies. Duplicated tests with
  different names but identical assertion bodies are dead weight and mask missing coverage.
- **Common AI failure**: generating 3–5 tests that share the same body, varying only the test name
  string. The assertions are identical; only the description changed.
- **Red-flag**: two or more tests with different names but identical (or near-identical) `assert*` /
  `expect*` blocks; no observable difference in what is being verified.

### 10. Coverage theater

- **Rule**: high line coverage with low assertion density is not safety. A test that exercises code
  paths but asserts nothing meaningful inflates coverage while providing no regression protection.
  Mutation testing (PIT for JVM, mutmut for Python, go-mutesting for Go) reveals this.
- **Common AI failure**: generating tests that call every public method once, assert only
  `assertNotNull(result)`, and declare "100% coverage." No meaningful verification occurs.
- **Red-flag**: coverage is high but assertions are sparse (`assertNotNull` / `assertTrue(result != null)`
  dominating); no parameterized/boundary tests; mutation score (if measured) is low despite line
  coverage.

---

## Guard review checklist

For AI-generated or quickly pasted test code, before merge:

- [ ] Every test has at least one assertion that can realistically fail.
- [ ] No assertion merely echoes what a mock was configured to return.
- [ ] The class/module under test is instantiated as the real implementation, not mocked.
- [ ] Assertions target observable behavior (return value, exception, DB state), not internal calls.
- [ ] No `now()` / `sleep` / live network / real RNG in unit tests. Clock and I/O are injected.
- [ ] Every error branch and boundary condition has a test.
- [ ] No blind snapshot commits. Snapshots are small and human-reviewed.
- [ ] No skip/disable without a justification comment + ticket reference.
- [ ] No duplicate tests with different names but identical assertions.
- [ ] Coverage is backed by real assertions, not just `assertNotNull` padding.

## Halt conditions

Halt (do not proceed) if:

- The test file has no assertions whatsoever.
- The class under test is itself mocked throughout the file.
- More than half the tests have a skip/disable annotation with no justification.

Output on halt:

```
## Test review halted

Halt reason:
- (specific reason from above)

Items requiring confirmation:
1. ...
```

Do NOT propose alternatives or explain how to fix on halt. Output only the halt reason.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code examples (bad → good per rule): [reference.md](./reference.md)
- Umbrella: [backend-architecture](../backend-architecture/SKILL.md)
- Adjacent: [backend-security-guard](../backend-security-guard/SKILL.md),
  [backend-data-transactions](../backend-data-transactions/SKILL.md),
  [backend-reliability](../backend-reliability/SKILL.md)
- JUnit 5: https://junit.org/junit5/docs/current/user-guide/
- MockK: https://mockk.io/
- pytest: https://docs.pytest.org/
- testify: https://github.com/stretchr/testify
- Testcontainers: https://testcontainers.com/
- PIT mutation testing: https://pitest.org/
