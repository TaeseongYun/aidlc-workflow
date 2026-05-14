<!-- workflow-step: STEP-5.5 | gate: GATE-2.5 | producer: ctx-aidlc-run | condition: User Scenarios >= 3 or new user types -->
# User Stories

이 파일은 `aidlc-docs/features/<feature-slug>/user-stories/stories.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/user-stories/personas.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- personas.md가 작성된 경우 함께 작성한다.
- 각 스토리는 INVEST 기준을 충족해야 한다.
- Acceptance Criteria는 Gherkin 형식(Given-When-Then)으로 작성한다.

---

## Summary

| ID | 페르소나 | 스토리 제목 | 우선순위 |
|----|---------|-----------|---------|
| US-1 | | | Must / Should / Could |
| US-2 | | | Must / Should / Could |

## US-1. {스토리 제목}

- 페르소나: {Persona N}
- 스토리: {역할}로서, {목표}를 달성하기 위해, {기능}을 원한다.
- 우선순위: Must / Should / Could

### Acceptance Criteria

```gherkin
Given {사전 조건}
When {사용자 행동}
Then {기대 결과}
```

### 참고사항
- {관련 requirements.md 항목 참조}

## US-2. {스토리 제목}

- 페르소나: {Persona N}
- 스토리: {역할}로서, {목표}를 달성하기 위해, {기능}을 원한다.
- 우선순위: Must / Should / Could

### Acceptance Criteria

```gherkin
Given {사전 조건}
When {사용자 행동}
Then {기대 결과}
```

### 참고사항
-

## INVEST 체크리스트

| 기준 | 설명 | US-1 | US-2 |
|------|------|------|------|
| Independent | 다른 스토리와 독립적으로 구현 가능한가 | | |
| Negotiable | 구현 방식에 여지가 있는가 | | |
| Valuable | 사용자에게 가치를 제공하는가 | | |
| Estimable | 규모 추정이 가능한가 | | |
| Small | 하나의 스프린트 내 완료 가능한가 | | |
| Testable | 수용 기준이 검증 가능한가 | | |
