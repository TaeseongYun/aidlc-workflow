# 2026-04-22: 과신 방지, Content Validation 강화, Error Recovery

## 배경

awslabs/aidlc-workflows와 비교 분석 결과, team-ai-workflow의 분석/설계 깊이는 우위에 있으나 3가지 영역에서 보강이 필요함을 식별.

1. **AI 과신 방지**: AI 주도 단계(STEP 6, 6.5, 6.7)에서 질문 없이 진행하거나 불확실한 판단을 확정처럼 취급하는 문제
2. **산출물 사전 검증**: 다이어그램 구문 오류, 참조 무결성 깨짐 등이 파일 생성 후에야 발견되는 문제
3. **오류 복구 절차 부재**: 세션 중단, 산출물 손상, 상태 불일치 시 복구 경로가 정의되지 않은 문제

## 변경 사항

### 1. Overconfidence Prevention (과신 방지 규칙)

**파일**: `common/overconfidence-prevention.md` 신규

5가지 규칙을 정의:
- **불확실성 명시 의무**: CTX/코드에 근거가 없는 판단에 `⚠️ UNCERTAIN` 마커 부착
- **자체 검증 (Self-Verification)**: STEP 6, 6.5, 6.7에서 산출물 작성 후 3가지 검증 질문 수행
- **질문 누락 감지**: STEP 3 완료 시 고위험 키워드 대비 질문 생성 여부 자동 점검
- **Readiness Score 상한**: `⚠️ UNCERTAIN` 마커가 있는 도메인은 만점의 80%를 상한으로 적용
- **모호한 표현 금지**: "~일 것이다", "당연히", "간단하게 처리 가능" 등을 확정 진술로 사용 금지

기존 체계와의 연동:
- `question-governance.md`의 확신도 태깅(`[확신: 추정]`, `[확신: AI추천]`)과 연결
- `readiness-score.md`의 도메인 점수에 상한 규칙 적용
- `audit.md`에 `[OVERCONFIDENCE-CHECK]` 이벤트 기록

### 2. Content Validation 강화 (산출물 사전 검증)

**파일**: `common/content-validation.md` 섹션 0 신규 + 기존 섹션 2, 3 보강

섹션 0 "산출물 생성 전 사전 검증 (Pre-Write Validation)" 추가:
- **구조 검증**: 필수 섹션 존재, 빈 섹션 감지, 헤딩 레벨 순차 확인
- **참조 무결성**: 파일 링크, UOW ID, 질문 번호, feature-slug 일관성
- **다이어그램 검증**: Mermaid 구문/노드 ID/특수문자 이스케이프, ASCII 허용 문자/폭 규칙
- **특수문자 검증**: 테이블 파이프 이스케이프, 백틱 짝, YAML frontmatter 유효성
- 검증 실패 시 `audit.md`에 `[PRE-WRITE-VALIDATION]` 이벤트 기록

기존 섹션 보강:
- 섹션 2 (Mermaid): 노드 ID 규칙, 라벨 특수문자 이스케이프, 5+ 노드 텍스트 대안 필수 추가
- 섹션 3 (ASCII): 허용 문자 목록, 동일 폭 규칙 명시

### 3. Error Recovery (오류 복구 절차)

**파일**: `common/error-recovery.md` 신규

- **오류 심각도 4단계**: CRITICAL / HIGH / MEDIUM / LOW 분류 기준
- **세션 재개 절차**: aidlc-state.md 확인 → 산출물 무결성 검증 → 불일치 복구
  - 상태 표시 완료인데 산출물 없음 → STEP 재실행
  - 산출물 존재인데 상태 미완료 → 산출물 검증 후 상태 갱신
- **STEP별 오류 처리**: Project Detection, 분석/질문, Unit Decomposition, Readiness Score
- **산출물 복구**: 백업 필수, 재생성 절차, aidlc-state.md 손상 시 재구성
- **사용자 요청 되돌리기**: STEP 재실행 시 의존성 경고, GATE 변경 요청 처리
- **audit.md 연동**: `[RECOVERY]` 이벤트 로깅 포맷 정의

### 4. core-workflow.md 갱신

**파일**: `core/core-workflow.md`

- 섹션 11 "과신 방지" 추가 — `common/overconfidence-prevention.md` 참조
- 섹션 12 "오류 복구" 추가 — `common/error-recovery.md` 참조
- 기존 섹션 번호 순차 조정 (금지 사항 → 13, 컨텍스트 우선순위 → 14)

## 수정된 파일 전체 목록

| 파일 | 변경 유형 |
|------|----------|
| `common/overconfidence-prevention.md` | 신규 |
| `common/content-validation.md` | 섹션 추가 + 기존 섹션 보강 |
| `common/error-recovery.md` | 신규 |
| `core/core-workflow.md` | 섹션 2개 추가, 번호 조정 |
| `README.md` | 변경 이력, 문서 링크 갱신 |
| `docs/concepts.md` | 과신 방지, 오류 복구 개념 추가 |

### 5. 평가 프레임워크 (tools/evaluator/)

**파일**: `tools/evaluator/` 디렉토리 신규

4개 bash 스크립트로 구성된 산출물 자동 검증 도구:
- **validate-artifacts.sh**: 필수 파일 존재, 필수 섹션, 빈 섹션, UOW ID 참조 무결성, feature-slug 일관성, 다이어그램 검증
- **validate-questions.sh**: Request Anchor, Summary, 질문별 필수 필드(분류/영향도/미응답 시/범위/우선순위), policy 질문 AI 추천 금지, BLOCK 현황, 확신도 통계
- **validate-readiness-score.sh**: Score 테이블 존재/합계 추출, 판정 일관성(READY/CONDITIONAL/NOT_READY), BLOCK 교차 검증, 배점 합산, UNCERTAIN 마커
- **validate-all.sh**: 위 3개를 순차 실행하고 종합 결과 출력

### 6. Golden Baseline 테스트 케이스

**파일**: `examples/golden-baselines/` 디렉토리 신규

depth별 3개 참조 출력 세트:
- **minimal-bugfix/**: 질문 1개, UOW 1개, GATE-2/3만 진행, READY 94점
- **standard-feature/**: 질문 3개(BLOCK 2건), UOW 6개, CONDITIONAL 64점
- **comprehensive-platform/**: 질문 12개, UOW 7개, 전체 GATE 활성, READY 111/120점

### 7. Extension 확장팩

**파일**: `extensions/performance/`, `extensions/api-contract/` 신규

- **performance-baseline**: PERF-01~06 (응답 시간, 처리량, 배치 성능, DB 쿼리, 캐싱, 부하 테스트)
- **api-contract**: API-01~05 (버전 관리, 스키마, 에러 응답, 하위 호환성, 문서화)

**파일**: `common/extension-rules.md`, `templates/aidlc-state.md` 갱신

## 수정된 파일 전체 목록 (추가분)

| 파일 | 변경 유형 |
|------|----------|
| `tools/evaluator/validate-artifacts.sh` | 신규 |
| `tools/evaluator/validate-questions.sh` | 신규 |
| `tools/evaluator/validate-readiness-score.sh` | 신규 |
| `tools/evaluator/validate-all.sh` | 신규 |
| `tools/evaluator/README.md` | 신규 |
| `examples/golden-baselines/README.md` | 신규 |
| `examples/golden-baselines/minimal-bugfix/*` | 신규 (4파일) |
| `examples/golden-baselines/standard-feature/*` | 신규 (4파일) |
| `examples/golden-baselines/comprehensive-platform/*` | 신규 (4파일) |
| `extensions/performance/performance-baseline.opt-in.md` | 신규 |
| `extensions/performance/performance-baseline.md` | 신규 |
| `extensions/api-contract/api-contract.opt-in.md` | 신규 |
| `extensions/api-contract/api-contract.md` | 신규 |
| `common/extension-rules.md` | Extension 목록 추가 |
| `templates/aidlc-state.md` | Extension 항목 추가 |

## 참조 출처

| 출처 | 가져온 패턴 |
|------|-----------|
| awslabs/aidlc-workflows `overconfidence-prevention.md` | 과신 방지 필요성, "의심하면 질문하라" 원칙 |
| awslabs/aidlc-workflows `error-handling.md` | 오류 심각도 분류, 단계별 오류 처리, 복구 절차 구조 |
| awslabs/aidlc-workflows `session-continuity.md` | 세션 재개 시 상태 검증, 산출물 로딩 순서 |
| awslabs/aidlc-workflows `content-validation.md` | 파일 생성 전 검증, Mermaid/ASCII 사전 체크 |
| team-ai-workflow 기존 체계 | 확신도 태깅, Readiness Score, audit.md 연동으로 독자 설계 |
