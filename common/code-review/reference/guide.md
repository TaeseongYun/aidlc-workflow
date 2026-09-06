# Code Review

> Platform-agnostic reference for reviewing code changes: what to look for, how to
> rate findings, how to comment, and where automation ends and human judgment begins.
> Companion procedure: [`../SKILLS.md`](../SKILLS.md).

Code review is the practice of a second person (or agent) examining a change before it
merges, to catch defects, spread knowledge, and keep the codebase coherent. It is a
*gate*, not a formality: the goal is a correct, maintainable change — not a rubber stamp
and not a rewrite of the author's style.

---

## Goals (in priority order)

1. **Correctness** — the change does what it claims and does not break what worked.
2. **Safety** — no security holes, data loss, or irreversible operations slip through.
3. **Maintainability** — the next reader (often the author, months later) can understand and change it.
4. **Knowledge transfer** — reviewer and author both learn the system a little better.
5. **Consistency** — the change fits the codebase's existing patterns and conventions.

A review that optimizes #5 at the expense of #1 (bikeshedding style while missing a bug)
has failed. Rank findings by impact, not by how easy they are to spot.

---

## What to review

Review the **diff first**, then the **surrounding context** the diff depends on. A line
can be correct in isolation and wrong given its callers.

| Change type | Primary risk to probe |
| :---------- | :-------------------- |
| New feature | Requirements met? Edge cases? New failure modes? |
| Bug fix | Root cause fixed, not just the reported symptom? Sibling callers still correct? Regression test added? |
| Refactor | Behavior preserved? Tests still meaningful (not just still green)? |
| Dependency bump | Breaking changes read? Lockfile consistent? Supply-chain risk? |
| Config / infra | Reversible? Blast radius? Secrets not committed? |
| Hotfix | Minimal and targeted? Follow-up issue filed for the real fix? |

---

## Review dimensions

Walk these deliberately — do not read top-to-bottom once and approve. Each dimension is a
separate pass or lens.

| Dimension | Ask |
| :-------- | :-- |
| **Correctness** | Does the logic hold for empty / null / max / concurrent / error inputs? Off-by-one? |
| **Design** | Right layer? Single responsibility? Is a new abstraction earning its keep, or speculative? |
| **Security** | Input validation at trust boundaries? Authz checks? Injection, SSRF, path traversal? Secrets? |
| **Error handling** | Failures surfaced or swallowed? Partial writes? Idempotent retries? Resource cleanup? |
| **Performance** | N+1 queries, unbounded loops, sync I/O on a hot path — only where it measurably matters. |
| **Tests** | Do tests fail if the logic breaks? Do they cover the new branches and the reported bug? |
| **Readability** | Names say what they mean? Control flow followable? Comments explain *why*, not *what*? |
| **API / contract** | Backward compatible? Versioned? Docs and types updated with the code? |
| **Observability** | Can you debug this in production — logs, metrics, error context at the right level? |

---

## Severity taxonomy

Label every finding. Severity is what turns a wall of comments into a clear decision.

| Severity | Definition | Merge action |
| :------- | :--------- | :----------- |
| **Critical** | Data loss, security hole, corruption, or a guaranteed production break. | Block. Must fix before merge. |
| **High** | A real bug or a design flaw that will bite soon; wrong behavior on a plausible path. | Request changes. |
| **Medium** | Should fix, but not a blocker: missing test, weak error handling, unclear naming on a public surface. | Request changes or agree a fast follow-up. |
| **Low** | Minor improvement; safe to merge as-is. | Non-blocking comment. |
| **Nit** | Pure preference or cosmetics a formatter/linter should own. | Optional; prefer to automate away. |

Rule of thumb: if you cannot state the concrete failure a comment prevents, it is probably
a Nit — mark it as one so the author can triage honestly.

---

## Comment conventions

Prefix each comment with its intent so the author knows whether to act. This follows
[Conventional Comments](https://conventionalcomments.org/).

| Label | Meaning | Blocking? |
| :---- | :------ | :-------- |
| `issue:` | A problem that should be addressed. | Usually |
| `suggestion:` | A concrete proposed change. | Sometimes |
| `question:` | You need info before you can judge. | Until answered |
| `nitpick:` | Trivial/preference. | No |
| `praise:` | Call out something done well (do this — it is not filler). | No |
| `thought:` | A non-blocking idea for later. | No |
| `chore:` | A required process step (changelog, version bump). | Usually |

Decorate to remove ambiguity: `(blocking)` / `(non-blocking)` / `(if-minor)`.
Good comment shape: **label + specific location + the concrete risk + a suggested fix.**
"This is wrong" is noise; "issue (blocking): `parseAmount` throws on empty string — the
CSV import path (line 88) passes empty cells here; guard or default to 0" is actionable.

---

## Change size

Small changes get real reviews; large ones get skimmed. This is the single biggest lever
on review quality.

| PR size (lines changed) | Reality |
| :---------------------- | :------ |
| < 100 | Reviewable thoroughly in one sitting. Aim here. |
| 100–400 | Fine with a clear description and logical commits. |
| 400–1000 | Split it, or expect the review to miss things. |
| > 1000 | Effectively unreviewable; approvals here are trust, not review. |

Generated code, lockfiles, and vendored files should be flagged as such so reviewers can
skip them without inflating the perceived size.

---

## Responsibilities

**Author (before requesting review)**
- Self-review the diff first; leave inline notes on non-obvious choices.
- Write a description: *what*, *why*, and *how to verify*. Link the issue/ticket.
- Keep it small and single-purpose; separate refactors from behavior changes.
- Make CI green (build, tests, lint) before asking a human.

**Reviewer**
- Understand the intent before critiquing the implementation.
- Distinguish "wrong" from "not how I'd write it." Approve changes that are correct and clear even if not your style.
- Rank findings by severity; do not bury a Critical under ten Nits.
- Be specific and kind; review the code, not the author.
- Approve when it is *good enough to ship and improve later*, not when it is perfect.

---

## Review lifecycle

```
draft → ready-for-review → (changes-requested ⇄ re-review)* → approved → merged
```

- **changes-requested** must name the blocking items explicitly.
- **re-review** should focus on the deltas since the last pass, not re-litigate settled points.
- **approved** with non-blocking comments means "merge when you've considered these."

---

## Automation vs human review

Automate everything a machine judges reliably, so humans spend attention on judgment.

| Concern | Owner |
| :------ | :---- |
| Formatting, import order, whitespace | Formatter (auto) |
| Style rules, obvious bug patterns, unused code | Linter / static analysis (auto) |
| Type errors | Type checker (auto) |
| Known vulnerable dependencies, leaked secrets | Scanner in CI (auto) |
| Test pass/fail, coverage threshold | CI (auto) |
| Correctness of business logic | Human / agent |
| Design and abstraction fit | Human / agent |
| Security design (authz model, trust boundaries) | Human / agent |
| Readability and intent | Human / agent |

If reviewers routinely leave formatting/style Nits, that is a signal to add a linter rule,
not to keep commenting.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Rubber-stamping | Defects merge; review becomes theater. | Actually run the diff through the dimensions, or decline the review. |
| Bikeshedding | Trivial debates stall the change; real issues get lost. | Automate style; cap Nits; focus on impact. |
| Scope creep | "While you're here, also refactor X" bloats and delays. | File a follow-up; keep the PR single-purpose. |
| Ghost review | PR sits for days; author is blocked. | Review small PRs fast; set a team SLA. |
| Symptom-only fixes | The bug's siblings stay broken. | Require the root cause and a regression test. |
| Vanity approval on huge PRs | "LGTM" on 2000 lines is trust, not review. | Split, or state explicitly that it was skimmed. |

---

## Metrics (use with care)

Measure the process, never rank people. Metrics that judge individuals get gamed.

| Metric | Useful for | Failure mode if misused |
| :----- | :--------- | :---------------------- |
| Time-to-first-review | Spotting bottlenecks | Encourages rushed skims |
| PR size distribution | Coaching toward small PRs | — |
| Defect escape rate (bugs found after merge) | System health | Blame instead of process fixes |
| Review iterations per PR | Finding unclear requirements | Punishing thoroughness |

---

## Specialized reviews

- **Security review** — trust boundaries, authz, injection, secrets, cryptography choices. Warrants a dedicated pass for auth, payments, and data-export paths.
- **Performance review** — only when there is a real budget or observed regression; profile before optimizing.
- **Architecture review** — for changes that cross module/service boundaries or introduce a new pattern; see [`../architecture-design/reference/guide.md`](../../architecture-design/reference/guide.md).

---

## References

- Google Engineering Practices — Code Review Developer Guide: <https://google.github.io/eng-practices/review/>
- Conventional Comments: <https://conventionalcomments.org/>
- "The Art of Readable Code" — Boswell & Foucher (naming, control flow, comments)
