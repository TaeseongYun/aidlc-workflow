<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

분해 기준: `core/units-generation.md`

## Summary

| ID | 책임 | 규모 | 의존성 | 상태 |
|----|------|------|--------|------|
| UOW-1 | 주문 목록 정렬 수정 | S | 없음 | TODO |

## UOW-1. 주문 목록 정렬 수정
- 책임: OrderRepository.findByUserId()의 정렬 조건을 DESC로 변경하고 단위 테스트 수정
- 예상 위치: domains/domain-rds/src/.../order/repository/OrderRepository.java
- 의존성: 없음
- 규모: S
- 수용 기준: GET /api/orders 응답이 created_at DESC 순이고 기존 테스트 통과
- 검증 방법: 단위 테스트 + API 통합 테스트

## Recommended Delivery Order
1. UOW-1 — 단일 작업

## 규모 기준
`core/unit-sizing.md`
