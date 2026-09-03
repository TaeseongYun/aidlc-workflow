---
name: ctx-aidlc-sync
description: One-shot sync of this workflow repo with the upstream AWS AI-DLC repo (awslabs/aidlc-workflows). Detects upstream changes since the last recorded sync commit, filters them through the adoption tables in docs/methodology-references.md (port adopted patterns, skip not-taken areas with a reason, escalate new concepts), works in an isolated git worktree branch, iterates a 4-axis sync score, and opens a PR only when the score exceeds 90. Use when the user asks to sync/catch up with upstream aidlc, or on a periodic upstream check.
allowed-tools: Read, Write, Edit, Bash, Skill
---

ROLE: UPSTREAM_SYNC_OPERATOR
MODE: ONE_SHOT_SYNC
EXECUTION_MODEL: WORKTREE_BRANCH_SCORE_LOOP_THEN_PR

# ctx-aidlc-sync

Sync this workflow repository with its upstream methodology source,
**https://github.com/awslabs/aidlc-workflows** (branch `main`). The two repos
share no git history and diverge deliberately, so this is a **content-level
port**, never a git merge: upstream changes are read, filtered through this
repo's adoption decisions, and re-expressed in this repo's structure and
conventions.

Framework root: `{{TEAM_AI_WORKFLOW_DIR}}`

## Purpose And Scope

- Detect what changed upstream since the last recorded sync.
- Disposition every change as PORT / SKIP / ESCALATE using
  `docs/methodology-references.md` §1 ("What we took" / "What we did not take")
  as the adoption filter.
- Apply PORT items in an isolated git worktree branch of **this workflow repo**
  (not a user project), then score the sync and open a PR when it passes.

Out of scope: merging the PR (human decides), changing the adoption policy
itself (ESCALATE instead), touching `main` directly, syncing any repo other
than the workflow repo.

## Guardrails

- **Never git-merge or copy upstream files verbatim.** Port the pattern,
  re-expressed in this repo's terminology, structure, and English-canonical
  docs. Wholesale file copies are a halt condition.
- **Adoption filter is binding.** Changes in "What we did not take" areas
  (implementation/deployment automation, excluded artifacts, estimation) are
  SKIP with a one-line reason — never ported, never silently dropped.
- **No-Implicit-Decisions.** A new upstream concept that fits neither table is
  ESCALATE: record it in the report and stop short of adopting it. Do not
  guess the adoption decision.
- **In-house patterns are not overwritten** (`methodology-references.md` §6):
  CTX rules, Stage Gates, Readiness Score, question governance. Upstream never
  wins over an in-house pattern without an explicit human decision.
- Work only in a dedicated `git worktree` + branch (`sync/aidlc-<shortsha>`),
  created with `git worktree add` — never a plain directory, never on `main`.
- **PR only above 90**: total score > 90 AND Coverage ≠ 0. Below that, iterate;
  on STALLED/EXHAUSTED, halt and report — never open the PR anyway.
- Scores require rationale per axis; never record numbers alone. Never
  merge the PR or push to `main`.

## Input

- `/ctx-aidlc-sync` — full sync from the last recorded state.
- Optional `--check`: detection + disposition table only; no worktree, no edits.
- Optional `--baseline <sha>`: override the starting upstream commit.

Before doing anything, verify:

1. The current directory is the workflow repo root (`git rev-parse --show-toplevel`
   resolves, and `docs/methodology-references.md` exists).
2. `git`, `gh`, and network access to github.com are available.
3. `docs/upstream-sync-state.md` either exists or this is an acknowledged first
   run (baseline mode).
4. No `sync/aidlc-*` worktree or branch is already present.

## State File

`docs/upstream-sync-state.md` in this repo records: upstream URL, last-synced
upstream SHA, sync date, and the disposition table of the last run. It is
updated **inside the sync PR** so state lands only when the sync merges.

**First run (no state file):** do not port history. Record the current upstream
HEAD as the baseline, create the state file via a normal (scored) PR, and
report "baseline set — future runs sync from here."

## Procedure

1. **Fetch upstream** into the scratchpad (never inside the repo):
   `git clone --filter=blob:none https://github.com/awslabs/aidlc-workflows <scratch>/aidlc-upstream`
   (or `git fetch` an existing clone).
2. **Detect**: read `docs/upstream-sync-state.md` for `lastSyncedSha`; list
   changes with `git log <lastSyncedSha>..origin/main --oneline` and
   `git diff <lastSyncedSha>..origin/main --stat`. Nothing new → report
   "already in sync" and stop.
3. **Disposition** every changed file/commit against the adoption tables:
   - `PORT` — touches an adopted pattern (artifact structure, adaptive depth,
     extension opt-in, input validation, contradiction detection, state/audit
     tracking). Name the target file(s) in this repo.
   - `SKIP` — not-taken area; one-line reason.
   - `ESCALATE` — new concept with no adoption decision; summarize for the
     human.
   With `--check`, print the table and stop here.
4. **Worktree**: from this repo's root,
   `git worktree add ../aidlc-sync-<shortsha> -b sync/aidlc-<shortsha>`.
5. **Apply** PORT items in the worktree, re-expressed per this repo's
   conventions. Update `docs/upstream-sync-state.md` (new SHA, date,
   disposition table). Update `docs/methodology-references.md` §1 if an
   adopted pattern's upstream shape changed materially.
6. **Score loop** (see below) until COMPLETE, STALLED, or EXHAUSTED.
7. **On COMPLETE**: commit (one commit; message lists upstream SHA range and
   dispositions), push the branch, open a PR titled
   `sync: aidlc upstream <old-short>..<new-short>` whose body contains the
   disposition table and per-axis scores. Report the PR URL. Remove the
   worktree only after the push succeeds.

## Sync Score (4 axes × 25, threshold > 90)

| Axis | 25 points means |
|---|---|
| Coverage | Every upstream change since `lastSyncedSha` is dispositioned; no unlisted file |
| Fidelity | Each PORT preserves upstream meaning while matching this repo's structure/terms; no verbatim copies |
| Consistency | `bash tools/validate-skills.sh` passes; no contradiction or stale cross-reference introduced (actually run the script — unrun ⇒ axis = 0) |
| Traceability | State file updated; disposition table complete with reasons; commit/PR reproduce the mapping |

Verdicts per round, mirroring `ctx-score-loop`:

- `COMPLETE`: total > 90 AND Coverage ≠ 0 → proceed to PR.
- `CONTINUE`: fix the weakest axis, re-score.
- `STALLED` (2 rounds without improvement) / `EXHAUSTED` (6 rounds or 30
  minutes): halt, report the blocked axis and reason, keep the worktree for
  inspection, no auto-restart, **no PR**.

## Output Format

```markdown
## aidlc upstream sync — <old-short>..<new-short>
- Upstream: awslabs/aidlc-workflows @ <new-sha>
- Dispositions: N PORT · N SKIP · N ESCALATE
  | Upstream change | Disposition | Target / Reason |
  |---|---|---|
- Score: Coverage a/25 · Fidelity b/25 · Consistency c/25 · Traceability d/25 = T/100 (round R)
- Verdict: COMPLETE → PR: <url>   (or STALLED/EXHAUSTED + blocked axis)
- Escalations needing a human decision: <list or "none">
```

## Halt Conditions

Upstream unreachable; state file references a SHA unknown upstream (history
rewrite — ask for a new baseline); a PORT would require copying files verbatim
or overwriting an in-house pattern; score loop STALLED/EXHAUSTED; worktree or
branch already exists.

```markdown
## aidlc upstream sync halted

Reason:
- <specific reason>

Needs confirmation:
1. <only the decision required to continue, or "none">
```

## Execution Guidelines

Validate input first, detect without mutation, disposition every change,
apply only PORT items in the isolated worktree, score with rationale each
round, and open the PR only on COMPLETE. Keep upstream commit SHAs and
disposition reasons verbatim in the state file and PR body. Do not
automatically start another skill, and do not merge the PR.
