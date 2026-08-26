---
name: rn-testing
description: React Native test generation + test-quality guard — write real, deterministic tests and
  detect/block the fake or flaky tests AI commonly produces (assertion-free, mock-echo/tautological,
  over-mocking the unit under test, implementation-detail coupling, non-determinism/flakiness,
  happy-path-only, snapshot abuse, smuggled skips, copy-paste clones, coverage theater). Covers the
  RN test pyramid and frameworks (Jest, @testing-library/react-native, MSW, Detox, Maestro). Auto-loads
  when writing or reviewing tests.
when_to_use: When writing tests, reviewing AI/LLM-generated tests before merge, touching test files,
  or on requests like "write tests", "is this test real", "why is this test flaky", "test review".
paths: "**/*.test.ts, **/*.test.tsx, **/__tests__/**, **/e2e/**"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# rn-testing — test generation + test-quality guard

AI-generated tests are **fast but frequently fake**. React Native compounds the
problem: native modules must be mocked, the event loop is non-obvious, and RNTL
queries tempt AI to reach into internal state instead of user-visible output.
The result is coverage theater — green numbers, zero verification. Empirically,
AI-generated test suites often assert only what the mock was told to return,
skip every error branch, and introduce `setTimeout`-based waits that flake in
CI. This skill is both a **generator** (write real tests) and a **guard** (detect and
block fake/flaky AI tests). Guard rules are safety rules; project `ctx/` may
tighten them but the floor is never lowered.

## Scope

- Targets: RN test files (`*.test.ts`, `*.test.tsx`, `__tests__/**`, `e2e/**`) —
  especially AI-generated or quickly produced tests.
- What it does: **generate real tests** (Mode A) and **detect fake/flaky patterns**
  (Mode B) for each failure mode below.
- Delegate: security test concerns → [rn-security], component architecture /
  testability seams (DI, inversion of control) → [rn-architecture], async state
  shape and async selectors → [rn-state-data], native module API contracts →
  [rn-native-modules].

## Mode A — Generate

### Test pyramid

Many unit tests, some integration tests, few e2e/UI tests. The pyramid is a
cost/speed/isolation trade-off:

- **Unit** (Jest + RNTL): pure logic, individual components, hooks. Fast, isolated,
  no device. The majority of your test suite.
- **Integration** (Jest + RNTL + MSW): component trees with mocked network via
  MSW service worker. No real device, near-full component behavior.
- **E2E / UI** (Detox or Maestro): run on a real device/emulator. Cover only
  the critical user journeys; these are slow, expensive, and the hardest to
  stabilize — minimize their count.

### Test behavior, not implementation

Query the UI through the lens of the user:

- **Prefer** `getByRole`, `getByText`, `getByLabelText` — things a user can see or
  interact with.
- **Avoid** `getByTestId` except where semantics are genuinely unavailable.
- **Never** reach into component internals (`instance()`, state, `wrapper.find(ComponentName)`
  internal-call-count asserts). If the output is correct, the implementation is
  irrelevant to the test.

AAA structure — **Arrange** (setup and render), **Act** (fire events), **Assert**
(check visible output). One logical assertion per test; split multi-behavior
tests into separate cases.

### Determinism — the calibration knob

A test that touches the real clock, real RNG, or real network is **flaky by
construction**. Fix it at the source:

- **Clock**: use `jest.useFakeTimers()` / `jest.setSystemTime()` rather than
  `new Date()` or `Date.now()` inside tests; advance with `jest.advanceTimersByTime()`.
- **RNG**: seed or mock `Math.random` / `crypto.getRandomValues`.
- **Network**: intercept with MSW (`setupServer`, `server.use(http.get(...))`) so
  tests never touch a real endpoint.
- **Native modules**: mock at the module level in `jest.setup.js` or with
  `jest.mock(...)` — not inline in every test file.
- **No `sleep` or real `setTimeout` in tests.** If you need to wait for async
  side-effects, use `waitFor` from RNTL or advance fake timers — never
  `await new Promise(r => setTimeout(r, 500))`.
- **No order-dependent shared state.** Reset mocks in `beforeEach`/`afterEach`.

### Error paths and boundaries

Every function that has a failure branch needs a test for that branch. Cover:

- null / undefined / empty inputs
- zero and max values
- network failure (MSW `http.get(..., () => HttpResponse.error())`)
- rejected promises and thrown errors
- permission denied / unavailable native module

Happy-path-only suites are the most common gap in AI-generated tests.

### Framework map — React Native

| Layer | Tool |
|---|---|
| Unit / component | Jest + `@testing-library/react-native` |
| Hook testing | `renderHook` from RNTL |
| Network mocking | MSW (`msw/native` or `msw` with `react-native-url-polyfill`) |
| Native module mocks | `jest.mock(...)` in `jest.setup.js` or per-test |
| Fake timers | `jest.useFakeTimers()` + `jest.advanceTimersByTime()` |
| Async assertions | `waitFor`, `findBy*` from RNTL |
| E2E / UI | Detox or Maestro (device/emulator required) |

### Native module mocking discipline

React Native native modules (Camera, Bluetooth, Haptics, SecureStore, etc.)
are not available in the Jest JS environment. Mock them once, globally, in
`jest.setup.js` or `__mocks__/<module>.ts`. Rules:

- Mock the **native module interface**, not the component that uses it.
- Return realistic shapes (not empty objects) so components render correctly.
- Reset call history in `beforeEach`; never carry state between tests.
- Do NOT mock the component under test itself — that is over-mocking (Rule 3 below).

Code samples → [reference.md](./reference.md).

## Mode B — Guard

Block bad AI tests. Each item: **rule → the failure AI commonly produces →
red-flag**. Code examples in [reference.md](./reference.md).

### 1. Assertion-free test

- **Rule**: every test must assert at least one user-visible outcome.
- **Common AI failure**: generates a test that renders a component or calls a
  function but only checks that it "didn't throw"; the `expect` block is absent
  or is a single no-op `expect(true).toBe(true)`.
- **red-flag**: test body has function calls and renders but zero meaningful
  `expect(...)` calls; or the only assertion is `expect(wrapper).toBeTruthy()`.

### 2. Mock-echo / tautological assertion

- **Rule**: assertions must verify real behavior, not echo back what a mock was
  configured to return.
- **Common AI failure**: stubs `fetchUser` to return `{ id: 1, name: 'Alice' }`,
  then asserts `expect(result.name).toBe('Alice')` — this verifies nothing; the
  mock is the only "source of truth".
- **red-flag**: the asserted value is the literal value passed to `mockResolvedValue`
  / `jest.fn().mockReturnValue(...)` with no transformation between stub and assertion.

### 3. Over-mocking / mocking the SUT

- **Rule**: the **unit under test** (component, hook, function) must not be mocked.
  Only its **dependencies** are mocked.
- **Common AI failure**: mocks `UserCard` while writing a test for `UserCard`;
  mocks a custom hook and then "tests" the component by checking the mock was called.
- **red-flag**: `jest.mock('../UserCard')` or `jest.spyOn` on the module that the
  test file is named after; importing the mock and asserting `.toHaveBeenCalled()`
  on the thing being tested.

### 4. Implementation-detail coupling

- **Rule**: assert observable output (rendered text, accessible elements, return
  values, emitted events) — never internal call order or private method invocations.
- **Common AI failure**: spies on a private helper, asserts `expect(spy).toHaveBeenCalledWith(...)`,
  asserts render call count, asserts internal state via `component.instance().state`.
- **red-flag**: `jest.spyOn` on a method not in the public API; call-count asserts
  on internal rendering logic; accessing `.state` or `.instance()` on RNTL output.

### 5. Non-determinism / flakiness

- **Rule**: no real clock, real RNG, real network, or real filesystem in unit/
  integration tests. No `sleep`. No shared mutable state between tests.
- **Common AI failure**: `new Date()` or `Date.now()` inline in a test; a
  `jest.fn()` that returns the current timestamp; `await new Promise(r => setTimeout(r, 1000))`
  as a "wait" strategy; a shared array mutated across tests.
- **red-flag**: `Date.now()` / `new Date()` without `jest.useFakeTimers()`; real
  `setTimeout`/`setInterval` durations as waits; no MSW but `fetch` calls pass;
  mutable top-level `let` state not reset in `beforeEach`.

### 6. Happy-path only

- **Rule**: any function with error handling, nullable inputs, or failure branches
  requires tests covering those branches.
- **Common AI failure**: writes one test for the success case of a `fetchProfile`
  call; never tests the network-error case, the 404 case, or the null-user case.
- **red-flag**: a hook or component with visible error UI, a `try/catch`, or a
  nullable prop — but the test file contains only one success-path test case.

### 7. Snapshot abuse

- **Rule**: snapshots are acceptable for small, stable, intentionally-reviewed
  component shapes. They are not a substitute for behavioral assertions and must
  not be auto-updated blindly.
- **Common AI failure**: generates a 400-line `.snap` file as the only assertion;
  includes `--updateSnapshot` or `--ci=false` in the test script so snapshots
  silently auto-update in CI.
- **red-flag**: `.snap` files larger than ~30 lines for a single component;
  snapshot as the **only** assertion in a test; `--updateSnapshot` in CI scripts;
  a `toMatchSnapshot()` on dynamic data (timestamps, random IDs).

### 8. Smuggled skip / disable

- **Rule**: `it.skip`, `xit`, `xdescribe`, `test.skip` require a justification
  comment with a tracking ticket or reason. A skip with no explanation is a
  hidden failure.
- **Common AI failure**: silently adds `it.skip(...)` when it cannot figure out
  how to make a test pass, leaving it disabled with no comment.
- **red-flag**: `it.skip`, `xit`, `xdescribe`, or `test.skip` with no adjacent
  comment explaining why and when to re-enable.

### 9. Copy-paste clone

- **Rule**: each test case must have a description that matches what it actually
  asserts. Duplicated tests with identical assertions under different names verify
  nothing new.
- **Common AI failure**: copies a success-case test, renames it "should handle
  error", but forgets to change the `mockResolvedValue` or the assertion — the
  two tests are functionally identical.
- **red-flag**: two or more `it(...)` blocks with identical `expect` calls and
  stub configurations but different description strings.

### 10. Coverage theater

- **Rule**: line coverage that passes through code without asserting any output
  is worthless. Every test must have at least one assertion tied to the code path
  it exercises.
- **Common AI failure**: renders a component in a loop across many props, calls
  `expect(screen.toJSON()).toBeTruthy()` as the sole assertion — inflates branch
  coverage while verifying nothing.
- **red-flag**: high coverage reported but near-zero distinct `expect` values per
  test; `toJSON().toBeTruthy()` or `toBeDefined()` as the only assertions across
  many tests; no mutation survivors reported (if mutation testing is available).

## Guard checklist — before merging AI-generated tests

- [ ] Every test has at least one meaningful `expect(...)` asserting user-visible output.
- [ ] No assertion echoes back a mock's literal stub value without transformation.
- [ ] The module under test is not itself mocked; only its dependencies are.
- [ ] No `jest.spyOn` on private/internal methods; no `.instance()` / `.state` access.
- [ ] Fake timers used wherever real time appears; MSW used wherever network is called.
- [ ] At least one test covers each visible error path or nullable input.
- [ ] Snapshots are small, reviewed, and not the sole assertion; `--updateSnapshot` absent from CI.
- [ ] No `it.skip`/`xit`/`xdescribe` without a justification comment and ticket.
- [ ] No two tests share identical assertions under different names.
- [ ] Coverage increase is backed by assertions, not bare renders.

## Halt conditions

Halt (do not continue) if:

- The test file imports and mocks the same module it is supposed to test (Rule 3).
- A CI script contains `--updateSnapshot` with no approval gate (Rule 7).
- More than half the tests in a file are `it.skip` without justification (Rule 8).

Output on halt:

```
## Test Guard — Halted

Halt reason:
- (specific rule and location)

Items requiring review:
1. ...
```

Do NOT propose alternatives on halt. Output only the halt reason.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code samples (bad → good): [reference.md](./reference.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md)
- Adjacent: [rn-security](../rn-security/SKILL.md), [rn-state-data](../rn-state-data/SKILL.md), [rn-native-modules](../rn-native-modules/SKILL.md)
- Testing Library React Native: https://callstack.github.io/react-native-testing-library/
- Jest fake timers: https://jestjs.io/docs/timer-mocks
- MSW: https://mswjs.io/docs/integrations/react-native
- Detox: https://wix.github.io/Detox/
- Maestro: https://maestro.mobile.dev/
- Skill protocol: [../../../skills/_shared/skill-protocol.md](../../../skills/_shared/skill-protocol.md)
