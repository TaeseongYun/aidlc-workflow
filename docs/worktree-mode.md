# Worktree Mode

Worktree mode turns a multi-feature roadmap into parallel git worktrees: one
worktree (and matching branch) per parallel-safe feature, so several features
can be built at the same time without stepping on each other.

It is a two-part capability:

- `scripts/worktree_alloc.py` — stdlib-only Python that detects the feature set
  and creates the worktrees.
- `/ctx-worktree` skill — the conversation-mode wrapper that shows the plan and,
  on your approval, creates the worktrees.

## When to use it

After `/ctx-aidlc-roadmap` has produced `aidlc-docs/_roadmap.md` (Phase 0) and
the roadmap has a phase whose features are meant to run in parallel. Each
parallel-safe feature is then developed on its own worktree, typically with a
separate `/ctx-aidlc-run` → `/ctx-domain-exec` session.

## Detection signal

The allocator parses the project's `aidlc-docs/_roadmap.md` (structure defined
by `templates/feature-roadmap.md`):

| Roadmap section | What is read | Used for |
|-----------------|--------------|----------|
| §2 Feature List | `Feature ID` (`F-N`) → `Slug` (kebab-case) | worktree/branch name |
| §5 Allocation   | a phase whose execution-mode cell says `parallel` / `병렬` | which features are parallel |
| §4 Dependency Graph | rows with `Resolution = parallel-safe` | fallback when §5 is absent |

The roadmap may be Korean or English: both the `parallel` / `병렬` execution-mode
wording and the verbatim `parallel-safe` enum value are recognized.

## CLI

```bash
# dry-run: show what would be created (reads aidlc-docs/_roadmap.md)
python3 scripts/worktree_alloc.py plan

# create one worktree per parallel-safe feature
python3 scripts/worktree_alloc.py create

# manual override (no roadmap): explicit slugs, or N generic worktrees
python3 scripts/worktree_alloc.py create --slugs coupon-issue,coupon-redeem
python3 scripts/worktree_alloc.py create --count 3

# inspect / clean up
python3 scripts/worktree_alloc.py list
python3 scripts/worktree_alloc.py prune

# self-check of the roadmap parser
python3 scripts/worktree_alloc.py --selftest
```

Flags for `plan` / `create`:

- `--roadmap PATH` — roadmap file (default `aidlc-docs/_roadmap.md`)
- `--base DIR` — where new worktrees are created (default: sibling of the main
  worktree, i.e. next to the current checkout)
- `--slugs a,b,c` — explicit slugs, bypasses roadmap detection
- `--count N` — create N generic worktrees named `feature-1`…`feature-N`

## Behavior

- **Idempotent**: a worktree whose path already exists is skipped, never
  overwritten. Re-running is safe.
- **Branch reuse**: if a branch named after the slug already exists it is checked
  out; otherwise a new branch is created (`git worktree add <path> -b <slug>`).
- **Worktree-aware**: works when invoked from inside an existing worktree; the
  base directory defaults to a sibling of the repository's main worktree.

## Invocation via the skill

```
/ctx-worktree
```

The skill always runs `plan` first, shows the detected allocation, waits for
your approval, then runs `create`.
