# Commit Review

> Platform-agnostic reference for reviewing individual commits and their messages: what
> makes a commit good, how to judge granularity, how to read a message, and how to clean
> up history before it merges. Companion procedure: [`../SKILLS.md`](../SKILLS.md).

Commit review examines the *units of change* — each commit and its message — rather than
the change as a whole. Whole-PR correctness lives in [`../../code-review/reference/guide.md`](../../code-review/reference/guide.md);
this guide is about how the change is *sliced and recorded*. A clean history is not
cosmetics: it is what makes `git bisect`, `git revert`, `git blame`, and cherry-pick work.
A commit is a permanent record — the diff shows *what* changed; the message must say *why*.

---

## What makes a good commit

| Property | Meaning | Why it matters |
| :------- | :------ | :------------- |
| **Atomic** | One logical change, nothing more. | Reverts and cherry-picks cleanly; easy to reason about. |
| **Single-purpose** | Does not mix a refactor with a behavior change, or two features. | Reviewer can hold the whole intent in their head. |
| **Self-contained** | Builds and passes tests *at that commit* — not just at the branch tip. | `git bisect` stays usable; every point in history is a valid checkpoint. |
| **Reversible** | Can be reverted without dragging in unrelated work. | Fast rollback when it turns out to be wrong. |
| **Explained** | Message states the intent the diff cannot show. | The reader six months out understands *why*. |

The test for atomicity: can you write the subject line without the word "and"? If the
natural summary is "add X **and** fix Y", it is two commits.

---

## Reviewing granularity

Judge the *slicing* of the branch, not just each diff in isolation.

| Signal | Verdict |
| :----- | :------ |
| One commit touches an unrelated concern (feature + drive-by rename) | Split it. |
| A "fix typo" / "address review" commit patches a commit earlier in the *same* branch | Squash it into the commit it fixes (fixup). |
| A commit does not build or its tests fail on their own | Reorder/squash so every commit is green. |
| A 2000-line commit labeled "implement feature" | Too coarse; split into reviewable steps. |
| Refactor and behavior change interleaved in one commit | Separate: refactor first (no behavior change), then the behavior change. |
| Each commit is a coherent, buildable step toward the goal | Good — approve the slicing. |

Aim for commits a reviewer can read in order and understand as a narrative. Noise commits
(`wip`, `oops`, `fix fix`) are branch scratch — they must not reach the default branch.

---

## Commit message anatomy

```
<type>: <subject line, imperative, ≤50 chars>
<blank line>
<body: wrap at ~72 cols. Explain WHY and the context,
not what the diff already shows. Note trade-offs,
alternatives rejected, and consequences.>
<blank line>
<trailers: Co-authored-by / Signed-off-by / issue refs>
```

| Part | Rule | Rationale |
| :--- | :--- | :-------- |
| **Subject** | Imperative mood ("Add", not "Added"/"Adds"), ≤50 chars, no trailing period, capitalized. | Completes "If applied, this commit will …". Fits `git log --oneline` and tooling. |
| **Blank line** | Exactly one, between subject and body. | Git treats the first paragraph as the summary; tools break without it. |
| **Body** | Wrap ~72 cols. Explain *why*, the problem, and the approach. Optional if the subject fully suffices (trivial change). | Terminals and `git log` do not soft-wrap; the *why* is what the diff cannot carry. |
| **Trailers** | `Key: value` lines in a final block. | Machine-parseable attribution and links. |

Imperative-mood check: the subject should read as a command, matching Git's own generated
messages ("Merge branch…", "Revert…"). "Fixed the bug" describes the past; "Fix the bug"
describes what applying the commit does.

---

## Conventional Commits types

A common convention that prefixes the subject with a type, enabling automated changelogs
and semantic-version bumps. `feat`/`fix` map to minor/patch; a `!` or `BREAKING CHANGE:`
footer signals major.

| Type | Use for | Version impact |
| :--- | :------ | :------------- |
| `feat` | A new user-facing feature. | MINOR |
| `fix` | A bug fix. | PATCH |
| `docs` | Documentation only. | none |
| `refactor` | Code change that neither fixes a bug nor adds a feature. | none |
| `test` | Adding or correcting tests. | none |
| `chore` | Maintenance, tooling, deps — no src behavior change. | none |
| `perf` | A change that improves performance. | PATCH |
| `build` | Build system or external dependency changes. | none |
| `ci` | CI configuration and scripts. | none |

Format: `type(optional-scope)!: subject`. The scope names the affected area
(`fix(auth): …`); the `!` marks a breaking change. Review that the type *matches the
diff* — a `fix:` that adds a feature, or a `feat:` that is pure refactor, misleads the
changelog and the version bump.

---

## Trailers

Trailers are `Key: value` lines in a final block, separated from the body by a blank line.
Parseable by `git interpret-trailers`.

| Trailer | Purpose | Notes |
| :------ | :------ | :---- |
| `Co-authored-by: Name <email>` | Credit a second author (pairing, agent). | Rendered as co-author by most forges. |
| `Signed-off-by: Name <email>` | Developer Certificate of Origin attestation. | Added by `git commit -s`; required by some projects (e.g. Linux). |
| `Fixes #123` / `Closes #123` | Link and auto-close an issue on merge. | Forge-specific keywords; verify the issue is the right one. |
| `Refs #123` | Reference without closing. | Use when the commit is partial. |
| `Reviewed-by:` / `Tested-by:` | Attribution of review/test work. | Common in kernel-style workflows. |

Review that trailers are real: a `Fixes #123` that does not actually resolve #123 leaves a
stale auto-close; a missing `Signed-off-by` blocks merge on DCO-gated repos.

---

## Cleaning up history before merge

Feature-branch history is a draft; the merged history is the published record. Rewrite the
*local, unpushed, unshared* branch before merge — never rewrite shared history.

| Tool | Use for |
| :--- | :------ |
| `git commit --fixup=<sha>` + `git rebase -i --autosquash` | Fold review-fix commits into the commit they correct, automatically. |
| `git rebase -i` (squash/reword/reorder/drop) | Collapse noise, fix messages, order commits into a clean narrative. |
| `git rebase --onto` | Move a branch to a new base without merge commits. |
| `git add -p` | Split a working change into atomic commits at hunk level. |

Golden rule of rebasing: **do not rewrite history that others may have pulled.** Rewriting
a shared branch forces every collaborator into a painful reconciliation. Clean up before
you push, or on branches you alone own.

---

## Signed commits

Cryptographic signatures prove *who* authored a commit; they are distinct from
`Signed-off-by` (which is a text attestation, not cryptographic).

| Aspect | Detail |
| :----- | :----- |
| Mechanism | `git commit -S` signs with GPG, SSH, or S/MIME keys. |
| Verification | `git log --show-signature`; forges display a "Verified" badge. |
| Why | Prevents author spoofing; some repos require signatures on protected branches. |
| Review | Confirm the signature is present *and valid* where policy requires it, not merely claimed. |

An unverified or absent signature on a branch that mandates them is a merge blocker, not a
nit.

---

## What must never enter a commit

Some content is expensive-to-impossible to remove once pushed — Git history is permanent,
so a leaked secret is compromised even after a later "removal" commit.

| Content | Risk | Action on finding it |
| :------ | :--- | :------------------- |
| Secrets (keys, tokens, passwords, `.env`) | Permanent leak; must rotate the credential, not just delete the line. | Block. Rotate the secret; scrub history (`filter-repo`) if pushed. |
| Large binaries / build artifacts | Bloats the repo permanently; every clone pays. | Block. Use LFS, an artifact store, or `.gitignore`. |
| Generated / vendored files that should be ignored | Noise; merge conflicts; hides real changes. | Add to `.gitignore`; regenerate in CI instead. |
| Commented-out dead code | History already preserves it; clutters the diff. | Delete it; Git remembers. |
| Unrelated formatting churn | Buries the real change; pollutes `blame`. | Split into its own `chore`/`style` commit. |

A secret scanner in CI should catch most of these automatically (see the automation table
in the code-review guide) — but a reviewer still confirms nothing sensitive slipped into
the diff.

---

## Commit review vs code review

| | Commit review | Code review |
| :-- | :------------ | :---------- |
| **Unit** | Each commit + its message. | The whole change (diff of the branch). |
| **Primary question** | Is history clean, atomic, and well-explained? | Is the code correct, safe, maintainable? |
| **Catches** | Mega-commits, WIP noise, bad messages, secrets, wrong Conventional-Commits type. | Logic bugs, design flaws, security holes, missing tests. |
| **Fix mechanism** | `rebase -i`, squash, fixup, reword. | Edit the code; add tests. |
| **When** | Before merge, once the diff is agreed. | Throughout, as the change evolves. |
| **Overlap** | Both flag secrets and generated files. | Both flag secrets and generated files. |

They are complementary passes. A branch can pass code review (the code is correct) and
still fail commit review (it is one 2000-line commit titled "stuff") — and vice versa.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| WIP / `wip` / `oops` commits merged to main | Break `bisect`; pollute history; some don't build. | Squash them away before merge. |
| "fix" chains (`fix`, `fix fix`, `fix the fix`) | Each patches the last; history is noise, not narrative. | `--fixup` + autosquash into the original commit. |
| Mega-commit ("implement everything") | Unreviewable; un-revertable; hides the real changes. | Split into atomic, buildable steps. |
| Message restates the diff ("change x to y") | Adds nothing; the diff already shows *what*. | Explain *why* the change was needed. |
| Empty or generic body ("updates", "misc") | Loses the intent forever. | State the problem and the reasoning, or omit the body if the subject truly suffices. |
| Past-tense / non-imperative subject | Inconsistent with Git's own messages and tooling. | Imperative mood: "Add", "Fix", "Remove". |
| Commit doesn't build on its own | `bisect` lands on a broken commit; blame misleads. | Reorder/squash so every commit is green. |

---

## References

- Conventional Commits specification: <https://www.conventionalcommits.org/>
- Pro Git — "Distributed Git · Contributing to a Project" (commit guidelines): <https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project>
- Pro Git — "Git Tools · Rewriting History" (rebase, squash, fixup): <https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History>
- Tim Pope — "A Note About Git Commit Messages": <https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html>
