<!-- workflow-step: STEP-5.7 | gate: GATE-2.7 | producer: ctx-aidlc-run | condition: UOW >= 3 or new component creation -->
# Services

이 파일은 `aidlc-docs/features/<feature-slug>/application-design/services.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/application-design/components.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- components.md가 작성된 경우 함께 작성한다.
- 서비스 레이어 구분이 필요 없는 단순 구조이면 생략할 수 있다.

---

## Service Layer Overview

| ID | 서비스명 | 책임 | 소속 컴포넌트 | 외부 노출 여부 |
|----|---------|------|------------|-------------|
| S-1 | | | C-{N} | 내부 / 외부 API |
| S-2 | | | C-{N} | |

## S-1. {서비스명}

- 책임: {이 서비스가 담당하는 비즈니스 로직}
- 소속 컴포넌트: C-{N}
- 외부 노출: 내부 전용 / REST API / gRPC / 이벤트
- 주요 오퍼레이션:
  - {오퍼레이션 1}: {입력} -> {출력}
  - {오퍼레이션 2}: {입력} -> {출력}
- 의존하는 서비스: S-{N} / 외부 시스템명 / 없음
- 트랜잭션 경계: {단일 트랜잭션 / 분산 / 이벤트 기반}

## S-2. {서비스명}

- 책임:
- 소속 컴포넌트:
- 외부 노출:
- 주요 오퍼레이션:
  -
- 의존하는 서비스:
- 트랜잭션 경계:

## 서비스 간 통신 방식

- 동기 호출: {서비스 간 직접 호출 관계}
- 비동기 이벤트: {이벤트 기반 통신 관계}
- 외부 연동: {외부 시스템과의 연결 방식}
