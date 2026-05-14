<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Requirement Verification Questions

> **Request Anchor**: 재구매 고객 할인 쿠폰 — 자동 발급, 사용 조건, 관리자 캠페인 관리

## Summary

| ID | 분류 | 우선순위 | 영향도 | 상태 | 미응답 시 |
|----|------|---------|--------|------|-----------|
| Q1 | policy | P1-IMPORTANT | high | OPEN | BLOCK |
| Q2 | policy | P1-IMPORTANT | high | OPEN | BLOCK |
| Q3 | domain | P1-IMPORTANT | medium | ANSWERED | ASSUME-A |

## 1. Domain And Scope

### Q3. 재구매 기준의 "구매 완료" 정의
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 재구매 기준 정의
- 유형: domain
- 분류: domain
- 영향도: medium
- 이유: "구매 완료"가 결제 완료인지, 배송 완료인지에 따라 재구매 판정 쿼리가 달라진다.
- 선택지:
  - A) 결제 완료 시점 → order 테이블의 paid_at 기준 조회
  - B) 배송 완료 시점 → delivery 테이블의 delivered_at 기준 조회
  - C) 기타 (직접 입력)
- AI 추천: A) 결제 완료 기준 — 근거: 결제 완료가 가장 단순하고 재작업 범위가 작음
- 미응답 시: ASSUME-A (결제 완료 기준이 가장 단순하고 재작업 범위가 작음)
- [답변]: A) 결제 완료 시점 기준으로 한다.
- [확신: 확실]

## 2. Policy / Exception

### Q1. 할인 방식: 정률 vs 정액
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 할인 쿠폰 발급
- 유형: policy
- 분류: policy
- 영향도: high
- 이유: 정률이면 금액 계산 로직과 최대 할인 한도가 필요하고, 정액이면 단순 차감이다. 데이터 모델과 결제 연동 로직이 완전히 다르다.
- 선택지:
  - A) 정액 할인 (예: 3,000원) → 캠페인 설정에 discount_amount 필드. 계산 단순
  - B) 정률 할인 (예: 10%) → 캠페인 설정에 discount_rate + max_discount_amount 필드. 금액 계산 로직 추가
  - C) 캠페인마다 선택 가능 → 두 필드 모두 필요. 분기 로직 추가
- 미응답 시: BLOCK
- [답변]:

### Q2. 다른 프로모션과 중복 적용 가능 여부
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 쿠폰 사용 조건
- 유형: policy
- 분류: policy
- 영향도: high
- 이유: 중복 적용 가능하면 결제 금액 계산에서 할인 순서를 정해야 한다. 불가능하면 "최대 1개 쿠폰" 검증 로직이 필요하다.
- 선택지:
  - A) 중복 불가 — 재구매 쿠폰 사용 시 다른 할인 적용 차단
  - B) 중복 가능 — 할인 순서 정의 필요
  - C) 기타 (직접 입력)
- 미응답 시: BLOCK
- [답변]:

## AI 자동 결정 (P2)

| # | 항목 | 디폴트 값 | 근거 | 변경 시 영향 |
|---|------|----------|------|-------------|
| 1 | 배치 실행 주기 | 일 1회 (새벽 3시) | 트래픽 최저 시간대, 운영 후 조정 가능 | 발급 지연 시간 |
| 2 | 쿠폰 유효기간 기본값 | 30일 | 업계 관행, 캠페인별 조정 가능 | 사용률만 영향 |
