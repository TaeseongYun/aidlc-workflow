# Quick Start

A guide for applying the AI requirements analysis/design/verification workflow to a project.
It can be used commonly across all projects, regardless of whether they are apps, backends, or frontends.

> **TL;DR** — you only need to memorize `/team-ai-workflow-start`. When you don't know where to
> begin, call it and it will diagnose and tell you the appropriate next command.

## 1. Clone the repo (once)

```bash
git clone https://github.com/TaeseongYun/aidlc-workflow.git ~/workspace/aidlc-workflow

# If you cloned it elsewhere, you must tell it via an environment variable.
echo 'export TEAM_AI_WORKFLOW_DIR="$HOME/workspace/aidlc-workflow"' >> ~/.zshrc
source ~/.zshrc
```

## 2. Install the skills (once, per account)

```bash
bash ~/workspace/aidlc-workflow/scripts/install-skills.sh
```

Skills such as `/team-ai-workflow-start`, `/ctx-aidlc-run`, and `/ctx-domain-exec` are installed globally.

In a **multi-account** environment (e.g., a Claude Code secondary account at `~/.claude-personal/`),
run it once more with the target home changed via environment variables.

```bash
CLAUDE_HOME="$HOME/.claude-personal" CODEX_HOME="$HOME/.codex-personal" \
  bash ~/workspace/aidlc-workflow/scripts/install-skills.sh
```

The script is idempotent, so it is safe to re-run after updating the main body.

## 3. Initialize the project (once per project)

```bash
cd my-project
bash ~/workspace/aidlc-workflow/scripts/init-project.sh
```

`ctx/`, `aidlc-docs/`, and `CLAUDE.md` are created automatically.

The generated structure:

```text
<project-root>/
├── CLAUDE.md
├── ctx/
│   ├── INDEX.md
│   └── project-profile.ctx.md
└── aidlc-docs/
    ├── aidlc-state.md
    ├── audit.md
    └── features/
```

## 4. Fill in the project information

Open Claude Code in the project and enter the command below.

```text
Analyze the project and fill in ctx/INDEX.md, ctx/project-profile.ctx.md
```

Claude automatically figures out the project structure, stack, modules, and so on, and fills them in.

## 5. Usage

### When you don't know where to start

```text
/team-ai-workflow-start
```

It diagnoses the current environment (location of the main body, skill installation, project
initialization, in-progress features, OMC/Ouroboros detection) and tells you the next command to run.

### The 4 main skills

```text
/ctx-aidlc-roadmap → (when multi-feature) decompose a large prepared plan into features + GATE-0
/ctx-worktree      → optionally create isolated worktrees for parallel-safe features
/ctx-aidlc-run     → requirements analysis + question extraction (per feature)
/ctx-domain-exec   → implementation based on approved requirements
```

### OMC / Ouroboros Integration

Once requirements are approved (GATE-2/3 passed), you can hand implementation off to OMC autopilot/ralph
or Ouroboros evolve. Detailed patterns: [docs/omc-ouroboros-integration.md](docs/omc-ouroboros-integration.md)

### Code Restraint (ponytail)

If you want to reduce the amount of code during the implementation stage, use [ponytail](https://github.com/DietrichGebert/ponytail)'s
7-step restraint ladder alongside. `/ctx-domain-exec` applies it automatically based on [core/lazy-implementation.md](core/lazy-implementation.md),
so it works without installing the plugin. Details: [docs/ponytail-integration.md](docs/ponytail-integration.md)

### Requirements Analysis

```text
/ctx-aidlc-run

Analyze this requirement against the team-ai-workflow standard.

Feature:
- (enter the requirement here)
```

### Multi-Feature (a large prepared plan)

If a plan is decomposed into multiple features and needs to be divided among the team, create a roadmap first instead of `/ctx-aidlc-run`.

```text
/ctx-aidlc-roadmap

Create a Phase 0 roadmap from the following prepared-requirement plan.
- Source: <plan path or body>
```

After GATE-0 approval, `aidlc-docs/_roadmap.md` is generated. Run `/ctx-worktree`
when parallel-safe features need isolated branches and directories; it shows the
allocation plan and waits for approval before creating anything. Each team member
then runs `/ctx-aidlc-run` for their own feature. For a single feature, Phase 0 is
skipped automatically at STEP R1.

Detailed operation: [docs/multi-feature-coordination.md](docs/multi-feature-coordination.md)

After running, artifacts are generated under `aidlc-docs/features/<feature-slug>/`:
- `status.md` — current status
- `requirements.md` — organized requirements
- `requirement-verification-questions.md` — list of open questions
- `unit-of-work.md` — work unit decomposition

### Implementation after answering questions

After answering the questions marked BLOCK in `requirement-verification-questions.md`:

```text
/ctx-domain-exec

Implement based on the content approved in aidlc-docs and ctx.

Feature:
- (enter the feature to implement)
```

## Session Separation

Large features must be split into sessions by Phase to maintain quality.
- **Phase A** (Discovery): STEP 1–3 → end the session after passing GATE-1
- **Phase B** (Definition): STEP 4–6 → end the session after passing GATE-3
- **Phase C** (Design): STEP 6.5–9 → end the session after passing GATE-5

Application criteria: minimal=optional, standard=recommended, comprehensive=**required**

Details: [docs/workflow-guide.md](docs/workflow-guide.md#세션-분리-기본-실행-모델)

## Next Steps

- Detailed workflow: [docs/workflow-guide.md](docs/workflow-guide.md)
- Core concepts: [docs/concepts.md](docs/concepts.md)
- FAQ / checklist: [docs/faq.md](docs/faq.md)
