# Branch Cleanup

> Platform-agnostic reference for keeping the branch list and worktrees tidy and safe:
> why stale branches accumulate, how to detect them, how to decide what is safe to delete,
> and how to recover when you delete the wrong thing.
> Companion procedure: [`../SKILLS.md`](../SKILLS.md).

Branch cleanup is the practice of removing branches and worktrees that no longer serve a
purpose, without destroying work that has not yet landed. It is *hygiene*, not a race to an
empty branch list: the goal is a repository where every remaining ref means something and
no unmerged commit is lost. The governing rule is simple — **never destroy unmerged work
without verification, and always leave a path back** (the reflog).

---

## Why stale branches accumulate

Branches are cheap to create and easy to forget. Nothing forces their deletion, so they
pile up unless a person or a bot removes them.

| Source | How it goes stale |
| :----- | :---------------- |
| Merged feature branches | Work landed; the branch was never deleted after merge. |
| Abandoned experiments | A spike that went nowhere; no one decided to keep or drop it. |
| Squash/rebase merges | The branch's commits were rewritten into `main`, so it never shows as "merged". |
| Long-lived personal branches | `wip/*`, `tmp/*`, `<name>/scratch` that outlived their reason. |
| Deleted remote branches | Remote-tracking refs (`origin/foo`) linger locally after the remote branch is gone. |

## Why stale branches are a problem

| Cost | What it looks like |
| :--- | :----------------- |
| Confusion | Which branch is current? Autocomplete and PR pickers fill with dead names. |
| Stale CI | Bots keep building/scanning dead branches; wasted minutes, noisy status. |
| Clutter | `git branch -a` scrolls for pages; the signal-to-noise ratio collapses. |
| False history | An old branch looks like active work; someone bases a change on it. |
| Merge ambiguity | Two branches with similar names; the wrong one gets merged or cherry-picked. |

---

## Detecting stale and merged branches

Stale is a judgment from several signals — never a single one. Combine merge status, age,
and upstream state before acting.

| Signal | How to read it | Command (illustrative) |
| :----- | :------------- | :--------------------- |
| Merged into main | Every commit is reachable from the integration branch → landed. | `git branch --merged main` |
| Not merged | Has commits not in main → may hold real work. | `git branch --no-merged main` |
| Squash/rebase-merged | Shows as *not* merged even though the work landed. Verify by content, not by `--merged`. | compare diff / `git cherry` |
| Last-commit age | Old + merged = prime cleanup target; old + unmerged = investigate. | `git for-each-ref --sort=committerdate --format='%(committerdate:short) %(refname:short)'` |
| Gone upstream | Remote branch deleted; local tracks a ref that no longer exists. | `git branch -vv` shows `[origin/x: gone]` |
| Open PR/MR | A branch with an open review is **not** stale, regardless of age. | platform PR list |

**Merged ≠ safe by name alone.** `--merged` answers "are these commits reachable from
main"; it does **not** account for squash or rebase merges, where the commits were rewritten
and the original branch reads as unmerged. Confirm landed-ness by comparing content (does
main already contain this change?) before trusting age alone.

---

## The safe-delete decision

Classify every branch before deleting. The class, not the impulse to tidy, dictates the action.

| Class | Definition | Action |
| :---- | :--------- | :----- |
| **Merged** | All commits reachable from the integration branch. | Safe to delete (`-d`). |
| **Squash/rebase-merged** | Work landed but shows as unmerged; content is in main. | Verify content is in main, then delete. |
| **Unmerged** | Commits not in main and not confirmed landed. | **Verify first** — inspect commits, ask the author. Never bulk-force. |
| **Protected** | `main`, `master`, `develop`, release branches, anything under branch protection. | **Never delete.** |
| **Active PR** | Open review or in-flight CI. | Leave until merged or explicitly closed. |
| **Shared** | Others have it checked out or based work on it. | Coordinate; do not delete unilaterally. |

Force-delete (`-D`) discards unmerged commits without asking. Reserve it for branches you
have *verified* are disposable — never as the default for "make the warning go away".

---

## Deleting branches: local vs remote

Local and remote branches are separate objects. Deleting one does not delete the other, and
a third artifact — the remote-tracking ref — must be pruned separately.

| Target | Command (illustrative) | Notes |
| :----- | :--------------------- | :---- |
| Local, merged | `git branch -d <name>` | Refuses if unmerged — this refusal is a safety feature, not an obstacle. |
| Local, unmerged | `git branch -D <name>` | Force. Only after verification; discards commits. |
| Remote | `git push <remote> --delete <name>` | Deletes the branch on the server for everyone. |
| Remote-tracking ref | `git remote prune <remote>` or `git fetch --prune` | Removes stale `origin/*` that point at deleted remote branches; deletes nothing on the server. |

**Prune is not delete.** `git remote prune` / `git fetch --prune` only clean your local view
of the remote (the `origin/*` refs). They never touch real branches on the server or your
local branches. Run `--prune` routinely; it is always safe. Set `fetch.prune = true` to make
every `git fetch` prune automatically.

Order for a fully-landed branch: delete remote (`push --delete`), delete local (`branch -d`),
prune tracking refs (`fetch --prune`). Deleting the remote first means the local delete and
the prune both agree the branch is gone.

---

## Worktree cleanup

A worktree is a second working directory attached to the same repository. Removing the
directory by hand leaves a dangling administrative entry; use the porcelain, then prune.

| Task | Command (illustrative) | Notes |
| :--- | :--------------------- | :---- |
| List worktrees | `git worktree list` | Shows path, HEAD, and branch per worktree. |
| Remove a worktree | `git worktree remove <path>` | Refuses if it has uncommitted changes — verify, then `--force` only if intended. |
| Prune stale entries | `git worktree prune -v` | Clears admin records for worktrees whose directory was deleted manually. |
| Lock a worktree | `git worktree lock <path>` | Prevents pruning of a worktree on removable/network media. |

A worktree's branch cannot be deleted while it is checked out somewhere. Remove or switch
the worktree first, then delete the branch. In this repo, `scripts/worktree_alloc.py prune`
wraps `git worktree prune -v`; see [`/ctx-worktree`](../SKILLS.md).

---

## Automation

Automate the safe, boring deletions so humans only handle the judgment calls. Prefer the
simplest automation that is safe over a clever one that can delete unmerged work.

| Automation | What it does | Safety note |
| :--------- | :----------- | :---------- |
| Auto-delete on merge | Platform deletes the source branch when a PR/MR merges. | Only fires on *merge*, so the work is landed by definition. Enable it. |
| Scheduled prune | CI runs `git fetch --prune` on a schedule. | Touches only tracking refs; always safe. |
| Stale-branch bot | Flags branches with no commits in N days. | Should **notify/label**, not auto-delete unmerged branches. |
| Protected-branch rules | Server refuses deletion of `main`/release branches. | Backstop against both humans and bots. |

The default posture: automate deletion of *merged* branches freely; automate only
*notification* for unmerged ones. A bot that force-deletes stale-but-unmerged branches will
eventually delete someone's unpushed-elsewhere work.

---

## Safety and recovery

Deletion in Git is rarely permanent — the commits survive in the reflog and as dangling
objects until garbage collection. Knowing the recovery path is what makes cleanup safe to do.

| Situation | Recovery |
| :-------- | :------- |
| Deleted a local branch, need it back | Find its tip in `git reflog`, then `git branch <name> <sha>`. |
| Don't know the old SHA | `git reflog` (and `git fsck --lost-found` for dangling commits). |
| Force-deleted unmerged work | Same reflog recovery *until* GC runs — act promptly. |
| Deleted the remote branch | Re-push from any local/worktree copy: `git push <remote> <name>`. |
| GC already ran | The commits may be gone; recovery from another clone or a teammate's copy only. |

`git reflog` records where HEAD and branches pointed for a retention window (default ~90
days for reachable, ~30 for unreachable). This window is the reason force-delete is
recoverable — but it is a window, not forever. **Verify before force-deleting; do not rely on
the reflog as a substitute for checking.**

---

## Naming conventions that signal lifecycle

Names that encode intent make cleanup a mechanical, low-risk sort instead of an
investigation. Align these with the branch strategy: [`../branch-strategy/reference/guide.md`](../../branch-strategy/reference/guide.md).

| Prefix | Signals | Cleanup implication |
| :----- | :------ | :------------------ |
| `feature/*`, `feat/*` | Delivers a feature; short-lived. | Delete on merge. |
| `fix/*`, `hotfix/*` | Targeted fix; short-lived. | Delete on merge. |
| `wip/*`, `tmp/*`, `scratch/*` | Explicitly disposable. | Aggressive stale threshold; safe to notify-and-drop. |
| `release/*` | Long-lived; may be protected. | Never auto-delete; follow the release policy. |
| `<name>/*` | Personal namespace. | Owner cleans up; a bot only nudges. |

Ticket IDs in the name (`feat/PROJ-123-...`) let a bot cross-check against a closed issue
before flagging — a closed ticket plus a merged branch is an unambiguous delete.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Bulk-deleting without checking merged status | Discards unmerged work silently. | Filter by `--merged` first; verify squash-merges by content. |
| Deleting shared branches | Breaks teammates' checkouts and based work. | Coordinate; delete only branches you own or that are confirmed landed. |
| Force-pruning others' work | `-D` on someone's unpushed-elsewhere branch = data loss. | Never `-D` a branch you did not verify; let owners clean their namespace. |
| Trusting `--merged` for squash-merges | Reads as unmerged; you keep dead branches or force-delete real ones. | Confirm content is in main before classing as merged. |
| Deleting the remote branch of an open PR | Closes/breaks the review unexpectedly. | Wait for merge or an explicit close. |
| Treating prune as delete | Fear of `--prune` leaves tracking refs to rot. | Prune routinely; it only cleans local views, never real branches. |
| Manual `rm -rf` of a worktree | Leaves a dangling admin entry and a locked branch. | `git worktree remove`, then `git worktree prune`. |

---

## References

- Git SCM — Branch management (`git-branch`): <https://git-scm.com/docs/git-branch>
- Git SCM — `git-fetch` (`--prune`) and `git-remote` (`prune`): <https://git-scm.com/docs/git-fetch>
- Git SCM — Working trees (`git-worktree`): <https://git-scm.com/docs/git-worktree>
- Git SCM — `git-reflog` (recovering deleted branches): <https://git-scm.com/docs/git-reflog>
- GitHub — Managing the automatic deletion of branches: <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches>
- GitLab — Delete source branch on merge / branch settings: <https://docs.gitlab.com/ee/user/project/merge_requests/>
