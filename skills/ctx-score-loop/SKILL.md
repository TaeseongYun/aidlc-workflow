---
description: Dependency-aware score loop — implement once, then auto-iterate 4-axis scoring until >85 or stalled
model: opus
allowed-tools: Read, Write, Edit, Bash, Skill
---

# ctx-score-loop

구현 **이후**, 의존성과 4축 검증을 자동 반복 채점하여 **85점 초과 시에만 완료**로 판정하는 루프.
"코드 구현 단 한 번의 요청"으로 사용자 추가 개입 없이 자율 반복한다.

Framework root: `{{TEAM_AI_WORKFLOW_DIR}}`

## 입력
- `<feature-slug>` 또는 대상 피처/모듈 경로 (필수)
- `engine`: `ralph`(기본) / `evolve` / `native` (선택)
- 상한 오버라이드: `max_rounds`, `max_minutes` (선택, 기본 10/30)

## 전제 (Hard Preconditions)
- GATE-3(구현 승인)를 통과한 피처에만 실행한다. 이 루프는 **GATE를 자동 통과시키지 않는다.**
- 채점 기준: `{{TEAM_AI_WORKFLOW_DIR}}/core/dependency-score.md`
- 채점 절차: `{{TEAM_AI_WORKFLOW_DIR}}/core/dependency-score-eval.md`
- 의존성 md 구조: `{{TEAM_AI_WORKFLOW_DIR}}/templates/dependency-check.md`

## 실행 흐름 (한 번 요청 → 자율 반복)

```
[1회 요청] → 루프 시작
  반복 {
    STEP A: 의존성 md 동기화 (사람 항목 보존 머지)
    STEP B: 빌드·테스트 명령 실제 실행 (미실행 축 0점)
    STEP C: 4축 채점 (각 25점, 근거 필수)
    STEP D: verdict 판정
    STEP E: Score History append + status.md 미러 + 보고
  } until verdict != CONTINUE
```

판정 규칙(`dependency-score-eval.md` STEP D):
- `COMPLETE` (total > 85 AND 빌드축 ≠ 0): "완료(85 초과)" 보고 후 **종료**.
- `CONTINUE`: 부족 축 보완 구현 후 다음 라운드.
- `STALLED` (2회 연속 미개선) / `EXHAUSTED` (10회 또는 30분) / `REGRESSED` (점수 하락): **즉시 중단**, 막힌 축·점수·사유 보고, **자동 재시작 금지**, 사람 결정 대기.

## 게이팅 (필수)
- **GR-1**: 빌드 축 0점이면 total > 85라도 COMPLETE 금지.
- **GR-2**: BLOCK 미해결 의존성 1건 이상이면 의존성 축 최대 12점.

## 엔진 위임
- 기본 `ralph`: `docs/omc-ouroboros-integration.md` §2-2 핸드오프 경로 사용. 종료조건 "의존성 md 4축 점수 > 85 & 빌드축 ≠ 0" 주입.
- `evolve` / `native`: 동일 종료조건을 해당 엔진에 전달. 규약은 엔진 독립적.

## 보고 형식
```
[ctx-score-loop] <feature-slug> — round N
  의존성 22/25 · 빌드 25/25 · 테스트 20/25 · AC 23/25 = 90/100
  verdict: COMPLETE (85 초과)
  → 완료. 루프 종료.
```
중단 시:
```
[ctx-score-loop] <feature-slug> — STALLED at round N
  최종 82/100. 막힌 축: 테스트(15/25 — CouponTest 2건 실패)
  → 중단. 사람 결정 대기.
```

## 금지 사항
- 빌드·테스트 축을 명령 실행 없이 추정 채점하지 않는다 (0점).
- 점수를 올리려 BLOCK 의존성을 임의 해제하지 않는다.
- 근거 없이 숫자만 기록하지 않는다.
- 중단 후 사람 승인 없이 자동 재시작하지 않는다.
- GATE를 자동 통과시키지 않는다.
- 사람이 작성한 의존성 md 항목(`<!-- src: human -->`)을 수정/삭제하지 않는다.

## 상세 가이드
`{{TEAM_AI_WORKFLOW_DIR}}/docs/score-loop-guide.md`
