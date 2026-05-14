# 2026-04-29: prepared-requirement에서 STEP 4/GATE-2 스킵 차단

## 배경

실전 사용 중, `prepared-requirement` 입력 시 AI가 STEP 1-C(입력 검증) 통과 후 곧장 STEP 6(UOW)으로 직진하여 STEP 4 질문 답변을 받지 않고 GATE-2까지 묵시적으로 통과시키는 문제가 보고됨.

원인 분석:
1. `SKILL.md`의 "Prepared requirements should skip raw-request artifacts" 표현이 모호하여 모델이 "prepared면 사전 단계 전반을 스킵"으로 확장 해석
2. STEP 1-A의 "skip rounds 1-3"(Discovery 한정)이 STEP 4(검증 질문)까지 스킵하는 것으로 일반화될 여지
3. `stage-gate-rules.md`의 "게이트 건너뛰기"가 블랙리스트형 나열이라, GATE-2가 명시적으로 스킵 불가임을 강제하지 못함
4. `input-validation.md`의 검증 통과 메시지("STEP 2로 진행합니다")가 자동 직진을 부추기고, STEP 4/GATE-2가 별도 진행됨을 안내하지 않음
5. STEP 4에서 질문 0개로 통과하는 경우의 가드레일 부재

## 변경 사항

### 1. SKILL.md / CLAUDE_COMMAND.md — prepared 스킵 범위 한정 + STEP 4 강제

**파일**: `skills/ctx-aidlc-run/SKILL.md`, `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

- "Prepared requirements should skip raw-request artifacts." → 스킵 대상을 `request-intake.md`, `planning-draft.md`, GATE-1로 한정. STEP 4와 GATE-2는 계속 수행됨을 명시.
- STEP 4에 "분류별 강제 규칙" 블록 추가 (SKILL.md / CLAUDE_COMMAND.md 동기):
  - `prepared-requirement` / `change-on-existing-feature`여도 STEP 4 필수 실행
  - STEP 1-C에서 식별한 빈 영역은 STEP 4에서 BLOCK 질문으로 전환
  - P0/P1 질문 0개 산출 시 단독 통과 금지 — 누락 감지 재수행 또는 사용자 명시 확인 후 audit.md 기록
- GATE-2에 스킵 불가 명시 라인 추가 (SKILL.md / CLAUDE_COMMAND.md 동기):
  - 모든 요청 분류에서 스킵 불가, STEP 6 직접 진입 금지
  - 미답변 BLOCK 질문이 1건이라도 있으면 통과 금지

> 두 파일은 표면(스킬 하니스 vs Claude 슬래시 명령)이 다르므로 항상 병행 갱신해야 한다. 한쪽만 수정하면 `scripts/install-skills.sh` 재설치 후에도 한쪽 표면에서 옛 규칙이 그대로 노출된다.

### 2. stage-gate-rules.md — 게이트 스킵 화이트리스트화

**파일**: `common/stage-gate-rules.md`

- "게이트 건너뛰기" 섹션을 화이트리스트 표로 변환. 표에 명시되지 않은 게이트는 어떤 분류·조건에서도 스킵 불가.
- 스킵 가능 게이트: GATE-1 / GATE-2.5 / GATE-2.7 / GATE-4 / GATE-5
- "명시적 스킵 불가 게이트" 항목 신설: GATE-2 / GATE-3 / GATE-3.5
- "사용자 일괄 승인" 규칙 보강: "skip gate" 또는 "전체 승인" 명시 시에도 스킵 불가 게이트는 일괄 스킵 대상에서 제외.

### 3. input-validation.md — 후속 단계 안내 추가

**파일**: `core/input-validation.md`

- 검증 통과 메시지를 "검증 통과. STEP 2로 진행합니다. 단, STEP 4 질문 생성과 GATE-2는 별도로 수행됩니다."로 수정.
- "후속 단계 안내 (필수)" 섹션 신설:
  - 검증 결과와 무관하게 STEP 2 → 3 → 4 → 5 → GATE-2 흐름은 모두 수행됨을 명시
  - 입력 문서가 충분해 보여도 STEP 4 질문 생성을 건너뛰지 않음
  - GATE-2는 prepared-requirement에서도 스킵 불가, 사용자 승인 없이 STEP 6 진입 금지
  - "검증 통과 = 결정 완료"가 아니며, 검증은 형태 점검일 뿐 정책/설계 합의가 아님을 명시

## 수정된 파일 전체 목록

| 파일 | 변경 유형 |
|------|----------|
| `skills/ctx-aidlc-run/SKILL.md` | 스킵 범위 한정 + STEP 4 분류별 강제 규칙 + GATE-2 스킵 불가 |
| `skills/ctx-aidlc-run/CLAUDE_COMMAND.md` | 동일 규칙 병행 갱신 (Claude 슬래시 명령 표면) |
| `common/stage-gate-rules.md` | 게이트 건너뛰기 화이트리스트화 |
| `core/input-validation.md` | 검증 통과 메시지 수정 + 후속 단계 안내 추가 |
| `README.md` | 변경 이력 갱신 |

## 기대 효과

- prepared 입력에서 AI가 STEP 1-C 통과 후 곧장 STEP 6으로 점프하는 경로가 SKILL.md / stage-gate-rules.md 양쪽에서 차단된다.
- "skip"의 범위가 화이트리스트로 고정되어 모델이 임의 확장 해석할 여지가 줄어든다.
- STEP 4에서 질문 0개로 통과하는 경우 사용자 명시 확인이 필요하므로, 사전 검토 누락이 audit.md에 가시화된다.
