<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Feature Requirements

## Goal
멀티 벤더 마켓플레이스에서 벤더별 정산 금액을 자동 산출하고, 관리자 승인 후 지급하는 정산 시스템을 구축한다.

## Background
- 현재 정산은 엑셀 수작업 (월 1회, 담당자 1명)
- 벤더 수 증가로 수작업 한계 도달 (현재 50개 → 연말 200개 예상)
- PG사(토스페이먼츠) 연동하여 대사 자동화 필요
- 기존 order, payment, vendor 도메인 존재

## In-Scope
- 벤더별 매출 집계 (주문 완료 기준)
- 수수료 정책 적용 (정률/정액/혼합, 벤더별 상이)
- 정산 주기 관리 (일/주/월, 벤더별 설정)
- PG사 대사 연동 (결제 건별 매칭)
- 관리자 정산 승인 워크플로우 (생성 → 검토 → 승인 → 지급)
- 벤더 포탈 정산 내역 조회 API
- 정산 이력 감사 로그

## Out-of-Scope
- 세금계산서 자동 발행 (2차 범위)
- 벤더 가입/심사 프로세스
- 실시간 매출 대시보드 (별도 feature)

## User Scenarios
1. 정산 담당자가 월 정산 실행 → 시스템이 벤더별 금액 자동 산출 → 담당자가 검토 후 승인
2. 벤더 A가 포탈에서 정산 내역 조회 → 주문별 수수료, 정산 금액, 상태 확인
3. PG사 대사 불일치 발생 → 시스템이 불일치 건 목록 생성 → 담당자가 수동 처리
4. 벤더 B의 수수료율 변경 → 다음 정산 주기부터 새 수수료 적용 (소급 없음)
5. 정산 승인 후 지급 실패 → 재시도 또는 수동 처리 → 감사 로그 기록

## Functional Requirements
- FR-1: 주문 완료(delivered) 건에 대해 벤더별 매출을 집계한다
- FR-2: 벤더별 수수료 정책(정률/정액/혼합)을 적용하여 정산 금액을 산출한다
- FR-3: 정산 주기(일/주/월)를 벤더별로 설정할 수 있다
- FR-4: PG사 결제 내역과 주문 건을 자동 매칭하여 대사한다
- FR-5: 정산 워크플로우: 생성 → 검토 → 승인 → 지급 상태 관리
- FR-6: 관리자 API로 정산 생성/검토/승인/반려가 가능하다
- FR-7: 벤더 API로 본인 정산 내역을 조회할 수 있다
- FR-8: 모든 정산 상태 변경은 감사 로그에 기록한다
- FR-9: 대사 불일치 건은 별도 목록으로 관리하며 수동 처리를 지원한다

## Non-Functional Requirements
- NFR-1: 정산 배치는 200 벤더 × 월 10만 건 주문 기준 30분 이내 완료
- NFR-2: PG사 API 호출은 rate limit(100 req/s) 준수
- NFR-3: 정산 금액 계산은 원 단위 반올림, 소수점 이하 절사
- NFR-4: 정산 데이터는 5년 보관
- NFR-5: 정산 승인은 ROLE_SETTLEMENT_ADMIN 권한만 가능

## Derived Requirements
- DR-1: settlement 테이블 (settlement_id, vendor_id, period, amount, fee, net_amount, status)
- DR-2: settlement_detail 테이블 (settlement_id, order_id, order_amount, fee_amount)
- DR-3: vendor_fee_policy 테이블 (vendor_id, fee_type, fee_rate, fee_amount, effective_from)
- DR-4: reconciliation 테이블 (pg_transaction_id, order_id, match_status, resolved_at)
- DR-5: 기존 order 도메인에서 기간별 벤더 매출 집계 쿼리 필요

## Requirement Gaps
- 없음 (전체 질문 응답 완료)

## Approval Preconditions
- 모두 해결됨

## Initial Risk Assessment
- R-1: PG사 API 응답 시간 변동 → 타임아웃/재시도 정책 필요 (P0)
- R-2: 대량 정산 배치 실행 시 DB 부하 → 배치 크기 조절, 읽기 전용 복제본 사용 검토
- R-3: 수수료 정책 변경 시 기존 정산 건 소급 여부 → 소급 없음으로 확정 (Q3)
- R-4: 정산 금액 오류 시 롤백 프로세스 → 반려 상태로 되돌리고 재산출
