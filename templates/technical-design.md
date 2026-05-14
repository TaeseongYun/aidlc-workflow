<!-- workflow-step: STEP-6.5 | gate: GATE-3.5 | producer: ctx-aidlc-run | condition: M/L units exist -->
# Technical Design

이 파일은 `aidlc-docs/features/<feature-slug>/technical-design.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- unit-of-work에 M 또는 L 규모 단위가 1개 이상 있을 때 작성한다.
- 모든 unit-of-work가 S 규모이면 이 문서를 생략할 수 있다.
- 생략 시 status.md에 "기술 설계 생략 — 전체 S 규모"로 기록한다.

---

## Implementation Scope

이 설계를 기준으로 이번 구현의 수준을 명시한다.
설계가 production을 목표로 하더라도 이번 구현이 prototype이라면 반드시 기록한다.

- 구현 수준: `production` / `prototype` / `local-MVP`
- Mock 허용 범위: `none` / `external-api-only` / `storage-only` / `all-external`
- 이번 구현에서 제외된 항목:
  - (없으면 "없음")
- Production 전환 시 추가 작업:
  - (없으면 "없음")

---

## 1. Design Overview

이 기능의 기술 설계 요약. 핵심 아키텍처 결정과 설계 방향을 2~5문장으로 기술한다.

- 대상 시스템/모듈:
- 설계 방향:
- brownfield 연결점: (기존 코드/모듈과의 접점)

## 2. Architecture Decisions

설계 과정에서 내린 기술 결정을 기록한다. 결정이 여러 개이면 항목을 추가한다.

### ADR-1. {결정 제목}

- 상태: proposed | accepted
- 맥락: (이 결정이 필요한 배경, 제약 조건)
- 선택지:
  - A) {옵션 A} — {장단점}
  - B) {옵션 B} — {장단점}
- 결정: {선택한 옵션과 이유}
- 영향: {이 결정으로 인한 기술적 결과}

## 3. API Specification

API 변경/추가가 없으면 "해당 없음"으로 표기한다.

### {HTTP Method} {Path}

- 목적:
- 요청:

```
{요청 구조}
```

- 응답:

```
{응답 구조}
```

- 에러 코드:
  - {코드}: {설명}

## 4. Data Model

DB 스키마 변경이 없으면 "해당 없음"으로 표기한다.

### 신규/변경 엔티티

| 엔티티 | 필드 | 타입 | 제약 조건 | 비고 |
|--------|------|------|----------|------|
| | | | | |

### 마이그레이션 필요 여부

- 필요 / 불필요
- (필요 시 마이그레이션 전략 간략 기술)

## 5. Module/Component Structure

변경 대상 모듈과 책임을 명시한다.

| 모듈/클래스 | 책임 | 신규/변경 | 대상 UOW |
|------------|------|----------|---------|
| | | | |

## 6. Interaction Flow

주요 유스케이스의 상호작용 흐름. `diagram-standards.md`를 따른다.
단순 플로우는 ASCII, 복잡한 관계는 Mermaid + 텍스트 대안.

플로우가 자명하면 "해당 없음"으로 표기한다.

## 7. Non-functional Design

`nfr-checklist.md` 기반으로 이 기능에 해당하는 항목만 기술한다.

- 성능:
- 정합성:
- 보안:
- 운영:

해당 없는 항목은 생략한다.

## 8. Testing Approach

unit-of-work의 검증 방법을 구체화한다.

| 대상 UOW | 테스트 유형 | 검증 내용 |
|---------|-----------|----------|
| | | |

## 9. Open Items

기술 설계 시점에서 미확정 사항. 구현 전 확인이 필요한 항목을 나열한다.
없으면 "없음"으로 표기한다.
