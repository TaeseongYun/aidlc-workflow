# Core Workflow

이 문서는 전 프로젝트 공통 AI 판단 흐름이다.

## 1. 프로젝트 상태 판별
- 먼저 현재 작업이 `greenfield`인지 `brownfield`인지 판별한다.
- 기존 코드, DB, 운영 플로우, 외부 연동이 있으면 `brownfield`로 본다.

## 2. 요구사항 분석 시작 조건
- 신규 기능 요청
- 정책 변경 요청
- 기존 기능 확장 요청
- 구조 영향이 있는 버그 수정

## 3. 공통 수행 순서
0. (multi-feature prepared-requirement인 경우) Phase 0 — Roadmapping을 선행한다 (`ctx-aidlc-roadmap`). 피처 분해, 자원 매트릭스, 의존 그래프, 분업 권고를 산출하고 GATE-0을 통과한 뒤 피처별 흐름으로 진입한다.
1. 현재 프로젝트 구조와 관련 도메인을 탐색한다.
1-A. (raw-request인 경우) Discovery 질문을 통해 요청을 명확화한다. multi-feature 답변이고 `_roadmap.md`가 없으면 Phase 0으로 핸드오프한다.
1-B. Depth Level을 판정한다 (`common/depth-levels.md`). minimal / standard / comprehensive.
1-C. (prepared-requirement인 경우) 입력 문서 검증을 수행한다 (`core/input-validation.md`).
1.5. (brownfield이고 기존 RE 산출물이 없는 경우) Reverse Engineering을 수행한다 (`core/reverse-engineering.md`).
2. 요구사항을 기능/정책/운영 관점으로 분해한다.
3. 추정이 필요한 빈칸을 질문으로 변환한다. 질문 거버넌스는 `common/question-governance.md`를 따른다.
4. 질문 답변 전에는 설계 결정을 확정하지 않는다. 답변의 모순은 `common/content-validation.md`로 검증한다.
5. 답변 후 요구사항 문서를 고정한다.
5.5. (조건부) 사용자 스토리를 정의한다.
5.7. (조건부) 시스템 구조를 설계한다.
6. 유닛 분해와 설계를 진행한다.
6.5. (조건부) 기술 설계를 진행한다.
6.7. (조건부) 인프라 설계를 진행한다.
7. 구현 전 테스트/운영/NFR 누락을 점검한다.
8. Readiness Score를 산출하고 구현 가능 여부를 판단한다.
9. (조건부) 빌드 및 테스트 가이드를 작성한다.

## 4. 질문을 반드시 생성해야 하는 경우
- 여러 설계가 모두 가능한 경우
- 결제/환불/정산/권한/보안/운영 영향이 있는 경우
- 사용자 화면 흐름이 정해지지 않은 경우
- 외부 시스템 연동 방식이 확정되지 않은 경우
- 데이터 모델 확장이 필요한 경우

## 5. 질문 없이 진행 가능한 경우
- 기존 프로젝트 규칙과 동일 패턴으로 처리 가능한 단순 변경
- 도메인/상태/정책 결정이 이미 `ctx/`, `AGENTS.md`에 명시된 경우

## 6. 승인 게이트
주요 산출물 작성 후에는 `common/stage-gate-rules.md`에 따라 사용자 승인을 받는다.
- GATE-0: roadmap 리뷰 (multi-feature prepared-requirement인 경우)
- GATE-1: planning-draft 리뷰 (raw-request인 경우)
- GATE-2: requirements + questions 리뷰
- GATE-2.5: user-stories 리뷰 (User Scenarios >= 3 또는 신규 사용자 유형 시, 조건부)
- GATE-2.7: application-design 리뷰 (UOW >= 3 예상 또는 신규 컴포넌트 생성 시, 조건부)
- GATE-3: unit-of-work 리뷰
- GATE-3.5: technical-design 리뷰 (M/L 규모 단위가 있을 때)
- GATE-4: infrastructure-design 리뷰 (인프라 변경이 필요할 때, 조건부)
- GATE-5: build/test-instructions 리뷰 (M/L 규모 단위가 있을 때, 조건부)
게이트를 통과하지 않으면 다음 단계로 진행하지 않는다.

## 7. 다이어그램
산출물에 상태 전이, 의존성, 플로우 등 시각 자료가 필요하면 `common/diagram-standards.md`를 따른다.
- 단순 플로우: ASCII
- 복잡한 관계: Mermaid (텍스트 대안 필수)

## 8. 산출물

### 프로젝트 레벨 산출물 (brownfield only)
- `aidlc-docs/reverse-engineering/business-overview.md` (STEP 1.5)
- `aidlc-docs/reverse-engineering/architecture-overview.md` (STEP 1.5)
- `aidlc-docs/reverse-engineering/component-inventory.md` (STEP 1.5)

### 프로젝트 레벨 산출물 (multi-feature prepared-requirement only)
- `aidlc-docs/_roadmap.md` (Phase 0 / GATE-0, producer: `ctx-aidlc-roadmap`)

### 필수 산출물
- `aidlc-docs/aidlc-state.md`
- `aidlc-docs/audit.md`
- `aidlc-docs/features/<feature-slug>/status.md`
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`

### 조건부 산출물 — INCEPTION 확장
- `aidlc-docs/features/<feature-slug>/user-stories/personas.md` (User Scenarios >= 3 또는 신규 사용자 유형)
- `aidlc-docs/features/<feature-slug>/user-stories/stories.md` (위와 동일 조건)
- `aidlc-docs/features/<feature-slug>/application-design/components.md` (UOW >= 3 예상 또는 신규 컴포넌트)
- `aidlc-docs/features/<feature-slug>/application-design/services.md` (위와 동일 조건)
- `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md` (위와 동일 조건)

### 조건부 산출물 — CONSTRUCTION
- `aidlc-docs/features/<feature-slug>/technical-design.md` (M/L 규모 단위가 있을 때)
- `aidlc-docs/features/<feature-slug>/infrastructure-design.md` (인프라 변경 필요 시)
- `aidlc-docs/features/<feature-slug>/deployment-architecture.md` (인프라 변경 필요 시)
- `aidlc-docs/features/<feature-slug>/build-instructions.md` (M/L 규모 단위가 있을 때)
- `aidlc-docs/features/<feature-slug>/test-instructions.md` (M/L 규모 단위가 있을 때)

### 조건부 산출물 — Extension
- `aidlc-docs/features/<feature-slug>/extensions/security-baseline.md` (사용자 opt-in 시)

## 9. 커밋 플랜 확정 후 문서 갱신 (필수)
커밋 플랜이 확정되면 반드시 아래 문서를 갱신한다.
- `aidlc-docs/features/<feature-slug>/status.md`: 현재 상태 반영
- `aidlc-docs/audit.md`: 커밋 플랜 확정 이벤트 append

## 10. audit.md / aidlc-state.md 실시간 갱신 규칙

### audit.md (append-only)
아래 이벤트 발생 시 **즉시** `aidlc-docs/audit.md`에 append 한다.
- **STEP 시작/완료**: 매 STEP 진입 시와 완료 시 기록. 조건부 STEP 스킵 시에도 스킵 사유 기록.
- **GATE 통과**: 사용자 승인/변경 요청/스킵 시 기록.
- **사용자 입력**: BLOCK/ASSUME 질문 답변, Discovery 라운드 응답 시 기록.
- **상태 변경**: feature status가 변경될 때 기록.
포맷은 `templates/audit.md`의 로깅 트리거 섹션을 따른다.

### aidlc-state.md
아래 이벤트 발생 시 **즉시** `aidlc-docs/aidlc-state.md`를 갱신한다.
- **STEP 완료/스킵**: 해당 체크박스를 `[x]` 또는 `[-]`로 갱신.
- **GATE 통과**: 해당 체크박스를 `[x]`로 갱신.
- **Current Stage**: 항상 현재 진행 중인 STEP으로 갱신.
- **Feature Status**: 상태 변경 시 최신 값으로 갱신.
- **Readiness Score**: 산출/변경 시 갱신.
- **Last Updated**: 모든 갱신 시 타임스탬프 갱신.

## 11. 과신 방지
AI 주도 단계(STEP 6, 6.5, 6.7)와 Readiness Score 산출(STEP 7)에서는 `common/overconfidence-prevention.md` 규칙을 적용한다.
- 불확실한 판단에 `⚠️ UNCERTAIN` 마커를 붙인다.
- 산출물 작성 후, 게이트 제시 전에 자체 검증(Self-Verification)을 수행한다.
- STEP 3 완료 시 질문 누락 감지를 수행한다.

## 12. 오류 복구
워크플로우 실행 중 오류, 세션 중단, 산출물 손상이 발생하면 `common/error-recovery.md` 절차를 따른다.
- 세션 재개 시 aidlc-state.md와 실제 산출물의 일치 여부를 검증한다.
- 불일치 발견 시 복구 절차를 수행하고 audit.md에 기록한다.
- 백업 없이 산출물을 재생성하지 않는다.

## 13. 금지 사항
- 비즈니스 정책을 AI가 임의 결정하지 않는다.
- 기존 프로젝트 구조를 이해하지 않고 새 구조를 강요하지 않는다.
- 질문이 필요한 항목을 구현 단계로 넘기지 않는다.
- 승인 게이트를 건너뛰거나 사용자 응답 없이 다음 단계로 진행하지 않는다.
- audit.md를 덮어쓰지 않는다. 항상 append 한다.
- STEP 완료 후 audit.md와 aidlc-state.md 갱신을 빠뜨리지 않는다.

## 14. 프로젝트 로컬 컨텍스트 우선순위
1. `AGENTS.md`
2. `ctx/INDEX.md` 또는 `ctx/project-profile.ctx.md`
3. 필요한 개별 `ctx/*.md`
4. 선택적 `.aidlc/project-profile.md` (ctx가 약한 프로젝트에서 대체 사용)
