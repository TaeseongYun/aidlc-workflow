# RICE Prioritization

기능 우선순위를 정량 평가하는 프레임워크.

## 공식

```
RICE Score = (Reach x Impact x Confidence) / Effort
```

## 항목 정의

### Reach (도달 범위)
- 일정 기간 내 이 기능의 영향을 받는 사용자/거래 수
- 예: "분기당 약 5,000명의 재구매 고객에게 노출"

### Impact (영향도)
- 개별 사용자/거래에 미치는 효과 크기
- 3: massive / 2: high / 1: medium / 0.5: low / 0.25: minimal

### Confidence (확신도)
- 위 추정에 대한 근거의 강도
- 100%: 데이터 기반 / 80%: 유사 사례 기반 / 50%: 직감 수준

### Effort (노력)
- 구현에 필요한 팀 작업량 (person-months)
- 예: 2 = 2명이 1개월 또는 1명이 2개월

## 사용 예시

| Feature | Reach | Impact | Confidence | Effort | Score |
|---------|-------|--------|------------|--------|-------|
| 재구매 할인 | 5000 | 2 | 80% | 2 | 4000 |
| VIP 등급 | 500 | 3 | 50% | 3 | 250 |

## 주의
- RICE는 우선순위 비교 도구이지 구현 결정 도구가 아니다.
- Score가 높아도 BLOCK 질문이 있으면 구현할 수 없다.
- Score 산출에 사용한 수치는 반드시 근거와 함께 기록한다.
