# Testing Strategy

> Platform-agnostic reference for deciding what to test, at which level, and how to
> keep tests fast, deterministic, and meaningful. Companion procedure:
> [`../SKILLS.md`](../SKILLS.md).

A test is a claim about behavior that a machine can re-check. Its only job is to
*fail when the logic breaks* and stay quiet otherwise. A test that passes no matter
what the code does is worse than no test — it costs runtime and buys false
confidence. Strategy is choosing the fewest tests that make real breakage loud.

---

## Goals (in priority order)

1. **Catch regressions** — a change that breaks behavior turns a check red before merge.
2. **Enable change** — good tests let you refactor without fear; that is their return on investment.
3. **Document behavior** — a test names an input and the expected output; it is executable spec.
4. **Localize failure** — when a test fails, it points near the cause, not five layers away.
5. **Run cheaply** — fast and deterministic, or developers stop running them.

A suite that optimizes coverage percentage (#none of these) while missing the one
branch that actually breaks has failed. Test behavior that matters, not lines that count.

---

## The test pyramid

Most tests at the base (fast, isolated), fewer as you climb (slow, broad). Inverting
this — many e2e, few unit — is the *ice-cream cone* anti-pattern: slow, flaky, and
hard to debug.

| Level | Scope | What it catches | Speed | Cost to write/maintain | Share of suite |
| :---- | :---- | :-------------- | :---- | :--------------------- | :------------- |
| **Unit** | One function/class, dependencies faked | Logic errors, edge cases, branch coverage | Milliseconds | Low | Most (~70%) |
| **Integration** | Several units + a real boundary (DB, queue, filesystem) | Wiring, serialization, SQL, config, contract mismatches | Seconds | Medium | Some (~20%) |
| **End-to-end (e2e)** | Whole system through its public entry (UI, API) | User-visible flows, deployment/env issues | Seconds–minutes | High | Few (~10%) |

The percentages are a shape, not a quota. The real rule: push each test to the
*lowest* level that can catch its failure. If a unit test can catch it, don't spend an
e2e run on it.

---

## Test doubles

A double stands in for a real dependency so a test can isolate the code under test.
Names follow Meszaros (*xUnit Test Patterns*); pick the least powerful one that works.

| Double | What it does | Use when |
| :----- | :----------- | :------- |
| **Dummy** | Passed to satisfy a signature, never used | A param is required but irrelevant to the test |
| **Stub** | Returns canned answers to calls | You need the collaborator to *return* something (state setup) |
| **Spy** | A stub that also records how it was called | You must assert a call *happened* but still want a light double |
| **Mock** | Pre-programmed with expectations; fails if calls don't match | You're verifying an *interaction* is the behavior (e.g. "sends exactly one email") |
| **Fake** | A working but simplified implementation (in-memory DB, hash-map repo) | A stub would be too much setup; you want realistic behavior without the real cost |

Prefer stubs/fakes (state verification) over mocks (interaction verification). Mocks
couple the test to *how* the code calls collaborators; over-mocking produces tests
that break on every refactor and pass even when the real integration is broken.

---

## What to test — and what not to

Test **behavior** (observable inputs → outputs, including error paths), not
**implementation** (private methods, internal call order, field values). Behavior
survives refactoring; implementation tests punish it.

| Test it | Don't test it |
| :------ | :------------ |
| Public API contracts and return values | Private helpers directly (test them through the public surface) |
| Branches, boundaries (empty/null/max/off-by-one), error paths | That a mock was called (unless the call *is* the behavior) |
| Bug fixes (a regression test that reproduces the bug) | Trivial getters/setters and pass-through wrappers |
| Non-trivial logic: parsers, money math, auth, state machines | The framework, the stdlib, or third-party code you don't own |
| Integration seams you own (your SQL, your serialization) | Generated code and config with no logic |

YAGNI applies to tests too: a one-line pure pass-through needs no test; a branch, loop,
parser, or money/security path needs at least one runnable check that fails if it breaks.

---

## Coverage: meaningful vs vanity

Coverage measures which lines *ran*, not which behavior is *verified*. A line can be
covered by a test with no assertion — executed, proven nothing.

| Signal | Meaningful coverage | Vanity coverage |
| :----- | :------------------ | :-------------- |
| Assertions | Every covered branch has an assertion that fails if it breaks | Lines run; asserts weak or absent |
| Target | Coverage is a *floor to notice gaps*, never a goal to hit | Coverage % is the KPI; devs write tests to move the number |
| Mutation | Survives mutation testing (flip a `>` to `>=`, a test goes red) | Mutants survive; tests don't detect injected bugs |
| Focus | High on logic-dense code; low is fine on glue | Uniform 100% including trivial glue |

The honest test of a test: **mutate the code it covers — if no test fails, the test
proves nothing.** Chasing a coverage number (Goodhart's law) produces assert-free
tests that inflate the metric and catch nothing.

---

## TDD vs test-after

| | Test-driven (red → green → refactor) | Test-after |
| :-- | :----------------------------------- | :--------- |
| **Flow** | Write failing test, make it pass, refactor | Write code, then tests |
| **Strength** | Forces testable design; the test is proven to fail first | Faster when the design is already clear |
| **Weakness** | Overhead when the API is still being explored | Easy to write tests that pass trivially (never seen red) |
| **Best for** | Well-understood logic, bug fixes (reproduce first), tricky algorithms | Spikes, exploratory code, UI glue |

The load-bearing part of TDD is not ceremony — it's that you *watched the test fail for
the right reason* before making it pass. A test-after test never seen red might be
asserting nothing. For a bug fix, always write the reproducing test first (see Regression).

---

## Structure: Arrange–Act–Assert

Every test has three phases; keep them visually separate and keep **one logical
assertion of behavior** per test (multiple `assert` lines checking one outcome is fine).

| Phase | Does | Keep it |
| :---- | :--- | :------ |
| **Arrange** | Set up inputs, doubles, system under test | Minimal; extract shared setup, but keep the test readable in isolation |
| **Act** | Invoke the one behavior under test | A single call — if you need two, that's two tests |
| **Assert** | Check the observable outcome | On behavior/output, not internal state |

A test that acts twice is testing two things and will report failure ambiguously.

---

## Deterministic tests (killing flakiness)

A flaky test — passes and fails on the same code — is worse than no test: it trains the
team to ignore red. Determinism means the same inputs always give the same result. The
usual sources of non-determinism, and the fix:

| Source | Symptom | Fix |
| :----- | :------ | :-- |
| **Time** | Fails at midnight, month-end, DST, timezone | Inject a clock; freeze time; never assert on `now()` |
| **Randomness** | Fails ~1 run in N | Seed the RNG; inject the random source |
| **Ordering** | Passes alone, fails in the suite (or vice-versa) | No inter-test dependencies; don't assert on unordered collection order |
| **Shared state** | Fails only in parallel / on rerun | Isolate fixtures; fresh DB/tmp per test; tear down; no global mutation |
| **Concurrency** | Fails under load, timing-dependent | Await deterministically; avoid `sleep`; use test hooks/barriers, not timers |
| **External network** | Fails when a service is down/slow | Stub the boundary; hermetic tests; no live third-party calls in CI |

Quarantine a flaky test *out of the required gate immediately*, then fix or delete it.
A flaky test left in the gate erodes trust in every other test.

---

## Regression tests

Every bug fix gets a test that **fails first, then passes with the fix** — this proves
the test reproduces the bug and the fix resolves it. Order matters:

1. Write a test that reproduces the reported bug; run it — it must **fail**.
2. Fix the root cause (not the symptom; check sibling callers of the changed function).
3. Run again — it now **passes**. Keep the test forever; it guards against re-breakage.

A fix without a reproducing test is unverified and unguarded — the bug can silently return.

---

## Contract tests

At a service boundary, both sides must agree on the message shape. A contract test
verifies that a consumer's expectations and a provider's responses match, *without*
running both together in one slow e2e.

| Party | Verifies | Runs against |
| :---- | :------- | :----------- |
| **Consumer** | "I send X, I expect a response shaped like Y" | A mock provider honoring the contract |
| **Provider** | "For request X, I return Y" | The recorded contract, in the provider's own CI |

The contract (a shared, versioned artifact) is the source of truth. This catches
integration drift between independently deployed services far cheaper than full e2e.

---

## Property-based testing (brief)

Instead of hand-picked examples, state a *property* that must hold for all inputs and let
the framework generate hundreds, shrinking any failure to a minimal case. Good for pure
logic with clear invariants: `decode(encode(x)) == x`, "sorted output is a permutation of
input," parsers, math. Complements example-based tests; doesn't replace them.

---

## Test naming

A test name should read as a sentence about behavior, so a failure log tells you what
broke without opening the code.

| Pattern | Example |
| :------ | :------ |
| `method_condition_expectedResult` | `withdraw_insufficientFunds_throws` |
| `should <behavior> when <condition>` | `should reject withdrawal when balance below amount` |
| Given/When/Then | `given_emptyCart_when_checkout_then_error` |

Pick one convention per suite. The name plus the failure message should be enough to
locate the defect; a test named `test1` that fails tells you nothing.

---

## Performance and security testing (pointers)

These are specialized and mostly separate from the correctness suite — don't block every
commit on them, but gate releases where they matter.

| Kind | Answers | Where |
| :--- | :------ | :---- |
| **Load / stress** | Does it hold up at N× traffic? Where does it degrade? | Dedicated env; against a budget, not "faster is better" |
| **Benchmark / micro** | Did this change regress a hot path? | Fixed hardware; compare to a baseline; track over time |
| **Security** | Injection, authz, secrets, dependency CVEs | SAST/DAST + dependency scan in CI; see [`../code-review/reference/guide.md`](../../code-review/reference/guide.md) |

---

## CI integration and gating

Tests only protect the codebase if they run automatically and *block merge* on failure.

| Concern | Rule |
| :------ | :--- |
| **When** | Run the fast suite (unit + fast integration) on every push/PR |
| **Required checks** | Mark them required — a red check blocks merge, no override by default |
| **Slow tiers** | e2e / load run on a schedule or pre-release, not on every commit, if they'd slow the loop |
| **Flaky gate** | A flaky test is quarantined out of the required set, not retried-until-green |
| **Coverage gate** | Optional and gentle (don't drop below floor); never a hard 100% bar |
| **Speed** | If the required suite is too slow, developers bypass it — parallelize, shard, or move slow tests to a later tier |

See [`../ci-cd-automation/reference/guide.md`](../../ci-cd-automation/reference/guide.md) for
pipeline stages, caching, and required-check configuration.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Testing implementation details | Breaks on every refactor; passes when integration is broken | Test observable behavior through the public surface |
| Ice-cream cone (too many e2e) | Slow, flaky, hard to localize; the loop rots | Push tests to the lowest level that catches the failure |
| Flaky tests left in the gate | Team learns to ignore red; real failures hide | Quarantine immediately; fix the non-determinism or delete |
| Coverage as a target | Goodhart: assert-free tests inflate the number | Coverage is a gap-finder floor; verify with mutation |
| Assert-free tests | Executes code, proves nothing; false confidence | Every test must fail if the behavior breaks |
| Over-mocking | Couples test to call structure; green while broken | Prefer stubs/fakes; mock only when interaction *is* the behavior |
| Slow required suite | Developers skip or bypass it | Parallelize/shard; tier the slow tests |
| Bug fix without a regression test | The bug silently returns | Reproduce first (red), fix, keep the test |

---

## References

- Martin Fowler — *The Practical Test Pyramid* (Ham Vocke): <https://martinfowler.com/articles/practical-test-pyramid.html>
- Freeman & Pryce — *Growing Object-Oriented Software, Guided by Tests*
- Google Testing Blog: <https://testing.googleblog.com/>
- Gerard Meszaros — *xUnit Test Patterns* (test-double taxonomy)
