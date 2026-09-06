# Testing Strategy — Skills

Actionable procedure an agent (or engineer) runs to decide what to test and to leave a
suite that fails when the logic breaks. This is the *how*; the *what/why* reference is
[`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-score-loop` (test axis — a test that never ran scores 0; unverified logic is not done).
- **Siblings**: [`../ci-cd-automation/reference/guide.md`](../ci-cd-automation/reference/guide.md) (gating), [`../code-review/reference/guide.md`](../code-review/reference/guide.md) (tests as a review dimension).
- **Platform-agnostic**: applies on any stack. Platform-specific runners/config live under `platforms/<platform>/`.

## When to use

Whenever you write or change non-trivial logic (a branch, loop, parser, money/security
path), fix a bug, or review whether a change is adequately tested before it merges.

## Inputs

- The code/change under test and its intent (what behavior must hold).
- The existing suite and how it runs (test command, CI config).
- For a bug fix: the reproduction steps or failing input.

## Outputs

- The minimum tests that fail if the behavior breaks, at the lowest level that catches it.
- For a bug fix: a regression test proven to go red before the fix.
- A verdict for review: **adequately tested** / **gaps: <list>** / **untested**.

## Procedure

1. **State the behavior.** In one line, name the observable input → output (including the
   error path). If you can't, you don't yet know what to test — clarify first.
2. **Pick the level.** Choose the *lowest* level that can catch the failure (unit >
   integration > e2e). Don't spend an e2e run on what a unit test proves.
3. **Choose the least-powerful double.** Dummy < stub < spy < mock < fake. Prefer
   stub/fake (state) over mock (interaction); mock only when the interaction *is* the behavior.
4. **Write it AAA.** Arrange (minimal setup), Act (one call), Assert (on behavior, not
   internals). One logical behavior per test. Name it as a sentence about behavior.
5. **Cover the edges.** Empty / null / max / off-by-one / error path — not just the happy path.
6. **Prove it can fail.** Watch it go red for the right reason (TDD), or mutate the code
   (flip a comparison, break the branch) and confirm a test goes red. A green-only test
   that never failed may assert nothing.
7. **For a bug fix:** write the reproducing test *first*, run it — it must fail. Fix the
   **root cause** (grep sibling callers of the changed function). Rerun — it passes. Keep it.
8. **Make it deterministic.** No wall-clock, unseeded RNG, ordering, shared state, `sleep`,
   or live network. Inject clock/RNG; isolate fixtures; stub external boundaries.
9. **Wire it into CI.** Ensure it runs in the fast suite on every PR and the check is
   required. If it's slow, tier it — don't slow the loop for everyone.

## Decision rules

- Non-trivial logic with no test that fails on breakage → **not done**; add the check.
- Bug fix without a reproducing regression test → **request changes**.
- Test asserts on private methods / call order / mock-was-called (not behavior) → rewrite to test behavior.
- Test can't be made to fail by mutating the code → it proves nothing; fix or delete it.
- Flaky test → quarantine out of the required gate now; fix the non-determinism or delete.
- Trivial one-line pass-through, getter, or framework glue → no test (YAGNI); say so.
- Coverage % below floor but logic-dense paths are asserted → fine; don't chase the number.

## Stop / escalate

- Behavior/requirements ambiguous → clarify before writing tests against a guessed spec.
- Test needs a real external service to pass → stub the boundary or move to a hermetic
  integration tier; don't put live third-party calls in the required gate.
- Change is a policy decision (pricing, retention, permissions) → the test encodes policy;
  confirm the intended behavior with a human owner before locking it in.

## Output format

```markdown
## Test plan: <behavior>  —  verdict: <adequately tested | gaps | untested>

Behavior: <one line: input → output, incl. error path>
Level: <unit | integration | e2e> — <why the lowest that catches it>

### Tests added / needed
- <name> — <what breaks make it fail> — <level>
- (bug fix) <name> — reproduces <bug>; red before fix, green after

### Determinism
- <clock/RNG/ordering/shared-state/network handled? how?>

### CI
- <runs in fast suite? required check? tiered if slow?>
```

## Quick checklist

- [ ] Behavior stated as input → output (incl. error path)
- [ ] Lowest level that catches the failure
- [ ] Least-powerful double; behavior not implementation asserted
- [ ] AAA; one behavior per test; behavior-sentence name
- [ ] Edges covered (empty/null/max/off-by-one/error)
- [ ] Proven it can fail (seen red / survives mutation)
- [ ] Bug fix: reproducing test red before fix, root cause fixed, sibling callers checked
- [ ] Deterministic (no time/RNG/order/shared-state/sleep/network)
- [ ] Runs in CI fast suite as a required check
