# 2026-04-14: Lazy Loading + 세션 분리 기본 실행 모델

## 배경

`/ctx-aidlc-run` 호출 시 31개 파일을 일괄 로딩하여 토큰을 과다 소모하고 있었다. minimal depth 작업에서도 comprehensive용 템플릿(infrastructure-design, deployment-architecture 등)을 전부 읽는 구조였다.

또한 세션 분리가 "선택적 가이드" 수준으로만 존재하여, 실전에서 comprehensive 작업 시 컨텍스트 붕괴로 답변 불일치가 반복 발생했다.

## 변경 사항

### 1. Lazy Loading (INPUT LOADING STRATEGY)

**파일**: `skills/ctx-aidlc-run/SKILL.md`

기존 PRIMARY INPUTS(31개 일괄 로딩)를 INPUT LOADING STRATEGY로 전환.

#### Bootstrap (스킬 시작 시 즉시 읽기 — 8개)
1. `core/core-workflow.md`
2. `common/no-implicit-decisions.md`
3. `common/depth-levels.md`
4. Project `AGENTS.md` (또는 `CLAUDE.md`)
5. Project `ctx/INDEX.md`
6. Project `ctx/project-profile.ctx.md`
7. `aidlc-docs/aidlc-state.md`
8. `aidlc-docs/audit.md`

#### Per-STEP Loading (해당 STEP 진입 시에만 읽기)
- STEP 1-C: `input-validation.md`
- STEP 1.5: `reverse-engineering.md`, RE templates
- STEP 1.5 Extension Scan: `extension-rules.md`, `extensions/*.opt-in.md`
- STEP 3: `planning-draft.md` template, `diagram-standards.md`
- 첫 GATE: `stage-gate-rules.md`
- STEP 4: `question-rules.md`, `question-governance.md`
- STEP 5: `requirements-analysis.md`
- STEP 5-V: `content-validation.md`
- STEP 5.5: `personas.md`, `stories.md` templates
- STEP 5.7: `components.md`, `services.md`, `component-dependency.md` templates
- STEP 6: `units-generation.md`, `unit-sizing.md`
- STEP 6.5: `technical-design.md` template, `nfr-checklist.md`
- STEP 6.7: `infrastructure-design.md`, `deployment-architecture.md` templates
- STEP 7: `readiness-score.md`
- STEP 9: `build-instructions.md`, `test-instructions.md` templates

#### 예상 효과

| Depth Level | 기존 파일 수 | Lazy Loading 후 | 절감 |
|-------------|------------|----------------|------|
| minimal | 31개 | ~12개 | -61% |
| standard | 31개 | ~18개 | -42% |
| comprehensive | 31개 | ~25개 | -19% |

### 2. 세션 분리 기본 실행 모델 격상

**파일**: `docs/workflow-guide.md`, `skills/ctx-aidlc-run/SKILL.md`

#### workflow-guide.md 변경
- 세션 분리를 문서 최상단으로 이동, "기본 실행 모델"로 명시
- 적용 기준 변경:
  - comprehensive: "강력 권장" → **필수**
  - standard: "선택" → **권장**
  - minimal: "불필요" → **선택**
- Phase C 세션 재개 패턴 추가
- 기존 하단 중복 세션 분리 섹션을 상단 참조로 대체

#### ctx-aidlc-run/SKILL.md 변경
- SESSION MANAGEMENT 섹션 신규 추가 (EXECUTION FLOW 직전)
- Phase 테이블, 적용 기준, 전환 규칙 명시
- GATE-1에 "Phase A 종료 지점" 안내 추가 (comprehensive 시 세션 분리 권고)
- GATE-3에 "Phase B 종료 지점" 안내 추가 (standard/comprehensive 시 세션 분리 권고)

## 수정된 파일 전체 목록

| 파일 | 변경 유형 |
|------|----------|
| `skills/ctx-aidlc-run/SKILL.md` | PRIMARY INPUTS → INPUT LOADING STRATEGY, SESSION MANAGEMENT 추가, GATE Phase 안내 |
| `docs/workflow-guide.md` | 세션 분리를 최상단 기본 실행 모델로 격상, 중복 제거 |
| `README.md` | 업데이트 문서 링크, 변경 이력 추가 |

## 참조 출처

| 출처 | 가져온 패턴 |
|------|-----------|
| BMAD-METHOD | Phase별 문서 기반 컨텍스트 전달 (세션 분리 근거) |
| AIDLC 워크숍 회고 | 컨텍스트 붕괴로 인한 답변 불일치 문제 (세션 분리 필요성) |
| 토큰 다이어트 분석 | 31개 일괄 로딩의 비효율 식별 (Lazy Loading 근거) |
