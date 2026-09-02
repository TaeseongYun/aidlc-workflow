---
description: Entry point for team-ai-workflow on any account/repo. Detects state, sets up if needed, and routes to ctx-aidlc-roadmap / ctx-worktree / ctx-aidlc-run / ctx-run. Also bridges to oh-my-claudecode and Ouroboros workflows.
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
- team-ai-workflow core: `/ctx-aidlc-roadmap`, `/ctx-worktree`, `/ctx-aidlc-run`, `/ctx-run`
- Auxiliary skills: `/ctx-architect-judge`, `/ctx-domain-exec`, `/ctx-reviewer`,
  `/ctx-updater`, `/ctx-refiner`, `/ctx-commit-planner`
- Post-implementation automatic scoring loop: `/ctx-score-loop` (only for features
  that pass GATE-3; autonomously iterates dependency/4-axis verification until the
  score exceeds 85)
- External orchestration (optional): oh-my-claudecode(OMC), Ouroboros

────────────────────────────────────
CORE RULES
────────────────────────────────────

- Do not create files arbitrarily without diagnosis results.
- Automatic execution is performed only when the user explicitly consents.
- This skill does not analyze requirements directly. Analysis is always done by `/ctx-aidlc-run`.
- This skill does not write code. Implementation is always done by `/ctx-run`.
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

F. 코드 그래프 전제조건 (Hallucination Guard — 권장 substrate)
   - `bash <본체경로>/scripts/check-graphify.sh .` 를 실행하고 종료코드를 읽는다.
   - 0 = 충족(graphify + `graphify-out/graph.json`), 2 = 도구 누락(→ degraded 가능), 3 = brownfield 그래프 미생성.
   - graphify는 강력히 권장되지만 필수는 아니다. 없으면 VERIFY가 grep/Read로 degrade된다
     (`common/graph-grounding.md`). 이 검사는 **다른 라우팅보다 먼저** 평가한다 (CASE 0 참조).

────────────────────────────────────
REPORT FORMAT
────────────────────────────────────

Output the diagnosis results in the following format.

```markdown
## team-ai-workflow 진단

### 환경
- 본체 위치: <경로 또는 "미설치">
- 글로벌 스킬: <설치됨 / 미설치>
- 코드 그래프 전제조건: <충족 / graphify 도구 누락(degraded 가능) / 그래프 미생성>
- 외부 연동: <OMC 감지 / Ouroboros 감지 / 없음>

### 현재 프로젝트 (<cwd>)
- 초기화 상태: <완료 / 부분 / 미초기화>
- 진행 중 feature: <N개 / 없음>
- multi-feature 모드: <yes / no>

### 다음 단계 후보
1. <상황별 권장 명령>
2. <대안>
3. <대안>
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
  bash ~/workspace/aidlc-workflow/scripts/install-skills.sh
  ```
- No automatic execution. Run with the Bash tool only upon user approval.

CASE 2: Core exists but global skills are not installed
- Recommended command:
  ```bash
  bash <본체경로>/scripts/install-skills.sh
  ```
- Automatic execution allowed upon user approval.

CASE 3: Global skills exist but the current project is not initialized
- Recommended command:
  ```bash
  bash <본체경로>/scripts/init-project.sh
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
- Recommendation: `/ctx-run`

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

team-ai-workflow handles the "What" of requirements analysis/design.
The "How" of execution automation/iteration loops is handled by OMC or Ouroboros.
The two do not conflict. Connect them with the following patterns.

### Pattern 1 — Full automation to the end with OMC autopilot

```text
사용자 요청
  ↓
/team-ai-workflow-start   ← 진단 + 라우팅
  ↓
/ctx-aidlc-run            ← 요구사항/설계 (사람 GATE)
  ↓ (GATE-2/3 통과)
/oh-my-claudecode:autopilot ← 구현/테스트/검증 자동 반복
```

OMC autopilot takes `aidlc-docs/features/<slug>/requirements.md` and
`unit-of-work.md` as input and performs the implementation.

### Pattern 2 — Evolutionary implementation with Ouroboros evolve

```text
/ctx-aidlc-run            ← Seed가 될 requirements 생성
  ↓
/ouroboros:seed            ← requirements.md → Seed spec
  ↓
/ouroboros:evolve          ← 진화 루프
```

Ouroboros is most effective when there is a measurable goal (test pass rate,
performance metrics, etc.). It uses the Acceptance Criteria of `unit-of-work.md`
as the Seed's verification.

### Pattern 3 — Complete a single feature with the ralph loop

```text
/ctx-aidlc-run            ← requirements + UOW 확정
  ↓ (GATE-3 통과)
/oh-my-claudecode:ralph   ← 검증 통과까지 반복 실행
```

Suitable for small (S size) features. Use the UOW's verification method as ralph's
termination condition.

### Precautions when connecting

- GATE approval is always done by a human. OMC/Ouroboros does not auto-pass GATEs.
- `audit.md` is respected as append-only by both systems. In case of conflict,
  team-ai-workflow's audit rule takes precedence.
- OMC's `.omc/state/` and Ouroboros's session state are kept in a space separate
  from `aidlc-docs/`. They do not overwrite each other.

────────────────────────────────────
CROSS-ACCOUNT / CROSS-REPO PORTABILITY
────────────────────────────────────

Checklist for operating identically across different accounts and different repositories.

1. **Unify the core clone location.** Recommended: `~/workspace/team-ai-workflow`.
   If using a different location, specify it with the `TEAM_AI_WORKFLOW_DIR` environment variable.

   ```bash
   echo 'export TEAM_AI_WORKFLOW_DIR="$HOME/work/team-ai-workflow"' >> ~/.zshrc
   ```

2. **Skills must be installed globally.**

   ```bash
   bash "$TEAM_AI_WORKFLOW_DIR/scripts/install-skills.sh"
   ```

   After installation, `ctx-*.md` files are created in `~/.claude/commands/`.

3. **When switching accounts**, global skills are based on the user's home directory, so they are retained as-is.
   However, if using Claude Code multi-account, you must install identically under `~/.claude-personal/` or
   a separate home path.

4. **When switching repositories**, run `init-project.sh` once in each repo.

   ```bash
   cd /path/to/new-repo
   bash "$TEAM_AI_WORKFLOW_DIR/scripts/init-project.sh"
   ```

5. **To update the core**, reinstall after `git pull`.

   ```bash
   cd "$TEAM_AI_WORKFLOW_DIR" && git pull
   bash scripts/install-skills.sh
   ```

   `install-skills.sh` is idempotent, so it is safe to run multiple times.

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
- Implementation/test/review (→ `/ctx-run` and its sub-skills)
- Automatic code modification (→ `/ctx-updater`)
- Direct invocation of external systems (the user invokes them with a separate skill)
