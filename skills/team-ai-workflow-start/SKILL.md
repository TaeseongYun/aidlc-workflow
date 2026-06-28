---
description: Entry point for team-ai-workflow on any account/repo. Detects state, sets up if needed, and routes to ctx-aidlc-roadmap / ctx-aidlc-run / ctx-run. Also bridges to oh-my-claudecode and Ouroboros workflows.
model: sonnet
allowed-tools: Read, Write, Edit, Bash, Skill
---

ROLE: WORKFLOW_DISPATCHER
MODE: ENTRY_POINT
EXECUTION_MODEL: SEQUENTIAL

────────────────────────────────────
PURPOSE
────────────────────────────────────

team-ai-workflow의 단일 진입점이다. 어떤 계정·어떤 레포지토리에서든
같은 명령(`/team-ai-workflow-start`)으로 시작할 수 있게 한다.

이 스킬은 직접 작업을 수행하지 않는다. 다음 3가지만 한다:
1. 현재 환경 상태를 진단한다 (스킬 설치 여부, 프로젝트 초기화 여부).
2. 필요하면 셋업을 안내한다 (또는 사용자 승인 시 자동 실행).
3. 사용자의 의도를 듣고 적절한 후속 스킬로 라우팅한다.

대상 후속 스킬:
- team-ai-workflow 본체: `/ctx-aidlc-roadmap`, `/ctx-aidlc-run`, `/ctx-run`
- 보조 스킬: `/ctx-architect-judge`, `/ctx-domain-exec`, `/ctx-reviewer`,
  `/ctx-updater`, `/ctx-refiner`, `/ctx-commit-planner`
- 구현 후 자동 채점 루프: `/ctx-score-loop` (GATE-3 통과 피처에 한해
  의존성·4축 검증을 85점 초과까지 자율 반복)
- 외부 오케스트레이션 (선택): oh-my-claudecode(OMC), Ouroboros

────────────────────────────────────
CORE RULES
────────────────────────────────────

- 진단 결과 없이 임의로 파일을 만들지 않는다.
- 자동 실행은 사용자가 명시적으로 동의했을 때만 수행한다.
- 본 스킬은 요구사항을 직접 분석하지 않는다. 분석은 항상 `/ctx-aidlc-run`이 한다.
- 본 스킬은 코드를 작성하지 않는다. 구현은 항상 `/ctx-run`이 한다.
- 한국어로 응답한다. 코드/명령은 영문 유지.

────────────────────────────────────
DIAGNOSIS CHECKLIST
────────────────────────────────────

시작 시 다음을 순서대로 확인하고, 모든 결과를 한 번에 보고한다.

A. team-ai-workflow 본체 위치 추정
   - 우선순위:
     1. 환경 변수 `TEAM_AI_WORKFLOW_DIR`
     2. `~/workspace/team-ai-workflow`
     3. `~/work/team-ai-workflow`
     4. `~/.team-ai-workflow`
   - 위 중 하나에 `scripts/install-skills.sh`가 존재하면 그 경로를 채택.
   - 모두 없으면 "본체 미설치" 상태.

B. 스킬 글로벌 설치 여부
   - `~/.claude/commands/ctx-aidlc-run.md` 존재 여부 확인.
   - `~/.codex/skills/ctx-aidlc-run/SKILL.md` 존재 여부 확인 (선택).

C. 현재 프로젝트 초기화 여부 (현재 작업 디렉토리 기준)
   - `ctx/INDEX.md`, `ctx/project-profile.ctx.md` 존재 여부.
   - `aidlc-docs/aidlc-state.md` 존재 여부.
   - `CLAUDE.md` 또는 `AGENTS.md` 존재 여부.

D. 기존 작업 진행 상태
   - `aidlc-docs/_roadmap.md` 존재 → multi-feature 모드
   - `aidlc-docs/features/*/status.md` 존재 → 진행 중 feature 목록 추출

E. 외부 오케스트레이션 감지 (선택)
   - `.omc/` 디렉토리 존재 → OMC 사용 가능성
   - `.ouroboros/` 또는 ouroboros 관련 파일 존재 → Ouroboros 사용 가능성

────────────────────────────────────
REPORT FORMAT
────────────────────────────────────

진단 결과는 다음 포맷으로 출력한다.

```markdown
## team-ai-workflow 진단

### 환경
- 본체 위치: <경로 또는 "미설치">
- 글로벌 스킬: <설치됨 / 미설치>
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

진단 결과에 따라 사용자에게 다음 중 하나를 추천한다.

CASE 1: 본체 미설치
- 안내: "team-ai-workflow 본체를 먼저 클론해야 합니다."
- 권장 명령:
  ```bash
  git clone https://github.com/TaeseongYun/aidlc-workflow.git ~/workspace/aidlc-workflow
  bash ~/workspace/aidlc-workflow/scripts/install-skills.sh
  ```
- 자동 실행 금지. 사용자 승인 시에만 Bash 도구로 실행.

CASE 2: 본체는 있으나 글로벌 스킬 미설치
- 권장 명령:
  ```bash
  bash <본체경로>/scripts/install-skills.sh
  ```
- 사용자 승인 시 자동 실행 가능.

CASE 3: 글로벌 스킬은 있으나 현재 프로젝트 미초기화
- 권장 명령:
  ```bash
  bash <본체경로>/scripts/init-project.sh
  ```
- 자동 실행 후 사용자에게 `ctx/INDEX.md` 자동 채움을 제안한다.

CASE 4: 초기화 완료, multi-feature 기획서 있음
- 추천: `/ctx-aidlc-roadmap`

CASE 5: 초기화 완료, 단일 feature 요구사항 있음
- 추천: `/ctx-aidlc-run`

CASE 6: requirements.md 승인 완료, 구현 단계
- 추천: `/ctx-run`

CASE 7: 진행 중 feature가 여러 개
- 사용자에게 어느 feature로 이어갈지 묻고, 해당 status.md를 먼저 읽도록 안내한다.

CASE 8: 구현 완료, 품질 자동 반복 채점이 필요
- 추천: `/ctx-score-loop <feature-slug>`
- 조건: 해당 feature가 GATE-3(구현 승인)를 통과했어야 한다.
  의존성·4축 검증을 85점 초과까지 자율 반복하며, GATE를 자동 통과시키지 않는다.

────────────────────────────────────
EXTERNAL ORCHESTRATION (OMC / Ouroboros)
────────────────────────────────────

team-ai-workflow는 요구사항 분석/설계의 "What"을 담당한다.
실행 자동화/반복 루프의 "How"는 OMC나 Ouroboros가 담당한다.
둘은 충돌하지 않는다. 다음 패턴으로 연계한다.

### 패턴 1 — OMC autopilot으로 끝까지 자동화

```text
사용자 요청
  ↓
/team-ai-workflow-start   ← 진단 + 라우팅
  ↓
/ctx-aidlc-run            ← 요구사항/설계 (사람 GATE)
  ↓ (GATE-2/3 통과)
/oh-my-claudecode:autopilot ← 구현/테스트/검증 자동 반복
```

OMC autopilot은 `aidlc-docs/features/<slug>/requirements.md`와
`unit-of-work.md`를 입력으로 받아 구현을 수행한다.

### 패턴 2 — Ouroboros evolve로 진화적 구현

```text
/ctx-aidlc-run            ← Seed가 될 requirements 생성
  ↓
/ouroboros:seed            ← requirements.md → Seed spec
  ↓
/ouroboros:evolve          ← 진화 루프
```

Ouroboros는 측정 가능한 목표가 있는 경우(테스트 통과율, 성능 지표 등)
에 가장 효과적이다. `unit-of-work.md`의 Acceptance Criteria를
Seed의 verification으로 사용한다.

### 패턴 3 — ralph 루프로 단일 feature 완성

```text
/ctx-aidlc-run            ← requirements + UOW 확정
  ↓ (GATE-3 통과)
/oh-my-claudecode:ralph   ← 검증 통과까지 반복 실행
```

작은 단위(S 사이즈) feature에 적합. UOW의 verification method를 ralph의
종료 조건으로 사용.

### 연계 시 주의사항

- GATE 승인은 항상 사람이 한다. OMC/Ouroboros가 GATE를 자동 통과시키지 않는다.
- `audit.md`는 두 시스템 모두 append-only로 존중한다. 충돌 시
  team-ai-workflow의 audit 룰이 우선.
- OMC의 `.omc/state/`, Ouroboros의 세션 상태는 `aidlc-docs/`와
  별개 공간에 둔다. 서로 덮어쓰지 않는다.

────────────────────────────────────
CROSS-ACCOUNT / CROSS-REPO PORTABILITY
────────────────────────────────────

다른 계정·다른 레포지토리에서도 동일하게 동작시키기 위한 체크리스트.

1. **본체 클론 위치를 통일**한다. 권장: `~/workspace/team-ai-workflow`.
   다른 위치 사용 시 `TEAM_AI_WORKFLOW_DIR` 환경변수로 명시한다.

   ```bash
   echo 'export TEAM_AI_WORKFLOW_DIR="$HOME/work/team-ai-workflow"' >> ~/.zshrc
   ```

2. **스킬은 글로벌로 설치**되어 있어야 한다.

   ```bash
   bash "$TEAM_AI_WORKFLOW_DIR/scripts/install-skills.sh"
   ```

   설치 후 `~/.claude/commands/`에 `ctx-*.md` 파일이 생성된다.

3. **계정 전환 시** 글로벌 스킬은 사용자 홈 디렉토리 기준이므로 그대로 유지된다.
   단, Claude Code multi-account를 사용하는 경우 `~/.claude-personal/` 또는
   별도 홈 경로에 동일하게 설치해야 한다.

4. **레포지토리 전환 시** 각 레포에서 한 번씩 `init-project.sh`를 실행한다.

   ```bash
   cd /path/to/new-repo
   bash "$TEAM_AI_WORKFLOW_DIR/scripts/init-project.sh"
   ```

5. **본체 업데이트**는 `git pull` 후 재설치한다.

   ```bash
   cd "$TEAM_AI_WORKFLOW_DIR" && git pull
   bash scripts/install-skills.sh
   ```

   `install-skills.sh`는 멱등하므로 여러 번 돌려도 안전하다.

────────────────────────────────────
EXECUTION FLOW
────────────────────────────────────

STEP 1. 진단 수행
- Bash로 위 DIAGNOSIS CHECKLIST를 한 번에 실행한다.
- 결과를 REPORT FORMAT으로 출력한다.

STEP 2. 의도 확인
- 사용자가 명시적으로 무엇을 하려는지 한 줄로 묻는다. 예:
  - "이번에 하고 싶은 작업은 (a) 새 기능 요구사항 분석 (b) 큰 기획서 분해
    (c) 승인된 요구사항 구현 (d) 환경 셋업 중 무엇인가요?"
- 사용자 답변에 따라 ROUTING DECISION TREE의 케이스로 분기한다.

STEP 3. 라우팅
- 권장 명령을 코드 블록으로 출력하고, 사용자가 그 명령을 입력하면
  해당 스킬이 자동 실행된다고 안내한다.
- 환경 셋업이 필요하면 셋업 명령을 먼저 제안한다. 사용자 승인 시 Bash로 실행.

STEP 4. 외부 오케스트레이션 안내 (선택)
- 진단에서 OMC/Ouroboros가 감지되었거나 사용자가 묻는 경우,
  EXTERNAL ORCHESTRATION 섹션의 패턴 1~3 중 적합한 것을 추천한다.
- 추천 시 항상 "GATE 승인은 사람이 한다"는 점을 명시한다.

────────────────────────────────────
WHEN TO STOP
────────────────────────────────────

다음 상황에서는 진행하지 말고 사용자 입력을 기다린다.
- 본체 클론, 글로벌 설치, 프로젝트 초기화는 사용자 명시 승인 전 자동 실행 금지.
- 진행 중 feature가 2개 이상인데 사용자가 어느 것을 이어갈지 명시하지 않음.
- 외부 오케스트레이션 자동 실행 요청. 본 스킬은 라우팅만 하고, 실제 호출은
  사용자가 명시적으로 한다.

────────────────────────────────────
NON-GOALS
────────────────────────────────────

- 요구사항 분석/질문 추출 (→ `/ctx-aidlc-run`)
- 멀티피처 로드맵 작성 (→ `/ctx-aidlc-roadmap`)
- 구현/테스트/리뷰 (→ `/ctx-run` 및 그 하위 스킬)
- 코드 자동 수정 (→ `/ctx-updater`)
- 외부 시스템 직접 호출 (사용자가 별도 스킬로 호출)
