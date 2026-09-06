# Branch Strategy — Skills

Actionable procedure an agent (or engineer) runs to choose a branch, name it, keep it short,
and get it merged safely. This is the *how*; the *what/why* reference is
[`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-worktree` (allocate parallel-safe features to isolated git
  worktrees so multiple short-lived branches run without clobbering each other).
- **Related siblings**: [`../branch-cleanup/reference/guide.md`](../branch-cleanup/reference/guide.md)
  (delete merged branches), [`../ci-cd-automation/reference/guide.md`](../ci-cd-automation/reference/guide.md)
  (when pipelines run per branch).
- **Platform-agnostic**: applies on any VCS host. Platform-specific rules live under `platforms/<platform>/`.

## When to use

Any time you start a unit of work, decide where a change should live, or set up how a repo
integrates and releases: opening a branch, wiring protection, or picking a model for a new repo.

## Inputs

- The change intent — the issue/ticket or task, and roughly how big it is.
- The repo's current model and protection rules (or the decision to set them).
- The delivery mode — continuous deploy vs discrete versioned releases.

## Outputs

- A correctly named, short-lived branch (or a decision to use a flag on trunk instead).
- For repo setup: a chosen model + protection rules + naming convention.

## Procedure

1. **Decide if a branch is even needed.** If the work is incomplete but the code is safe to
   have present-but-inert, prefer a **feature flag on trunk** over a long-lived branch. Branch
   only when you need an isolated review/CI unit.
2. **Pick the model** (repo-level, once) using the guide's comparison table: trunk-based or
   GitHub Flow for continuous deploy; release-branch/train for discrete supported versions.
   When two fit, take the lighter one.
3. **Name the branch** with a type prefix and, if you have one, the ticket id:
   `feat/PROJ-123-short-description`. Prefixes: `feat/ fix/ chore/ refactor/ docs/ hotfix/`.
4. **Scope it to stay short-lived** (< ~3 days). If the work is bigger, split it into shippable
   slices — one branch per slice — or put it behind a flag. For parallel features, allocate
   isolated **worktrees** (`/ctx-worktree`) instead of stashing.
5. **Integrate continuously.** Rebase/merge from `main` at least daily so conflicts stay small
   and semantic drift surfaces early.
6. **Open a PR and let CI + review gate it.** Keep the diff reviewable (see the code-review
   guide's size table). Required checks and required reviews must pass — never merge red.
7. **Merge via the repo's chosen method** (squash / rebase / merge). Prefer squash for small
   PRs so each merge is one revertible unit; use a **merge queue** if concurrent merges race.
8. **Land fixes on trunk too.** For a hotfix/release-branch fix, cherry-pick or merge the same
   fix back to the mainline so it does not regress next release.
9. **Delete the branch after merge** (and retire any now-shipped feature flag). See
   `../branch-cleanup`.

## Decision rules

- Incomplete but inert code → **flag on trunk**, not a long-lived branch.
- Branch older than ~3 days → **split it** or move it behind a flag; do not let it diverge.
- CI red on `main` → **fix or revert**, never merge on top.
- Fix to a release/hotfix branch → **must** have a tracked path back to trunk.
- Concurrent merges racing on `main` → **add a merge queue**.
- Someone proposes `dev`/`staging`/`prod` **branches** as the deploy mechanism → stop; deploy
  one artifact from `main` per environment via the pipeline instead.

## Stop / escalate

- Repo has no branch protection on `main` and you're about to push → set up protection first,
  or flag it to the owner; unreviewed code on the mainline is a Critical process gap.
- The chosen model doesn't fit the delivery mode (e.g. GitFlow on a continuously-deployed
  service) → surface the mismatch to a human owner before enforcing it.
- A required fix has no path back to trunk → escalate; do not ship a hotfix that will regress.

## Quick checklist

- [ ] Branch actually needed (else flag on trunk)
- [ ] Model fits the delivery mode
- [ ] Named with type prefix + ticket id
- [ ] Scoped to stay short-lived (< ~3 days); parallel work → worktrees
- [ ] Integrating from `main` at least daily
- [ ] PR reviewable; required checks + reviews green (never merge red)
- [ ] Merged via the repo's method; merge queue if merges race
- [ ] Release/hotfix fix also landed on trunk
- [ ] Branch deleted and shipped flag retired after merge
