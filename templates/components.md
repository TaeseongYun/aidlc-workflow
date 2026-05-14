<!-- workflow-step: STEP-5.7 | gate: GATE-2.7 | producer: ctx-aidlc-run | condition: UOW >= 3 or new component creation -->
# Components

이 파일은 `aidlc-docs/features/<feature-slug>/application-design/components.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/requirements.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- UOW가 3개 이상 예상되거나 신규 컴포넌트 생성이 포함될 때 작성한다.
- 기존 컴포넌트 내 변경만으로 충분한 경우 생략할 수 있다.
- 생략 시 status.md에 "시스템 구조 설계 생략 — 기존 컴포넌트 변경만 해당"으로 기록한다.

---

## Component Overview

| ID | 컴포넌트명 | 책임 | 유형 | 신규/기존 |
|----|----------|------|------|---------|
| C-1 | | | API / Service / Batch / UI / Infra | 신규 / 기존 변경 |
| C-2 | | | | |

## C-1. {컴포넌트명}

- 책임: {이 컴포넌트가 담당하는 것}
- 유형: API / Service / Batch / UI / Infra
- 신규/기존: 신규 / 기존 변경
- 주요 기능:
  - {기능 1}
  - {기능 2}
- 기술 스택: {해당 시 명시}
- Brownfield 연결점: {기존 모듈/서비스와의 접점. 없으면 "없음"}

## C-2. {컴포넌트명}

- 책임:
- 유형:
- 신규/기존:
- 주요 기능:
  -
- 기술 스택:
- Brownfield 연결점:
