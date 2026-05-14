# Workflow Guide

## Phase 0: Roadmapping (multi-feature 전용)

큰 prepared 기획서가 **여러 피처**로 분해되는 경우, Phase A 진입 전에 **Phase 0**(Roadmapping)을 선행한다. 단일 피처 작업에서는 Phase 0을 건너뛴다.

| 항목 | 내용 |
|------|------|
| 스킬 | `/ctx-aidlc-roadmap` |
| 입력 | prepared-requirement 원본 기획서 |
| 산출물 | `aidlc-docs/_roadmap.md` (프로젝트 레벨 단일 파일) |
| 게이트 | GATE-0 — Roadmap Review |
| 세션 종료 시점 | GATE-0 통과 후 |

진입 경로 (양방향):
1. **직접 호출**: 사용자가 큰 기획서를 받고 곧바로 `/ctx-aidlc-roadmap` 실행.
2. **핸드오프**: 사용자가 `/ctx-aidlc-run`을 먼저 실행했더라도 STEP 1-A 1번 라운드에서 "multiple independent features" 답변 AND `_roadmap.md` 미존재 → ctx-aidlc-run이 차단하고 `/ctx-aidlc-roadmap`을 안내.

GATE-0 통과 후에는 각 피처를 `/ctx-aidlc-run`으로 분담 실행한다 (각 피처는 prepared-requirement 분류, 원본 기획서의 해당 섹션을 입력).

자세한 운용 절차는 `docs/multi-feature-coordination.md`를 참조.

## 세션 분리 (기본 실행 모델)

모든 `/ctx-aidlc-run` 실행은 **Phase 단위 세션 분리**를 기본으로 한다.
하나의 세션에서 STEP 1~9를 모두 실행하면 LLM 컨텍스트 한계로 **답변 불일치, 산출물 간 모순**이 발생한다.

### Phase 구분

| Phase | 포함 STEP | 핵심 산출물 | 세션 종료 시점 |
|-------|----------|-----------|--------------|
| **0. Roadmapping** (multi-feature only) | R1, R2, R3, R4, R5, R6 | `_roadmap.md` | GATE-0 통과 후 |
| **A. Discovery** | 1, 1-A, 1-B, 1-C, 1.5, 2, 3 | `planning-draft.md`, `requirement-verification-questions.md` | GATE-1 통과 후 |
| **B. Definition** | 4, 5, 5.5, 5.7, 6 | `requirements.md`, `unit-of-work.md` | GATE-3 통과 후 |
| **C. Design** | 6.5, 6.7, 7, 8, 9 | `technical-design.md`, `build-instructions.md` | GATE-5 통과 후 |

### 적용 기준

| Depth Level | 세션 분리 | 이유 |
|-------------|----------|------|
| minimal | 선택 | 전체 컨텍스트가 작아 한 세션에서 가능 |
| standard | 권장 | 질문 수와 산출물이 많아지면 불일치 위험 |
| comprehensive | **필수** | 컨텍스트 초과로 인한 답변 불일치 방지 |

### 세션 분리 원칙

1. **각 Phase는 이전 Phase의 산출물만 참조한다.** 이전 세션의 대화 내용은 참조하지 않는다. 산출물이 유일한 인터페이스다.
2. **세션 재개 시 aidlc-state.md를 먼저 읽는다.** 현재 Phase, 완료된 STEP, 미해결 질문 수를 확인한다.
3. **Phase 전환 시 GATE 승인이 완료된 상태여야 한다.**

### 세션 재개 패턴

```text
/ctx-aidlc-run

Phase B를 시작한다.
aidlc-state.md를 먼저 읽고 현재 상태를 확인해라.
Phase A 산출물을 기준으로 요구사항 확정과 유닛 분해를 진행해라.

관련 산출물:
- aidlc-docs/features/<feature-slug>/planning-draft.md
- aidlc-docs/features/<feature-slug>/requirement-verification-questions.md
```

```text
/ctx-aidlc-run

Phase C를 시작한다.
aidlc-state.md를 먼저 읽고 현재 상태를 확인해라.

관련 산출물:
- aidlc-docs/features/<feature-slug>/requirements.md
- aidlc-docs/features/<feature-slug>/unit-of-work.md
```

---

## 사용 순서

### 1. 요구사항 분석 단계
- 목적:
  - 요구사항 공백 식별
  - 구현 전 질문 추출
  - unit-of-work 작성
  - (조건부) 사용자 스토리 정의, 시스템 구조 설계, 인프라 설계
- 사용 스킬:
  - `/ctx-aidlc-run`
- 이 단계의 결과:
  - 프로젝트 `aidlc-docs/` 생성 또는 갱신
  - 구현 전 멈춰야 할 질문 목록 정리
  - 새 기능이면 `aidlc-docs/features/<feature-slug>/` 생성
  - `status.md` 생성 및 초기 상태 기록
  - (조건부) `user-stories/`, `application-design/` 하위 산출물 생성
  - (조건부) `infrastructure-design.md`, `deployment-architecture.md` 생성

### 2. 사람 답변/승인 단계
- 목적:
  - 정책, UX, 정산, 환불 등 사람이 최종 결정해야 하는 항목 확정
  - 각 Gate(GATE-1 ~ GATE-5)에서 산출물 리뷰 및 승인
- 입력:
  - `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
  - 각 Gate별 리뷰 대상 산출물
- 결과:
  - 구현 가능한 요구사항으로 고정
  - `status.md`와 `aidlc-state.md` 상태 갱신
  - `audit.md`에 Gate 승인 기록 append

### 3. 구현 단계
- 목적:
  - 승인된 요구사항 기준으로 실제 코드 변경
- 사용 스킬:
  - `/ctx-run`
- 이 단계의 결과:
  - 코드 변경
  - 테스트
  - 필요 시 `ctx/` 보강

## 표준 사용 패턴

### 패턴 A. 신규 기능 시작
1. `/ctx-aidlc-run`으로 요구사항 분석 시작
2. `aidlc-docs/features/<feature-slug>/` 산출물 생성
3. 질문 문서에 대해 기획/오너 답변 수집
4. `/ctx-run`으로 구현

### 패턴 A-1. 날것 요구사항 시작
1. 마케팅/운영/현업의 원문 요청을 그대로 입력한다.
2. `/ctx-aidlc-run`으로 `request-intake.md`와 `planning-draft.md`를 먼저 생성한다.
3. 정책, 예외, 운영, 성공 기준을 질문 문서로 정리한다.
4. 답변 반영 후 `requirements.md`를 implementation-ready 상태로 승격한다.
5. 그 다음 `/ctx-run`으로 구현한다.

### 패턴 A-2. 기존 feature 추가 요청
1. `/ctx-aidlc-run`으로 먼저 기존 `feature-slug`와 연결 가능한지 판단한다.
2. 같은 feature의 후속 변경이면 기존 feature 폴더를 갱신한다.
3. 독립 기능이면 새 feature 폴더를 만든다.

### 패턴 B. 단순 구현 요청
- 이미 `ctx/`와 `aidlc-docs`에 필요한 결정이 모두 있으면 바로 `/ctx-run`

### 패턴 C. 정책이 섞인 대형 변경
- 반드시 `/ctx-aidlc-run`부터 시작
- 결제, 환불, 정산, 권한, 알림, 운영 영향이 있으면 구현 전에 질문 문서 작성

세션 분리 가이드는 문서 상단 "세션 분리 (기본 실행 모델)" 섹션을 참조한다.

---

## 어떤 경우에 /ctx-aidlc-run을 써야 하나
- 마케팅/운영/영업의 날것 요청이 바로 들어올 때
- 요구사항에 정책 공백이 많을 때
- 신규 도메인 추가일 때
- 기존 결제/환불/정산/권한/알림과 연결될 때
- 여러 팀이 함께 보는 기능일 때
- brownfield에서 영향 범위를 먼저 확인해야 할 때
- greenfield로 새 프로젝트를 시작할 때

## 어떤 경우에 /ctx-run만 써도 되나
- 이미 CTX와 기존 문서에 답이 명확할 때
- 기존 패턴을 그대로 따르는 소규모 변경일 때
- API/정책/정산 판단이 새로 필요하지 않을 때

## 요청 분류 원칙
- `raw-request`
  - 마케팅/운영/현업 원문 수준의 요청
  - 목표는 있으나 범위, 정책, 성공 기준이 정리되지 않음
  - 이 경우에만 `request-intake.md`, `planning-draft.md`를 만든다.
- `prepared-requirement`
  - 이미 구조화된 요구사항
  - 이 경우 `requirements.md` 중심으로 바로 진행한다.
- `change-on-existing-feature`
  - 기존 feature에 대한 추가 변경 또는 후속 요구사항
  - 이 경우 새 폴더보다 기존 feature 폴더 갱신을 우선 검토한다.

## Greenfield / Brownfield 기준
- `greenfield`
  - 완전 신규 프로젝트
  - 기존 코드/DB/API/운영 흐름이 사실상 없음
  - 요구사항과 도메인 정의부터 시작
- `brownfield`
  - 기존 프로젝트
  - 기존 코드/DB/API/운영/배포 제약을 읽어야 함
  - 새 기능도 기존 구조에 맞춰 들어가야 함

실무 기준:
- 기존 시스템을 읽어야 시작할 수 있으면 `brownfield`
- 읽을 기존 시스템이 없고 요구사항부터 세우면 `greenfield`

## Greenfield 사용 흐름

greenfield에서는 `ctx`가 입력이 아니라 중간 산출물이다.

### 1. 먼저 /ctx-aidlc-run
- 목적:
  - 요구사항 구조화
  - 질문 추출
  - unit-of-work 정의
  - 초기 프로젝트 구조 초안 생성
- 입력:
  - 제품 목표
  - 사용자/운영자
  - 핵심 기능
  - 제약 조건

### 2. aidlc-docs 먼저 생성
- 최소 산출물:
  - `aidlc-docs/aidlc-state.md`
  - `aidlc-docs/audit.md`
  - `aidlc-docs/features/<feature-slug>/status.md`
  - `aidlc-docs/features/<feature-slug>/requirements.md`
  - `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
  - `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- raw request인 경우 추가:
  - `aidlc-docs/features/<feature-slug>/request-intake.md`
  - `aidlc-docs/features/<feature-slug>/planning-draft.md`
- 조건부 산출물 (해당 시):
  - `aidlc-docs/features/<feature-slug>/user-stories/personas.md`
  - `aidlc-docs/features/<feature-slug>/user-stories/stories.md`
  - `aidlc-docs/features/<feature-slug>/application-design/components.md`
  - `aidlc-docs/features/<feature-slug>/application-design/services.md`
  - `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md`
  - `aidlc-docs/features/<feature-slug>/infrastructure-design.md`
  - `aidlc-docs/features/<feature-slug>/deployment-architecture.md`
  - `aidlc-docs/features/<feature-slug>/build-instructions.md`
  - `aidlc-docs/features/<feature-slug>/test-instructions.md`
  - `aidlc-docs/features/<feature-slug>/extensions/security-baseline.md`

### 3. 사람 답변/승인
- 요구사항 공백을 메운다.
- 정책, 예외, 운영 방식을 확정한다.

### 4. 최소 ctx 생성
- greenfield에서 `ctx`는 구현 전에 만들어지는 프로젝트 지식 베이스다.
- 처음부터 많은 문서를 만들 필요는 없다.
- 최소 권장 구조:

```text
ctx/
├── INDEX.md
├── project-profile.ctx.md
├── common/
│   ├── global.ctx.md
│   └── decisions.ctx.md
└── workflow/
    └── commit-workflow.ctx.md
```

### 5. 구현은 /ctx-run
- 이 시점부터는 `ctx`와 `aidlc-docs`를 함께 기준으로 사용한다.

## 날것 요구사항 처리 원칙
- 마케팅/운영 원문은 먼저 `request-intake.md`에 보존한다.
- AI는 날것 요구사항을 바로 확정 요구사항으로 바꾸지 않는다.
- 먼저 `planning-draft.md`에서 목표, 대상 사용자, 범위, 비범위, 운영 가정, 성공 기준을 구조화한다.
- 정책/예외/권한/알림/정산/운영 공백은 `requirement-verification-questions.md`로 분리한다.
- 질문이 해결된 뒤에만 `requirements.md`를 구현 기준 문서로 사용한다.

## 실제 시작 예시

### 날것 요구사항 분석 시작 예시

```text
/ctx-aidlc-run

이 요청은 기획 문서가 없는 raw request다.
team-ai-workflow 기준으로 먼저 기획 초안을 작성해라.
ctx/INDEX.md가 있으면 먼저 읽고, 없으면 CLAUDE.md 또는 README.md를 읽어라.
관련 ctx만 추가로 읽어라.
다음 순서로 문서를 작성해라:
- request-intake.md
- planning-draft.md
- requirement-verification-questions.md
- requirements.md
- unit-of-work.md

규칙:
- 마케팅 표현을 그대로 구현 규칙으로 확정하지 말 것
- 추정은 추정으로 표시할 것
- 사람이 답해야 하는 정책은 질문으로 올릴 것
- 질문이 남아 있으면 구현 가능한 상태라고 판단하지 말 것

Feature:
- 재구매 고객을 대상으로 특정 기간 동안 할인 혜택을 주고 재방문을 유도하고 싶다.
```

### 요구사항 분석 시작 예시

```text
/ctx-aidlc-run

이번 요구사항을 team-ai-workflow 기준으로 분석해라.
ctx/INDEX.md가 있으면 먼저 읽고, 없으면 AGENTS.md 또는 CLAUDE.md, README.md를 읽어라.
관련 ctx만 추가로 읽어라.
aidlc-docs 산출물을 만들고, 정책 공백이 있으면 질문 문서에서 멈춰라.
새 요구사항이면 `aidlc-docs/features/<feature-slug>/` 아래에 작성해라.
해당 feature 폴더에 `status.md`도 함께 생성해라.

Feature:
- 예약 취소 정책이 포함된 신규 결제 기능 추가

Relevant CTX Path(s):
- ctx/INDEX.md
- ctx/project-profile.ctx.md
```

### 구현 시작 예시

```text
/ctx-run

aidlc-docs와 ctx에 승인된 내용 기준으로 구현해라.
새 정책을 추정하지 말고 기존 결정만 사용해라.
해당 feature 폴더의 산출물만 기준으로 구현해라.

Feature:
- 승인된 요구사항 중 예약 상태 전이 및 API 구현

Relevant CTX Path(s):
- ctx/INDEX.md
- ctx/project-profile.ctx.md
- ctx/domain/*.ctx.md
```

### Greenfield 시작 예시

```text
/ctx-aidlc-run

신규 프로젝트다. ctx는 아직 없다.
team-ai-workflow 기준으로 greenfield 요구사항 분석을 수행해라.
aidlc-docs를 먼저 생성하고, 필요한 질문과 unit-of-work를 정리해라.
초기 ctx 최소 구조도 제안해라.

Feature:
- 신규 B2B 승인 요청 처리 시스템을 만든다
- 사용자는 요청 등록, 상태 조회, 결과 확인을 할 수 있어야 한다
- 운영자는 승인 정책과 처리 상태를 관리해야 한다
```
