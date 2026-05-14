# Stop Conditions

워크플로우에서 "멈춰야 하는 시점"을 한곳에 정리한 문서다.
아래 조건 중 하나라도 해당하면 구현으로 진행하지 않는다.

## Decision Tree

```mermaid
flowchart TD
    A[요청 수신] --> B{raw-request인가?}
    B -->|Yes| C{planning-draft 작성 완료?}
    C -->|No| STOP1[STOP: planning-draft 먼저 작성]
    C -->|Yes| D{GATE-1 승인?}
    D -->|No| STOP2[STOP: 사용자 승인 대기]
    B -->|No| E[requirements + questions 작성]

    D -->|Yes| E
    E --> F{BLOCK 질문이 남아있는가?}
    F -->|Yes| STOP3[STOP: BLOCK 질문 해결 대기]
    F -->|No| G{GATE-2 승인?}
    G -->|No| STOP4[STOP: 사용자 승인 대기]
    G -->|Yes| H[unit-of-work 작성]

    H --> I{GATE-3 승인?}
    I -->|No| STOP5[STOP: 사용자 승인 대기]
    I -->|Yes| J{M/L 규모 단위 존재?}
    J -->|Yes| K[technical-design 작성]
    J -->|No| L[Readiness Score 산출]

    K --> M{GATE-3.5 승인?}
    M -->|No| STOP6[STOP: 사용자 승인 대기]
    M -->|Yes| L

    L --> N{Score >= 80?}
    N -->|Yes| READY[구현 가능]
    N -->|No| O{Score 60~79?}
    O -->|Yes| CONDITIONAL[ASSUME 조건부 진행]
    O -->|No| STOP7[STOP: 질문 해결 필요]
```

## 정책 기반 STOP 조건

아래 항목이 명시적으로 확정되지 않았으면 구현에 진입하지 않는다.
출처: `common/stage-gate-rules.md` 승인 필요 항목, `skills/ctx-aidlc-run/SKILL.md` WHEN TO STOP

| 조건 | 출처 |
|------|------|
| 환불/취소 정책이 미확정 | stage-gate-rules.md |
| 정산 기준이 미확정 | stage-gate-rules.md |
| 할인 우선순위/비용 부담 주체 미확정 | stage-gate-rules.md |
| 권한/역할 규칙 미확정 | stage-gate-rules.md |
| 외부 연동 방식 미확정 | stage-gate-rules.md |
| 알림 타이밍/채널 정책 미확정 | ctx-aidlc-run WHEN TO STOP |
| 기존 CTX와 새 요청이 충돌 | ctx-aidlc-run WHEN TO STOP |
| 복수 설계가 유효하고 ADR로 해소 불가 | ctx-aidlc-run WHEN TO STOP |
| technical-design.md Open Items에 미해결 항목 존재 | ctx-aidlc-run WHEN TO STOP |

## 게이트 기반 STOP 조건

| 게이트 | STOP 조건 |
|--------|----------|
| GATE-1 | 사용자가 planning-draft를 승인하지 않음 |
| GATE-2 | 사용자가 requirements를 승인하지 않음, 또는 BLOCK 질문 미해결 |
| GATE-3 | 사용자가 unit-of-work를 승인하지 않음, 또는 UOW 규모 필드 누락 |
| GATE-3.5 | 사용자가 technical-design을 승인하지 않음 |

## Readiness Score 기반 STOP

| 점수 | 판정 | 동작 |
|------|------|------|
| 80+ | READY | 구현 가능 |
| 60~79 | CONDITIONAL | ASSUME 조건 명시 후 진행 가능. 재작업 위험 있음 |
| 0~59 | NOT_READY | 구현 금지. BLOCK 질문 해결 필요 |
