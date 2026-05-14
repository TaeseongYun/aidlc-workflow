<!-- workflow-step: STEP-1 | gate: none | producer: ctx-aidlc-run | updated-by: all steps -->
# Feature Status

## Identity
- Feature Slug: repurchase-coupon
- Title: 재구매 고객 할인 쿠폰

## Readiness Score

| 영역 | 배점 | 점수 | 상태 |
|------|------|------|------|
| 기능 요구사항 명확성 | 20 | 18 | OK |
| 비기능 요구사항 확인 | 15 | 12 | OK |
| 도메인/상태 전이 정의 | 20 | 15 | ASSUME 포함 |
| 승인 항목 해결 | 20 | 5 | BLOCK 2건 |
| 외부 의존성 정의 | 10 | 8 | OK |
| 테스트/운영 계획 | 15 | 10 | OK |
| **합계** | **100** | **68** | **CONDITIONAL** |

## Scope
- 재구매 기준 정의 및 쿠폰 자동 발급
- 쿠폰 사용 제한 (1인 1회, 유효기간)
- 관리자 캠페인 ON/OFF

## Gate Approval History

| 게이트 | 결정 | 일시 | 비고 |
|--------|------|------|------|
| GATE-1 | approved | 2026-03-20T14:00:00Z | planning-draft 승인 |
| GATE-2 | approved | 2026-03-20T15:30:00Z | BLOCK 2건 잔여, 조건부 승인 |
| GATE-3 | approved | 2026-03-20T16:00:00Z | |
| GATE-3.5 | approved | 2026-03-20T17:00:00Z | technical-design 승인 |

## Approval
- Status: questions-open
- BLOCK Questions: 2
- ASSUME Conditions: 1

## Implementation
- Status: not-started

## Related Files
- `requirements.md`
- `requirement-verification-questions.md`
- `unit-of-work.md`
- `technical-design.md`

## Notes
- 기술 설계 생략 여부: M 규모 단위 있음 → STEP 6.5 필요
