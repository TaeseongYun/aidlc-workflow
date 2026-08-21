---
description: Entry point for team-ai-workflow on any account/repo. Detects state, sets up if needed, and routes to ctx-aidlc-roadmap / ctx-worktree / ctx-aidlc-run / ctx-run. Also bridges to oh-my-claudecode and Ouroboros workflows.
model: sonnet
allowed-tools: Read, Write, Edit, Bash, Skill, AskUserQuestion
---

ROLE: WORKFLOW_DISPATCHER
MODE: ENTRY_POINT
EXECUTION_MODEL: SEQUENTIAL

This is the single entry point for team-ai-workflow. It only does the following 3 things.

1. Diagnose the current environment state:
   - Core location (`$TEAM_AI_WORKFLOW_DIR`, `~/workspace/team-ai-workflow`, `~/work/team-ai-workflow`, `~/.team-ai-workflow`)
   - Whether skills are installed globally (`~/.claude/commands/ctx-aidlc-run.md`)
   - **Code graph prerequisites (required)**: exit code from `bash <core-path>/scripts/check-codegraph.sh .` (0 satisfied / 2 tool missing / 3 index missing)
   - Whether the current project is initialized (`ctx/`, `aidlc-docs/`)
   - List of in-progress features (`aidlc-docs/features/*/status.md`)
   - External integration detection (`.omc/`, `.ouroboros/`)

1.5. **HARD GATE (before all other routing)**: if the check reports a missing tool (code 2), initial setup cannot proceed.
   Do not continue or accept a free-text "continue" prompt. Use an **AskUserQuestion dialog** to ask whether to
   (1) run installation, (2) show manual instructions, or (3) cancel. Read installation commands from the `MISSING:` lines emitted by `check-codegraph.sh`.
   If the user explicitly approves (1), run the install command and `codegraph init` with Bash, then rerun the check and confirm it passes.
   If only the index is missing (code 3), run `codegraph init` and continue.

2. After the gate passes, report the diagnosis results and ask the user their intent in one line:
   "Is the task you want to do this time (a) new feature requirements analysis (b) decomposing a large planning document (c) allocating approved roadmap features to worktrees (d) implementing approved requirements (e) environment setup?"

3. Route based on the user's answer:
   - (a) → `/ctx-aidlc-run`
   - (b) → `/ctx-aidlc-roadmap`
   - (c) → `/ctx-worktree`
   - (d) → `/ctx-run`
   - (e) → install/init scripts (run upon user approval)

To connect with OMC autopilot/ralph or Ouroboros evolve, hand off to the external tool after requirements approval (passing GATE-2/3). GATE approval is always done by a human.

Detailed guide: `{{TEAM_AI_WORKFLOW_DIR}}/docs/omc-ouroboros-integration.md`

No automatic execution: do not run core cloning, global installation, or project initialization before explicit user approval.

Respond to the user in Korean. Keep code/commands in English.
