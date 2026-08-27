---
name: ctx-worktree
description: Plan and create isolated git worktrees for parallel-safe features in an approved aidlc multi-feature roadmap. Use after GATE-0 or when the user explicitly provides worktree slugs/count.
allowed-tools: Read, Bash
---

ROLE: WORKTREE_ALLOCATOR
MODE: MULTI_FEATURE_ALLOCATION
EXECUTION_MODEL: SEQUENTIAL_WITH_APPROVAL

## Purpose And Scope

Translate `aidlc-docs/_roadmap.md` allocation phases into one git worktree and
matching branch per parallel-safe feature. This skill may inspect worktrees,
show an allocation plan, and create exactly the approved plan.

It does not edit the roadmap, assign people, start feature implementation,
merge branches, remove worktrees, or prune metadata unless the user explicitly
requests that separate operation.

## Guardrails

- Always run `plan` before `create` and show its complete target list.
- Never run `create` without explicit user approval of that target list.
- Treat approval as valid only for the shown roadmap, base directory, and targets.
- If any of those values changes before creation, show the new plan and ask again.
- A worktree is a `git worktree` checkout (created via `git worktree add` inside
  the allocator), never a plain directory. If the allocator script is missing,
  halt — do not fall back to `mkdir` or hand-made directories.
- Never overwrite an existing path or force-remove/recreate a worktree.
- Do not infer manual slugs or a worktree count when roadmap detection returns none.
- Run commands from the target project's git root, not the workflow repository.

## Input

Accepted inputs:

- `/ctx-worktree` to detect targets from `aidlc-docs/_roadmap.md`.
- Optional roadmap path or base directory.
- Explicit `--slugs` or `--count` only when the user requests a manual override.
- An explicit request to list worktrees or prune stale worktree metadata.

Before planning, verify:

1. The current project is inside a git repository.
2. `{{TEAM_AI_WORKFLOW_DIR}}/scripts/worktree_alloc.py` exists.
3. The roadmap exists when no manual override was provided.
4. GATE-0 is approved when approval state is available in
   `aidlc-docs/aidlc-state.md`. If it is pending, stop before planning creation.

## Procedure

1. Resolve the project root with `git rev-parse --show-toplevel`.
2. Build one stable argument set from the user's input. Do not add overrides.
3. From the project root, run:

   ```bash
   python3 {{TEAM_AI_WORKFLOW_DIR}}/scripts/worktree_alloc.py plan <arguments>
   ```

4. Report the detected count, paths, and branches. Ask for explicit approval.
5. After approval, confirm the roadmap and arguments have not changed, then run:

   ```bash
   python3 {{TEAM_AI_WORKFLOW_DIR}}/scripts/worktree_alloc.py create <same arguments>
   ```

6. Run the allocator's `list` command and report created, skipped, and failed
   targets. A nonzero exit is a failed allocation; do not claim completion.

For a list-only request, run `list` without the approval gate. For prune, show
what `git worktree list --porcelain` marks as prunable and obtain explicit
approval before running `prune`.

## Output Format

Before approval:

```markdown
## Worktree allocation plan
- Project root: <path>
- Roadmap: <path or manual override>
- Base directory: <path>
- Targets: <count>
  <verbatim plan target lines>
- Status: awaiting approval
```

After creation:

```markdown
## Worktree allocation result
- Created: <count and targets>
- Skipped: <count and targets>
- Failed: <count and targets>
- Current worktrees: <allocator list output>
```

## Halt Conditions

Stop when the repository, allocator, or required roadmap is missing; GATE-0 is
pending; no parallel targets are detected; inputs are invalid; the plan changed
after approval; or creation fails.

```markdown
## Worktree allocation halted

Reason:
- <specific reason>

Needs confirmation:
1. <only the decision required to continue, or "none">
```

## Execution Guidelines

Validate input first, plan without mutation, obtain approval, create the exact
approved targets, and verify with `list`. Keep allocator stdout verbatim where
it identifies paths or failures. Do not automatically start another skill.

## Graph Isolation (per worktree)

Each worktree is its own directory, so each gets its **own** `graphify-out/graph.json` — no branch
shares another's in-flight graph. This skill does not build graphs (that happens per worktree via
`init-project.sh` / `ctx-run`); it only creates the isolated worktrees. Downstream:

- Build/refresh the graph inside each worktree (`graphify .` / `graphify . --update`).
- Review across worktrees with `graphify prs --worktrees` (worktree → branch → PR blast radius).
- After merging a branch to main, regenerate main's graph (`graphify . --update`).
- `graphify-out/` is git-ignored (added by `init-project.sh`), so per-worktree graphs never collide.
