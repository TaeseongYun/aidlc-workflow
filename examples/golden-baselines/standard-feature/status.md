<!-- workflow-step: STEP-7 | gate: none | producer: ctx-aidlc-run | updated-by: all steps -->
# Feature Status

## Identity
- Feature Slug: standard-feature
- Title: 재구매 고객 할인 쿠폰

## Readiness Score

| 영역 | 배점 | 점수 | 상태 |
|------|------|------|------|
| 기능 범위 정의 | 15 | 15 | OK |
| 정책/예외 확정 | 20 | 5 | BLOCK 2건 |
| 사용자 시나리오 | 15 | 15 | OK |
| NFR 확인 | 15 | 12 | OK |
| 승인 항목 해결 | 20 | 5 | BLOCK 2건 |
| 리스크 평가 | 15 | 12 | OK |
| **합계** | **100** | **64** | **CONDITIONAL** |

## Scope
- 재구매 기준 정의 및 쿠폰 자동 발급
- 쿠폰 사용 제한 (1인 1회, 유효기간)
- 관리자 캠페인 ON/OFF

## Gate Approval History

| 게이트 | 결정 | 일시 | 비고 |
|--------|------|------|------|
| GATE-2 | approved | 2026-03-20T15:30:00Z | BLOCK 2건 잔여, 조건부 승인 |
| GATE-3 | approved | 2026-03-20T16:00:00Z | UOW 6건 확인 |

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
