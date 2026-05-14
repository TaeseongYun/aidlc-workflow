<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Requirement Verification Questions

> **Request Anchor**: 멀티 벤더 정산 시스템 — 벤더별 매출 집계, 수수료 산출, PG 대사, 승인 워크플로우

## Summary

| ID | 분류 | 우선순위 | 영향도 | 상태 | 미응답 시 |
|----|------|---------|--------|------|-----------|
| Q1 | policy | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q2 | policy | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q3 | policy | P1-IMPORTANT | high | ANSWERED | BLOCK |
| Q4 | domain | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q5 | domain | P1-IMPORTANT | medium | ANSWERED | AI-RECOMMEND-B |
| Q6 | policy | P1-IMPORTANT | medium | ANSWERED | BLOCK |
| Q7 | domain | P1-IMPORTANT | medium | ANSWERED | AI-RECOMMEND-A |
| Q8 | scope | P1-IMPORTANT | medium | ANSWERED | DEFER-TO-FEATURE |
| Q9 | domain | P1-IMPORTANT | medium | ANSWERED | ASSUME-A |
| Q10 | policy | P0-CRITICAL | high | ANSWERED | BLOCK |
| Q11 | domain | P1-IMPORTANT | medium | ANSWERED | AI-RECOMMEND-A |
| Q12 | scope | P1-IMPORTANT | low | ANSWERED | DEFER-TO-FEATURE |

## 1. Domain And Scope

### Q4. PG사 대사 방식
- 우선순위: P0-CRITICAL
- 범위: [원래 요청] PG사 대사 연동
- 유형: domain
- 분류: domain
- 영향도: high
- 이유: PG사 API 구조에 따라 대사 배치 설계가 완전히 달라진다. 외부 연동이므로 P0.
- 선택지:
  - A) 건별 실시간 매칭 → 결제 완료 webhook에서 즉시 매칭
  - B) 일괄 배치 매칭 → PG사 일별 거래 내역 다운로드 후 매칭
  - C) 혼합 → webhook 우선, 누락분 배치로 보완
- AI 추천: C) 혼합 — 근거: 실시간 매칭이 빠르지만 webhook 누락 가능성 있으므로 배치 보완 필요
- 미응답 시: BLOCK
- [답변]: C) 혼합 방식 채택
- [확신: 확실]

### Q5. 정산 배치 실행 시간대
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 정산 주기 관리
- 유형: domain
- 분류: domain
- 영향도: medium
- 이유: 피크 시간 회피 및 PG사 데이터 갱신 시점에 맞춰야 한다.
- 선택지:
  - A) 새벽 3시 (트래픽 최저)
  - B) 새벽 6시 (PG사 일별 정산 완료 후)
  - C) 관리자가 수동 트리거
- AI 추천: B) 새벽 6시 — 근거: PG사 일별 정산 데이터가 보통 새벽 5시경 확정
- 미응답 시: AI-RECOMMEND-B
- [답변]: B) 새벽 6시
- [확신: 확실]

### Q8. 실시간 매출 대시보드 포함 여부
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 벤더 포탈 조회
- 유형: scope
- 분류: scope
- 영향도: medium
- 이유: 대시보드는 정산과 별도의 조회 최적화가 필요하다.
- 선택지:
  - A) 포함 → 실시간 집계 쿼리 또는 CQRS 패턴 필요
  - B) 제외 → 별도 feature로 분리
- 미응답 시: DEFER-TO-FEATURE
- [답변]: B) 별도 feature로 분리
- [확신: 확실]

### Q9. 정산 금액 반올림 규칙
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 수수료 산출
- 유형: domain
- 분류: domain
- 영향도: medium
- 이유: 금액 계산 정밀도에 따라 벤더 간 1원 차이 분쟁이 발생할 수 있다.
- 선택지:
  - A) 원 단위 반올림, 소수점 이하 절사 → 단순, 업계 관행
  - B) 원 단위 반올림, 소수점 이하 반올림 → 정밀하지만 복잡
- 미응답 시: ASSUME-A
- [답변]: A) 원 단위 반올림, 소수점 이하 절사
- [확신: 확실]

### Q11. 대사 불일치 처리 방식
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] PG 대사
- 유형: domain
- 분류: domain
- 영향도: medium
- 이유: 불일치 건이 정산 승인을 막는지, 별도 처리인지에 따라 워크플로우가 달라진다.
- 선택지:
  - A) 불일치 건은 정산에서 제외하고 별도 관리 → 정산은 매칭된 건만 진행
  - B) 불일치 건도 정산에 포함하되 경고 표시 → 관리자가 승인 시 확인
- AI 추천: A) 별도 관리 — 근거: 불일치 건을 정산에 포함하면 오류 전파 위험
- 미응답 시: AI-RECOMMEND-A
- [답변]: A) 불일치 건은 별도 관리
- [확신: 확실]

### Q12. 세금계산서 연동 포함 여부
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 정산 시스템 범위
- 유형: scope
- 분류: scope
- 영향도: low
- 이유: 세금계산서 발행은 별도 외부 연동(홈택스 API)이 필요하다.
- 미응답 시: DEFER-TO-FEATURE
- [답변]: 2차 범위로 분리
- [확신: 확실]

## 2. Policy / Exception

### Q1. 수수료 정책 유형
- 우선순위: P0-CRITICAL
- 범위: [원래 요청] 수수료 정책 적용
- 유형: policy
- 분류: policy
- 영향도: high
- 이유: 데이터 모델과 계산 로직이 완전히 달라진다. 핵심 비즈니스 정책이므로 P0.
- 선택지:
  - A) 정률만 (예: 10%) → 단순 계산
  - B) 정액만 (예: 건당 500원) → 단순 계산
  - C) 정률 + 정액 혼합 (벤더별 설정) → 유연하지만 데이터 모델 복잡
- 미응답 시: BLOCK
- [답변]: C) 혼합 방식. 벤더별로 정률/정액/혼합 중 선택 가능하도록 한다.
- [확신: 확실]

### Q2. 정산 주기 기본값
- 우선순위: P0-CRITICAL
- 범위: [원래 요청] 정산 주기 관리
- 유형: policy
- 분류: policy
- 영향도: high
- 이유: 주기에 따라 배치 설계와 벤더 현금흐름이 달라진다. 비즈니스 결정 필수.
- 선택지:
  - A) 월 1회 (1일~말일 집계, 다음 달 15일 지급)
  - B) 주 1회 (월~일 집계, 다음 수요일 지급)
  - C) 벤더별 선택 가능 (일/주/월)
- 미응답 시: BLOCK
- [답변]: C) 벤더별 선택 가능. 기본값은 월 1회.
- [확신: 확실]

### Q3. 수수료 변경 시 소급 적용 여부
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 수수료 정책
- 유형: policy
- 분류: policy
- 영향도: high
- 이유: 소급 적용 시 이미 산출된 정산 건을 재계산해야 하며, 벤더 분쟁 소지가 있다.
- 선택지:
  - A) 소급 없음 → 다음 정산 주기부터 적용. effective_from 기준.
  - B) 소급 적용 → 미지급 정산 건 재계산. 복잡도 증가.
- 미응답 시: BLOCK
- [답변]: A) 소급 없음. effective_from 이후 주문 건부터 새 수수료 적용.
- [확신: 확실]

### Q6. 정산 승인 단계 수
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 승인 워크플로우
- 유형: policy
- 분류: policy
- 영향도: medium
- 이유: 승인 단계에 따라 상태 머신과 역할 구조가 달라진다.
- 선택지:
  - A) 단일 승인 → 검토 → 승인(=지급 확정)
  - B) 이중 승인 → 검토 → 1차 승인 → 2차 승인(=지급 확정)
- 미응답 시: BLOCK
- [답변]: A) 단일 승인. 추후 필요 시 2차 승인 추가.
- [확신: 확실]

### Q7. 지급 실패 시 자동 재시도 여부
- 우선순위: P1-IMPORTANT
- 범위: [원래 요청] 정산 지급
- 유형: domain
- 분류: domain
- 영향도: medium
- 이유: 자동 재시도 시 중복 지급 방지 로직이 필요하다.
- 선택지:
  - A) 자동 재시도 (3회, exponential backoff) → 멱등키 기반 중복 방지 필요
  - B) 수동 재시도만 → 관리자가 재지급 버튼 클릭
- AI 추천: A) 자동 재시도 — 근거: 일시적 네트워크 오류가 대부분, 멱등키로 중복 방지 가능
- 미응답 시: AI-RECOMMEND-A
- [답변]: A) 자동 재시도 3회. 실패 시 관리자 알림.
- [확신: 확실]

### Q10. 정산 데이터 접근 권한
- 우선순위: P0-CRITICAL
- 범위: [원래 요청] 정산 승인 워크플로우
- 유형: policy
- 분류: policy
- 영향도: high
- 이유: 정산 금액은 민감 정보이므로 접근 권한이 보안 경계에 해당한다. P0.
- 선택지:
  - A) ROLE_SETTLEMENT_ADMIN만 전체 정산 CRUD
  - B) ROLE_SETTLEMENT_ADMIN(승인) + ROLE_SETTLEMENT_VIEWER(조회만)
  - C) 벤더는 본인 정산만 조회, 관리자는 전체 관리
- 미응답 시: BLOCK
- [답변]: C) 벤더는 본인 정산만, 관리자는 ROLE_SETTLEMENT_ADMIN으로 전체 관리.
- [확신: 확실]

## AI 자동 결정 (P2)

| # | 항목 | 디폴트 값 | 근거 | 변경 시 영향 |
|---|------|----------|------|-------------|
| 1 | 정산 배치 chunk size | 1000건 | 일반적 초기값, 운영 후 조정 가능 | 배치 속도만 영향 |
| 2 | PG 대사 재시도 횟수 | 3회 (exponential backoff) | AWS 권장 패턴 | 대사 완료 시간 |
| 3 | 감사 로그 보관 기간 | 5년 | 전자금융거래법 기준 | 스토리지 비용 |
