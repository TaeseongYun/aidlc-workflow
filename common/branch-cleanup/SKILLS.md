# Branch Cleanup — Skills

Actionable procedure an agent (or engineer) runs to prune stale branches and worktrees
without losing unmerged work. This is the *how*; the *what/why* reference is
[`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: [`/ctx-worktree`](../../skills/ctx-worktree/SKILL.md) (worktree
  prune/cleanup — `scripts/worktree_alloc.py prune` wraps `git worktree prune -v`).
- **Cross-link siblings**: [`../branch-strategy/reference/guide.md`](../branch-strategy/reference/guide.md)
  (naming/lifecycle), [`../git-history/reference/guide.md`](../git-history/reference/guide.md)
  (reflog recovery).
- **Platform-agnostic**: applies on any Git host. Platform-specific rules live under `platforms/<platform>/`.

## When to use

Periodic hygiene, after a batch of PRs merges, when `git branch -a` has become unreadable,
or when a stale-branch bot flags candidates. Not during active work on the branch in question.

## Inputs

- The repository and its integration branch (`main`/`master`/`develop`).
- Optional: a candidate list (from a bot, a ticket, or the user).

## Outputs

- Deleted local/remote branches and pruned tracking refs — **merged/verified only**.
- Removed/pruned worktrees.
- A short report: what was deleted, what was skipped and why, what needs owner sign-off.

## Procedure

1. **Sync first.** `git fetch --prune` — get current remote state and drop tracking refs for
   already-deleted remote branches before you judge anything.
2. **Classify every candidate.** For each branch determine: merged / squash-merged /
   unmerged / protected / active-PR / shared (see the guide's decision table). Use
   `git branch --merged main` and `git branch -vv`; **verify squash/rebase merges by content**,
   not by `--merged` alone.
3. **Delete the safe class.** Merged and content-verified branches: `git branch -d <name>`
   locally; `git push <remote> --delete <name>` for the remote copy.
4. **Hold the unsure class.** Unmerged, shared, active-PR, or protected → do **not** delete.
   Surface them for the owner/user; never `-D` to silence a warning.
5. **Clean worktrees.** `git worktree list`; `git worktree remove <path>` (refuses on
   uncommitted changes — respect that); then `git worktree prune -v`
   (or `scripts/worktree_alloc.py prune`) to clear dangling entries.
6. **Confirm recovery path exists.** Before any force-delete, note the tip SHA (`git reflog`)
   so the branch is restorable. If you cannot verify a branch is disposable, do not force it.
7. **Report.** List deleted, skipped-with-reason, and needs-sign-off.

## Decision rules

- **Merged / content-in-main** → delete (`-d`, `push --delete`).
- **Squash/rebase-merged** → verify content is in main, then delete.
- **Unmerged, not verified** → **stop**; verify or ask the owner. Never bulk `-D`.
- **Protected** (`main`, release, branch-protected) → **never delete**.
- **Active PR / shared** → leave until merged or the owner agrees.
- **Tracking refs only** (`[origin/x: gone]`) → `git fetch --prune`; always safe.

## Stop / escalate

- Branch is unmerged and you cannot confirm the work landed elsewhere → ask the author; do
  not guess-delete.
- Branch is shared or others based work on it → coordinate; no unilateral deletion.
- Force-delete would be needed → require explicit confirmation and a recorded tip SHA first.
- Recovery needed after an accidental delete → `git reflog` → `git branch <name> <sha>`;
  see [`../git-history/reference/guide.md`](../git-history/reference/guide.md).

## Output format

```markdown
## Branch cleanup — <repo/scope>

Synced: git fetch --prune
Integration branch: <main>

### Deleted (merged/verified)
- <name> — merged into main; local + remote removed

### Skipped
- <name> — unmerged, N commits not in main → owner sign-off needed
- <name> — protected (release branch)
- <name> — open PR #<n>

### Worktrees
- removed: <path>; pruned: <count> stale entries

### Needs sign-off
- <name> — <why>
```

## Quick checklist

- [ ] `git fetch --prune` run before judging
- [ ] Every candidate classified (merged / squash / unmerged / protected / PR / shared)
- [ ] Squash/rebase merges verified by content, not `--merged` alone
- [ ] Only merged/verified branches deleted; unmerged held for the owner
- [ ] No protected or shared branch deleted
- [ ] Worktrees removed via porcelain, then pruned
- [ ] Tip SHA recorded before any force-delete; reflog recovery path known
- [ ] Report lists deleted / skipped-with-reason / needs-sign-off
