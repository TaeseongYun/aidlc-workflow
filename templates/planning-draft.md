<!-- workflow-step: STEP-3 | gate: GATE-1 | producer: ctx-aidlc-run | condition: raw-request only -->
# Planning Draft

이 파일은 `aidlc-docs/features/<feature-slug>/planning-draft.md`에 생성하는 것을 권장한다.

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

선행 문서:
- `aidlc-docs/features/<feature-slug>/request-intake.md`

후행 문서:
- `aidlc-docs/features/<feature-slug>/requirements.md`

---

## Planning Mode
- Request Type:
  - raw-request / prepared-requirement
- Project Mode:
  - greenfield / brownfield

---

## 1. Executive Summary

문제, 솔루션, 기대 효과를 1~2문단으로 요약한다.
비개발자(기획자, 사업담당자, 경영진)가 이 문단만 읽고 전체 맥락을 파악할 수 있어야 한다.

> {요약 작성}

---

## 2. Problem Statement

### 누가 겪는가
-

### 무엇이 문제인가
-

### 왜 문제인가 (비즈니스 영향)
-

### 근거
- 고객 피드백:
- 데이터/지표:
- 내부 관찰:

---

## 3. Target Users & Personas

### Primary Users
- 역할:
- 핵심 과업 (Jobs-to-be-Done):
- 현재 해결 방법:

### Secondary Users
- 역할:
- 핵심 과업:

### Operators / Admin
- 역할:
- 필요 권한:
- 운영 시나리오:

### Stakeholders
- 의사결정권자:
- 승인 필요 사항:

---

## 4. Strategic Context

### Business Goals
- 연관 OKR/KPI:
- 비즈니스 임팩트:

### 경쟁 환경 (해당 시)
- 유사 서비스/기능:
- 차별화 포인트:

### 왜 지금인가
- 시장/내부 트리거:
- 지연 시 리스크:

이 섹션은 선택적이다. 내부 도구나 운영 개선처럼 시장 맥락이 불필요한 경우 "해당 없음"으로 표기한다.

---

## 5. Solution Overview

### 상위 설명
-

### 핵심 기능 목록
1.
2.
3.

### 사용자 플로우 (주요 시나리오)

핵심 시나리오를 텍스트로 기술한다.
복잡한 플로우는 `diagram-standards.md`에 따라 다이어그램을 추가한다.

1. {시나리오명}:
   - 시작 조건:
   - 사용자 행동:
   - 시스템 응답:
   - 종료 상태:

### Brownfield 연결점 (기존 시스템이 있을 때)
- 연관 모듈/서비스:
- 연관 테이블/API:
- 기존 흐름과의 관계 (대체 / 확장 / 병행):

---

## 6. Scope Draft

### In-Scope Draft
-

### Out-of-Scope Draft
- {제외 항목}: {제외 이유}

---

## 7. Policy Draft

비즈니스 정책이 관련된 항목만 작성한다. 해당 없는 항목은 삭제한다.

- Pricing / Discount:
- Eligibility:
- Lifecycle / Expiration:
- Cancellation / Refund:
- Notification / Messaging:
- Admin / Operations:

---

## 8. Success Metrics

### Primary Metric
- 지표:
- 현재 기준값 (baseline):
- 목표값:
- 측정 기간:

### Secondary Metrics
- [ ] {지표}: {목표값} (측정 기간: ___)

### Guardrail Metrics
이 기능이 악화시키면 안 되는 지표를 기록한다.
- [ ] {지표}: {허용 범위}

### 판정 방법
- 측정 도구:
- 판정 시점:
- 판정 주체:

---

## 9. Dependencies & Risks

### 기술 의존성
-

### 외부 의존성 (연동, 파트너, 인프라)
-

### 리스크 & 대응
| 리스크 | 영향 | 발생 가능성 | 대응 방안 |
|--------|------|------------|----------|
| | high/medium/low | high/medium/low | |

---

## 10. Assumptions
-

---

## 11. Open Decisions
-

---

## 12. Recommendation
- Ready for requirements drafting:
- Requires stakeholder answers before requirements:
- Suggested next action:
