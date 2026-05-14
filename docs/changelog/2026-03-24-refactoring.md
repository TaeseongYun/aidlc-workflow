# 변경 사항: 구조 리팩토링 (P0~P3)

## 변경 일자
2026-03-24

## 배경

프로젝트 전체 구조를 분석한 결과 다음 문제가 확인되었다:
- 동일 규칙이 3~4곳에 중복 서술 → 변경 시 불일치 발생 위험
- 핵심 용어 정의 부재 → 온보딩 비용 증가
- 템플릿과 워크플로우 단계 간 연결 정보 부재
- 스킬 간 공통 보일러플레이트 반복
- 산출물 기대 수준을 보여주는 예제 부재
- Sonnet 모델 지정으로 인한 rate limit 문제

---

## P0: 중복 제거 (Critical)

### P0-1: 질문 포맷 중복 제거
- **문제**: 질문 포맷이 `common/question-rules.md`, `templates/requirement-verification-questions.md`, `skills/ctx-aidlc-run/SKILL.md` 3곳에 반복
- **해결**: `question-rules.md`를 single source of truth로 유지. 템플릿은 1개 예시만 남기고 나머지 섹션은 참조로 축소
- **수정 파일**: `templates/requirement-verification-questions.md`

### P0-2: approval-rules → stage-gate-rules 합병
- **문제**: `approval-rules.md` 내용이 `stage-gate-rules.md`의 부분집합이면서 별도 파일로 존재
- **해결**: `approval-rules.md` 삭제. 고유 내용을 `stage-gate-rules.md`의 "승인 필요 항목" 섹션으로 흡수
- **삭제 파일**: `common/approval-rules.md`
- **수정 파일**: `common/stage-gate-rules.md`, `skills/ctx-aidlc-run/SKILL.md`, `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

### P0-3: 사이즈 정의 추출
- **문제**: S/M/L 규모 정의가 `templates/unit-of-work.md`, `skills/ctx-aidlc-run/SKILL.md`, `docs/changelog/` 3곳에 반복
- **해결**: `core/unit-sizing.md` 신규 생성. 3곳의 인라인 정의를 참조로 교체
- **신규 파일**: `core/unit-sizing.md`
- **수정 파일**: `templates/unit-of-work.md`, `skills/ctx-aidlc-run/SKILL.md`, `docs/changelog/2026-03-23-technical-design.md`

---

## P1: 누락 보강 (High Priority)

### P1-1: 용어 사전
- **문제**: `raw-request`, `brownfield`, `BLOCK`, `UOW`, `ADR` 등 핵심 용어가 정의 없이 사용
- **해결**: `docs/terminology.md` 신규 생성 (7개 카테고리, 25개 용어)
- **신규 파일**: `docs/terminology.md`
- **수정 파일**: `README.md` (링크 추가)

### P1-2: 템플릿 워크플로우 메타데이터
- **문제**: 템플릿 파일만 보면 어떤 STEP에서 생성되는지, 어떤 GATE와 연결되는지 알 수 없음
- **해결**: 9개 템플릿 상단에 `<!-- workflow-step / gate / producer -->` HTML 코멘트 추가
- **수정 파일**: `templates/` 하위 9개 파일

### P1-3: project-profile 합병
- **문제**: `project-profile.md`와 `project-profile.ctx.md`가 거의 동일
- **해결**: `project-profile.md` 삭제. `project-profile.ctx.md`에 통합 (Related CTX Files를 optional 섹션으로)
- **삭제 파일**: `templates/project-profile.md`
- **수정 파일**: `templates/project-profile.ctx.md`, `core/core-workflow.md`

---

## P2: 구조 개선 (Medium Priority)

### P2-1: 스킬 공통 프로토콜 추출
- **문제**: 6개 스킬에서 입력 검증 규칙, 실행 지침, 출력 제약이 동일하게 반복
- **해결**: `skills/_shared/skill-protocol.md` 신규 생성. 6개 스킬의 보일러플레이트를 참조로 교체
- **신규 파일**: `skills/_shared/skill-protocol.md`
- **수정 파일**: 6개 스킬 SKILL.md, `skills/README.md`

### P2-2: STOP 조건 통합 문서
- **문제**: "언제 멈춰야 하나?"가 8개 이상 파일에 흩어져 있음
- **해결**: `docs/stop-conditions.md` 신규 생성. Mermaid decision tree + 정책/게이트/점수 기반 STOP 조건 통합
- **신규 파일**: `docs/stop-conditions.md`
- **수정 파일**: `README.md`

### P2-3: 채워진 예제 산출물
- **문제**: `examples/`에 디렉토리 구조만 있고 실제 내용 예제 없음
- **해결**: "재구매 할인 쿠폰" 시나리오로 status, requirements, questions, unit-of-work, technical-design 5개 예제 생성
- **신규 파일**: `examples/filled-outputs/` (README.md, status.md, requirements.md, requirement-verification-questions.md, unit-of-work.md, technical-design.md)
- **수정 파일**: `examples/project-layout-example.md`

---

## P3: 가이드 추가 (Polish)

### P3-1: 한영 혼용 스타일 가이드
- **문제**: 템플릿 헤딩은 영어, 질문 라벨은 한글 필수, 본문은 혼재 → 일관성 없음
- **해결**: `docs/style-guide.md` 신규 생성. 섹션 헤딩/필드 라벨/본문/커밋 메시지 각각의 언어 규칙 정의
- **신규 파일**: `docs/style-guide.md`
- **수정 파일**: `README.md`

### P3-2: Readiness Score 스키마화
- **문제**: 채점 기준이 마크다운 산문으로만 존재하여 자동 채점이 어려움
- **해결**: `core/readiness-score.schema.yaml` 신규 생성. 6개 영역 15개 기준을 구조화된 YAML로 정의
- **신규 파일**: `core/readiness-score.schema.yaml`
- **수정 파일**: `core/readiness-score.md`

### P3-3: Brownfield 실전 가이드
- **문제**: brownfield 프로젝트 탐색에 대한 구체적 가이드 부재
- **해결**: `docs/brownfield-guide.md` 신규 생성. 5단계 탐색 순서 + 쿠폰 시스템 실전 예시
- **신규 파일**: `docs/brownfield-guide.md`
- **수정 파일**: `README.md`

---

## 스킬 모델 설정 변경

### CLAUDE_COMMAND.md에 Technical Design 누락 수정
- **문제**: 2026-03-23에 STEP 6.5(Technical Design) + GATE-3.5를 `SKILL.md`에 추가했으나, `CLAUDE_COMMAND.md` 동기화를 누락. Claude Code가 `/ctx-aidlc-run` 실행 시 `CLAUDE_COMMAND.md`를 참조하면 M/L 규모에서도 `technical-design.md`를 생성하지 않는 버그 발생
- **해결**: `CLAUDE_COMMAND.md`에 다음을 추가
  - Required Reading Order에 `core/unit-sizing.md`, `templates/technical-design.md` 추가
  - Required Outputs에 `technical-design.md` (M/L 규모 필수) 추가
  - Technical Design (STEP 6.5 + GATE-3.5) 섹션 추가
- **수정 파일**: `skills/ctx-aidlc-run/CLAUDE_COMMAND.md`

### Sonnet rate limit 해소
- **문제**: `ctx-reviewer`, `ctx-updater`에 `model: sonnet` 지정 → ctx-run 실행 중 모델 전환 시 Sonnet rate limit 도달
- **해결**: 두 스킬에서 `model: sonnet` 제거. 부모 스킬(ctx-run)의 `model: opus`를 상속
- **수정 파일**: `skills/ctx-reviewer/SKILL.md`, `skills/ctx-updater/SKILL.md`

---

## 변경 통계

| 구분 | 수 |
|------|---|
| 신규 파일 | 14 |
| 수정 파일 | 31 |
| 삭제 파일 | 2 |

## 호환성

- 하위 호환: 기존 스킬 실행 흐름 변경 없음
- 기존 산출물 영향 없음
- 스킬 재배포 필요: `bash scripts/install-skills.sh`
