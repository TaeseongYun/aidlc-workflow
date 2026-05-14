# 2026-04-29: Phase 0 Roadmapping과 멀티피처 협업 워크플로우

## 배경

큰 prepared 기획서가 자연스럽게 여러 피처로 분해되는 경우, 팀이 분업할 때 다음 문제가 반복적으로 보고됨:

1. **피처 간 자원 중복** — 서로 다른 피처가 같은 컴포넌트/테이블/공통 모듈을 만들려고 함
2. **선행 의존성 비가시화** — 피처 B가 피처 A의 산출물을 필요로 하지만 어디에도 명시되지 않음
3. **분업 기준 부재** — 누가 무엇을 맡을지 결정할 근거 자료가 없음

기존 `ctx-aidlc-run` STEP 1-A의 1번 라운드는 "여러 피처면 분해하라"고 안내만 할 뿐 차단·로드맵 산출·핸드오프가 없었다. 그 결과 사용자는 (a) 한 피처 폴더에 모든 작업을 강제로 묶거나, (b) 피처별로 ctx-aidlc-run을 따로 돌리며 머지 충돌·정책 불일치를 사후에 발견하는 방식으로만 대응 가능했다.

본 변경은 **Phase 0 — Roadmapping** 단계를 워크플로우에 정식 편입하여 이 빈 영역을 메운다.

## 변경 사항

### 1. 새 스킬 — `ctx-aidlc-roadmap`

**파일**: `skills/ctx-aidlc-roadmap/SKILL.md`, `skills/ctx-aidlc-roadmap/CLAUDE_COMMAND.md` (신규)

- Phase 0 단독 실행 스킬. STEP R1 ~ R6 + GATE-0으로 구성.
- 입력: prepared-requirement 원본 기획서. raw-request / change-on-existing-feature / single-feature는 거절하고 적절한 스킬로 안내.
- 출력: 프로젝트-레벨 단일 파일 `aidlc-docs/_roadmap.md` 1개.
- BOOTSTRAP / Lazy Loading / 실시간 audit·state 갱신은 ctx-aidlc-run과 동일 패턴으로 통일.
- 피처별 `requirements.md`, `unit-of-work.md`는 만들지 않는다 (그건 ctx-aidlc-run의 책임).

스킬 단계:
- **STEP R1** Input Validation — 분류 확인, multi-feature 신호 판정. 단일이면 모든 R-step `[-]` 스킵.
- **STEP R2** Feature Decomposition — 피처 슬러그(kebab-case) + 1줄 책임. Single Domain Principle 적용.
- **STEP R3** Resource Matrix — 컴포넌트/테이블/API/이벤트의 피처별 점유 표. 동일 자원이 2+ 피처에 등장하면 ⚠.
- **STEP R4** Dependency Graph — 피처 간 의존, 순환 검사, ⚠ 자원 처리 (foundation 추출 또는 단일 소유 지정).
- **STEP R5** Allocation Recommendation — 직렬/병렬 그룹화, 역할 기반 분업 권고, 머지 충돌 위험 표기.
- **STEP R6** Roadmap File Output — `_roadmap.md` 작성, `aidlc-state.md` 동기화.
- **GATE-0** — 사용자 승인 후 피처별 핸드오프 메시지 출력.

### 2. ctx-aidlc-run 확장 — 양방향 진입 지원

**파일**: `skills/ctx-aidlc-run/SKILL.md`, `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

- BOOTSTRAP에 `aidlc-docs/_roadmap.md` 즉시 읽기 추가.
- CORE RULES에 "로드맵이 있으면 그 의존성·공유 자원 정보를 무시하지 않는다" 한 줄 추가.
- STEP 1 Roadmap awareness 추가 — 로드맵 존재 시 working feature-slug가 항목에 있는지 검증, 의존하는 선행 피처 산출물을 `status.md` "Roadmap Context" 섹션에 인용. 슬러그 미일치 시 (a) 추가 / (b) standalone / (c) 중단 중 하나를 사용자에게 묻고 audit 기록.
- STEP 1-A 1번 라운드에 멀티피처 핸드오프 분기 — "multiple" AND `_roadmap.md` 미존재 → STOP, audit.md `[HANDOFF] ctx-aidlc-run → ctx-aidlc-roadmap` 기록, `/ctx-aidlc-roadmap` 실행 안내.

### 3. 게이트 — GATE-0 신설

**파일**: `common/stage-gate-rules.md`

- 게이트 목록 표 최상단에 GATE-0 추가 (Roadmap Review).
- 화이트리스트형 스킵 규칙: GATE-0은 single-feature일 때만 스킵 가능.
- 명시적 스킵 불가 게이트에 GATE-0 추가 — 한번 발동되면 사용자 일괄 승인으로도 스킵 불가.
- 리뷰 항목 신설: 피처 분해 적절성, ⚠ 자원 해소, 순환 의존 부재, 분업 권고 직렬/병렬 구분, 슬러그 명명 규칙, aidlc-state 동기화.

### 4. 산출물 / 상태 / 감사 — 멀티피처 메타데이터 정착

**파일**: `templates/feature-roadmap.md` (신규), `templates/aidlc-state.md`, `templates/audit.md`, `core/core-workflow.md`

- `templates/feature-roadmap.md` 신규 — `_roadmap.md`의 8개 섹션 (Source / Feature List / Resource Matrix / Dependency Graph / Allocation / Handoff Plan / Open Items / GATE-0 Pointers).
- `templates/aidlc-state.md`:
  - `Roadmap State` 섹션 신설 (Roadmap Path, Multi-Feature Mode, GATE-0 Decision, Last Update)
  - `Feature Index`를 표 형식으로 변경 + Roadmap Source 컬럼 추가
  - `Cross-Feature Dependencies` 섹션 신설 (Source/Depends On/Shared Resource/Resolution)
  - `Roadmap Phase Progress` 체크리스트 신설 (R1~R6 + GATE-0)
- `templates/audit.md`:
  - Phase 0 STEP / GATE-0의 Feature 필드는 `roadmap`으로 표기한다는 규칙 명시
  - `[HANDOFF]` 이벤트 포맷 신설 (from-skill / to-skill / Reason / Resume Hint)
- `core/core-workflow.md`:
  - 공통 수행 순서 0번에 Phase 0 진입 조건 추가
  - 승인 게이트 목록에 GATE-0 추가
  - 산출물 목록에 `aidlc-docs/_roadmap.md` 등재 (multi-feature prepared-requirement 전용 프로젝트 레벨 산출물)

### 5. 운용 가이드 / 빠른 시작 / 워크플로우 가이드

**파일**: `docs/multi-feature-coordination.md` (신규), `docs/workflow-guide.md`, `README.md`, `QUICKSTART.md`, `skills/README.md`

- `docs/multi-feature-coordination.md` 신규 — 7개 섹션 (적용 조건 / 양방향 진입 / 산출물 해석 / 분업 패턴 3종 / 충돌 해결 / 피처별 실행 / FAQ).
- `docs/workflow-guide.md` — Phase A 앞에 "Phase 0: Roadmapping" 섹션 추가, 세션 분리 표에 Phase 0 행 추가.
- `README.md` — 워크플로우 흐름 다이어그램에 Phase 0 블록, 디렉터리 구조에 `_roadmap.md`, 스킬 표에 `/ctx-aidlc-roadmap` 등재.
- `QUICKSTART.md` — 멀티피처 시나리오 단락 추가 (단일 피처 흐름 다음).
- `skills/README.md` — 새 스킬 등재, 단일/멀티 흐름을 별도 권장 흐름으로 분리.

### 6. 설치 / 초기화 스크립트 동기화

**파일**: `scripts/install-skills.sh`, `scripts/init-project.sh`

- `install-skills.sh` SKILLS 배열에 `ctx-aidlc-roadmap` 등록 — 새 스킬이 글로벌 경로(`~/.codex/skills/`, `~/.claude/commands/`)에도 함께 배포된다.
- `init-project.sh`의 `aidlc-state.md` / `audit.md` 인라인 heredoc 생성을 `cp templates/*.md` 기반으로 전환:
  - `aidlc-state.md` — 템플릿 복사 후 Start Date만 sed로 채움. Roadmap State, Cross-Feature Dependencies가 새 프로젝트에서도 즉시 사용 가능.
  - `audit.md` — `sed '/^---$/q'`로 첫 구분선까지만 잘라 복사 (규칙·트리거·HANDOFF 포맷까지 이식, 샘플 Feature Start 엔트리 제거).
- 이후 템플릿 변경은 init 스크립트 수정 없이 자동 반영된다.

## 사용자 질문 — "별도 스킬을 만들면 어느 시점에 실행해야 하나?"

본 변경의 발단이 된 사용자 질문에 대한 결론:

| 진입 경로 | 시점 | 트리거 조건 |
|----------|------|-----------|
| 1. 직접 호출 | prepared 기획서 수령 직후 | 사용자가 큰 기획서임을 알고 `/ctx-aidlc-roadmap`을 먼저 실행 |
| 2. 핸드오프 | `/ctx-aidlc-run` STEP 1-A 1번 라운드 | "multiple independent features" 답변 AND `_roadmap.md` 미존재 → ctx-aidlc-run이 차단하고 안내 |
| 종료 | GATE-0 승인 후 | `_roadmap.md` 확정 → 각 팀원이 자기 피처 슬러그를 인자로 `/ctx-aidlc-run` (prepared-requirement, 해당 피처 발췌물 입력) |

## 수정/신규 파일 전체 목록

| 파일 | 변경 유형 |
|------|----------|
| `skills/ctx-aidlc-roadmap/SKILL.md` | 신규 |
| `skills/ctx-aidlc-roadmap/CLAUDE_COMMAND.md` | 신규 |
| `templates/feature-roadmap.md` | 신규 |
| `docs/multi-feature-coordination.md` | 신규 |
| `docs/changelog/2026-04-29-multi-feature-roadmap-phase0.md` | 신규 |
| `skills/ctx-aidlc-run/SKILL.md` | BOOTSTRAP / CORE RULES / STEP 1 / STEP 1-A 갱신 |
| `skills/ctx-aidlc-run/CLAUDE_COMMAND.md` | Required Reading / Behavior Rules 동기 |
| `common/stage-gate-rules.md` | GATE-0 항목·스킵 규칙·리뷰 항목 추가 |
| `core/core-workflow.md` | Phase 0 진입 조건 / 게이트 목록 / 산출물 등재 |
| `templates/aidlc-state.md` | Roadmap State / Cross-Feature Deps / Roadmap Phase Progress |
| `templates/audit.md` | Phase 0 Feature 표기 / [HANDOFF] 포맷 |
| `docs/workflow-guide.md` | Phase 0 섹션 + 세션 분리 표 |
| `README.md` | 흐름 다이어그램 / 디렉터리 / 스킬 / 변경 이력 |
| `QUICKSTART.md` | 멀티피처 시나리오 |
| `skills/README.md` | 새 스킬 등재 + 흐름 분기 |
| `scripts/install-skills.sh` | SKILLS 배열에 새 스킬 등록 |
| `scripts/init-project.sh` | 인라인 heredoc → 템플릿 cp 기반 전환 |

## 검증

- `tools/validate-skills.sh`: 38 PASS / 0 FAIL (새 스킬 5개 검사 항목 모두 통과)
- `init-project.sh`를 임시 디렉터리에서 실행하여 `aidlc-state.md` Start Date 자동 채움, `audit.md`가 규칙·트리거·HANDOFF 포맷까지 이식되고 샘플 엔트리는 제거되는 것을 확인.

## 기대 효과

- 큰 prepared 기획서를 바로 분업하기 전에 **피처 분해·자원 매트릭스·의존 그래프**를 강제 산출하므로 사후 머지 충돌과 정책 불일치가 줄어든다.
- ctx-aidlc-run의 STEP 1-A에서 멀티피처가 감지되면 자동 차단되므로 단일 피처 폴더에 이질적 도메인이 묶이는 패턴이 차단된다.
- `aidlc-state.md`의 Cross-Feature Dependencies 표가 단일 출처가 되어, 어느 팀원이 어느 피처를 맡고 있고 무엇을 기다리는지가 가시화된다.
- 단일 피처 프로젝트에는 영향이 없다 (STEP R1에서 `[-]` 스킵).

## 후속 과제 (이번 작업 범위 외)

- Phase 0 산출물에 대한 Golden Baseline 예시 (`examples/golden-baselines/multi-feature/_roadmap.md`)
- `tools/evaluator/`에 GATE-0 통과 조건 검증 룰 추가 (피처 슬러그 명명, ⚠ 자원 해소, 순환 의존 부재)
