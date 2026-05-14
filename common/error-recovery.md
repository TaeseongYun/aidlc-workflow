# Error Recovery

워크플로우 실행 중 오류나 중단이 발생했을 때의 복구 절차를 정의한다.

## 1. 오류 심각도 분류

| 심각도 | 설명 | 워크플로우 영향 |
|--------|------|----------------|
| **CRITICAL** | 워크플로우 진행 불가 | 필수 산출물 누락, aidlc-state.md 손상, 필수 입력 처리 불가 |
| **HIGH** | 현재 STEP 완료 불가 | BLOCK 질문 미답변, 이전 STEP 산출물 불완전, 모순 미해결 |
| **MEDIUM** | 우회하여 진행 가능 | 조건부 산출물 누락, 비핵심 검증 실패 |
| **LOW** | 진행에 영향 없음 | 포맷 불일치, 선택 정보 누락 |

## 2. 세션 재개 절차

세션 분리(`docs/workflow-guide.md` 참조) 후 새 세션에서 재개할 때의 절차이다.

### 2.1 상태 확인 (필수)

1. `aidlc-docs/aidlc-state.md`를 읽는다.
2. 아래 항목을 확인한다:
   - Current Stage: 현재 어디까지 진행했는가
   - Current Phase: A / B / C 중 어느 단계인가
   - Stage Progress 체크박스: 완료/스킵/미진행 상태
   - Confidence Summary: 불확실 답변 현황

3. 사용자에게 현재 상태를 요약하여 제시한다:
```markdown
## 세션 재개

- Feature: {feature-slug}
- 마지막 완료: {마지막 [x] STEP}
- 다음 단계: {다음 미진행 STEP}
- 미해결 항목: {BLOCK 질문 수, UNCERTAIN 마커 수}

> A) 이어서 진행 — {다음 단계 설명}
> B) 이전 단계 리뷰 — 수정이 필요한 부분 확인
```

### 2.2 산출물 무결성 검증

다음 STEP으로 진행하기 전에, 해당 STEP에 필요한 이전 산출물이 존재하고 유효한지 확인한다.

| 진행할 STEP | 필요한 산출물 |
|-------------|-------------|
| STEP 4-5 | requirements.md 또는 planning-draft.md |
| STEP 5.5 | requirements.md, requirement-verification-questions.md |
| STEP 5.7 | requirements.md, (있다면) stories.md |
| STEP 6 | requirements.md |
| STEP 6.5 | unit-of-work.md |
| STEP 6.7 | unit-of-work.md, (있다면) technical-design.md |
| STEP 7-8 | unit-of-work.md, requirements.md |
| STEP 9 | unit-of-work.md, requirements.md, Readiness Score >= 80 |

### 2.3 불일치 발견 시

**aidlc-state.md에 완료로 표시되었으나 산출물이 없는 경우**:
1. aidlc-state.md의 해당 STEP을 `[ ]`로 되돌린다.
2. 해당 STEP부터 재실행한다.
3. `audit.md`에 `[RECOVERY] STEP {N} — 산출물 누락으로 재실행` 이벤트를 기록한다.

**산출물은 존재하나 aidlc-state.md에 미완료로 표시된 경우**:
1. 산출물 내용이 완전한지 확인한다 (필수 섹션, 빈 섹션 여부).
2. 완전하면 aidlc-state.md를 `[x]`로 갱신한다.
3. 불완전하면 해당 STEP부터 재실행한다.

## 3. STEP별 오류 처리

### STEP 1 (Project Detection) 오류

**프로젝트 루트를 식별할 수 없음**:
- 사용자에게 프로젝트 경로와 구조를 확인 요청한다.
- 최소 정보(언어, 프레임워크)로 진행 가능하면 사용자 제공 정보로 대체한다.

**greenfield/brownfield 판단이 불확실**:
- 기존 코드, DB, 운영 시스템이 **하나라도** 있으면 brownfield로 판단한다.
- 판단 근거를 `audit.md`에 기록한다.

### STEP 3-5 (분석/질문/요구사항) 오류

**사용자가 모순된 답변을 제공**:
- `content-validation.md`의 모순 감지 규칙에 따라 처리한다.
- 모순이 해결될 때까지 GATE-2를 진행하지 않는다.

**질문 답변이 불완전 (일부만 응답)**:
1. 미응답 질문 목록을 명시한다.
2. BLOCK 질문이 미응답이면 해당 질문을 다시 제시한다.
3. ASSUME/AI-RECOMMEND 질문이 미응답이면 `question-governance.md`의 미응답 대응 규칙을 적용한다.

### STEP 6 (Unit Decomposition) 오류

**순환 의존성 발견**:
1. 순환 관계를 명시한다: "UOW-A → UOW-B → UOW-A".
2. 분해 기준(`core/units-generation.md`)에 따라 경계를 재조정한다.
3. 재조정 후 GATE-3에서 사용자 확인을 받는다.

### STEP 7 (Readiness Score) 오류

**점수 산출 기준 데이터 부족**:
- 누락된 도메인은 0점으로 산출한다 (가점 없음).
- `status.md`에 "미평가 도메인" 섹션으로 명시한다.
- 미평가 도메인이 2개 이상이면 자동으로 NOT_READY 판정한다.

## 4. 산출물 복구 절차

### 산출물 재생성이 필요한 경우

1. 기존 산출물을 백업한다: `{파일명}` → `{파일명}.backup.md`
2. `audit.md`에 `[RECOVERY] {파일명} — 재생성 시작. 사유: {사유}` 이벤트를 기록한다.
3. 해당 STEP을 처음부터 재실행한다.
4. 재생성 완료 후 백업 파일은 사용자가 삭제를 승인할 때까지 보존한다.

### aidlc-state.md 손상 시

1. 백업을 생성한다: `aidlc-state.md.backup`
2. 사용자에게 현재 진행 상황을 확인한다.
3. `aidlc-docs/features/<feature-slug>/` 내 존재하는 산출물 목록을 기반으로 상태를 재구성한다.
4. 재구성 결과를 사용자에게 제시하고 승인을 받은 후 적용한다.
5. `audit.md`에 `[RECOVERY] aidlc-state.md — 손상으로 재구성` 이벤트를 기록한다.

## 5. 사용자 요청에 의한 되돌리기

### STEP 재실행 요청

사용자가 특정 STEP의 결과에 불만족하여 재실행을 요청한 경우:

1. 해당 STEP의 산출물을 백업한다.
2. **해당 STEP 이후에 의존하는 STEP이 이미 완료되었는지** 확인한다.
3. 의존 STEP이 있으면 사용자에게 경고한다:
   ```
   STEP {N} 재실행 시 STEP {M}, {L}의 산출물도 영향을 받습니다.
   해당 산출물도 함께 재생성하시겠습니까?
   ```
4. 사용자 승인 후 재실행한다.
5. `audit.md`에 `[REDO] STEP {N} — 사용자 요청으로 재실행` 이벤트를 기록한다.

### GATE에서 변경 요청

사용자가 GATE에서 "수정 요청"을 선택한 경우:

1. 수정 요청 내용을 `audit.md`에 원문 그대로 기록한다.
2. 수정 범위를 판단한다:
   - **부분 수정**: 해당 산출물만 수정하고 다시 GATE를 제시한다.
   - **전면 재작업**: 해당 STEP을 처음부터 재실행한다.
3. 수정이 이전 STEP의 산출물에도 영향을 미치면 사용자에게 알린다.

## 6. audit.md 로깅 포맷

복구/오류 이벤트는 아래 포맷으로 기록한다.

```markdown
## [RECOVERY] {대상}
- Timestamp: {ISO 8601}
- Feature: {feature-slug}
- Error Type: CRITICAL / HIGH / MEDIUM / LOW
- Description: {발생한 문제}
- Resolution: {수행한 조치}
- Artifacts Affected: {영향받은 파일 목록}
```

## 7. 금지 사항

- 산출물 손상/누락을 무시하고 다음 STEP으로 진행하지 않는다.
- 백업 없이 산출물을 재생성하지 않는다.
- 사용자 확인 없이 aidlc-state.md를 재구성하지 않는다.
- 복구 이벤트를 audit.md에 기록하지 않고 넘어가지 않는다.
