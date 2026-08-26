---
name: frontend-testing
description: Frontend (web) test generation + test-quality guard — write real, deterministic
  tests and detect/block the fake or flaky tests AI commonly produces (assertion-free,
  mock-echo/tautological, over-mocking the unit under test, implementation-detail coupling,
  non-determinism/flakiness, happy-path-only, snapshot abuse, smuggled skips, copy-paste
  clones, coverage theater). Covers the frontend test pyramid and frameworks (Vitest/Jest,
  @testing-library/react, user-event, MSW, Playwright). Auto-loads when writing or
  reviewing tests.
when_to_use: When writing tests, reviewing AI/LLM-generated tests before merge, touching
  test files, or on requests like "write tests", "is this test real", "why is this
  test flaky", "test review".
paths: "**/*.test.ts, **/*.test.tsx, **/*.spec.ts, **/*.spec.tsx, **/e2e/**"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# frontend-testing — test generation + test-quality guard

AI-generated tests are **fast but frequently fake**. Common failures: tests that run
code but assert nothing, tests that only re-assert what a mock was told to return,
tests that mock away the very unit under test, and non-deterministic tests that flake
in CI. Coverage looks green while nothing is actually verified — **coverage theater**.
This skill is both a **generator** (write real tests) and a **guard** (detect and block
fake or flaky AI tests). Guard rules are safety rules; project `ctx/` may tighten them
but the floor is never lowered.

## Scope

- Targets: `**/*.test.ts`, `**/*.test.tsx`, `**/*.spec.ts`, `**/*.spec.tsx`, `**/e2e/**`.
- What it does: **generate real tests** (Mode A) and **detect/block bad AI tests** (Mode B).
- Delegate:
  - Accessibility assertions (ARIA roles, label coverage, focus order) → [frontend-accessibility].
  - Security review of test fixtures (hard-coded secrets, unsafe patterns in helpers) → [frontend-security].
  - Testability / DI seam design (making code testable) → [frontend-architecture].
  - State management test strategy → [frontend-state-data].
- Scope note: these rules govern behavioral correctness of the tests themselves, not
  the application logic under test.

## Mode A — Generate

### Test pyramid

Write **many unit tests, some integration tests, few e2e tests**. Unit tests are fast
and precise; e2e tests are slow and flaky by nature — use them only for critical user
flows that cannot be covered at a lower level.

| Layer | Tool | What to test |
|---|---|---|
| Unit | Vitest / Jest | Pure functions, hooks, isolated component behavior |
| Integration | Vitest + @testing-library/react + MSW | Component trees that fetch data, form submissions, state flows |
| E2E | Playwright | Critical flows end-to-end in a real browser |

### Test behavior, not implementation

Use **Testing Library** queries to interact with the DOM as a user would:
- Prefer `getByRole` (most robust), then `getByLabelText`, `getByPlaceholderText`,
  `getByText`. Use `getByTestId` only as a last resort.
- Do **not** query by class name, internal component state, or React internals.
- Fire interactions through `@testing-library/user-event` (`userEvent.click`,
  `userEvent.type`), not `fireEvent` — `userEvent` simulates real browser behavior.
- One logical assertion per test. Structure every test as **Arrange → Act → Assert**.

### Determinism (the calibration knob)

A test that touches the real clock, real RNG, or real network is flaky by construction.
Always inject and control external dependencies:

- **Clock**: use `vi.useFakeTimers()` / `jest.useFakeTimers()` + `vi.advanceTimersByTime()`.
  Never call `new Date()` or `Date.now()` in a test without faking first.
- **Network**: use **MSW** (`msw/node` for Vitest/Jest, `msw/browser` for integration
  with a real renderer). Never `jest.fn()` over `fetch` or `axios` — MSW intercepts at
  the network layer and tests the real calling code. In e2e (Playwright), use
  `page.route()` or a test API server.
- **Random**: seed the RNG or inject a deterministic factory.
- **No `sleep`**: `await new Promise(r => setTimeout(r, 500))` → use `waitFor` /
  `findBy*` / `vi.runAllTimers()` instead.
- **No order-dependence**: each test must be runnable in isolation. Use `beforeEach`
  to reset MSW handlers and fake timers.

### Error paths + boundaries

Every function with a failure branch needs at least one test for that branch.
Cover: empty/null/undefined inputs, zero, max, malformed data, network error responses
(MSW `{ status: 500 }`), and loading states. A component that renders differently when
data is loading or when a request fails must have tests for both states.

### Framework map

| Concern | Tool |
|---|---|
| Test runner | Vitest (preferred) or Jest |
| Component rendering + queries | `@testing-library/react` (`render`, `screen`) |
| User interactions | `@testing-library/user-event` v14+ |
| Network interception | MSW (`setupServer` / `server.use()` per test) |
| Async assertions | `waitFor`, `findBy*` from Testing Library |
| Fake timers | `vi.useFakeTimers()` / `jest.useFakeTimers()` |
| Snapshot (limited) | Vitest/Jest built-in — small, reviewed, not the sole assertion |
| E2E | Playwright (`page.goto`, `locator`, `expect`) |

## Mode B — Guard

Block bad AI tests before merge. Each item: **rule → common AI failure → red-flag**.
Code examples (bad → good) in [reference.md](./reference.md).

### 1. Assertion-free test

- **Rule**: a test must assert at least one observable outcome. Running code without
  asserting is not a test.
- **Common AI failure**: generates a test body that calls the function or renders the
  component but contains no `expect(...)` calls.
- **red-flag**: test body has function calls or `render(...)` but zero `expect`.

### 2. Mock-echo / tautological

- **Rule**: do not assert that a mock returns exactly the value you stubbed it to
  return. That verifies the mock, not the code under test.
- **Common AI failure**: `mockReturnValue(42)` … `expect(result).toBe(42)` with no
  logic in between that could fail.
- **red-flag**: the only assertion echoes the stub's return value verbatim.

### 3. Over-mocking / mocking the SUT

- **Rule**: never mock the module, class, or function that the test is supposed to
  exercise. Mocking the system under test makes the test vacuous.
- **Common AI failure**: `vi.mock('./MyComponent')` in a test file titled
  `MyComponent.test.tsx`; mocking the hook being tested.
- **red-flag**: a `vi.mock` / `jest.mock` targeting the same module being tested.

### 4. Implementation-detail coupling

- **Rule**: assert observable behavior — what the user sees or what the public API
  returns — not internal call order, private method invocations, or internal state.
- **Common AI failure**: `expect(spy).toHaveBeenCalledWith(internalValue)` on a
  private helper, or `expect(component.state.count).toBe(1)` accessing React
  internals.
- **red-flag**: `toHaveBeenCalledTimes` / `toHaveBeenCalledWith` on internal helpers;
  accessing `instance()`, internal state, or private class members.

### 5. Non-determinism / flakiness

- **Rule**: no real clock, real RNG, `sleep`, real network, or real filesystem in a
  unit or integration test. Inject or fake every time-based or I/O dependency.
- **Common AI failure**: `expect(new Date().getFullYear()).toBe(2024)`,
  `await new Promise(r => setTimeout(r, 1000))`, calling the real API endpoint.
- **red-flag**: `new Date()` / `Date.now()` / `Math.random()` without faking; `sleep`
  / `setTimeout` without fake timers; `fetch` / `axios` called without MSW intercept.

### 6. Happy-path only

- **Rule**: every component or function with visible failure branches (error state,
  loading state, empty state, boundary values) must have at least one test per branch.
- **Common AI failure**: generates only the success-path test for a component that
  clearly renders an error message or a skeleton loader.
- **red-flag**: a component with `isLoading` / `isError` / `isEmpty` props/states
  has tests for success only.

### 7. Snapshot abuse

- **Rule**: snapshots are useful for small, stable fragments (e.g., a formatted string,
  a serialized config). They are **not** a substitute for behavioral assertions. Large
  snapshots are noise; auto-updated snapshots commit without human review.
- **Common AI failure**: `expect(container).toMatchSnapshot()` as the only assertion
  on a complex component; adding `--updateSnapshot` to CI scripts.
- **red-flag**: snapshot > ~30 lines; snapshot is the sole assertion; `--updateSnapshot`
  or `--ci=false` in CI config; snapshot file committed with no behavioral assertions.

### 8. Smuggled skip / disable

- **Rule**: `it.skip`, `xit`, `test.skip`, `describe.skip`, `xdescribe` require a
  justification comment with a reason and a ticket/issue reference. A skip with no
  comment is a silently deleted test.
- **Common AI failure**: adds `it.skip(...)` or wraps a describe in `xdescribe` to
  make failing tests pass without fixing them.
- **red-flag**: `it.skip` / `xit` / `test.skip` / `describe.skip` / `xdescribe` with
  no adjacent comment explaining why and linking a ticket.

### 9. Copy-paste clone

- **Rule**: duplicated test bodies where the test name/description diverges from what
  is actually asserted indicate a copy-paste error. Two tests with different names
  asserting identical things cover only one scenario.
- **Common AI failure**: copies a passing test, changes the `it(...)` description, but
  forgets to change the input or the assertion.
- **red-flag**: two or more `it(...)` blocks with different descriptions but identical
  `expect` calls and identical inputs.

### 10. Coverage theater

- **Rule**: a test that exercises code paths but asserts nothing (or asserts only
  trivial non-behavioral things) inflates line coverage while providing no regression
  value. Line coverage is a floor, not a goal.
- **Common AI failure**: wraps a component in `render(...)` with no `expect`, or calls
  a function and asserts only that it did not throw.
- **red-flag**: high line coverage with near-zero meaningful assertions; the only
  assertion is `.not.toThrow()` or `.toBeDefined()` on a trivially-defined export.

## Guard review checklist

For tests that AI generated or were added quickly, before merge:

- [ ] Every `it`/`test` block contains at least one `expect` that could realistically fail.
- [ ] No assertion merely echoes a `mockReturnValue` / `mockResolvedValue` stub.
- [ ] No `vi.mock` / `jest.mock` targeting the module being tested.
- [ ] Assertions are on observable output (rendered text, return value, DOM state), not internals.
- [ ] No `new Date()`, `Date.now()`, `Math.random()`, or `sleep` without fake timers.
- [ ] Network calls go through MSW, not a `jest.fn()` patched onto `fetch`/`axios`.
- [ ] Error states, loading states, and boundary inputs each have at least one test.
- [ ] Snapshots are small, reviewed, and accompanied by at least one behavioral assertion.
- [ ] All `it.skip` / `xit` / `describe.skip` have a justification comment + ticket.
- [ ] No two tests assert identical things under different names.
- [ ] Line coverage does not substitute for meaningful assertions.

## Halt conditions

Halt and report (do not generate or approve tests) when:

- The code under test is not provided or readable.
- A guard violation is found during review mode and the violation cannot be auto-fixed
  (e.g., the test is assertion-free and the correct assertion is ambiguous without
  understanding the intended behavior).

Output on halt:

```markdown
## Test Guard — Halted

Halt reason:
- (specific reason)

Items requiring clarification:
1. ...
```

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Bad → good code samples per rule: [reference.md](./reference.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- Adjacent: [frontend-accessibility](../frontend-accessibility/SKILL.md), [frontend-security](../frontend-security/SKILL.md), [frontend-state-data](../frontend-state-data/SKILL.md)
- Testing Library queries: https://testing-library.com/docs/queries/about
- MSW (Mock Service Worker): https://mswjs.io/docs/
- Vitest: https://vitest.dev/
- Playwright: https://playwright.dev/docs/intro
- Skill protocol: [../../../skills/_shared/skill-protocol.md](../../../skills/_shared/skill-protocol.md)
