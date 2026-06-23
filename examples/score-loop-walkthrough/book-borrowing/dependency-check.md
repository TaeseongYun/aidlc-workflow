<!-- workflow-step: post-implementation | producer: ctx-score-loop | EXAMPLE -->
# Dependency Check — book-borrowing

> walkthrough 예시. `/ctx-score-loop book-borrowing` 실행 후 **3라운드 만에 완료(92점)**된 상태를 보여준다.
> 채점 기준: `core/dependency-score.md`. 절차: `core/dependency-score-eval.md`.

## Loop Config (기본값 사용 — 비워둠)

| 파라미터 | 기본값 | 이 피처 설정 |
|----------|--------|-------------|
| complete_threshold (초과 기준) | 85 | |
| stall_rounds (정체 판정) | 2 | |
| max_rounds (최대 반복) | 10 | |
| max_minutes (최대 시간) | 30 | |

---

## 1. 기능 간 선후관계 의존성 (Functional Order)

| # | 선행 항목 | 기대 상태 | 해결 | BLOCK | 근거 | 출처 |
|---|-----------|-----------|------|-------|------|------|
| F-1 | 회원(Member) 도메인 존재 | 사용 가능 | ☑ | ☐ | 기존 회원 테이블/엔티티 확인됨 | <!-- src: human --> |
| F-2 | 도서(Book) 도메인 존재 | 재고 필드 포함 | ☑ | ☐ | Book.availableCopies 필드 확인 | <!-- src: human --> |

## 2. 빌드/라이브러리 의존성 (Build / Library)

| # | 의존성 | 기대 버전/설정 | 해결 | BLOCK | 근거 | 출처 |
|---|--------|----------------|------|-------|------|------|
| B-1 | ORM/DB 트랜잭션 지원 | 비관적 락 가능 | ☑ | ☐ | SELECT FOR UPDATE 지원 확인 | <!-- src: auto --> |

## 3. 모듈 간 의존성 (Module)

| # | From → To | 기대 계약 | 해결 | BLOCK | 근거 | 출처 |
|---|-----------|-----------|------|-------|------|------|
| M-1 | loan → book | 재고 차감 API(원자적) | ☑ | ☐ | Book.decreaseStock() 호출/구현 확인 | <!-- src: auto --> |
| M-2 | loan → member | 회원 대출 수 조회 | ☑ | ☐ | Member.activeLoanCount() 확인 | <!-- src: auto --> |

---

## 4. Current Score (최신 라운드 = 3)

| 축 | 배점 | 점수 | 근거 (필수) |
|----|------|------|-------------|
| 1. 의존성 해결 | 25 | 25 | F-1/F-2/B-1/M-1/M-2 전부 해결, BLOCK 0건 |
| 2. 빌드/컴파일 | 25 | 25 | `gradle build` 종료 코드 0, 경고 0 (실행 로그 기준) |
| 3. 테스트/커버리지 | 25 | 20 | 단위·통합 12/12 통과(리포트 기준), 동시성 테스트 1건 미작성으로 -5 |
| 4. 요구사항/AC 충족 | 25 | 22 | UOW-1~3 수용기준 충족, FR-6(중복거부) 엣지 1건 보완 여지로 -3 |
| **총점** | **100** | **92** | |

**판정**: COMPLETE (92 > 85 AND 빌드 25 ≠ 0 → GR-1 통과)

---

## 5. Score History (append-only)

| round | total | per_axis (의/빌/테/AC) | verdict | timestamp (UTC) |
|-------|-------|----------------------|---------|-----------------|
| 1 | 75 | 18 / 25 / 12 / 20 | CONTINUE | 2026-06-23T01:30:00Z |
| 2 | 82 | 22 / 25 / 15 / 20 | CONTINUE | 2026-06-23T01:33:00Z |
| 3 | 92 | 25 / 25 / 20 / 22 | COMPLETE | 2026-06-23T01:37:00Z |

> 라운드마다 부족 축(테스트·AC)을 보완하며 75 → 82 → 92로 올라갔고, round 3에서 85를 초과해 **자동 완료**되었다.
> 만약 round 3에서도 82에 머물러 round 4까지 82였다면 → **2회 연속 미개선 = STALLED**로 중단·보고되었을 것이다.
