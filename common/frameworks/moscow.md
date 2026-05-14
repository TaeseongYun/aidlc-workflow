# MoSCoW Prioritization

요구사항을 4단계로 분류하여 범위를 정리하는 프레임워크.

## 분류

### Must Have
- 이것 없이는 출시할 수 없다.
- 법적 요구, 핵심 비즈니스 로직, 데이터 정합성.

### Should Have
- 중요하지만 없어도 출시는 가능하다.
- 우회 방법이 있거나 수동 처리로 대체 가능.

### Could Have
- 있으면 좋지만 일정 압박 시 제외 가능.
- UX 개선, 편의 기능, 추가 알림.

### Won't Have (this time)
- 이번 범위에서 명시적으로 제외.
- 향후 검토 대상으로 기록.

## 사용 예시

| 요구사항 | 분류 | 근거 |
|----------|------|------|
| 재구매 할인 적용 | Must | 핵심 비즈니스 목표 |
| 할인 이력 대시보드 | Should | 수동 조회로 대체 가능 |
| 할인 추천 알고리즘 | Could | MVP 이후 검토 |
| 타사 포인트 연동 | Won't | 이번 범위 아님 |

## requirements.md 연결
- Must → In-Scope (Functional Requirements)
- Should → In-Scope (낮은 우선순위로 명시)
- Could → Out-of-Scope (향후 검토로 기록)
- Won't → Out-of-Scope (명시적 제외)

## 주의
- 분류는 사람이 결정한다. AI가 Must/Should를 임의로 판단하지 않는다.
- 분류 기준이 불명확하면 질문으로 올린다.
- Won't는 "안 한다"가 아니라 "이번에는 안 한다"이다. 삭제하지 않고 기록한다.
