# Commit Review — Skills

Actionable procedure an agent (or engineer) runs to review the *commits* of a change —
their granularity and messages — distinct from whole-PR code review. This is the *how*;
the *what/why* reference is [`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-commit-planner` (design the commit structure before writing), `/ctx-reviewer` (CTX-violation check on the code).
- **Related references**: [`../commit-workflow/reference/guide.md`](../commit-workflow/reference/guide.md) (how to *make* good commits), [`../git-history/reference/guide.md`](../git-history/reference/guide.md) (rewriting and inspecting history), [`../code-review/reference/guide.md`](../code-review/reference/guide.md) (reviewing the code itself).
- **Platform-agnostic**: applies to any Git repo. Platform-specific conventions live under `platforms/<platform>/`.

## When to use

Before a branch merges, once the code is agreed: to check that history is atomic, each
commit builds, and every message explains its intent. Also when an agent has just authored
commits and is self-reviewing before handing off.

## Inputs

- The commit range — `git log --oneline <base>..<head>` and `git log -p <base>..<head>` for full messages + diffs.
- Change intent — the issue/ticket or task, to confirm messages match reality and Conventional-Commits types are correct.
- Branch ownership — whether the branch is shared (rewriting shared history is off-limits).

## Outputs

- A list of findings, each with **severity + which commit (sha/subject) + the concrete problem + suggested fix** (`squash`, `reword`, `split`, `reorder`, `drop`).
- A verdict: **Approve** / **Approve with non-blocking comments** / **Request changes** / **Block**.

## Procedure

1. **List the commits.** `git log --oneline <base>..<head>`. Read them as a narrative: do
   they tell a coherent, ordered story, or is it scratch (`wip`, `fix fix`)?
2. **Judge granularity.** For each commit, ask: single-purpose? Any subject that needs
   "and"? Any commit that mixes refactor with behavior change? Flag splits and squashes.
3. **Check each commit builds.** Confirm no commit is broken on its own (tests/build pass
   at that commit) — required for `bisect`. If unverifiable, note it and recommend checking.
4. **Review each message.** Subject imperative + ≤50 chars + no trailing period; blank
   line; body wraps ~72 and explains *why* not *what*; Conventional-Commits type matches
   the diff. A message that restates the diff is a finding.
5. **Verify trailers.** `Co-authored-by` / `Signed-off-by` present where required; issue
   refs (`Fixes #N`) point at the right issue; signatures valid where policy mandates.
6. **Scan for forbidden content.** Secrets, large binaries, generated/vendored files,
   dead commented-out code, unrelated formatting churn. A secret is Critical.
7. **Propose the cleanup.** Name the exact history operation (fixup+autosquash, interactive
   rebase to squash/reword/reorder) — but only for **unpushed / solely-owned** branches.
8. **Decide the verdict** using the rules below and emit the report.

## Decision rules

- Any **secret / credential** in history → **Block**; require rotation, not just deletion.
- Any commit that does not build on its own, or a large binary / generated file committed → **Request changes**.
- WIP / fixup / "fix" chains reaching the merge → **Request changes**; require squash.
- Message restates the diff, wrong Conventional-Commits type, or non-imperative subject → **Request changes** (Medium).
- Granularity slightly off but every commit builds and is honest → **Approve with non-blocking comments**.
- Clean, atomic, well-messaged history → **Approve**.

## Stop / escalate

- Branch is **shared** and needs history rewrite → do not rewrite; escalate. Rewriting shared history breaks collaborators.
- Intent unclear (can't tell if the Conventional-Commits type or issue ref is right) → ask the author; do not guess.
- Signing/DCO policy is unclear for this repo → confirm the policy before blocking on a missing signature.

## Output format

```markdown
## Commit review: <branch>  —  verdict: <Approve | Approve w/ comments | Request changes | Block>

Range: <base>..<head>  (<N commits>)
Branch: <shared | solely-owned — rewrite allowed?>

### Findings
- [Critical] <sha> "<subject>" — secret/large-binary — <fix: rotate + scrub>
- [High]     <sha> "<subject>" — doesn't build on its own — <fix: reorder/squash>
- [Medium]   <sha> "<subject>" — message restates diff / wrong type — <fix: reword>
- [Nit]      <sha> "<subject>" — subject 54 chars — <fix: tighten>
praise: <a commit sliced or explained well>

### Proposed cleanup (unpushed/owned branch only)
- squash <sha> into <sha>; reword <sha>; split <sha>
```

## Quick checklist

- [ ] Commits read as a coherent, ordered narrative
- [ ] Each commit is single-purpose (no subject needs "and")
- [ ] Each commit builds / passes tests on its own
- [ ] Subjects imperative, ≤50 chars; bodies explain *why*, wrap ~72
- [ ] Conventional-Commits type matches each diff
- [ ] Trailers present/correct; signatures valid where required
- [ ] No secrets, large binaries, or generated files in history
- [ ] Cleanup proposed only for unpushed / solely-owned branches
- [ ] Verdict follows the decision rules
