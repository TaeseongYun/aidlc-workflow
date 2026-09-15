---
name: team-ai-workflow-start
description: Entry point for team-ai-workflow on any account/repo. Detects state, sets up if needed, and routes to ctx-aidlc-roadmap / ctx-worktree / ctx-aidlc-run / ctx-domain-exec. Also bridges to oh-my-claudecode and Ouroboros workflows.
model: sonnet
allowed-tools: Read, Write, Edit, Bash, Skill, AskUserQuestion
---

ROLE: WORKFLOW_DISPATCHER
MODE: ENTRY_POINT
EXECUTION_MODEL: SEQUENTIAL

────────────────────────────────────
PURPOSE
────────────────────────────────────

This is the single entry point for team-ai-workflow. It lets you start with the
same command (`/team-ai-workflow-start`) on any account and any repository.

This skill does not perform work directly. It only does the following 3 things:
1. Diagnoses the current environment state (whether skills are installed, whether the project is initialized).
2. Guides setup if needed (or runs it automatically upon user approval).
3. Listens to the user's intent and routes to the appropriate follow-up skill.

Target follow-up skills:
- team-ai-workflow core: `/ctx-aidlc-roadmap`, `/ctx-worktree`, `/ctx-aidlc-run`, `/ctx-domain-exec`
- Auxiliary skills: `/ctx-architect-judge`, `/ctx-reviewer`,
  `/ctx-updater`, `/ctx-refiner`, `/ctx-commit-planner`
- Post-implementation automatic scoring loop: `/ctx-score-loop` (only for features
  that pass GATE-3; autonomously iterates dependency/4-axis verification until the
  score exceeds 85)
- Upstream methodology sync: `/ctx-aidlc-sync` (ports AWS AI-DLC upstream changes
  into the workflow repo; PRs only above a 90-point sync score)
- External orchestration (optional): oh-my-claudecode(OMC), Ouroboros

────────────────────────────────────
CORE RULES
────────────────────────────────────

- Do not create files arbitrarily without diagnosis results.
- Automatic execution is performed only when the user explicitly consents.
- This skill does not analyze requirements directly. Analysis is always done by `/ctx-aidlc-run`.
- This skill does not write code. Implementation is always done by `/ctx-domain-exec` (or an OMC/Ouroboros handoff).
- Respond to the user in Korean. Keep code/commands in English.

────────────────────────────────────
DIAGNOSIS CHECKLIST
────────────────────────────────────

At startup, check the following in order and report all results at once.

A. Estimate the team-ai-workflow core location
   - Priority:
     1. Environment variable `TEAM_AI_WORKFLOW_DIR`
     2. `~/workspace/team-ai-workflow`
     3. `~/work/team-ai-workflow`
     4. `~/.team-ai-workflow`
   - If `scripts/install-skills.sh` exists in one of the above, adopt that path.
   - If none exist, the state is "core not installed".

B. Whether skills are installed globally
   - Check whether `~/.claude/commands/ctx-aidlc-run.md` exists.
   - Check whether `~/.codex/skills/ctx-aidlc-run/SKILL.md` exists (optional).

C. Whether the current project is initialized (based on the current working directory)
   - Whether `ctx/INDEX.md`, `ctx/project-profile.ctx.md` exist.
   - Whether `aidlc-docs/aidlc-state.md` exists.
   - Whether `CLAUDE.md` or `AGENTS.md` exists.

D. Existing work progress state
   - `aidlc-docs/_roadmap.md` exists → multi-feature mode
   - `aidlc-docs/features/*/status.md` exists → extract the list of in-progress features

E. External orchestration detection (optional)
   - `.omc/` directory exists → OMC may be in use
   - `.ouroboros/` or Ouroboros-related files exist → Ouroboros may be in use

F. Code graph prerequisites (Hallucination Guard — recommended substrate)
   - Run `bash <core-path>/scripts/check-graphify.sh .` and read the exit code.
   - 0 = satisfied (graphify + `graphify-out/graph.json`), 2 = tool missing (→ degraded possible), 3 = brownfield graph not built.
   - graphify is strongly recommended but not mandatory. Without it, VERIFY degrades to grep/Read
     (`common/graph-grounding.md`). Evaluate this check **before all other routing** (see CASE 0).

────────────────────────────────────
REPORT FORMAT
────────────────────────────────────

Output the diagnosis results in the following format
(render headings/labels in Korean at runtime, per the response-language rule in CORE RULES).

```markdown
## team-ai-workflow diagnosis

### Environment
- Core location: <path or "not installed">
- Global skills: <installed / not installed>
- Code graph prerequisites: <satisfied / graphify tool missing (degraded possible) / graph not built>
- External integration: <OMC detected / Ouroboros detected / none>

### Current project (<cwd>)
- Initialization state: <complete / partial / not initialized>
- In-progress features: <N / none>
- multi-feature mode: <yes / no>

### Next-step candidates
1. <recommended command for the situation>
2. <alternative>
3. <alternative>
```

────────────────────────────────────
ROUTING DECISION TREE
────────────────────────────────────

Based on the diagnosis results, recommend one of the following to the user.

CASE 0: Code graph prerequisites not satisfied (evaluate before every other case — non-blocking)
- Condition: apply when diagnosis F reports that `graphify` is missing (exit code 2).
  If only the graph is missing on a brownfield project (code 3), the tool is
  available; build it with `graphify .` and make the check pass.
- graphify is the guard's preferred VERIFY substrate but is NOT mandatory. Setup and
  routing may proceed in DEGRADED mode, where VERIFY falls back to grep/Read per
  `common/graph-grounding.md` (dev facts are marked `⚠️ UNCERTAIN` more aggressively).
- Response: first state clearly that graphify is missing and that the guard will run in
  DEGRADED mode unless installed. Then use an **AskUserQuestion dialog, not free text**,
  to ask which to do:
    (1) install graphify now, (2) proceed in degraded mode, or (3) cancel.
  - Read and present the installation command exactly from the `MISSING:` line
    emitted by `check-graphify.sh` (graphify: `uv tool install "graphifyy[mcp]"`).
  - If the user **explicitly approves** option (1), run the install command and
    `graphify .` with Bash, then rerun `check-graphify.sh` and continue once it passes
    (code 0). Never execute automatically without approval (skill-protocol Execution Boundary).
  - If the user chooses option (2), record `Hallucination Guard Mode: degraded` in
    `aidlc-docs/aidlc-state.md` (create/update the field) and continue to the next case.
  - If the user chooses option (3), stop and wait.
- Rationale: the guard's VERIFY step prefers the code graph, but a missing tool must not
  block a team from using the workflow — it degrades, it does not fail.

CASE 1: Core not installed
- Guidance: "You must clone the team-ai-workflow core first."
- Recommended command:
  ```bash
  git clone https://github.com/TaeseongYun/aidlc-workflow.git ~/workspace/aidlc-workflow
  echo 'export TEAM_AI_WORKFLOW_DIR="$HOME/workspace/aidlc-workflow"' >> ~/.zshrc
  bash ~/workspace/aidlc-workflow/scripts/install-skills.sh
  ```
  (Diagnosis A finds the core via `TEAM_AI_WORKFLOW_DIR` — the env line makes the clone path detectable.)
- No automatic execution. Run with the Bash tool only upon user approval.

CASE 2: Core exists but global skills are not installed
- Recommended command:
  ```bash
  bash <core-path>/scripts/install-skills.sh
  ```
- Automatic execution allowed upon user approval.

CASE 3: Global skills exist but the current project is not initialized
- Recommended command:
  ```bash
  bash <core-path>/scripts/init-project.sh
  ```
- After automatic execution, propose auto-filling `ctx/INDEX.md` to the user.

CASE 4: Initialization complete, multi-feature planning document present
- Recommendation: `/ctx-aidlc-roadmap`

CASE 5: Approved multi-feature roadmap has a parallel execution phase
- Recommendation: `/ctx-worktree`
- The skill must show the allocation plan and wait for approval before creation.

CASE 6: Initialization complete, single-feature requirements present
- Recommendation: `/ctx-aidlc-run`

CASE 7: requirements.md approval complete, implementation stage
- Recommendation: `/ctx-architect-judge` → `/ctx-domain-exec`, or an OMC/Ouroboros handoff (Pattern 1~3 below)

CASE 8: Multiple in-progress features
- Ask the user which feature to continue with, and guide them to read that status.md first.

CASE 9: Implementation complete, automatic iterative quality scoring needed
- Recommendation: `/ctx-score-loop <feature-slug>`
- Condition: that feature must have passed GATE-3 (implementation approval).
  It autonomously iterates dependency/4-axis verification until the score exceeds 85,
  and does not auto-pass GATEs.

────────────────────────────────────
EXTERNAL ORCHESTRATION (OMC / Ouroboros)
────────────────────────────────────

team-ai-workflow handles the "What" of requirements analysis/design; OMC or
Ouroboros handles the "How" of automated execution. Three handoff patterns
(details, configuration, and diagrams: `{{TEAM_AI_WORKFLOW_DIR}}/docs/omc-ouroboros-integration.md`):

| Pattern | When | Handoff (after human GATEs) |
|---|---|---|
| 1. OMC autopilot | full implementation automation | GATE-2/3 passed → `/oh-my-claudecode:autopilot` on `requirements.md` + `unit-of-work.md` |
| 2. Ouroboros evolve | measurable goal (tests, metrics) | `/ouroboros:seed` from requirements → `/ouroboros:evolve`; UOW Acceptance Criteria = Seed verification |
| 3. OMC ralph | small (S size) single feature | GATE-3 passed → `/oh-my-claudecode:ralph`; UOW verification = termination condition |

Precautions: GATE approval is always human — OMC/Ouroboros never auto-pass one.
`audit.md` stays append-only for both systems (team-ai-workflow's rule wins on
conflict). `.omc/state/` and Ouroboros session state live outside `aidlc-docs/`.

────────────────────────────────────
CROSS-ACCOUNT / CROSS-REPO PORTABILITY
────────────────────────────────────

Same commands on any account/repo — full checklist in the README ("Using It on
Other Accounts/Repos") and `{{TEAM_AI_WORKFLOW_DIR}}/docs/omc-ouroboros-integration.md`:

1. One core clone location, pointed to by `TEAM_AI_WORKFLOW_DIR` in the shell rc.
2. Global install per account home: `CLAUDE_HOME=... CODEX_HOME=... bash "$TEAM_AI_WORKFLOW_DIR/scripts/install-skills.sh"` (idempotent; prunes removed skills).
3. Per repo, once: `bash "$TEAM_AI_WORKFLOW_DIR/scripts/init-project.sh"`.
4. To update: `git pull` in the core, then re-run the install script.

────────────────────────────────────
EXECUTION FLOW
────────────────────────────────────

STEP 1. Perform diagnosis
- Run the DIAGNOSIS CHECKLIST above all at once with Bash, including the
  `check-graphify.sh` command in diagnosis F.
- Output the results in the REPORT FORMAT.

STEP 1.5. Code graph check (CASE 0 — non-blocking)
- If diagnosis F reports a missing tool (exit code 2), present the CASE 0
  AskUserQuestion dialog (install / proceed in degraded mode / cancel). Only a
  cancel choice stops here; install or degraded both continue to STEP 2.
- If only the graph is missing on brownfield (code 3), run `graphify .` and continue.

STEP 1.7. Recall prior run results (non-blocking)
- Before routing, surface earlier results so the session has continuity. When a graph is
  present, prefer `graphify query "<question>"`; otherwise read the local structured log:
  `npx tsx {{TEAM_AI_WORKFLOW_DIR}}/scripts/run-logger.ts recall --project . --limit 20`
- Protocol: `{{TEAM_AI_WORKFLOW_DIR}}/common/run-logging.md`. Skip silently if `aidlc-docs/` is absent.

STEP 2. Confirm intent
- Ask the user in one line what they explicitly want to do. Example:
  - "Is the task you want to do this time (a) new feature requirements analysis
    (b) decomposing a large planning document (c) allocating approved roadmap
    features to worktrees (d) implementing approved requirements (e) environment setup?"
- Branch to the appropriate case in the ROUTING DECISION TREE based on the user's answer.

STEP 3. Routing
- Output the recommended command as a code block, and inform the user that when they enter that command
  the corresponding skill runs automatically.
- If environment setup is needed, propose the setup command first. Run with Bash upon user approval.

STEP 4. External orchestration guidance (optional)
- If OMC/Ouroboros was detected in the diagnosis or the user asks,
  recommend the appropriate one among Patterns 1–3 in the EXTERNAL ORCHESTRATION section.
- When recommending, always state that "GATE approval is done by a human".

────────────────────────────────────
WHEN TO STOP
────────────────────────────────────

In the following situations, do not proceed and wait for user input.
- graphify is missing (CASE 0): present the AskUserQuestion dialog (install /
  degraded / cancel) before routing. Only a cancel choice stops the flow; do not
  accept a free-text "continue" prompt in place of the dialog. Install or degraded
  both continue.
- Do not auto-execute core cloning, global installation, or project initialization before explicit user approval.
- There are 2 or more in-progress features but the user has not specified which one to continue with.
- Request for automatic execution of external orchestration. This skill only routes; the actual invocation
  is done explicitly by the user.

────────────────────────────────────
NON-GOALS
────────────────────────────────────

- Requirements analysis/question extraction (→ `/ctx-aidlc-run`)
- Multi-feature roadmap authoring (→ `/ctx-aidlc-roadmap`)
- Implementation/test/review (→ `/ctx-domain-exec`, `/ctx-reviewer` and the other ctx-* skills)
- Applying CTX reflection proposals to CTX documents (→ `/ctx-updater`)
- Direct invocation of external systems (the user invokes them with a separate skill)
