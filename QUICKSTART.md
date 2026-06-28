# Quick Start

AI 요구사항 분석/설계/검증 워크플로우를 프로젝트에 적용하기 위한 가이드이다.
앱/백엔드/프론트 구분 없이 모든 프로젝트에서 공용으로 사용 가능하다.

> **TL;DR** — `/team-ai-workflow-start`만 외우면 된다. 어디서 시작할지 모를 때 부르면
> 진단 후 적절한 후속 명령을 알려준다.

## 1. repo 클론 (최초 1회)

```bash
git clone https://github.com/TaeseongYun/aidlc-workflow.git ~/workspace/aidlc-workflow

# 다른 위치에 클론했다면 환경변수로 알려줘야 한다.
echo 'export TEAM_AI_WORKFLOW_DIR="$HOME/workspace/aidlc-workflow"' >> ~/.zshrc
source ~/.zshrc
```

## 2. 스킬 설치 (최초 1회, 계정마다)

```bash
bash ~/workspace/aidlc-workflow/scripts/install-skills.sh
```

`/team-ai-workflow-start`, `/ctx-aidlc-run`, `/ctx-run` 등 스킬이 글로벌로 설치된다.

**multi-account 환경** (예: Claude Code 부계정 `~/.claude-personal/`)에서는
환경변수로 대상 홈을 바꿔 한 번 더 실행한다.

```bash
CLAUDE_HOME="$HOME/.claude-personal" CODEX_HOME="$HOME/.codex-personal" \
  bash ~/workspace/aidlc-workflow/scripts/install-skills.sh
```

스크립트는 멱등하므로 본체를 업데이트한 후에도 안전하게 재실행 가능하다.

## 3. 프로젝트 초기화 (프로젝트마다 1회)

```bash
cd my-project
bash ~/workspace/aidlc-workflow/scripts/init-project.sh
```

`ctx/`, `aidlc-docs/`, `CLAUDE.md`가 자동 생성된다.

생성되는 구조:

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

## 4. 프로젝트 정보 채우기

프로젝트에서 Claude Code를 열고 아래 명령어를 입력한다.

```text
ctx/INDEX.md, ctx/project-profile.ctx.md 프로젝트 분석해서 채워줘
```

Claude가 프로젝트 구조, 스택, 모듈 등을 자동으로 파악해서 채워준다.

## 5. 사용법

### 어디서 시작할지 모를 때

```text
/team-ai-workflow-start
```

현재 환경(본체 위치, 스킬 설치, 프로젝트 초기화, 진행 중 feature, OMC/Ouroboros 감지)을
진단하고 다음에 해야 할 명령을 알려준다.

### 메인 스킬 3종

```text
/ctx-aidlc-roadmap → (멀티피처일 때) 큰 prepared 기획서를 피처로 분해 + GATE-0
/ctx-aidlc-run     → 요구사항 분석 + 질문 추출 (피처 단위)
/ctx-run           → 승인된 요구사항 기준 구현
```

### OMC / Ouroboros 연동

requirements가 승인(GATE-2/3 통과)되면 구현을 OMC autopilot/ralph나 Ouroboros evolve에
넘길 수 있다. 상세 패턴: [docs/omc-ouroboros-integration.md](docs/omc-ouroboros-integration.md)

### 코드 절제 (ponytail)

구현 단계에서 코드량을 줄이고 싶으면 [ponytail](https://github.com/DietrichGebert/ponytail)의
7단계 절제 사다리를 함께 쓴다. `/ctx-run`이 [core/lazy-implementation.md](core/lazy-implementation.md)를
근거로 ROLE 1/3에서 자동 적용하므로 플러그인 설치 없이도 동작한다. 상세: [docs/ponytail-integration.md](docs/ponytail-integration.md)

### 요구사항 분석

```text
/ctx-aidlc-run

이번 요구사항을 team-ai-workflow 기준으로 분석해라.

Feature:
- (여기에 요구사항 입력)
```

### 멀티피처 (큰 prepared 기획서)

기획서가 여러 피처로 분해되어 팀 분업이 필요하면 `/ctx-aidlc-run` 대신 먼저 로드맵을 만든다.

```text
/ctx-aidlc-roadmap

다음 prepared-requirement 기획서로 Phase 0 로드맵을 작성한다.
- 원본: <기획서 경로 또는 본문>
```

GATE-0 승인 후 `aidlc-docs/_roadmap.md`가 생성되고, 각 팀원이 자기 피처에 대해 `/ctx-aidlc-run`을 실행한다. 단일 피처라면 STEP R1에서 자동 스킵된다.

상세 운용: [docs/multi-feature-coordination.md](docs/multi-feature-coordination.md)

실행 후 `aidlc-docs/features/<feature-slug>/` 아래에 산출물이 생성된다:
- `status.md` — 현재 상태
- `requirements.md` — 요구사항 정리
- `requirement-verification-questions.md` — 미결 질문 목록
- `unit-of-work.md` — 작업 단위 분해

### 질문 답변 후 구현

`requirement-verification-questions.md`에서 BLOCK 상태인 질문에 답변한 뒤:

```text
/ctx-run

aidlc-docs와 ctx에 승인된 내용 기준으로 구현해라.

Feature:
- (구현할 feature 입력)
```

## 세션 분리

대규모 기능은 Phase 단위로 세션을 나눠야 품질이 유지된다.
- **Phase A** (Discovery): STEP 1~3 → GATE-1 통과 후 세션 종료
- **Phase B** (Definition): STEP 4~6 → GATE-3 통과 후 세션 종료  
- **Phase C** (Design): STEP 6.5~9 → GATE-5 통과 후 세션 종료

적용 기준: minimal=선택, standard=권장, comprehensive=**필수**

상세: [docs/workflow-guide.md](docs/workflow-guide.md#세션-분리-기본-실행-모델)

## 다음 단계

- 상세 워크플로우: [docs/workflow-guide.md](docs/workflow-guide.md)
- 핵심 개념: [docs/concepts.md](docs/concepts.md)
- FAQ / 체크리스트: [docs/faq.md](docs/faq.md)
