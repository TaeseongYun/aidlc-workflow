# Code Review — Skills

Actionable procedure an agent (or engineer) runs to review a change. This is the *how*;
the *what/why* reference is [`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-reviewer` (CTX-violation check), `/ctx-score-loop` (post-impl scoring), `/ctx-commit-planner` (commit structure).
- **Platform-agnostic**: applies on any stack. Platform-specific rules live under `platforms/<platform>/`.

## When to use

Any time a change is proposed for merge: a PR/MR, a local diff before commit, or an agent
self-reviewing its own output before handing off.

## Inputs

- The diff (required) — `git diff <base>...<head>`, a PR, or staged changes.
- Change intent — the issue/ticket, PR description, or task. If missing, ask before reviewing.
- Context — the files the diff touches and their immediate callers.

## Outputs

- A list of findings, each with **severity + location + concrete risk + suggested fix**.
- A verdict: **Approve** / **Approve with non-blocking comments** / **Request changes** / **Block**.

## Procedure

1. **Understand intent.** Read the description/ticket. State in one line what the change is
   supposed to do. If you cannot, stop and ask — you cannot review against an unknown goal.
2. **Scope the diff.** List changed files; separate generated/vendored/lockfiles (skip-read,
   note them) from hand-written code. Gauge size (see guide's size table); if > ~400 lines,
   say so and consider requesting a split.
3. **Read the diff once for the shape** — what's the approach — before nitpicking lines.
4. **Pass per dimension.** For each dimension in the guide's table (correctness, design,
   security, error handling, performance, tests, readability, API, observability), scan the
   diff *and the callers it touches*. For bug fixes, grep every caller of the changed
   function — the lazy root-cause fix is one guard where all callers route through, not a
   patch on the single path named in the ticket.
5. **Rate each finding** with a severity (Critical / High / Medium / Low / Nit). If you
   can't name the concrete failure a comment prevents, downgrade it to Nit.
6. **Write comments** in Conventional-Comments form: `label (blocking?): location — risk — suggested fix`.
   Add at least one `praise:` when earned.
7. **Check tests.** Confirm a test would *fail if the new logic broke*. For a bug fix, require
   a regression test that reproduces the original bug. Green tests that don't exercise the
   change are not coverage.
8. **Decide the verdict** using the rules below and emit the report.

## Decision rules

- Any **Critical** → **Block**.
- Any **High**, or a missing test for new logic → **Request changes**.
- Only **Medium/Low** → **Approve with non-blocking comments** (or agree a fast follow-up).
- Only **Nits** → **Approve**; consider a lint rule so the Nit never recurs.
- "Not how I'd write it" but correct and clear → **Approve**. Do not gate on style.

## Stop / escalate

- Intent unknown or requirements ambiguous → ask the author; do not guess-approve.
- Change is a policy/business decision (pricing, refunds, permissions, data retention) →
  escalate to a human owner; an agent must not approve policy.
- Diff too large to review honestly → say so explicitly; request a split rather than skim-approve.
- Security-sensitive path (auth, payments, data export) → require a dedicated security pass.

## Output format

```markdown
## Review: <title>  —  verdict: <Approve | Approve w/ comments | Request changes | Block>

Intent: <one line>
Scope: <N files, ~M lines; skipped: lockfile, generated>

### Findings
- [Critical] path:line — <risk> — <fix>
- [High]     path:line — <risk> — <fix>
- [Medium]   path:line — <risk> — <fix>
- [Nit]      path:line — <preference>
praise: <what was done well>

### Tests
- <does a test fail if the change breaks? regression test present?>
```

## Quick checklist

- [ ] Intent understood and stated
- [ ] Diff scoped; generated files set aside; size acceptable
- [ ] Every dimension passed (not just top-to-bottom once)
- [ ] Bug fix traces to root cause; sibling callers checked
- [ ] Every finding has a severity
- [ ] A test fails if the new logic breaks; regression test for bug fixes
- [ ] Verdict follows the decision rules
