---
name: flutter-testing
description: Flutter test generation + test-quality guard — write real, deterministic tests and
  detect/block the fake or flaky tests AI commonly produces (assertion-free, mock-echo/tautological,
  over-mocking the unit under test, implementation-detail coupling, non-determinism/flakiness,
  happy-path-only, snapshot abuse, smuggled skips, copy-paste clones, coverage theater). Covers the
  Flutter test pyramid and frameworks (flutter_test unit + testWidgets, mocktail, integration_test,
  golden tests, fakeAsync, stubbed http/Dio). Auto-loads when writing or reviewing tests.
when_to_use: When writing tests, reviewing AI/LLM-generated tests before merge, touching test files,
  or on requests like "write tests", "is this test real", "why is this test flaky", "test review".
paths: "**/test/**", "**/integration_test/**", "**/*_test.dart"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# flutter-testing — test generation + test-quality guard

AI-generated tests are **fast but frequently fake**. Common failures: tests that assert nothing,
tests that only re-assert what a mock was told to return, tests that mock away the very unit under
test, and non-deterministic tests that flake in CI. Coverage looks green while nothing is actually
verified — "coverage theater". This skill is both a **generator** (write real tests) and a **guard**
(detect and block fake/flaky AI tests). Guard rules are safety rules; project `ctx/` may tighten
them but the floor is never lowered.

## Scope

- Targets: files in `test/`, `integration_test/`, and any `*_test.dart` file — especially
  AI-generated or quickly-copied test suites.
- What it does: **generate real, deterministic tests** (Mode A) and **detect/block fake or
  flaky test patterns** (Mode B).
- Delegate to adjacent skills: secure storage / crypto in tests → [flutter-security],
  widget routing test setup → [flutter-navigation-platform], state-layer integration tests
  (BLoC/Riverpod) → [flutter-state-management], testability/DI seam design → [flutter-architecture].

## Mode A — Generate

### Test pyramid

Many unit, some widget (`testWidgets`), few integration/golden. Keep the pyramid honest:

- **Unit tests** (`test()` in `flutter_test`): pure Dart, fast, no Flutter binding. Cover service
  classes, repositories, use-cases, parsers, helpers. The bulk of the suite.
- **Widget tests** (`testWidgets()`): render a single widget or small subtree in
  `WidgetTester`. Call `tester.pumpAndSettle()` only when animations finish; prefer
  `tester.pump()` with an explicit `Duration` inside `fakeAsync` when you control time.
- **Integration tests** (`integration_test`): full-app smoke paths on a device/emulator.
  Few and slow — one or two critical user journeys, not a full regression suite.
- **Golden tests**: pixel snapshots for visual regressions. Treat every `.png` commit as a
  deliberate review; never auto-update blindly.

### Behavior over implementation (AAA)

Structure every test as **Arrange → Act → Assert**. Test observable behavior (return values,
emitted states, UI text/widgets present), never internal call order or private fields.
One logical assertion per test — use `group()` to organize related cases.

```dart
// Arrange
final repo = MockWeatherRepository();
when(() => repo.fetchWeather('London')).thenAnswer((_) async => Weather(temp: 20));
final sut = WeatherBloc(repo);

// Act
sut.add(const FetchWeatherEvent('London'));

// Assert
await expectLater(
  sut.stream,
  emitsInOrder([isA<WeatherLoading>(), isA<WeatherLoaded>()]),
);
```

### Determinism — the calibration knob

A test that touches the real clock, real network, or real filesystem is **flaky by
construction**. Inject every non-deterministic dependency:

- **Clock / time**: wrap `DateTime.now()` in an injectable `Clock` abstraction; in tests pass
  a fixed instant. Use `fakeAsync` + `clock.elapse()` to advance time without real waits.
- **Network**: stub `http.Client` or Dio's `HttpClientAdapter` with a test double
  (e.g. `MockClient` from `package:http/testing.dart`); never hit a real endpoint in a unit test.
- **Randomness**: inject the seed or pass a `Random` instance; use `Random(42)` in tests for a
  deterministic sequence.
- **`Future`/`Timer`**: control with `fakeAsync` — no `await Future.delayed(Duration.zero)`
  workarounds and no bare `sleep`.
- **`pumpAndSettle` discipline**: `pumpAndSettle()` loops until the tree is idle; an infinite
  animation causes it to time out. Inside `fakeAsync`, advance time explicitly with
  `tester.pump(duration)` to stay in control.

### Error paths and boundaries

Always cover the failure branch for any code that has one. For every happy-path test, ask:
what happens when the repository throws? When the list is empty? When input is null/zero/max?
Widget tests must cover error-state widgets (`ErrorWidget`, retry buttons, empty states).

### Flutter test framework map

| Layer | Framework | Notes |
|---|---|---|
| Unit | `flutter_test` (`test`, `expect`) | No binding needed; pure Dart |
| Mocking | `mocktail` | `Mock`, `when()`, `verify()`, `any()` |
| Widget | `flutter_test` (`testWidgets`, `WidgetTester`) | `pump`, `pumpAndSettle`, `find.*` |
| Time control | `fake_async` (`fakeAsync`, `FakeAsync`) | Wrap async code; advance with `flushMicrotasks`, `elapse` |
| HTTP stub | `package:http/testing.dart` (`MockClient`) or Dio's `HttpClientAdapter` | Return canned responses |
| Integration | `integration_test` (`IntegrationTestWidgetsFlutterBinding`) | On-device; use sparingly |
| Golden | `flutter_test` (`matchesGoldenFile`) | Review every committed `.png` |

---

## Mode B — Guard

Detect and block these 10 AI test failure modes. Each item: **rule → common AI failure →
red-flag**. Code examples in [reference.md](./reference.md).

### 1. Assertion-free test

- **Rule**: every test body must contain at least one `expect(...)` or `verify(...)` call that
  can actually fail. A test that exercises code without asserting anything gives false confidence.
- **Common AI failure**: scaffolding a test that calls the SUT, sets up mocks, then returns
  without asserting the output or state.
- **red-flag**: a `test()` or `testWidgets()` body with zero `expect`/`verify` calls, or only
  a `verify` that a mock was called (with no output assertion).

### 2. Mock-echo / tautological assertion

- **Rule**: an assertion must verify something the SUT computed, not re-state what the mock
  was told to return. `when(mock.x()).thenReturn(V)` → `expect(result, V)` verifies nothing
  real about the SUT.
- **Common AI failure**: stubbing a method to return `42`, calling the SUT, then asserting the
  result is `42` — the SUT could be removed and the test would still pass.
- **red-flag**: the expected value in `expect` is the same literal/object used in `thenReturn`
  or `thenAnswer`, with no transformation by the SUT in between.

### 3. Over-mocking / mocking the SUT

- **Rule**: mock the **dependencies** of the unit under test, never the unit itself. If the class
  being tested is a mock, the test exercises nothing.
- **Common AI failure**: creating a `MockWeatherBloc` or `MockMyService` and then testing it,
  leaving the real implementation completely untested.
- **red-flag**: a `Mock` subclass whose name matches the class named in the test description,
  or a `MockX` used as the object passed to `expect`.

### 4. Implementation-detail coupling

- **Rule**: assert on observable outputs — returned values, emitted states, rendered widgets,
  written data. Do not assert on private method calls, internal call order, or interaction
  counts that are an artifact of the current implementation.
- **Common AI failure**: `verify(() => sut._transform(any())).called(1)` — brittle; the private
  method may be refactored away without changing behavior.
- **red-flag**: `verify` calls on methods that are not part of the public API, call-count
  assertions that are not meaningful to behavior, spying on private or protected members.

### 5. Non-determinism / flakiness

- **Rule**: unit and widget tests must not touch the real clock (`DateTime.now()`), real network,
  real filesystem, or `sleep`. Shared mutable state between tests causes order-dependence.
  All time-dependent logic must run inside `fakeAsync`.
- **Common AI failure**: `await Future.delayed(const Duration(milliseconds: 100))` in a widget
  test, calling a real HTTP endpoint, using `DateTime.now()` in the Arrange step.
- **red-flag**: `Future.delayed` without `fakeAsync`, `http.get(Uri.parse('https://...'))` in a
  unit test, `DateTime.now()` in Arrange/Act, shared top-level mutable variables across tests.

### 6. Happy-path only

- **Rule**: any function with error handling, null returns, empty-list branches, or exception
  paths requires at least one test per significant branch. A single success test for a
  repository that can throw is incomplete.
- **Common AI failure**: one test named `test('fetchWeather returns weather')` for a repository
  method that can also throw `NetworkException`, return an empty list, or receive a 404.
- **red-flag**: a function with `try/catch`, nullable return, or conditional logic and only one
  test with no negative or boundary cases.

### 7. Snapshot / golden abuse

- **Rule**: golden tests are for detecting **unintended** visual regressions. Every committed
  `.png` must be reviewed. Running `flutter test --update-goldens` without reviewing the diff
  is equivalent to deleting the assertion. A golden must not be the only assertion for logic.
- **Common AI failure**: generating a golden test for every widget, regenerating without
  review when a PR bumps a dependency, using a golden as a proxy for behavior correctness.
- **red-flag**: `--update-goldens` in CI without a gate, a test with `matchesGoldenFile` as its
  only assertion for a widget whose behavior matters, committed goldens with no review comment.

### 8. Smuggled skip / disable

- **Rule**: `skip:` parameter, `// ignore:`, or any mechanism that silently disables a test is
  forbidden without a comment containing the reason and a tracking reference (issue URL or
  ticket ID).
- **Common AI failure**: adding `skip: 'TODO'` or `skip: true` to make a failing test pass CI,
  leaving it in permanently.
- **red-flag**: `test('...', skip: ...)` or `testWidgets('...', skip: ...)` without a comment
  explaining why and a ticket reference; `// ignore:` on a test expectation.

### 9. Copy-paste clone

- **Rule**: two tests with different names but identical (or near-identical) assertion bodies
  are a maintenance liability and mask missing coverage. Extract shared setup into `setUp` /
  helper functions; parameterize with a loop or table if the cases only differ in input.
- **Common AI failure**: duplicating a test block and only changing the test name, leaving the
  assertions unchanged so neither test adds unique coverage.
- **red-flag**: two or more `test()` blocks in the same file with identical `expect` calls and
  no meaningful difference in Arrange.

### 10. Coverage theater

- **Rule**: high line coverage with near-zero meaningful assertions is not a passing test suite.
  Calling a function without asserting its output, or only asserting that it does not throw,
  inflates coverage while verifying nothing. Prefer mutation score over line coverage as the
  quality signal.
- **Common AI failure**: wrapping every public method in a `test()` that calls it once and has
  no `expect`, so the coverage tool marks those lines green.
- **red-flag**: tests where the only `expect` is `expect(() => sut.method(), returnsNormally)`
  (or equivalent), a file with 90%+ coverage but no state/output assertions, tests added
  solely to hit a coverage threshold.

---

## Halt conditions

Halt (do not generate or approve tests) if:

- The code under test has no injectable seams for dependencies — escalate to [flutter-architecture]
  for a DI fix before adding tests.
- The requested test requires hitting a real external service — request a stub/mock contract first.
- A golden test is requested but the widget tree is not yet stable — golden tests on in-progress
  UI lock in accidents as baselines.

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

For AI-generated or quickly-copied Flutter tests, before merge:

- [ ] Every `test()` / `testWidgets()` body contains at least one `expect` or meaningful `verify`.
- [ ] No assertion re-states only what a mock was told to return (mock-echo).
- [ ] The class under test is NOT itself mocked.
- [ ] Assertions target observable behavior, not private method calls or call counts.
- [ ] No `DateTime.now()` / real network / `sleep` in unit or widget tests; time via `fakeAsync`.
- [ ] Error paths, empty results, and boundary inputs each have at least one test.
- [ ] Committed goldens were reviewed; `--update-goldens` not run blindly.
- [ ] No `skip:` without a reason comment and a ticket reference.
- [ ] No copy-paste clones with identical assertions and different names.
- [ ] Tests have meaningful `expect` calls on SUT output / state, not just coverage fill.

---

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code examples (bad → good per rule): [reference.md](./reference.md)
- Umbrella: [flutter-architecture](../flutter-architecture/SKILL.md)
- Adjacent: [flutter-security](../flutter-security/SKILL.md), [flutter-state-management](../flutter-state-management/SKILL.md), [flutter-navigation-platform](../flutter-navigation-platform/SKILL.md)
- flutter_test docs: https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html
- mocktail: https://pub.dev/packages/mocktail
- fake_async: https://pub.dev/packages/fake_async
- integration_test: https://docs.flutter.dev/testing/integration-tests
- Flutter testing docs: https://docs.flutter.dev/testing
