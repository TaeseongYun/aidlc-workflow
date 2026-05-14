# Stage Gate Rules

## 목적
각 주요 산출물 완료 시 명시적 승인 게이트를 두어, 미확인 상태로 다음 단계에 진입하는 것을 방지한다.

## 승인 필요 항목

다음 항목은 인간 승인 전 확정하지 않는다.

- API 응답 형태
- 환불/취소 정책
- 정산 기준
- 할인 우선순위
- 권한/역할 규칙
- 운영자 수동 개입 지점
- 외부 연동 방식
- `ctx/`에 없는 신규 프로젝트 정책

승인이 필요한 단계:
- requirements 확정
- application design 확정
- NFR 확정
- 구현 범위 확정

## 게이트 목록

| 게이트 | 발동 시점 | 리뷰 대상 | 통과 조건 |
|--------|----------|----------|----------|
| GATE-0 | _roadmap.md 작성 완료 | _roadmap.md | multi-feature prepared-requirement일 때만 발동. 사용자가 피처 분해/의존/공유 자원을 확인하고 승인 또는 수정 요청. 미승인 시 피처별 ctx-aidlc-run 진입 차단. |
| GATE-1 | planning-draft 작성 완료 | planning-draft.md | raw-request일 때만 발동. 사용자가 초안을 확인하고 승인 또는 수정 요청. |
| GATE-2 | requirements + questions 작성 완료 | requirements.md, requirement-verification-questions.md | BLOCK 질문이 모두 해결되었거나, 사용자가 조건부 진행을 명시적으로 승인. |
| GATE-2.5 | user-stories 작성 완료 | personas.md, stories.md | 조건부 발동. User Scenarios >= 3 또는 신규 사용자 유형일 때. 사용자가 페르소나와 스토리를 확인하고 승인 또는 수정 요청. |
| GATE-2.7 | application-design 작성 완료 | components.md, services.md, component-dependency.md | 조건부 발동. UOW >= 3 예상 또는 신규 컴포넌트 생성 시. 사용자가 시스템 구조를 확인하고 승인 또는 수정 요청. |
| GATE-3 | unit-of-work 작성 완료 | unit-of-work.md | 사용자가 작업 분해를 확인하고 승인 또는 수정 요청. |
| GATE-3.5 | technical-design 작성 완료 | technical-design.md | M/L 규모 단위가 있을 때만 발동. 사용자가 기술 설계를 확인하고 승인 또는 수정 요청. |
| GATE-4 | infrastructure-design 작성 완료 | infrastructure-design.md, deployment-architecture.md | 조건부 발동. 인프라 변경이 필요할 때. 사용자가 인프라 설계를 확인하고 승인 또는 수정 요청. |
| GATE-5 | build/test-instructions 작성 완료 | build-instructions.md, test-instructions.md | 조건부 발동. M/L 규모 단위가 있을 때. 사용자가 빌드/테스트 가이드를 확인하고 승인 또는 수정 요청. |

## 게이트 규칙

### 진행 금지 조건
- 게이트에서 사용자가 명시적으로 승인하지 않으면 다음 단계로 진행하지 않는다.
- "계속 진행해" 등 명시적 승인 없이 침묵으로 넘어가지 않는다.
- 승인 전 산출물 내용을 요약하여 사용자에게 제시한다.

### 게이트 건너뛰기 (화이트리스트)

아래 표에 명시된 조건일 때만 게이트를 스킵할 수 있다. 표에 없는 게이트는 어떤 분류·조건에서도 스킵하지 않는다.

| 게이트 | 스킵 가능 조건 |
|--------|--------------|
| GATE-0 | single-feature (multi-feature 감지 안 됨) |
| GATE-1 | `prepared-requirement` 또는 `change-on-existing-feature` |
| GATE-2.5 | User Scenarios < 3 AND 신규 사용자 유형 없음 |
| GATE-2.7 | UOW < 3 예상 AND 신규 컴포넌트 없음 |
| GATE-4 | 인프라 변경 없음 |
| GATE-5 | 전체 S 규모 |

#### 명시적 스킵 불가 게이트
- **GATE-0** (Roadmap): multi-feature prepared-requirement일 때 필수. 한번 발동되면 사용자 일괄 승인으로도 스킵하지 않는다.
- **GATE-2** (Requirements): 모든 요청 분류에서 필수. `prepared-requirement`여도 스킵 불가.
- **GATE-3** (Unit-of-Work): 모든 요청에서 필수.
- **GATE-3.5** (Technical Design): M/L 규모 UOW가 1개 이상이면 필수. 전체 S 규모일 때만 발동 자체가 안 된다.

#### 사용자 일괄 승인
- 사용자가 "skip gate" 또는 "전체 승인"을 명시하면 위 표의 스킵 가능 게이트만 일괄 스킵할 수 있다.
- GATE-2 / GATE-3 / GATE-3.5는 사용자가 일괄 승인을 명시해도 스킵하지 않는다. 각 게이트에서 산출물 요약을 제시하고 별도 확인을 받는다.

## 승인 메시지 표준 포맷

게이트 도달 시 아래 구조로 메시지를 출력한다.

```markdown
## [단계명] 완료

> **진행 상황**: {Request Anchor 요약} → 현재: {현재 단계} → 다음: {다음 단계}

### 산출물 요약
- [핵심 내용 요약 — 사실 중심, 2~5개 항목]

### 리뷰 요청
> 다음 파일을 검토해 주세요:
> - `aidlc-docs/features/<feature-slug>/[파일명]`

### 다음 단계
> A) 수정 요청 — 변경이 필요한 부분을 알려주세요
> B) 승인 후 계속 — 다음 단계([다음 단계명])로 진행합니다
```

### 포맷 규칙
- 산출물 요약은 사실 중심으로 짧게 쓴다. 워크플로우 안내 문구를 섞지 않는다.
- 리뷰 대상 파일 경로를 명시한다.
- 선택지는 항상 2개(수정 요청 / 승인 후 계속)만 제공한다.
- 3개 이상의 선택지나 부가 옵션을 임의로 추가하지 않는다.

## 감사 로그 연동

게이트 통과 시 `audit.md`에 기록한다. 게이트뿐 아니라 STEP 시작/완료/스킵, 사용자 질문 답변, 상태 변경 시에도 기록한다. 전체 로깅 트리거와 포맷은 `templates/audit.md`를 참조한다.

```markdown
## [GATE-N] [단계명]
- Timestamp: [ISO 8601]
- Feature: <feature-slug>
- Gate: GATE-N
- Decision: approved / change-requested / skipped
- User Input: "[사용자 원문 그대로]"
- Notes: [변경 요청 시 요청 내용 요약]
```

### 감사 로그 규칙
- 사용자 입력은 원문 그대로 기록한다. 요약하거나 의역하지 않는다.
- 타임스탬프는 ISO 8601 형식을 사용한다.
- audit.md는 항상 append 한다. 기존 내용을 덮어쓰지 않는다.

## 게이트별 리뷰 항목

### GATE-0: Roadmap
- 피처 분해가 책임 단위로 적절한가 (한 피처에 이질적 도메인이 섞이지 않았는가)
- 자원 매트릭스의 ⚠ 표시 항목(중복 자원)이 모두 해소 또는 `foundation-*`로 추출되었는가
- 의존 그래프에 순환 의존이 없는가
- 분업 권고에 병렬 가능 그룹과 직렬 필수 구간이 구분되어 있는가
- 각 피처 슬러그가 kebab-case 명명 규칙을 따르는가
- `aidlc-state.md` Cross-Feature Dependencies 표가 동기화되었는가

### GATE-1: Planning Draft
- 목표/배경이 원래 요청 의도를 반영하는가
- 범위/정책 초안 누락 없는가
- 성공 지표가 측정 가능한가

### GATE-2: Requirements
- 기능/정책/운영 관점을 모두 포함하는가
- BLOCK 질문 답변이 완료되었는가
- Out-of-Scope가 명확한가, 리스크가 식별되었는가
- Readiness Score 60 미만이면 통과해도 구현 금지 유지

### GATE-2.5: User Stories
- 페르소나가 실제 사용자 유형을 반영하는가
- 유저 스토리가 INVEST 기준 충족하는가
- Acceptance Criteria가 Gherkin 형식으로 검증 가능한가
- 페르소나 간 관계/권한 경계가 명확한가

### GATE-2.7: Application Design
- 컴포넌트 식별이 적절하고 책임이 명확한가
- 서비스 레이어 구분이 합리적인가
- 의존성에 순환이 없는가
- Brownfield: 기존 구조와 연결점 명시 여부

### GATE-3: Unit of Work
- 작업 단위 분해가 적절한가
- 의존성 관계/규모 산정이 합리적인가
- 수용 기준이 검증 가능한가
- 모든 UOW 규모 필드(S/M/L)가 채워져야 통과 가능

### GATE-3.5: Technical Design
- ADR 결정이 근거 기반인가 (추측 아닌가)
- API 응답 형태가 명시적이고 완전한가
- 데이터 모델 변경이 기존 스키마와 호환되는가
- 모듈 구조가 UOW 분해와 일치하는가
- 암묵적 설계 결정이 남아 있지 않은가

### GATE-4: Infrastructure Design
- 리소스 구성이 요구사항에 부합하는가
- 보안/네트워크 설정이 적절한가
- 비용 추정이 합리적인가
- 마이그레이션 계획과 롤백 전략이 있는가

### GATE-5: Build & Test Instructions
- 빌드 절차가 재현 가능한가
- UOW별 빌드 순서가 의존성을 반영하는가
- 테스트 시나리오가 Acceptance Criteria를 커버하는가
- 에지 케이스/예외 테스트, Quality Gate 기준이 명확한가
- 모든 게이트 통과 + Readiness Score 80 이상이면 구현 가능 상태
