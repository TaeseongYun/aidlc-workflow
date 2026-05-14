<!-- workflow-step: STEP-6 | gate: GATE-3 | producer: ctx-aidlc-run -->
# Unit of Work

이 파일은 `aidlc-docs/features/<feature-slug>/unit-of-work.md`에 생성하는 것을 권장한다.

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

분해 기준:
- `core/units-generation.md`를 따른다.
- 결제/환불/정산은 항상 별도 단위로 검토한다.

## Summary

| ID | 책임 | 규모 | 의존성 | 상태 |
|----|------|------|--------|------|
| UOW-1 | | S/M/L | 없음 | TODO |
| UOW-2 | | S/M/L | UOW-1 | TODO |

## UOW-1. {단위 제목}
- 책임: {이 단위가 담당하는 것}
- 예상 위치: {코드/문서 경로}
- 의존성: 없음 / UOW-{N}
- 규모: S / M / L
- 수용 기준: {이 단위가 완료된 상태의 정의}
- 검증 방법: 단위 테스트 / 통합 테스트 / 수동 확인 / 코드 리뷰

## UOW-2. {단위 제목}
- 책임: {이 단위가 담당하는 것}
- 예상 위치: {코드/문서 경로}
- 의존성: UOW-1
- 규모: S / M / L
- 수용 기준: {이 단위가 완료된 상태의 정의}
- 검증 방법: 단위 테스트 / 통합 테스트 / 수동 확인 / 코드 리뷰

## Recommended Delivery Order
1. UOW-1 — {이유}
2. UOW-2 — {이유}

## 규모 기준
`core/unit-sizing.md`를 따른다.
