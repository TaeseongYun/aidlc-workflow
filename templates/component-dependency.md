<!-- workflow-step: STEP-5.7 | gate: GATE-2.7 | producer: ctx-aidlc-run | condition: UOW >= 3 or new component creation -->
# Component Dependency

이 파일은 `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/application-design/components.md`
- `aidlc-docs/features/<feature-slug>/application-design/services.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- components.md와 services.md가 작성된 경우 함께 작성한다.
- 컴포넌트가 2개 이하이면 생략할 수 있다.

---

## Dependency Matrix

| From \ To | C-1 | C-2 | C-3 | 외부 시스템 |
|-----------|-----|-----|-----|----------|
| C-1 | - | {관계} | | |
| C-2 | | - | {관계} | |
| C-3 | | | - | {관계} |

관계 유형: `호출` / `이벤트` / `DB 공유` / `없음`

## 의존성 방향 규칙

- 순환 의존이 있는가: 예 / 아니오
- 순환 의존이 있으면 해소 방안을 기술한다.

## 핵심 의존 경로

1. {사용자 요청} -> C-{N} -> C-{M} -> {결과}
2. {배치 트리거} -> C-{N} -> {외부 시스템} -> {결과}

## Brownfield 영향

- 기존 컴포넌트에 새 의존이 추가되는 경우를 명시한다.
- 기존 의존성 변경이 필요한 경우 영향 범위를 기술한다.
