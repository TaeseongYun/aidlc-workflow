<!-- producer: ctx-score-loop | EXAMPLE | per-round progress log -->
# Loop Run Log — book-borrowing

Shows how the loop runs — with no additional user intervention — when `/ctx-score-loop book-borrowing` is executed **once**.

---

## Execution

```
/ctx-score-loop book-borrowing
```

The user types just this one line. Everything after is fully automatic.

---

## Per-Round Progress

### Round 1
```
[ctx-score-loop] book-borrowing — round 1
  dependency 18/25 · build 25/25 · test 12/25 · AC 20/25 = 75/100
  verdict: CONTINUE
  weak axes: test(12) — missing limit/duplicate case tests. AC(20) — concurrency unverified.
  → implement fixes for weak axes, then re-score.
```
- The build passes but the tests are weak. Instead of stopping, the loop **improves the tests**.

### Round 2
```
[ctx-score-loop] book-borrowing — round 2
  dependency 22/25 · build 25/25 · test 15/25 · AC 20/25 = 82/100
  verdict: CONTINUE
  previous 75 → 82 (improvement +7). Not stalled.
  weak axes: test(15) — concurrency test still missing.
  → add concurrency test, then re-score.
```
- 82 points. Still at or below 85, so not complete. Since it's improving, keep going.

### Round 3
```
[ctx-score-loop] book-borrowing — round 3
  dependency 25/25 · build 25/25 · test 20/25 · AC 22/25 = 92/100
  verdict: COMPLETE  (92 > 85 AND build ≠ 0)
  → complete (over 85). Loop ends.
```
- **92 points > 85 → complete.** Since the build axis is not 0, GR-1 passes. Report completion to the user and end.

---

## What If It Had Stalled (counter-example)

The loop doesn't always succeed. For example, if a concurrency bug can't be caught and the tests keep getting blocked:

```
[ctx-score-loop] book-borrowing — round 3 (stall detected)
  dependency 22/25 · build 25/25 · test 15/25 · AC 20/25 = 82/100
  previous 82 → 82 (improvement 0). round 2 was also 80→82 (marginal). 2 consecutive rounds without improvement.
  verdict: STALLED
  → stop. Blocked axis: test(15/25 — LoanConcurrencyTest failing due to deadlock).
  → awaiting human decision. Does not auto-restart.
```

In this case the loop **does not spin forever** — it stops and reports the blocked point to a human.
- **Stall**: 2 consecutive rounds with no score improvement
- **Cap**: 10 rounds or 30 minutes reached
- **Regression**: score dropped from the previous round (report only, no auto-rollback)

---

## Preventing False Completion (counter-example 2)

What if the build is broken but other axes push the score past 85?

```
[ctx-score-loop] book-borrowing — round N
  dependency 25/25 · build 0/25 · test 25/25 · AC 25/25 = 75/100
  (assumption: even with build 0 + full marks elsewhere, the total is 75, so it falls short anyway)

  Even if the total exceeded 85, if the build axis is 0:
  verdict: INCOMPLETE  (GR-1: completion is forbidden when build is 0)
  → "a broken-build state is not called complete."
```

The build and test axes only credit **actual command execution results**. If you don't run the commands, that axis scores 0. So "completing without ever running it" is impossible.

---

## Key Summary (when explaining to someone else)

1. `/ctx-score-loop <feature>` **once** is all it takes. No need to request verification each time.
2. The 4 axes (dependency, build, test, AC — 25 points each) are **scored repeatedly**.
3. It's only complete once it **exceeds 85**. Exactly 85 is incomplete.
4. Build and test only count as score when **actually run** (blocks false completion).
5. On stall (2 rounds) / cap (10 rounds / 30 min) / regression, it **stops and reports the reason**. No infinite loop.
