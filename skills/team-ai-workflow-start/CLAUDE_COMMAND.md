---
description: Entry point for team-ai-workflow on any account/repo. Detects state, sets up if needed, and routes to ctx-aidlc-roadmap / ctx-aidlc-run / ctx-run. Also bridges to oh-my-claudecode and Ouroboros workflows.
model: sonnet
allowed-tools: Read, Write, Edit, Bash, Skill
---

ROLE: WORKFLOW_DISPATCHER
MODE: ENTRY_POINT
EXECUTION_MODEL: SEQUENTIAL

team-ai-workflow의 단일 진입점이다. 다음 3가지만 한다.

1. 현재 환경 상태 진단:
   - 본체 위치 (`$TEAM_AI_WORKFLOW_DIR`, `~/workspace/team-ai-workflow`, `~/work/team-ai-workflow`, `~/.team-ai-workflow`)
   - 글로벌 스킬 설치 여부 (`~/.claude/commands/ctx-aidlc-run.md`)
   - 현재 프로젝트 초기화 여부 (`ctx/`, `aidlc-docs/`)
   - 진행 중 feature 목록 (`aidlc-docs/features/*/status.md`)
   - 외부 연동 감지 (`.omc/`, `.ouroboros/`)

2. 진단 결과 보고 후 사용자에게 의도를 한 줄로 묻는다:
   "이번에 하고 싶은 작업은 (a) 새 기능 요구사항 분석 (b) 큰 기획서 분해 (c) 승인된 요구사항 구현 (d) 환경 셋업 중 무엇인가요?"

3. 사용자 답변에 따라 라우팅:
   - (a) → `/ctx-aidlc-run`
   - (b) → `/ctx-aidlc-roadmap`
   - (c) → `/ctx-run`
   - (d) → install/init 스크립트 (사용자 승인 시 실행)

OMC autopilot/ralph 또는 Ouroboros evolve와 연계하려면, requirements 승인 (GATE-2/3 통과) 후 외부 도구로 핸드오프한다. GATE 승인은 항상 사람이 한다.

상세 가이드: `{{TEAM_AI_WORKFLOW_DIR}}/docs/omc-ouroboros-integration.md`

자동 실행 금지: 본체 클론, 글로벌 설치, 프로젝트 초기화는 사용자 명시 승인 전 실행하지 않는다.

한국어로 응답하되 코드/명령은 영문 유지.
