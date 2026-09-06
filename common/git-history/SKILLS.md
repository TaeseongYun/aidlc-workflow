# Git History — Skills

Actionable procedure an agent (or engineer) runs to keep history clean and recover it
when something goes wrong. This is the *how*; the *what/why* reference is
[`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-commit-planner` (design commit structure in meaningful units before committing).
- **Cross-links**: sibling guides [`../branch-strategy/reference/guide.md`](../branch-strategy/reference/guide.md) and [`../commit-workflow/reference/guide.md`](../commit-workflow/reference/guide.md).
- **Platform-agnostic**: applies on any stack. Platform-specific rules live under `platforms/<platform>/`.

## When to use

Before sharing a branch (tidy the local series), when integrating work (choose merge vs
rebase), when hunting a regression (bisect/blame), when undoing a change (revert vs reset),
or when recovering from a bad rewrite (reflog).

## Inputs

- The branch and its base — is it local-only, your own remote branch, or shared/public?
- Intent — tidy history, integrate, find a bug, undo a change, or recover lost work.
- For bisect: a known-good commit and a reliable pass/fail test.

## Outputs

- A history where each commit is a working, single-purpose, well-described state.
- A specific SHA (bisect), provenance answer (blame), or recovered ref (reflog).

## Procedure

1. **Classify the branch first.** Local-only, own-remote, or shared/public? This single
   fact decides whether rewriting is allowed at all. Shared/public → **never** rewrite;
   undo with `git revert`.
2. **Tidy before sharing.** On a private branch, use `git rebase -i <base>` to reorder,
   squash, and reword into a clean logical series. In automated/sandboxed environments
   where interactive editors are unavailable, use `git commit --fixup=<sha>` +
   `git rebase --autosquash` with `GIT_SEQUENCE_EDITOR=:`, and stage with `git add -p` or
   explicit paths instead of `git add -i`.
3. **Choose integration shape.** Rebase to *update* a private branch onto latest base;
   merge to *integrate* a finished branch. Match the repo's existing policy (linear vs
   merge-commit) — do not mix arbitrarily.
4. **Push rewrites safely.** Only `--force-with-lease`, never bare `--force`, and only on a
   branch you classified as safe to rewrite in step 1.
5. **Find a regression with bisect.** `git bisect start` → `bad` current → `good <sha>` →
   test each checkout, or automate with `git bisect run <test>`. `git bisect reset` when
   done. Clean, building commits make this land on a real cause.
6. **Find provenance with blame.** `git blame -w -M -C -L <range> <file>` to reach past
   reformatting and moves to the real authoring commit; read its message for the *why*.
7. **Undo correctly.** `git revert <sha>` for anything published; `git reset` only on
   local, unshared commits — and confirm the target before `reset --hard`.
8. **Recover with reflog.** After a bad reset/rebase/amend, `git reflog`, find the last
   good SHA, and `git reset --hard <sha>` or `git branch rescue <sha>`.
9. **Tag releases annotated.** `git tag -a` (or `-s`) with a message; push tags explicitly.

## Decision rules

- Branch is shared or public → **never rewrite**; use `git revert`.
- Rewriting an allowed branch → **`--force-with-lease` only**, never bare `--force`.
- Undoing published history → **`git revert`**; undoing local commits → `git reset`.
- `reset --hard` → confirm the target SHA first; the discarded state is only in the reflog.
- Backporting one commit → `git cherry-pick -x`; but prefer a merge where topology allows.
- Every commit must build and pass tests — otherwise `git bisect` is unreliable.

## Stop / escalate

- About to rewrite a shared/public branch → stop; confirm with the team or use `revert`.
- `reset --hard` or force-push would discard work you did not create → surface it, do not proceed.
- Bisect keeps landing on broken (non-building) commits → the history itself is the problem; flag it.
- Reflog does not contain the lost state (e.g. after a fresh clone) → escalate; it may be unrecoverable.

## Quick checklist

- [ ] Branch classified: local / own-remote / shared — rewrite decision follows from it
- [ ] Local series tidied before sharing (non-interactive path if sandboxed)
- [ ] Integration shape matches repo policy (rebase to update, merge to integrate)
- [ ] Any force-push uses `--force-with-lease`, never bare `--force`
- [ ] Published history undone with `revert`, not `reset`
- [ ] Each commit is a working, single-purpose, clearly-described state
- [ ] Releases tagged with annotated (`-a`/`-s`) tags and pushed explicitly
- [ ] Reflog remembered as the recovery path before any destructive rewrite
