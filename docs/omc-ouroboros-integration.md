# OMC · Ouroboros 연동 가이드

team-ai-workflow은 "**무엇을 만들 것인가**"를 결정하는 워크플로우다.
`oh-my-claudecode`(OMC)와 Ouroboros는 "**어떻게 자동으로 굴릴 것인가**"를 담당하는 오케스트레이션 레이어다.
두 영역을 분리해 사용하면 동일한 요구사항 산출물을 여러 실행 전략으로 돌릴 수 있다.

```text
┌────────────────────────────┐    ┌──────────────────────────┐
│ team-ai-workflow           │    │ OMC / Ouroboros          │
│ - 요구사항 분석             │    │ - 자동화 루프            │
│ - 멀티피처 로드맵           │ →  │ - 진화적 구현            │
│ - UOW 분해                  │    │ - 반복 검증              │
│ - 사람 GATE                 │    │ - 병렬 에이전트           │
└────────────────────────────┘    └──────────────────────────┘
        (What)                            (How)
```

GATE 승인은 항상 사람이 한다. OMC/Ouroboros가 GATE를 자동 통과시키지 않는다.

---

## 1. 진입점: `/team-ai-workflow-start`

새 계정·새 레포에서 처음 시작할 때 이 스킬을 부르면 다음을 자동 진단한다.

- 본체 클론 위치 (`$TEAM_AI_WORKFLOW_DIR` 또는 표준 경로)
- 글로벌 스킬 설치 상태
- 현재 프로젝트 `ctx/` · `aidlc-docs/` 초기화 상태
- 진행 중 feature 목록
- `.omc/` · `.ouroboros/` 디렉토리 감지

진단 후 적절한 후속 명령(`/ctx-aidlc-roadmap`, `/ctx-aidlc-run`, `/ctx-run`,
또는 OMC/Ouroboros 핸드오프)을 추천한다.

```text
/team-ai-workflow-start
```

---

## 2. team-ai-workflow → OMC 패턴

### 2-1. autopilot — 끝까지 자동 실행

```text
사용자 요청
  ↓
/ctx-aidlc-run                ← 요구사항/설계 (GATE-2/3 사람 승인)
  ↓
/oh-my-claudecode:autopilot   ← 구현 → 테스트 → 검증 자동 반복
```

OMC autopilot 호출 시 입력 컨텍스트로 다음을 전달한다.

- `aidlc-docs/features/<slug>/requirements.md`
- `aidlc-docs/features/<slug>/unit-of-work.md`
- `aidlc-docs/features/<slug>/technical-design.md` (M/L 사이즈 시)
- `ctx/INDEX.md`, `ctx/project-profile.ctx.md`

권장 호출 예:

```text
/oh-my-claudecode:autopilot

다음 산출물 기반으로 구현해라. GATE-3 통과한 상태.
- aidlc-docs/features/coupon-feature/requirements.md
- aidlc-docs/features/coupon-feature/unit-of-work.md

unit-of-work.md의 각 UOW Acceptance Criteria가 통과할 때까지 반복.
구현 후 ctx-reviewer로 검증할 것.
```

### 2-2. ralph — 단일 feature 완성 루프

S 사이즈(작은 단위) feature에 적합. UOW의 verification method를 종료 조건으로 사용한다.

```text
/ctx-aidlc-run                ← UOW 1~2개로 분해 (S 사이즈만)
  ↓
/oh-my-claudecode:ralph       ← 검증 통과까지 반복
```

```text
/oh-my-claudecode:ralph

목표: aidlc-docs/features/<slug>/unit-of-work.md의 모든 UOW가 통과.
검증: 각 UOW의 Verification 섹션의 명령을 실행해 성공.
참조: ctx/, aidlc-docs/features/<slug>/
```

### 2-3. team — 병렬 분업

`_roadmap.md`로 분해된 멀티피처를 병렬로 처리할 때.

```text
/ctx-aidlc-roadmap            ← Phase 0 분해 + GATE-0
  ↓ (각 feature는 독립)
/oh-my-claudecode:team        ← N 에이전트가 feature 별로 동시 진행
```

`_roadmap.md`의 dependency graph에 따라 직렬/병렬 그룹을 OMC team에 전달한다.

---

## 3. team-ai-workflow → Ouroboros 패턴

### 3-1. Seed 생성 + evolve

```text
/ctx-aidlc-run                ← requirements.md 확정
  ↓
/ouroboros:seed                ← requirements.md → Seed spec
  ↓
/ouroboros:evolve              ← 진화 루프
```

Ouroboros는 측정 가능한 목표(테스트 통과율, 성능 지표, 정확도)가 있을 때 효과적이다.
`unit-of-work.md`의 Acceptance Criteria를 Seed의 verification으로 변환한다.

권장 호출 예:

```text
/ouroboros:seed

기반 문서: aidlc-docs/features/<slug>/requirements.md
검증 기준: aidlc-docs/features/<slug>/unit-of-work.md의 각 UOW Verification
종료 조건: 모든 Acceptance Criteria 통과
```

### 3-2. evaluate로 산출물 평가

이미 구현된 코드를 team-ai-workflow의 산출물 기준으로 평가하려면:

```text
/ouroboros:evaluate

대상: <repo>
기준: aidlc-docs/features/<slug>/requirements.md
verification: aidlc-docs/features/<slug>/unit-of-work.md
```

---

## 4. 충돌 방지 규칙

세 시스템이 같은 레포에서 동작할 때 따라야 할 규칙.

### 4-1. 상태 디렉토리 분리

| 시스템 | 상태 위치 | 역할 |
|--------|-----------|------|
| team-ai-workflow | `aidlc-docs/` | 요구사항·설계·UOW (Source of Truth) |
| OMC | `.omc/state/`, `.omc/notepad.md` | 실행 상태·런타임 메모 |
| Ouroboros | `.ouroboros/`, 세션 파일 | Seed·진화 이력 |

서로 다른 디렉토리만 쓴다. 절대 덮어쓰지 않는다.

### 4-2. audit.md는 append-only

- team-ai-workflow가 `aidlc-docs/audit.md`의 형식과 소유권을 가진다.
- OMC/Ouroboros가 추가 이벤트를 기록할 때는 `[OMC]` 또는 `[OUR]` 프리픽스로
  명확히 구분한다.
- 기존 엔트리를 절대 수정하지 않는다.

### 4-3. GATE는 사람만 통과시킨다

| GATE | 의미 | 자동 통과 가능? |
|------|------|----------------|
| GATE-0 | Roadmap Review | 불가 |
| GATE-1 | Planning Draft (raw만) | 불가 |
| GATE-2 | Requirements Review | 불가 |
| GATE-2.5/2.7 | User Stories / Application Design | 불가 |
| GATE-3 | Unit-of-Work Review | 불가 |
| GATE-3.5 | Technical Design | 불가 |
| GATE-4 | Infrastructure | 불가 |
| GATE-5 | Build & Test Instructions | 불가 |

OMC/Ouroboros가 자동으로 GATE 통과 메시지를 만들지 않도록 프롬프트에 명시한다.

### 4-4. 한 번에 한 시스템만 쓰기 (권장)

GATE-3 이전 단계는 team-ai-workflow가 전담한다.
GATE-3 통과 이후 구현 단계에서 OMC 또는 Ouroboros를 선택적으로 사용한다.

---

## 5. 다른 계정 · 다른 레포지토리에서 동일하게 사용하기

### 5-1. 본체 클론과 환경변수

```bash
# 권장 위치
git clone https://github.com/nhnad-haru/team-ai-workflow.git \
  ~/workspace/team-ai-workflow

# 다른 위치 사용 시 환경변수 명시
echo 'export TEAM_AI_WORKFLOW_DIR="$HOME/workspace/team-ai-workflow"' >> ~/.zshrc
source ~/.zshrc
```

### 5-2. 글로벌 스킬 설치

```bash
bash "$TEAM_AI_WORKFLOW_DIR/scripts/install-skills.sh"
```

설치 결과:

- `~/.claude/commands/ctx-*.md` (Claude Code)
- `~/.claude/commands/team-ai-workflow-start.md` (진입 스킬)
- `~/.codex/skills/ctx-*/` (Codex CLI, 선택)

### 5-3. multi-account 환경

Claude Code multi-account를 사용해 `~/.claude-personal/` 같은 별도 홈 경로가 있는 경우,
각 홈마다 install-skills.sh를 실행하거나 심볼릭 링크를 건다.

```bash
# 예: personal 계정 홈에도 설치
CLAUDE_HOME="$HOME/.claude-personal" \
  bash "$TEAM_AI_WORKFLOW_DIR/scripts/install-skills.sh"
```

(install-skills.sh가 `CLAUDE_HOME` 환경변수를 지원하지 않는 경우, 심볼릭 링크 사용:
`ln -s ~/.claude/commands ~/.claude-personal/commands`)

### 5-4. 레포지토리 초기화

각 레포에서 한 번만 실행한다.

```bash
cd /path/to/new-repo
bash "$TEAM_AI_WORKFLOW_DIR/scripts/init-project.sh"
```

생성되는 구조:

```text
<repo>/
├── CLAUDE.md (없으면)
├── ctx/
│   ├── INDEX.md
│   ├── project-profile.ctx.md
│   └── workflow/commit-workflow.ctx.md
└── aidlc-docs/
    ├── aidlc-state.md
    ├── audit.md
    └── features/
```

이미 있는 파일은 건드리지 않는다.

### 5-5. 본체 업데이트

```bash
cd "$TEAM_AI_WORKFLOW_DIR" && git pull
bash scripts/install-skills.sh
```

install 스크립트는 멱등하므로 안전하게 재실행 가능하다.

---

## 6. 트러블슈팅

### `/ctx-aidlc-run`이 인식되지 않는다

```bash
ls -la ~/.claude/commands/ctx-aidlc-run.md
```

파일이 없으면 install-skills.sh를 다시 실행한다.

### 스킬은 있는데 `{{TEAM_AI_WORKFLOW_DIR}}` 치환이 안 됐다

설치 시점의 본체 경로가 박혀야 하는데 플레이스홀더가 그대로 남아 있다면
install-skills.sh를 다시 돌린다. `sed -i ''`는 macOS BSD sed 기준이므로
Linux에서는 `sed -i`로 수정 필요.

### 두 계정에서 동일 레포를 동시에 작업 중인데 audit.md가 충돌난다

`audit.md`는 append-only지만 동시 작성 시 race condition이 생길 수 있다.
서로 다른 feature-slug를 쓰고, 같은 feature를 동시에 수정하지 않는다.

### OMC autopilot이 requirements를 무시한다

autopilot 프롬프트에 `requirements.md`와 `unit-of-work.md` 경로를 명시했는지 확인.
"파일 경로를 따른다"가 아니라 "이 파일에 적힌 Acceptance Criteria가 통과해야 한다"
라고 검증 조건을 명시한다.

### Ouroboros evolve가 무한 루프

종료 조건이 측정 불가능하면 그렇다. UOW의 Verification 섹션이 구체적 명령
(예: `./gradlew :module:test --tests CouponTest`)으로 작성되어 있는지 확인.

---

## 7. 권장 사용 시나리오

| 시나리오 | 추천 조합 |
|---------|-----------|
| 한 명이 작은 feature(S) 빠르게 끝내기 | `/ctx-aidlc-run` → `/oh-my-claudecode:ralph` |
| 중간 크기(M) feature, 사람이 PR 단위로 검토 | `/ctx-aidlc-run` → `/oh-my-claudecode:autopilot` |
| 큰 기획서, 팀 분업 | `/ctx-aidlc-roadmap` → 각자 `/ctx-aidlc-run` → `/oh-my-claudecode:team` |
| 측정 가능한 목표(테스트 통과율 등) | `/ctx-aidlc-run` → `/ouroboros:seed` → `/ouroboros:evolve` |
| 기존 코드 평가 | `/ctx-aidlc-run` (요구사항 정리만) → `/ouroboros:evaluate` |
| 단순 변경(change-on-existing-feature) | `/ctx-aidlc-run`만으로 충분, 외부 도구 불필요 |
