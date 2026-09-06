# Commit Workflow

> Platform-agnostic reference for authoring commits: how to decide commit
> boundaries, stage selectively, write messages, and curate history before it is
> shared. Companion procedure: [`../SKILLS.md`](../SKILLS.md).
> Reviewing commits (not authoring them) lives in [`../../commit-review/reference/guide.md`](../../commit-review/reference/guide.md).

A commit is the smallest unit of recorded change. The authoring practice is to
shape ongoing work into a sequence of commits that each make sense on their own —
so history reads as a series of deliberate steps, not a dump of whatever the
working tree happened to hold. The goal is a history that is *bisectable*,
*revertable*, and *readable*, one commit at a time.

---

## The atomic commit principle

One commit does one thing. "One thing" means a single logical change that is
complete on its own: it builds, it passes tests, and reverting it removes that
change and nothing else.

| A commit is atomic when… | It is not atomic when… |
| :----------------------- | :--------------------- |
| It has one purpose stateable in one sentence. | The subject needs "and" to describe it. |
| It builds and tests pass at that commit. | It leaves the tree broken "until the next commit." |
| Reverting it removes exactly one change. | Reverting it also rips out an unrelated fix. |
| A reviewer can read it in isolation. | You must read three commits to understand one. |

Atomic does not mean *tiny*. A coherent feature slice touching ten files is one
atomic commit; two unrelated typo fixes in one file are two.

---

## Deciding commit boundaries

Draw the boundary where a reviewer's mental context resets. Split when the *kind*
of change changes.

| Case | Do | Why |
| :--- | :- | :-- |
| Refactor + behavior change together | Split | Reviewer can't tell which lines changed behavior. |
| Two independent bug fixes | Split | Each should revert alone. |
| Formatting/rename mixed with logic | Split | Whitespace noise hides the real diff. |
| "And also" in the message | Split | Two purposes → two commits. |
| Unrelated file touched by accident | Drop | It belongs in another commit, or nowhere. |
| Code + its test | Keep | The test proves the code; splitting leaves a commit untested. |
| Signature change + its updated callers | Keep | Splitting breaks the build mid-history. |
| Feature + its doc/type update | Keep | Contract and docs drift if separated. |

---

## Selective staging

The working tree is not the commit. Stage deliberately so each commit contains
only what belongs to it — even when unrelated edits share a file.

| Technique | Use it to |
| :-------- | :-------- |
| Stage whole files | The file changed for one reason only. |
| Stage hunks (interactive/patch add) | A file holds two unrelated changes; take one hunk now, the rest later. |
| Stage single lines | A hunk mixes concerns and can't be split by hunk. |
| Review the staged diff before committing | Catch stray debug lines, secrets, unrelated edits. |

Rule: commit the *staged* diff, and read it first. `git diff --staged` (or the
patch-add preview) is the last gate before a change becomes permanent history.

---

## Commit message format

The message is documentation the next reader hits before the code. Explain *why*,
not *what* — the diff already shows what.

| Part | Rule |
| :--- | :--- |
| **Subject** | Imperative mood ("Add", not "Added"/"Adds"). ≤ 50 chars. No trailing period. Capitalized. |
| **Blank line** | Always separate subject from body. |
| **Body** | Wrap at ~72 chars. Explain *why* and the trade-offs, not the mechanics. Optional for trivial changes. |
| **Trailers** | Machine-readable footers: `Co-authored-by:`, `Signed-off-by:`, `Refs: #123`, `BREAKING CHANGE: …`. |

Imperative test: the subject should complete "If applied, this commit will
___." — "Fix the null deref", not "Fixed the null deref".

Why-not-what, concretely:

| Weak (what) | Strong (why) |
| :---------- | :----------- |
| `Change timeout to 30s` | `Raise timeout to 30s; upstream p99 is 22s and we were dropping valid slow responses` |
| `Update regex` | `Widen email regex to accept +tagged addresses reported in #412` |

---

## Conventional Commits

An optional convention that makes the *type* of change machine-readable — driving
changelogs and semantic version bumps. Format: `type(scope): subject`.

| Type | Meaning | Version impact |
| :--- | :------ | :------------- |
| `feat` | A new feature | MINOR |
| `fix` | A bug fix | PATCH |
| `refactor` | Behavior-preserving restructure | none |
| `perf` | Performance improvement | PATCH |
| `docs` | Documentation only | none |
| `test` | Tests only | none |
| `build` / `ci` | Build system or CI config | none |
| `chore` | Maintenance, no src/test change | none |
| `revert` | Reverts a previous commit | context |

A `!` after the type/scope (`feat(api)!:`) or a `BREAKING CHANGE:` trailer marks
a MAJOR bump. Scope is an optional noun naming the affected area: `fix(auth):`.

---

## Amend vs new commit

| Situation | Action |
| :-------- | :----- |
| Fix a typo/mistake in the commit you *just* made, not yet pushed | Amend. |
| Add a forgotten file to the last (unpushed) commit | Stage it, amend. |
| Reword the last (unpushed) message | Amend. |
| The change is a distinct logical step | New commit. |
| The commit is already pushed to a *shared* branch | New commit (amending rewrites shared history — see below). |

Amend rewrites the last commit's hash. Safe on local/unshared work; disruptive
once others have pulled it.

---

## Curating before you push

Local history can be messy; *shared* history should be clean. Curate the branch
before it merges.

| Tool | Use for |
| :--- | :------ |
| Squash | Collapse "wip", "fix typo", "address review" noise into the real commit. |
| Fixup + autosquash | Mark a commit as a fixup of an earlier one; combine automatically on rebase. |
| Reword | Improve a message written in haste. |
| Reorder | Group related commits; put refactors before the feature that uses them. |
| Drop | Remove a commit that shouldn't ship (debug spike, reverted experiment). |

Interactive rebase is the tool for all of these. Do it *before* the branch is
shared, or only on a branch you own; never rewrite a commit others have built on.

---

## Refactor vs behavior change

Keep these in separate commits — the single highest-value split.

| Commit | Contains | Diff should show |
| :----- | :------- | :--------------- |
| Refactor | Renames, extractions, moves — no behavior change | Structure moving; tests unchanged and still green |
| Behavior change | New/changed logic | Only the lines that actually change what the program does |

Why: a reviewer shouldn't wade through 200 renamed lines to find the 3 that changed
behavior — and when a bug appears, bisect lands on the behavior commit, not a rename.

---

## Pre-commit hooks

Hooks run checks at commit time. They catch problems before they enter history —
at the cost of commit latency.

| Hook check | Catches | Trade-off |
| :--------- | :------ | :-------- |
| Format | Style drift | Fast; auto-fixable; near-zero downside. |
| Lint | Bug patterns, unused code | Fast; occasional false positives. |
| Secret scan | Committed credentials/keys | High value; a leaked secret is a real incident. |
| Type check | Type errors | Slower; big correctness win on typed stacks. |
| Unit tests | Regressions | Can be slow — keep the hook to fast tests; leave the full suite to CI. |

Guidance: keep hooks fast enough that they don't tempt a `--no-verify` bypass.
Push slow, comprehensive checks (full test matrix, integration) to CI. A hook the
team routinely skips is worse than no hook.

---

## Commit cadence

| Practice | Rationale |
| :------- | :-------- |
| Commit early and often *locally* | Small steps = safe checkpoints you can return to. |
| Curate *before* pushing | The team sees clean, atomic commits, not your keystroke log. |
| Never leave the branch on a broken state before a break | You'll forget the context; `git stash` or a WIP commit you'll squash. |
| Push logical, complete units | A pushed commit is a promise it builds. |

Local commits are cheap and private — use them liberally as save points; only the
curated version crosses into shared history.

---

## Never commit

| Never commit | Why | Instead |
| :----------- | :-- | :------ |
| Secrets (keys, tokens, passwords) | Permanent in history even after deletion; must be *rotated*. | Env vars, secret manager, ignore rules + a scanner. |
| Large binaries / build outputs | Bloat every clone forever; diffs are useless. | Ignore them; use artifact storage or LFS. |
| Generated artifacts (compiled code, lockfile churn you didn't cause) | Merge conflicts, noise, review overhead. | Generate in CI; ignore in the repo. |
| Local/editor config, `.env` files | Machine-specific; may leak paths or secrets. | Personal global ignore; commit a `.env.example`. |
| Commented-out code | History already remembers it. | Delete it; it's in the reflog/log if needed. |

If a secret is committed, deleting the file is not enough — it lives in history.
Rotate the credential and scrub history (filter/BFG) if it was pushed.

---

## Recovery

Git rarely loses committed work; the reflog is the safety net.

| You did… | Recover by |
| :------- | :--------- |
| Bad reset / rebase | `git reflog` → find the pre-op ref → reset back to it. |
| Amended and lost the old commit | reflog shows the pre-amend hash. |
| Deleted a branch with unmerged commits | reflog / `fsck --lost-found`. |
| Dropped a commit in interactive rebase | reflog holds it until gc (default ~90 days). |

Anything *committed* is recoverable from the reflog for weeks; anything only in the
working tree and never staged is not — another reason to commit often.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Giant end-of-day commit | Unreviewable; unbisectable; mixes a dozen concerns. | Commit as you finish each logical step. |
| Mixing concerns in one commit | Can't revert one without the other; review is muddled. | One purpose per commit; split by staging. |
| Committing broken states on a shared branch | Breaks bisect and everyone who pulls. | Keep shared history green; break only on local WIP. |
| Vague messages (`fix`, `wip`, `stuff`) | Future readers get nothing; changelog is noise. | Imperative subject + why in the body. |
| `--amend`/rebase on pushed shared commits | Rewrites history others built on; forces confusing recovery. | New commit, or coordinate explicitly. |
| Committing to silence a hook (`--no-verify`) as habit | The checks exist for a reason; you're merging what they'd block. | Fix the finding, or fix the hook if it's wrong. |

---

## References

- Conventional Commits: <https://www.conventionalcommits.org/>
- Pro Git — Recording Changes / Commit Guidelines: <https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository>
- Pro Git — Rewriting History (amend, rebase, reflog): <https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History>
- "How to Write a Git Commit Message" — Beams: <https://cbea.ms/git-commit/>
