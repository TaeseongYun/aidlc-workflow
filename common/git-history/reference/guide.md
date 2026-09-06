# Git History

> Platform-agnostic reference for keeping a clean, useful, recoverable Git history:
> what makes history a debugging tool, how to shape it safely, and where rewriting
> stops being allowed. Companion procedure: [`../SKILLS.md`](../SKILLS.md).

Git history is not a byproduct of committing — it is a queryable record of *why the code
is the way it is*. A good history answers questions the code alone cannot: which change
introduced a bug (`git bisect`), who last touched a line and in what context
(`git blame`), and how to undo exactly one mistake without losing everything after it
(`git revert`). Treat every commit as a future debugging clue and every rewrite as a
question of *who else depends on this*.

---

## Why history quality matters

Each Git tool below is only as good as the history feeding it. A clean history makes them
sharp; a noisy one makes them useless.

| Tool | What it does | What clean history buys you |
| :--- | :----------- | :-------------------------- |
| `git bisect` | Binary-search commits to find the one that broke something. | Each commit builds and passes tests, so a bisect lands on a real cause, not a broken WIP commit. |
| `git blame` | Attribute each line to the commit that last changed it. | Small, single-purpose commits with clear messages explain *why*, not just *when*. |
| `git revert` | Create a new commit that undoes a prior one. | An atomic commit reverts cleanly; a commit mixing five concerns cannot be undone in part. |
| Onboarding | New readers reconstruct intent from the log. | A narrative of logical steps teaches the system; a "misc fixes" dump teaches nothing. |
| `git log -S` / `-G` | Search history for when a string or pattern appeared. | Focused diffs make the introducing change obvious. |

The through-line: **history is a debugging tool.** Optimize commits for the person
bisecting at 3am, not for the moment you type them.

---

## Linear vs merge-commit history

Two shapes of history, two sets of trade-offs. Pick one per repo and enforce it; mixing
them arbitrarily is what produces an unreadable log.

| Aspect | Linear (rebase / squash-merge) | Merge-commit (explicit merges) |
| :----- | :----------------------------- | :----------------------------- |
| Log readability | Straight line, easy to follow. | Braided; needs `--graph` to parse. |
| Bisect | Clean — every commit is a real state. | Works, but merge commits can be awkward to test. |
| Context preserved | Branch topology is lost. | Records exactly what was merged and when. |
| Blame | Direct line to the authoring commit. | Can point at a merge commit. |
| Concurrent work | Rewrites local commits onto latest base. | Keeps parallel lines intact. |
| Revert a feature | Revert individual commits (or the squash). | `git revert -m 1 <merge>` undoes the whole branch at once. |
| Risk | Rebasing shared branches is dangerous (see golden rule). | "Merge bomb" commits with huge unreviewed diffs. |

Common policy: **rebase locally to tidy, merge to integrate** — feature branches are
rebased/squashed while private, then merged (often squash-merged) into the mainline so the
mainline reads as one logical change per feature.

---

## Rebase vs merge

Both combine work from two branches. They differ in whether they rewrite commits.

| | `git merge` | `git rebase` |
| :-- | :---------- | :----------- |
| Result | New merge commit joining both histories. | Your commits replayed on top of the new base. |
| History | Non-linear; preserves topology. | Linear; topology erased. |
| Commit identity | Preserved (same SHAs). | Rewritten (new SHAs). |
| Conflicts | Resolved once, in the merge commit. | Resolved per replayed commit. |
| Safe on shared branch | Yes. | No — rewrites commits others may have. |
| Best for | Integrating a finished branch into main. | Updating a private branch onto latest main; cleaning local commits. |

Rule: **merge to integrate, rebase to update or tidy — and only rebase commits you have
not shared.**

---

## Interactive rebase

`git rebase -i <base>` opens a to-do list of commits you can reorder, squash, edit, drop,
or reword. It is the primary tool for turning a messy local branch into a clean series
before it is shared.

| Command | Effect |
| :------ | :----- |
| `pick` | Keep the commit as-is. |
| `reword` | Keep the change, edit the message. |
| `edit` | Pause at this commit to amend content. |
| `squash` | Merge into the previous commit, combining messages. |
| `fixup` | Like squash, but discard this commit's message. |
| `drop` | Delete the commit entirely. |
| reorder | Move a line to change commit order. |

> **Automation note:** interactive commands (`git rebase -i`, `git add -i`) open an editor
> and are frequently unavailable in automated, headless, or sandboxed environments. Prefer
> non-interactive equivalents there: `git commit --fixup=<sha>` then
> `git rebase --autosquash` (with a pre-set editor of `true`/`GIT_SEQUENCE_EDITOR=:`), or
> stage precisely with `git add -p` / explicit pathspecs instead of `git add -i`. Design
> commit hygiene so it does not *require* an interactive editor.

---

## The golden rule

**Never rewrite history that others depend on.** Rebasing, squashing, amending, or
force-pushing a branch that another person (or CI, or a downstream fork) has already pulled
rewrites commits out from under them — their next pull diverges, and merges duplicate every
"rewritten" commit.

| Branch state | Rewriting allowed? |
| :----------- | :----------------- |
| Local, never pushed | Freely. |
| Pushed to your own feature branch, no one else on it | Yes — with `--force-with-lease`. |
| Shared feature branch (others have pulled) | Only by explicit team agreement. |
| Public / mainline (`main`, release branches) | Never. Use `git revert` to undo. |

---

## Safe force-push

When you *do* legitimately rewrite a private branch, push with a lease, never a bare force.

| Command | Behavior | Use when |
| :------ | :------- | :------- |
| `git push --force` | Overwrites the remote unconditionally, even if someone else pushed. | Almost never — you can destroy others' commits. |
| `git push --force-with-lease` | Overwrites only if the remote is where you last saw it; aborts if someone pushed in between. | Any rewrite of a branch that is safe to rewrite. |
| `git push --force-with-lease=<ref>:<sha>` | Same, pinned to an exact expected SHA. | Scripts/CI where the ref must be exact. |

`--force-with-lease` is the seatbelt: it turns "I clobbered a teammate's push" into a
clean abort. Make it the default; never type bare `--force` on anything shared.

---

## Finding a regression: `git bisect`

Binary search across history to find the commit that introduced a bug — `O(log n)` builds
instead of reading every commit.

| Step | Command |
| :--- | :------ |
| Start | `git bisect start` |
| Mark current as broken | `git bisect bad` |
| Mark a known-good commit | `git bisect good <sha>` |
| Test each checkout, then | `git bisect good` or `git bisect bad` |
| Automate | `git bisect run <test-command>` (exit 0 = good, non-0 = bad) |
| Finish | `git bisect reset` |

`git bisect run` with a script is the payoff of a clean history: if every commit builds
and the test is reliable, Git finds the culprit unattended. Broken intermediate commits
force manual `git bisect skip` and slow everything down — another reason each commit should
be a working state.

---

## Provenance: `git blame`

`git blame <file>` shows, per line, the last commit that changed it — the entry point for
"why is this here?"

| Flag | Purpose |
| :--- | :------ |
| `-L <start>,<end>` | Blame only a line range. |
| `-w` | Ignore whitespace-only changes. |
| `-M` | Detect moved lines within a file. |
| `-C` | Detect lines copied from other files. |
| `-w -M -C` together | See past reformatting and code moves to the real authoring commit. |

Blame points at a commit; the commit's message and diff supply the *why*. This is the
second half of the argument for good messages and small commits — blame is only as
informative as the commit it lands on.

---

## Undoing: revert vs reset

Two ways to undo — one forward-moving and safe for shared history, one that rewrites.

| Command | Effect on history | Effect on working tree | Safe on shared branch? |
| :------ | :---------------- | :--------------------- | :--------------------- |
| `git revert <sha>` | Adds a *new* commit that undoes the change. | Applies the inverse diff. | Yes — history only grows. |
| `git reset --soft <sha>` | Moves HEAD back; commits after become uncommitted. | Untouched; changes kept staged. | No — rewrites. |
| `git reset --mixed <sha>` (default) | Moves HEAD back. | Changes kept, unstaged. | No — rewrites. |
| `git reset --hard <sha>` | Moves HEAD back. | **Discards** all changes after `<sha>`. | No — rewrites; destructive. |

Rule: **revert to undo public history; reset only on local, unshared commits.**
`reset --hard` throws work away — confirm the target and remember the reflog exists (below)
before running it.

---

## Cherry-pick and its risks

`git cherry-pick <sha>` copies one commit's change onto the current branch — useful for
backporting a fix to a release branch without merging the whole feature.

| Risk | Why | Mitigation |
| :--- | :-- | :--------- |
| Duplicate commits | The cherry-picked change and its original both exist; a later merge can double-apply or conflict. | Prefer merging where topology allows; `-x` records the source SHA in the message. |
| Missing dependencies | The commit relies on earlier changes not picked. | Pick the whole dependent range, or verify the target builds. |
| Divergent evolution | Two lineages of the "same" fix drift apart. | Track that the fix lives in both places; reconcile deliberately. |

Cherry-pick is a targeted copy, not integration — reach for it only when a merge is not the
right shape.

---

## The safety net: `git reflog`

`git reflog` records where HEAD (and each branch) has pointed, including states no longer
reachable from any branch — the recovery path after a bad reset, rebase, or amend.

| Situation | Recovery |
| :-------- | :------- |
| `reset --hard` threw away commits | `git reflog`, find the pre-reset SHA, `git reset --hard <sha>` or `git branch rescue <sha>`. |
| Rebase went wrong | `git reflog`, find the `rebase (start)` entry, reset to the commit before it. |
| Deleted a branch | Find its tip in the reflog and recreate it. |
| Amended and lost the original | The pre-amend commit is in the reflog until it expires. |

Reflog entries are local and expire (default ~90 days for reachable, 30 for unreachable).
It is the reason most "I lost my work" situations are recoverable — but it is not a backup;
it does not survive a fresh clone. Knowing it exists is what makes rewriting commits a
reversible operation instead of a gamble.

---

## Tags and annotated tags

Tags mark specific commits — typically releases — with a stable, human-readable name.

| Type | Command | Contains | Use for |
| :--- | :------ | :------- | :------ |
| Lightweight | `git tag v1.2.0` | Just a pointer to a commit. | Private/temporary bookmarks. |
| Annotated | `git tag -a v1.2.0 -m "..."` | Tagger, date, message; a full object. | Releases — carries provenance and can be signed. |
| Signed | `git tag -s v1.2.0 -m "..."` | Annotated + GPG signature. | Releases where authenticity must be verifiable. |

Prefer **annotated tags for anything you publish**: they record who tagged what and when,
survive as first-class objects, and can be verified. Push tags explicitly (`git push
--tags` or `git push origin <tag>`) — they do not travel with a normal push.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Rewriting public history | Everyone's clone diverges; merges duplicate commits. | `git revert` to undo published changes. |
| Bare `--force` on a shared branch | Silently overwrites teammates' pushes. | `--force-with-lease`, and only on branches safe to rewrite. |
| Giant merge bombs | A single merge commit hides thousands of unreviewed lines. | Small, reviewed branches; integrate frequently. |
| Meaningless merge commits | "Merge branch 'main' into main" noise buries real merges. | Rebase-update private branches; reserve merges for real integration. |
| Broken intermediate commits | `git bisect` lands on a commit that won't build. | Keep each commit a working, tested state. |
| `reset --hard` without checking | Discards uncommitted and committed work irretrievably by name. | Verify the target; know the reflog; prefer `revert`. |
| "misc fixes" / "wip" commit messages | `blame` and onboarding learn nothing. | One concern per commit; explain the *why*. |

---

## References

- Pro Git — Ch. 7.6, *Rewriting History* (amend, interactive rebase, filter-branch): <https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History>
- Pro Git — Ch. 7.10, *Debugging with Git* (`git blame`, `git bisect`): <https://git-scm.com/book/en/v2/Git-Tools-Debugging-with-Git>
- Git SCM Reference — `git-rebase`, `git-bisect`, `git-revert`, `git-reflog`, `git-cherry-pick`, `git-tag`: <https://git-scm.com/docs>
- Pro Git — Ch. 3.6, *Rebasing* (merge vs rebase, the golden rule): <https://git-scm.com/book/en/v2/Git-Branching-Rebasing>
