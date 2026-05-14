<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

분해 기준:
- `core/units-generation.md`를 따른다.
- 규모 기준: `core/unit-sizing.md`를 따른다.

## Summary

| ID | 책임 | 규모 | 의존성 | 상태 |
|----|------|------|--------|------|
| UOW-1 | 캠페인 도메인 모델 및 저장소 | S | 없음 | TODO |
| UOW-2 | 재구매 판정 쿼리 | S | UOW-1 | TODO |
| UOW-3 | 쿠폰 자동 발급 배치 | M | UOW-1, UOW-2 | TODO |
| UOW-4 | 관리자 캠페인 API | S | UOW-1 | TODO |
| UOW-5 | 쿠폰 사용 검증 및 결제 연동 | M | UOW-1 | TODO |
| UOW-6 | 발급/사용 현황 조회 API | S | UOW-1, UOW-3 | TODO |

## UOW-1. 캠페인 도메인 모델 및 저장소
- 책임: campaign 테이블, coupon_issue 테이블, JPA Entity, Repository 생성
- 예상 위치: domains/domain-rds/src/.../campaign/
- 의존성: 없음
- 규모: S
- 수용 기준: Entity와 Repository가 존재하고 기본 CRUD 테스트 통과
- 검증 방법: 단위 테스트

## UOW-2. 재구매 판정 쿼리
- 책임: 최근 N일 내 결제 완료 이력이 있는 고객 ID 목록 조회
- 예상 위치: domains/domain-rds/src/.../order/repository/
- 의존성: UOW-1
- 규모: S
- 수용 기준: 기간 조건으로 재구매 대상 고객 목록을 정확히 반환
- 검증 방법: 단위 테스트 (테스트 데이터 기반)

## UOW-3. 쿠폰 자동 발급 배치
- 책임: 스케줄러로 재구매 대상 조회 → 미발급 고객에게 쿠폰 발급 → 발급 이력 기록
- 예상 위치: center/back-end/src/.../campaign/batch/
- 의존성: UOW-1, UOW-2
- 규모: M
- 수용 기준: 배치 실행 시 대상 고객에게 쿠폰 발급, 중복 발급 없음, 10만 건 기준 5분 이내 완료
- 검증 방법: 통합 테스트

## UOW-4. 관리자 캠페인 API
- 책임: 캠페인 CRUD + ON/OFF API
- 예상 위치: center/back-end/src/.../campaign/controller/
- 의존성: UOW-1
- 규모: S
- 수용 기준: 캠페인 생성/수정/조회/ON/OFF가 API로 동작
- 검증 방법: 통합 테스트

## UOW-5. 쿠폰 사용 검증 및 결제 연동
- 책임: 주문 시 쿠폰 적용 요청 → 유효성 검증 → 할인 적용 → 사용 처리
- 예상 위치: center/back-end/src/.../payment/service/, .../coupon/service/
- 의존성: UOW-1
- 규모: M
- 수용 기준: 유효한 쿠폰 적용 시 할인 반영, 만료/사용완료 쿠폰 차단, 최소 주문 금액 미달 차단
- 검증 방법: 통합 테스트

## UOW-6. 발급/사용 현황 조회 API
- 책임: 관리자용 발급 현황, 사용률 통계 API
- 예상 위치: center/back-end/src/.../campaign/controller/
- 의존성: UOW-1, UOW-3
- 규모: S
- 수용 기준: 캠페인별 발급 수, 사용 수, 사용률 반환
- 검증 방법: 통합 테스트

## Recommended Delivery Order
1. UOW-1 — 다른 모든 단위의 기반
2. UOW-2 — 배치(UOW-3)의 선행 조건
3. UOW-4 — 관리자가 캠페인을 먼저 생성해야 배치가 의미 있음
4. UOW-3 — 실제 발급 동작
5. UOW-5 — 발급된 쿠폰을 사용하는 흐름
6. UOW-6 — 현황 조회는 데이터가 쌓인 후 의미 있음

## 규모 기준
`core/unit-sizing.md`를 따른다.
