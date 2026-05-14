# 2026-04-14: Risk-Based Priority, Input Validation, AI 주도 유닛 분해, 세션 분리

## 배경

AIDLC 워크숍 5일간 회고록 분석 결과, 실전에서 발생한 문제 중 방법론 수준에서 해결 가능한 4가지를 식별하여 반영.

회고에서 도출한 핵심 문제:
1. AI가 저위험 세부사항(배치 크기)에 질문을 집중하고 고위험 영역(외부 API)을 간과
2. 인간이 유닛을 강제 지정하여 이질적 기능이 하나의 유닛에 묶임
3. 입력 문서(prepared_doc)의 정책 구멍이 인셉션 전체로 전파
4. LLM 컨텍스트 한계로 단계별 답변 불일치 발생

## 변경 사항

### 1. Risk-Based Priority (질문 우선순위 시스템)

**파일**: `common/question-governance.md` 섹션 4 신규

- 모든 질문에 `P0-CRITICAL` / `P1-IMPORTANT` / `P2-DEFERRABLE` 우선순위 부여
- P0: 외부 시스템 통합, 보안 경계, 데이터 정합성 — 반드시 인간 확인
- P1: 비즈니스 정책, 예외 처리, 데이터 모델 — 표준 질문 흐름
- P2: 배치 크기, 로깅 레벨, 재시도 횟수 — AI가 디폴트로 결정, 인간에게 알림만
- 리스크 태그(`⚠️ RISK:`) 입력 메커니즘으로 인간이 고위험 영역을 사전 표시 가능
- P2 질문은 질문 예산에 포함하지 않음
- 중요도 정렬 기준을 P0/P1/P2 기반으로 변경
- 금지 사항 3건 추가 (P0→P2 격하 금지, P2→BLOCK 제시 금지, 스키마/인증/API 계약의 P2 분류 금지)

**파일**: `templates/requirement-verification-questions.md`

- Summary 테이블에 `우선순위` 컬럼 추가
- 질문 포맷에 `우선순위` 필드 추가
- "AI 자동 결정 (P2)" 섹션 신설

### 2. Input Validation (사전 문서 검증)

**파일**: `core/input-validation.md` 신규, `core/core-workflow.md` STEP 1-C 추가

- `prepared-requirement` 입력 시 STEP 2 진입 전에 문서 검증 수행
- 검증 항목: 완전성 검사(6개 영역), 모순 탐지, 미정의 용어 탐지, 리스크 태그 수집
- 검증 후 사용자에게 3가지 선택지 제시 (문서 보완 / 현재 상태로 진행 / 범위 축소)
- 예상 BLOCK 질문 수를 사전 경고

**파일**: `templates/aidlc-state.md`

- `Input Validation Result` 필드 추가
- STEP 1-C 체크박스 추가

### 3. AI 주도 유닛 분해

**파일**: `core/units-generation.md` 전면 강화

- "분해 주체" 섹션 신규: AI가 먼저 제안 → 인간이 승인/조정
- 인간이 유닛을 직접 지정하는 것을 비권장으로 명시
- 응집도 검증 규칙 3가지:
  - 단일 도메인 원칙: 유닛 내 독립 도메인 2개 이상이면 분리 검토
  - 질문 수 기반 크기 검증: 3개 이하 적정, 8개 이상 반드시 분리
  - 외부 연동 분리: 외부 API는 별도 유닛

### 4. 세션 분리 가이드 (점진적 컨텍스트)

**파일**: `docs/workflow-guide.md` 섹션 신규

- Phase A(Discovery) / B(Definition) / C(Design)로 워크플로우를 3개 Phase로 구분
- 각 Phase는 이전 Phase의 산출물만 참조 — 대화 내용은 참조하지 않음
- comprehensive depth에서 세션 분리 강력 권장
- 세션 재개 시 aidlc-state.md를 먼저 읽는 규칙

**파일**: `templates/aidlc-state.md`

- `Current Phase` 필드 추가 (A/B/C)

### 5. 스킬 반영

**파일**: `skills/ctx-aidlc-run/SKILL.md`

- PRIMARY INPUTS에 `core/input-validation.md` 추가
- STEP 1-C 실행 흐름 전체 추가 (조건 판정, 검증, 리스크 태그 수집, 사용자 선택지)
- STEP 4에 Risk-Based Priority 규칙 전체 추가 (P0/P1/P2 분류, 리스크 태그 승격, P2 자동 결정)
- STEP 6에 AI 주도 분해 + 응집도 검증 규칙 추가

**파일**: `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

- Mission에 STEP 1-C 참조 추가
- Required Reading Order에 `input-validation.md` 추가
- Question Rules에 P0/P1/P2 전체 규칙 추가

## 수정된 파일 전체 목록

| 파일 | 변경 유형 |
|------|----------|
| `common/question-governance.md` | 섹션 추가 + 기존 섹션 번호 조정 |
| `core/core-workflow.md` | STEP 1-C 라인 추가 |
| `core/input-validation.md` | 신규 |
| `core/units-generation.md` | 전면 강화 |
| `docs/workflow-guide.md` | 섹션 추가 |
| `templates/aidlc-state.md` | 필드/체크박스 추가 |
| `templates/requirement-verification-questions.md` | 컬럼/필드/섹션 추가 |
| `skills/ctx-aidlc-run/SKILL.md` | 입력 목록, 실행 흐름, 규칙 추가 |
| `skills/ctx-aidlc-run/CLAUDE_COMMAND.md` | 미션, 읽기 목록, 질문 규칙 추가 |
| `README.md` | 워크플로우 흐름, 문서 링크, 변경 이력 갱신 |

## 참조 출처

| 출처 | 가져온 패턴 |
|------|-----------|
| AIDLC 워크숍 회고 | 질문 우선순위 문제, 유닛 강제 지정 문제, 문서 미검토 문제, 컨텍스트 붕괴 |
| BMAD-METHOD | Phase별 문서 기반 컨텍스트 전달 (세션 분리 근거) |
| aidlc-workflows | 입력 검증의 필요성 (prepared_doc 투입 시 정합성 문제) |
