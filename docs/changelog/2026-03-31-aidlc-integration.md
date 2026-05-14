# 변경 사항: AI-DLC 산출물 통합 및 실시간 audit/state 갱신

## 변경 일자
2026-03-31

## 배경

AWS AI-DLC(aidlc-workflows) 프로젝트와 비교 분석한 결과 다음 공백이 확인되었다:
- 사용자 관점(User Stories) 산출물 부재 → "누구를 위한 건지" 검증 불가
- 시스템 구조(Application Design) 산출물이 technical-design.md 하나에 뭉쳐 있어 리뷰 어려움
- 인프라/배포/운영 산출물 부재 → Construction 이후 공백
- 보안 체크리스트 미지원
- audit.md/aidlc-state.md가 Gate 통과 시에만 갱신 → 과정 기록 누락

AI-DLC 25개 산출물 중 커버리지가 60%(15개)에서 80%(20개)로 상승하는 것을 목표로 통합하였다.

---

## 신규 템플릿 (10개)

### INCEPTION 확장 (5개)

| 파일 | 용도 | 발동 조건 | Gate |
|------|------|---------|------|
| `templates/personas.md` | 사용자 페르소나 정의 | User Scenarios >= 3 또는 신규 사용자 유형 | GATE-2.5 |
| `templates/stories.md` | INVEST + Gherkin 유저 스토리 | 위와 동일 | GATE-2.5 |
| `templates/components.md` | 시스템 컴포넌트 식별 | UOW >= 3 예상 또는 신규 컴포넌트 | GATE-2.7 |
| `templates/services.md` | 서비스 레이어 / API 경계 | 위와 동일 | GATE-2.7 |
| `templates/component-dependency.md` | 컴포넌트 간 의존성 매트릭스 | 위와 동일 | GATE-2.7 |

### CONSTRUCTION 확장 (4개)

| 파일 | 용도 | 발동 조건 | Gate |
|------|------|---------|------|
| `templates/infrastructure-design.md` | 인프라 리소스 / 비용 / 마이그레이션 | 인프라 변경 필요 시 | GATE-4 |
| `templates/deployment-architecture.md` | 배포 토폴로지 / 모니터링 / DR | 위와 동일 | GATE-4 |
| `templates/build-instructions.md` | 빌드 절차 / UOW별 빌드 순서 | M/L 규모 단위 존재 시 | GATE-5 |
| `templates/test-instructions.md` | 테스트 전략 / 시나리오 / Quality Gate | 위와 동일 | GATE-5 |

### Extension (1개)

| 파일 | 용도 | 발동 조건 | Gate |
|------|------|---------|------|
| `templates/security-baseline.md` | SECURITY-01~11 체크리스트 | 사용자 opt-in 시 | GATE-2 |

---

## 신규 STEP / GATE (8개)

| STEP | 이름 | 조건 |
|------|------|------|
| STEP 5.5 | User Stories | User Scenarios >= 3 또는 신규 사용자 유형 |
| STEP 5.7 | Application Design | UOW >= 3 예상 또는 신규 컴포넌트 |
| STEP 6.7 | Infrastructure Design | 인프라 변경 필요 시 |
| STEP 9 | Build & Test Instructions | M/L 규모 단위 존재 시 |

| Gate | 이름 | 조건 |
|------|------|------|
| GATE-2.5 | User Stories Review | STEP 5.5 실행 시 |
| GATE-2.7 | Application Design Review | STEP 5.7 실행 시 |
| GATE-4 | Infrastructure Design Review | STEP 6.7 실행 시 |
| GATE-5 | Build & Test Review | STEP 9 실행 시 |

---

## Readiness Score 확장

- 기존 6개 영역 100점 유지
- 조건부 가점 영역 2개 추가:
  - 사용자 스토리 품질 (최대 10점) — GATE-2.5 발동 시에만 채점
  - 시스템 구조 설계 (최대 10점) — GATE-2.7 발동 시에만 채점
- 판정 임계값은 실제 만점의 80%/60% 비율로 환산

---

## audit.md / aidlc-state.md 실시간 갱신

### 변경 전
- audit.md: Gate 통과 시에만 기록 (최대 8회)
- aidlc-state.md: STEP 1/6/7에서만 갱신 (3회)

### 변경 후
- audit.md: 모든 STEP 시작/완료/스킵 + Gate + 질문 답변 + 상태 변경마다 기록 (20회+)
- aidlc-state.md: 모든 STEP 완료/스킵마다 체크박스 갱신 (12회+)

### 로깅 트리거 4종 (audit.md)
1. **STEP 시작/완료**: 매 STEP 진입/완료 시. 조건부 스킵 시에도 사유 기록.
2. **GATE 통과**: 승인/변경 요청/스킵 시.
3. **사용자 입력**: BLOCK/ASSUME 질문 답변, Discovery 라운드 응답 시.
4. **상태 변경**: feature status 변경 시.

### 체크박스 범례 (aidlc-state.md)
- `[x]` 완료
- `[-]` 스킵 (사유 괄호 표기)
- `[ ]` 미진행

---

## 수정 파일 (9개)

| 파일 | 변경 내용 |
|------|---------|
| `core/core-workflow.md` | STEP 5.5/5.7/6.7/9 추가, GATE-2.5/2.7/4/5 추가, 산출물 섹션 재구성, 실시간 갱신 규칙 섹션 신설 |
| `common/stage-gate-rules.md` | GATE-2.5/2.7/4/5 상세 규칙, 건너뛰기 조건 추가, 감사 로그 연동 확장 |
| `core/readiness-score.md` | 조건부 가점 영역 2개, 비율 환산 판정 기준 |
| `core/readiness-score.schema.yaml` | user_stories_quality, system_design_quality 영역 + conditional_scoring 섹션 |
| `templates/feature-status.md` | Readiness Score 테이블 확장, Gate History 확장, Related Files 확장 |
| `templates/audit.md` | 로깅 트리거 4종 포맷 추가 |
| `templates/aidlc-state.md` | 갱신 규칙 명시, 신규 STEP/GATE 체크박스, 체크박스 범례 |
| `skills/ctx-aidlc-run/SKILL.md` | PRIMARY INPUTS 확장, OUTPUT CONTRACT 확장, EXECUTION FLOW에 신규 STEP/GATE + 실시간 audit 갱신 명령 |
| `docs/workflow-guide.md` | 요구사항 분석 단계, 승인 단계, greenfield 산출물 목록 업데이트 |

---

## AI-DLC 대비 커버리지

| 구분 | 통합 전 | 통합 후 |
|------|--------|--------|
| AI-DLC 25개 산출물 대응 | 15개 (60%) | 20개 (80%) |
| 미통합 (의도적 제외) | 10개 | 5개 |
| team-ai-workflow에만 있는 산출물 | 5개 | 5개 (유지) |

미통합 5개: component-methods.md, story-generation-plan.md, application-design-plan.md, security-baseline.opt-in.md, operations.md — Gate 체계가 대체하거나 기존 섹션에 흡수.

---

## 변경 통계

| 구분 | 수 |
|------|---|
| 신규 파일 | 10 |
| 수정 파일 | 9 |
| 삭제 파일 | 0 |

## 호환성

- 하위 호환: 기존 필수 산출물 6개 변경 없음
- 신규 산출물은 모두 조건부 — 기존 워크플로우에 영향 없음
- 스킬 재배포 필요: `bash scripts/install-skills.sh`
