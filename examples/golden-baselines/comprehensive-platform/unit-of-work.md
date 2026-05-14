<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

분해 기준: `core/units-generation.md`

## Summary

| ID | 책임 | 규모 | 의존성 | 상태 |
|----|------|------|--------|------|
| UOW-1 | 정산 도메인 모델 및 저장소 | M | 없음 | TODO |
| UOW-2 | 벤더 수수료 정책 관리 | S | UOW-1 | TODO |
| UOW-3 | 매출 집계 및 정산 산출 배치 | L | UOW-1, UOW-2 | TODO |
| UOW-4 | PG사 대사 연동 | M | UOW-1 | TODO |
| UOW-5 | 정산 승인 워크플로우 API | M | UOW-1, UOW-3 | TODO |
| UOW-6 | 벤더 정산 조회 API | S | UOW-1 | TODO |
| UOW-7 | 정산 감사 로그 | S | UOW-1, UOW-5 | TODO |

## UOW-1. 정산 도메인 모델 및 저장소
- 책임: settlement, settlement_detail, vendor_fee_policy, reconciliation 테이블 및 Entity/Repository
- 예상 위치: domains/domain-rds/src/.../settlement/
- 의존성: 없음
- 규모: M
- 수용 기준: 4개 테이블 DDL, Entity, Repository 생성. 기본 CRUD 테스트 통과.
- 검증 방법: 단위 테스트

## UOW-2. 벤더 수수료 정책 관리
- 책임: 벤더별 수수료 정책 CRUD API, effective_from 기반 적용 로직
- 예상 위치: center/back-end/src/.../settlement/service/FeePolicy*
- 의존성: UOW-1
- 규모: S
- 수용 기준: 정률/정액/혼합 정책 설정 가능, effective_from 이후 적용 확인
- 검증 방법: 단위 테스트

## UOW-3. 매출 집계 및 정산 산출 배치
- 책임: 주문 완료 건 벤더별 집계 → 수수료 적용 → 정산 금액 산출 → settlement 생성
- 예상 위치: center/back-end/src/.../settlement/batch/
- 의존성: UOW-1, UOW-2
- 규모: L
- 수용 기준: 200 벤더 × 10만 건 기준 30분 이내, 정산 금액 = 매출 - 수수료, 원 단위 절사
- 검증 방법: 통합 테스트 + 성능 테스트

## UOW-4. PG사 대사 연동
- 책임: PG사 API 호출 → 거래 내역 다운로드 → 주문 건 매칭 → 불일치 목록 생성
- 예상 위치: center/back-end/src/.../settlement/reconciliation/
- 의존성: UOW-1
- 규모: M
- 수용 기준: 매칭 성공/실패/불일치 분류, rate limit 준수, webhook + 배치 혼합
- 검증 방법: 통합 테스트 (PG API mock)

## UOW-5. 정산 승인 워크플로우 API
- 책임: 정산 상태 관리 (생성 → 검토 → 승인 → 지급), 관리자 API, 지급 재시도
- 예상 위치: center/back-end/src/.../settlement/controller/, service/
- 의존성: UOW-1, UOW-3
- 규모: M
- 수용 기준: 상태 전이가 규칙대로 동작, 권한 검증(ROLE_SETTLEMENT_ADMIN), 재시도 3회
- 검증 방법: 통합 테스트

## UOW-6. 벤더 정산 조회 API
- 책임: 벤더 포탈용 정산 내역 조회 API (본인 정산만 접근)
- 예상 위치: center/back-end/src/.../settlement/controller/VendorSettlement*
- 의존성: UOW-1
- 규모: S
- 수용 기준: 벤더별 정산 목록/상세 조회, 타 벤더 데이터 접근 차단
- 검증 방법: 통합 테스트 (권한 테스트 포함)

## UOW-7. 정산 감사 로그
- 책임: 정산 상태 변경 이벤트 기록, 조회 API
- 예상 위치: center/back-end/src/.../settlement/audit/
- 의존성: UOW-1, UOW-5
- 규모: S
- 수용 기준: 모든 상태 변경이 감사 로그에 기록, 5년 보관 정책 적용
- 검증 방법: 통합 테스트

## Recommended Delivery Order
1. UOW-1 — 전체 기반
2. UOW-2 — 정산 산출의 선행 조건
3. UOW-4 — 대사 연동 (독립 작업 가능)
4. UOW-3 — 핵심 배치 (UOW-1, UOW-2 필요)
5. UOW-5 — 승인 워크플로우 (UOW-3 이후)
6. UOW-7 — 감사 로그 (UOW-5 이벤트 필요)
7. UOW-6 — 벤더 조회 (데이터 축적 후 의미)

## 규모 기준
`core/unit-sizing.md`
