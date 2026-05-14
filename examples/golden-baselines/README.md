# Golden Baselines

워크플로우 변경 시 품질 회귀를 감지하기 위한 참조 출력 세트이다.

## 사용법

```bash
# 특정 baseline으로 검증 도구 실행
bash tools/evaluator/validate-all.sh examples/golden-baselines/standard-feature
```

워크플로우 규칙을 수정한 후 3개 baseline 모두 통과하는지 확인한다.

## Baseline 목록

| Baseline | Depth | 시나리오 | 특징 |
|----------|-------|---------|------|
| `minimal-bugfix/` | minimal | 기존 패턴 재사용 버그 수정 | 질문 3개 이하, 조건부 STEP 대부분 스킵, UOW 1개 |
| `standard-feature/` | standard | 중간 규모 신규 기능 | 질문 7개 이하, GATE-3까지 진행, UOW 3~5개 |
| `comprehensive-platform/` | comprehensive | 대규모 플랫폼 기능 | 질문 12개, 전체 GATE 활성, UOW 5개+, 기술 설계 포함 |

## Baseline 갱신 원칙

- 워크플로우 규칙 변경 시 baseline도 함께 갱신한다.
- 갱신 전 기존 baseline을 백업한다.
- 갱신 사유를 changelog에 기록한다.
