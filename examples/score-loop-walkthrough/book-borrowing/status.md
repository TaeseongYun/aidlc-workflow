<!-- workflow-step: STEP-1 | gate: none | producer: ctx-aidlc-run | EXAMPLE -->
# Feature Status — 도서 대출

## Identity
- Feature Slug: book-borrowing
- Title: 도서 대출 (Book Borrowing)
- Request Type: prepared-requirement
- Status: approved (GATE-2/3 통과 — 예시)

## Readiness Score

| 영역 | 배점 | 점수 | 상태 |
|------|------|------|------|
| 기능 범위 정의 | 15 | 15 | Goal/In/Out 명확 |
| 정책/예외 확정 | 20 | 18 | 중복 정책 AI추천(경고 마크) |
| 사용자 시나리오 | 15 | 15 | 시나리오 3 + 엣지 2 |
| NFR 확인 | 15 | 13 | 동시성 전략 P2 |
| 승인 항목 해결 | 20 | 20 | BLOCK 0 |
| 리스크 평가 | 15 | 14 | 리스크 2 + 대응 |
| **합계** | **100** | **95** | **READY** |

**판정: READY (95/100)** — BLOCK 0건.

### 불확실 영역
- Q1 중복 대출 정책 `[AI추천]` — 도메인 전문가 검토 권장.

## Post-Implementation Score (구현 후 — ctx-score-loop)

> 아래는 3단계 점수 루프가 채운 **최종** 값이다. 라운드별 변화는 `dependency-check.md`의 Score History를 본다.

| 항목 | 값 |
|------|-----|
| 최신 총점 | 92 |
| 최신 라운드 | 3 |
| 축별 (의/빌/테/AC) | 25 / 25 / 20 / 22 |
| 판정 | COMPLETE (>85) |
| 최종 갱신 | 2026-06-23T01:37:56Z |

## Implementation
- Code Started: (예시 — 가상 구현)

## Related Files
- Requirements: ./requirements.md
- Questions: ./requirement-verification-questions.md
- Unit of Work: ./unit-of-work.md
- Dependency Check (점수 루프): ./dependency-check.md
- Loop Run Log: ./LOOP-RUN.md
