# Commit Workflow — Skills

Actionable procedure an agent (or engineer) runs to turn a working tree of changes
into a clean sequence of commits. This is the *how*; the *what/why* reference is
[`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-commit-planner` (judge whether changes can be committed and design the commit structure in meaningful units — plan first, then author).
- **Siblings**: [`../commit-review/reference/guide.md`](../commit-review/reference/guide.md) (reviewing commits), [`../branch-strategy/reference/guide.md`](../branch-strategy/reference/guide.md) (branch naming and flow).
- **Platform-agnostic**: applies on any stack. Platform-specific rules live under `platforms/<platform>/`.

## When to use

Any time you have uncommitted work to record: after finishing a logical step, before
pushing a branch, or when curating a messy local history into shareable commits.

## Inputs

- The working tree changes — `git status`, `git diff`.
- Change intent — what each edit was *for*. If several unrelated edits are mixed, you'll split by intent.
- Branch state — is it local/unshared (safe to rewrite) or already pushed?

## Outputs

- One or more commits, each atomic (one purpose, builds, tests pass), with a clear message.
- A curated branch ready to push/merge (noise squashed, refactors split from behavior).

## Procedure

1. **Survey.** Run `git status` and `git diff`. List every change and, in one phrase,
   what each was *for*. If you can't name the purpose, don't commit it yet.
2. **Group by purpose.** Cluster changes into atomic units (see the boundary tables in
   the guide). Split refactors from behavior changes. Keep code with its test.
3. **Stage one unit.** Stage only the files/hunks/lines for the first unit — patch-add
   when a file holds two concerns. Leave the rest unstaged.
4. **Verify the staged diff.** Read `git diff --staged`. Confirm: no stray debug lines,
   no unrelated edits, **no secrets, no large/generated files**. If a secret is present,
   remove it and (if it was ever pushed) rotate it.
5. **Confirm it's self-contained.** The staged unit should build and pass tests on its
   own. If it depends on a later change to compile, the boundary is wrong — regroup.
6. **Write the message.** Imperative subject ≤ 50 chars, blank line, body wrapped ~72
   explaining *why*. Use `type(scope):` if the repo uses Conventional Commits. Add
   trailers (`Refs:`, `Co-authored-by:`, `BREAKING CHANGE:`) as needed.
7. **Commit, then repeat** from step 3 for the next unit until the tree is clean.
8. **Curate before push.** On your own/unshared branch, interactive-rebase to squash
   `wip`/`fixup` noise, reword hasty messages, and order refactors before the features
   that use them. Do not rewrite commits others have built on.

## Decision rules

- Subject needs "and" → **split** into two commits.
- Refactor + behavior change in one unit → **split**; refactor commit first.
- Fix/typo in the commit you just made, **not yet pushed** → **amend**.
- Same fix but the commit is **already pushed to a shared branch** → **new commit**.
- `wip`/`fixup`/`address review` commits on an unshared branch → **squash** before push.
- Secret or large/generated file in the staged diff → **stop**; unstage, ignore, rotate if leaked.

## Stop / escalate

- A secret is already committed and pushed → rotate the credential now; scrubbing history
  (filter/BFG) is a coordinated team operation, not a quiet amend.
- The change is a policy/business decision (pricing, permissions, data retention) →
  the *code* commit is fine, but flag the decision to a human owner.
- You need to rewrite history on a shared branch → escalate; coordinate, don't force-push silently.
- Lost work after a bad reset/rebase → `git reflog` first; the pre-op state is almost always still there.

## Output format

```markdown
## Commit plan: <branch>

Intent: <one line — what this branch delivers>

### Commits (in order)
1. <type(scope): subject>   — files: <a, b>   — why: <reason>
2. <type(scope): subject>   — files: <c>      — why: <reason>

### Curation
- squash: <wip commits folded in>
- split:  <refactor separated from behavior>
- rewrite-safe: <yes — unshared branch | no — already pushed>
```

## Quick checklist

- [ ] Every change's purpose named; unrelated edits separated
- [ ] Each commit atomic: one purpose, builds, tests pass, reverts cleanly
- [ ] Refactor commits split from behavior-change commits
- [ ] Staged diff read: no debug lines, no secrets, no large/generated files
- [ ] Message: imperative subject ≤ 50, why-not-what body, correct type/trailers
- [ ] History curated before push; no rewrite of shared commits
