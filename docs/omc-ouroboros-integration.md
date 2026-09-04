# OMC · Ouroboros Integration Guide

team-ai-workflow is the workflow that decides "**what to build**".
`oh-my-claudecode` (OMC) and Ouroboros are the orchestration layer responsible for "**how to run it automatically**".
Using the two areas separately lets you run the same requirements outputs with multiple execution strategies.

```text
┌────────────────────────────┐    ┌──────────────────────────┐
│ team-ai-workflow           │    │ OMC / Ouroboros          │
│ - Requirements analysis    │    │ - Automation loop        │
│ - Multi-feature roadmap    │ →  │ - Evolutionary impl.     │
│ - UOW decomposition        │    │ - Iterative verification │
│ - Human GATE               │    │ - Parallel agents        │
└────────────────────────────┘    └──────────────────────────┘
        (What)                            (How)
```

GATE approval is always done by a human. OMC/Ouroboros does not auto-pass a GATE.

> **Restraint layer (ponytail)**: Unlike the two systems above that automate "how (How)", ponytail is responsible for
> "**how little (How little)**" to build. It applies a 7-step restraint ladder in the implementation stage (`/ctx-domain-exec`),
> and can also be injected into OMC autopilot/ralph prompts.
> Integration: [ponytail-integration.md](ponytail-integration.md), rules: [../core/lazy-implementation.md](../core/lazy-implementation.md)

---

## 1. Entry point: `/team-ai-workflow-start`

When you first start on a new account or a new repo, calling this skill auto-diagnoses the following.

- Main-body clone location (`$TEAM_AI_WORKFLOW_DIR` or the standard path)
- Global skill installation status
- Current project `ctx/` · `aidlc-docs/` initialization status
- List of in-progress features
- `.omc/` · `.ouroboros/` directory detection

After diagnosis, it recommends the appropriate follow-up command (`/ctx-aidlc-roadmap`, `/ctx-aidlc-run`, `/ctx-domain-exec`,
or an OMC/Ouroboros handoff).

```text
/team-ai-workflow-start
```

---

## 2. team-ai-workflow → OMC patterns

### 2-1. autopilot — automatic execution to the end

```text
User request
  ↓
/ctx-aidlc-run                ← requirements/design (GATE-2/3 human approval)
  ↓
/oh-my-claudecode:autopilot   ← implement → test → verify, auto-repeat
```

When calling OMC autopilot, pass the following as input context.

- `aidlc-docs/features/<slug>/requirements.md`
- `aidlc-docs/features/<slug>/unit-of-work.md`
- `aidlc-docs/features/<slug>/technical-design.md` (for M/L sizes)
- `ctx/INDEX.md`, `ctx/project-profile.ctx.md`

Recommended call example:

```text
/oh-my-claudecode:autopilot

Implement based on the following outputs. GATE-3 has passed.
- aidlc-docs/features/coupon-feature/requirements.md
- aidlc-docs/features/coupon-feature/unit-of-work.md

Repeat until each UOW's Acceptance Criteria in unit-of-work.md passes.
Verify with ctx-reviewer after implementation.
```

### 2-2. ralph — single-feature completion loop

Suitable for S-size (small-unit) features. Uses the UOW's verification method as the termination condition.

```text
/ctx-aidlc-run                ← decompose into 1~2 UOWs (S size only)
  ↓
/oh-my-claudecode:ralph       ← repeat until verification passes
```

```text
/oh-my-claudecode:ralph

Goal: all UOWs in aidlc-docs/features/<slug>/unit-of-work.md pass.
Verification: run the commands in each UOW's Verification section and succeed.
Reference: ctx/, aidlc-docs/features/<slug>/
```

### 2-2-S. ctx-score-loop — dependency-aware score loop (automatic verification after implementation)

**After** implementation, it automatically and repeatedly scores dependencies and 4-axis verification, and judges **complete only when the score exceeds 85**.
It extends ralph's termination condition from "UOW Verification command passes" to "**dependency md 4-axis score > 85 & build axis ≠ 0**".

```text
/ctx-aidlc-run                ← GATE-3 passed (implementation approved)
  ↓
/ctx-score-loop <slug>        ← one request autonomously repeats implement→score→improve
  (can delegate to the ralph engine internally)
```

4 axes (25 points each): dependency resolution / build·compile / test·coverage / requirements·AC fulfillment.
Scoring criteria: `core/dependency-score.md`. Procedure: `core/dependency-score-eval.md`.

Example of injecting the termination condition into a ralph handoff:

```text
/oh-my-claudecode:ralph

Goal: the 4-axis score in aidlc-docs/features/<slug>/dependency-check.md > 85.
Verification: score every round using the core/dependency-score-eval.md procedure.
  - The build·test axes count only actual command execution results (unrun = 0 points).
  - If the build axis is 0 points, it is not complete even if it exceeds 85 (GR-1).
Termination: total > 85 → report complete. 2 rounds stalled / 10-round·30-minute cap / score drop → stop immediately and report the reason.
Reference: ctx/, aidlc-docs/features/<slug>/, core/dependency-score.md
```

Termination/stop behavior:
- `COMPLETE` (>85 & build≠0): report complete, then terminate.
- `STALLED` (no improvement over 2 rounds) / `EXHAUSTED` (10 rounds·30 minutes) / `REGRESSED` (drop): stop immediately, report the stuck axis·score·reason, no automatic restart.

### 2-3. team — parallel division of labor

When processing multi-features decomposed by `_roadmap.md` in parallel.

```text
/ctx-aidlc-roadmap            ← Phase 0 decomposition + GATE-0
  ↓ (each feature is independent)
/oh-my-claudecode:team        ← N agents proceed per feature concurrently
```

Pass the serial/parallel groups to OMC team according to the dependency graph in `_roadmap.md`.

---

## 3. team-ai-workflow → Ouroboros patterns

### 3-1. Seed generation + evolve

```text
/ctx-aidlc-run                ← finalize requirements.md
  ↓
/ouroboros:seed                ← requirements.md → Seed spec
  ↓
/ouroboros:evolve              ← evolution loop
```

Ouroboros is effective when there is a measurable goal (test pass rate, performance metric, accuracy).
Convert the Acceptance Criteria in `unit-of-work.md` into the Seed's verification.

Recommended call example:

```text
/ouroboros:seed

Base document: aidlc-docs/features/<slug>/requirements.md
Verification criteria: each UOW Verification in aidlc-docs/features/<slug>/unit-of-work.md
Termination condition: all Acceptance Criteria pass
```

### 3-2. Evaluate outputs with evaluate

To evaluate already-implemented code against team-ai-workflow's outputs:

```text
/ouroboros:evaluate

Target: <repo>
Criteria: aidlc-docs/features/<slug>/requirements.md
verification: aidlc-docs/features/<slug>/unit-of-work.md
```

---

## 4. Conflict-prevention rules

Rules to follow when the three systems operate in the same repo.

### 4-1. State directory separation

| System | State location | Role |
|--------|-----------|------|
| team-ai-workflow | `aidlc-docs/` | Requirements·design·UOW (Source of Truth) |
| OMC | `.omc/state/`, `.omc/notepad.md` | Execution state·runtime notes |
| Ouroboros | `.ouroboros/`, session files | Seed·evolution history |

Each uses only its own directory. Never overwrite.

### 4-2. audit.md is append-only

- team-ai-workflow owns the format and ownership of `aidlc-docs/audit.md`.
- When OMC/Ouroboros records additional events, it clearly distinguishes them with an `[OMC]` or `[OUR]`
  prefix.
- Never modify existing entries.

### 4-3. Only humans pass GATEs

| GATE | Meaning | Can auto-pass? |
|------|------|----------------|
| GATE-0 | Roadmap Review | No |
| GATE-1 | Planning Draft (raw only) | No |
| GATE-2 | Requirements Review | No |
| GATE-2.5/2.7 | User Stories / Application Design | No |
| GATE-3 | Unit-of-Work Review | No |
| GATE-3.5 | Technical Design | No |
| GATE-4 | Infrastructure | No |
| GATE-5 | Build & Test Instructions | No |

Specify in the prompt so that OMC/Ouroboros does not automatically create a GATE-pass message.

### 4-4. Use only one system at a time (recommended)

team-ai-workflow handles the stages before GATE-3 exclusively.
After GATE-3 passes, use OMC or Ouroboros optionally in the implementation stage.

---

## 5. Using it the same way on a different account · different repository

### 5-1. Main-body clone and environment variables

```bash
# recommended location
git clone https://github.com/TaeseongYun/aidlc-workflow.git \
  ~/workspace/aidlc-workflow

# when using a different location, specify the environment variable
echo 'export TEAM_AI_WORKFLOW_DIR="$HOME/workspace/aidlc-workflow"' >> ~/.zshrc
source ~/.zshrc
```

### 5-2. Global skill installation

```bash
bash "$TEAM_AI_WORKFLOW_DIR/scripts/install-skills.sh"
```

Installation results:

- `~/.claude/commands/ctx-*.md` (Claude Code)
- `~/.claude/commands/team-ai-workflow-start.md` (entry skill)
- `~/.codex/skills/ctx-*/` (Codex CLI, optional)

### 5-3. multi-account environment

If you use Claude Code multi-account and have a separate home path such as `~/.claude-personal/`,
run install-skills.sh for each home or set up a symbolic link.

```bash
# e.g., also install into the personal account home
CLAUDE_HOME="$HOME/.claude-personal" \
  bash "$TEAM_AI_WORKFLOW_DIR/scripts/install-skills.sh"
```

(If install-skills.sh does not support the `CLAUDE_HOME` environment variable, use a symbolic link:
`ln -s ~/.claude/commands ~/.claude-personal/commands`)

### 5-4. Repository initialization

Run once per repo.

```bash
cd /path/to/new-repo
bash "$TEAM_AI_WORKFLOW_DIR/scripts/init-project.sh"
```

Structure created:

```text
<repo>/
├── CLAUDE.md (if missing)
├── ctx/
│   ├── INDEX.md
│   ├── project-profile.ctx.md
│   └── workflow/commit-workflow.ctx.md
└── aidlc-docs/
    ├── aidlc-state.md
    ├── audit.md
    └── features/
```

Existing files are left untouched.

### 5-5. Updating the main body

```bash
cd "$TEAM_AI_WORKFLOW_DIR" && git pull
bash scripts/install-skills.sh
```

The install script is idempotent, so it is safe to re-run.

---

## 6. Troubleshooting

### `/ctx-aidlc-run` is not recognized

```bash
ls -la ~/.claude/commands/ctx-aidlc-run.md
```

If the file is missing, run install-skills.sh again.

### The skill exists but `{{TEAM_AI_WORKFLOW_DIR}}` was not substituted

The main-body path at install time should be embedded, but if the placeholder remains as-is,
re-run install-skills.sh. `sed -i ''` is for macOS BSD sed, so
on Linux you need to fix it to `sed -i`.

### Two accounts are working on the same repo at once and audit.md conflicts

`audit.md` is append-only, but a race condition can occur on simultaneous writes.
Use different feature-slugs, and do not modify the same feature at the same time.

### OMC autopilot ignores the requirements

Check that the `requirements.md` and `unit-of-work.md` paths are specified in the autopilot prompt.
Specify the verification condition as "the Acceptance Criteria written in this file must pass",
not "follow the file path".

### Ouroboros evolve loops infinitely

That happens when the termination condition is not measurable. Check that the UOW's Verification section
is written with a concrete command (e.g., `./gradlew :module:test --tests CouponTest`).

---

## 7. Recommended usage scenarios

| Scenario | Recommended combination |
|---------|-----------|
| One person finishing a small feature (S) quickly | `/ctx-aidlc-run` → `/oh-my-claudecode:ralph` |
| Auto-judging completion by score with dependency·multi-axis verification after implementation | `/ctx-aidlc-run` → `/ctx-score-loop` (autonomous repeat until score exceeds 85) |
| Medium-size (M) feature, human reviews per PR | `/ctx-aidlc-run` → `/oh-my-claudecode:autopilot` |
| Large planning document, team division of labor | `/ctx-aidlc-roadmap` → each `/ctx-aidlc-run` → `/oh-my-claudecode:team` |
| Measurable goal (test pass rate, etc.) | `/ctx-aidlc-run` → `/ouroboros:seed` → `/ouroboros:evolve` |
| Evaluating existing code | `/ctx-aidlc-run` (requirements organization only) → `/ouroboros:evaluate` |
| Simple change (change-on-existing-feature) | `/ctx-aidlc-run` alone is enough, no external tools needed |
