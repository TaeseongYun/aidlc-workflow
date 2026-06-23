# Dependency Score — Evaluation Procedure

루프가 **한 라운드**의 4축 채점을 어떻게 실행하는지의 규약이다.
점수 기준은 `core/dependency-score.md`, 스키마는 `core/dependency-score.schema.yaml`를 따른다.

## 입력
- 대상 피처/모듈의 의존성 검증 md (`templates/dependency-check.md` 구조)
- `unit-of-work.md` (AC 채점 기준)
- `requirements.md` Functional Requirements (AC 채점 기준)
- 빌드/테스트 명령 (출처: `build-instructions.md`, `test-instructions.md`, 또는 UOW Verification 섹션)

## 한 라운드 채점 절차

### STEP A. 의존성 md 동기화 (S-1)
1. 의존성 md가 없으면 `templates/dependency-check.md`로 생성한다.
2. 의존성을 탐지해 갱신하되, **출처 마커 머지 규칙**을 따른다:
   - `<!-- src: human -->` 항목: 읽기만. 수정/삭제 금지.
   - `<!-- src: auto -->` 항목 및 신규 자동 탐지 항목: 갱신.
   - 마커 없는 항목: human으로 간주, 보존.

### STEP B. 빌드/테스트 실제 실행 (S-3)
1. 빌드 명령을 **실제로 실행**하고 종료 코드/로그를 수집한다.
2. 테스트 명령을 **실제로 실행**하고 리포트를 수집한다.
3. 명령을 실행하지 않았거나 명령을 찾지 못하면, 해당 축은 **0점**으로 처리한다 (FR-4). 추정 채점 금지.

### STEP C. 4축 채점 (S-2)
각 축을 `core/dependency-score.md` 기준으로 채점하고 **근거 문장을 필수**로 기록한다.

1. **의존성 해결 (25)**: md 체크리스트 해결 비율로 비례 채점. BLOCK 미해결 1건 이상이면 최대 12점 (GR-2).
2. **빌드/컴파일 (25)**: STEP B의 빌드 결과 근거. 미실행 시 0점.
3. **테스트/커버리지 (25)**: STEP B의 테스트 결과 근거. 미실행 시 0점. 커버리지 목표 미정의 시 해당 5점 "해당 없음"으로 만점 제외.
4. **요구사항/AC (25)**: UOW 수용 기준 + requirements FR 기준으로 채점 (FR-5).

점수는 정수로 반올림한다.

### STEP D. 종료/중단 판정 (S-4)
총점과 Score History를 보고 verdict를 결정한다:

```
if 빌드축 == 0:                      verdict = INCOMPLETE  (GR-1: 완료 불가)
elif total > 85:                     verdict = COMPLETE
elif 라운드수 >= max_rounds
     or 경과시간 >= max_minutes:     verdict = EXHAUSTED
elif total < 직전_total:             verdict = REGRESSED
elif 최근 stall_rounds회 개선폭 == 0: verdict = STALLED
else:                                verdict = CONTINUE
```

- 개선폭 판정: 직전 라운드 대비 총점이 +1 미만이면 "미개선"으로 본다.
- 기본 파라미터: complete_threshold=85(초과), stall_rounds=2, max_rounds=10, max_minutes=30. 의존성 md의 Loop Config로 오버라이드 가능 (ADR-5).

### STEP E. 기록·보고 (S-5)
1. Score History에 `round | total | per_axis | verdict | ts(UTC)` 1행 append.
2. status.md의 Post-Implementation Score(최신 총점) 미러.
3. verdict별 동작:
   - `COMPLETE`: "완료(85 초과)" 보고 후 루프 종료.
   - `CONTINUE`: 부족 축을 보완 구현하고 다음 라운드(STEP A)로.
   - `STALLED` / `EXHAUSTED` / `REGRESSED`: **즉시 중단**, 막힌 축/항목·현재 점수·사유 보고, **자동 재시작 금지** (FR-13). 사람 결정 대기.
4. audit 기록 시 `[LOOP]` 프리픽스 사용.

## 금지 사항
- 빌드·테스트 축을 명령 실행 없이 추정 채점하지 않는다 (0점 처리).
- 점수를 올리기 위해 BLOCK 의존성을 임의 해제하지 않는다.
- 근거 없이 숫자만 기록하지 않는다.
- COMPLETE를 빌드 0점 상태에서 선언하지 않는다 (GR-1).
- 중단 후 사람 승인 없이 자동 재시작하지 않는다.
- GATE(사람 승인)를 자동 통과시키지 않는다. 루프는 GATE-3 이후 구간에서만 동작한다.
