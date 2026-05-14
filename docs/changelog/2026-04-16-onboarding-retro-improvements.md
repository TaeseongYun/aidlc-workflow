# 2026-04-16: 온보딩 회고 기반 개선 — Implementation Scope, Runtime Verification, init 버그 픽스

## 배경

세 개 온보딩 프로젝트(`meta-marketing-api-onboarding`, `onboarding-meta-api-hackathon`, `onboarding-odasiyoung-20260414`)의 회고 문서 7개를 비교 분석하여 공통 개선 포인트 11건을 도출했다.

도출된 11건을 기존 워크플로우 설계와 대조해 비판적으로 검토한 결과:

- **수용 불가 5건**: 이미 구현되어 있거나(#2 AI 결정 로그, #6 MVP scope cut), 게이트 설계 철학을 파괴하거나(#7 self-approval), 도메인 특화 분류를 범용 워크플로우에 넣는 것이 부적절하거나(#10 금전/법무 태그), tech-agnostic 원칙을 훼손하는 것(#11-B scaffold helper)
- **재설계 필요 4건**: 관찰은 유효하나 제안된 해결책이 잘못된 것(#1 #5 #8 #9) — 별도 판단 필요
- **수용 가능 3건**: 이번에 반영

## 변경 사항

### 1. Implementation Scope 섹션 신설 (technical-design.md)

**파일**: `templates/technical-design.md`

`## 작성 조건` 바로 다음에 `## Implementation Scope` 섹션 추가.

배경: 설계 문서는 production 기준이지만 실제 구현이 prototype이나 local-MVP인 경우,
그 사실이 어디에도 기록되지 않아 나중에 구현 수준을 오해하는 문제가 3개 프로젝트에서 공통 발생.

추가된 필드:
- `구현 수준`: `production` / `prototype` / `local-MVP`
- `Mock 허용 범위`: `none` / `external-api-only` / `storage-only` / `all-external`
- `이번 구현에서 제외된 항목`
- `Production 전환 시 추가 작업`

### 2. Runtime Verification 섹션 신설 (test-instructions.md + ctx-run)

**파일**: `templates/test-instructions.md`, `skills/ctx-run/SKILL.md`

배경: 테스트 통과와 실제 서비스 동작은 다른 문제임에도, 기존 워크플로우는 빌드·테스트 통과 이후의
런타임 검증 루틴을 정의하지 않았다. 3개 프로젝트 모두 서버 기동 확인 단계에서 누락이나 환경 제약으로
시간을 낭비했다.

`test-instructions.md`에 `## 8. Runtime Verification` 섹션 추가:
- 기동 명령
- 헬스 체크
- 대표 유스케이스 검증 (성공 케이스 + 차단/예외 케이스)
- 실행 로그 확인
- 환경 제약 기록 (sandbox, 포트 바인딩 등)

S 규모 단독 또는 서버 기동이 없는 경우 skip 허용.
환경 제약으로 기동 불가한 경우 제약 내용 기록 후 계속 진행.

`skills/ctx-run/SKILL.md` ROLE 2 (TEST_WRITER)에 테스트 통과 후
Runtime Verification 섹션 작성 지시 추가.

### 3. init-project.sh 대상 폴더 자동 생성 버그 픽스

**파일**: `scripts/init-project.sh`

기존: 존재하지 않는 경로를 인자로 넘기면 `cd` 실패로 스크립트 종료
수정: `cd` 전에 `mkdir -p "${PROJECT_ROOT}"` 추가

## 수정된 파일 전체 목록

| 파일 | 변경 유형 |
|------|----------|
| `templates/technical-design.md` | 섹션 추가 (Implementation Scope) |
| `templates/test-instructions.md` | 섹션 추가 (Runtime Verification) |
| `skills/ctx-run/SKILL.md` | ROLE 2 실행 지시 추가 |
| `scripts/init-project.sh` | 버그 픽스 (mkdir -p) |

## 반영하지 않은 항목 및 이유

| # | 항목 | 분류 | 이유 |
|---|------|------|------|
| #2 | AI 임시 결정 로그 | 수용 불가 | `requirement-verification-questions.md`에 이미 구현됨 (AI추천, 확신 태그, AI 자동결정 P2 테이블) |
| #6 | MVP Scope Cut 섹션 | 수용 불가 | `planning-draft.md` Section 6 Scope Draft로 이미 구현됨 |
| #7 | Self-Approval 모드 | 수용 불가 | 게이트 설계 철학 파괴. "skip gate" 명시로 이미 가능 |
| #10 | 정책 위험도 태그 | 수용 불가 | P0/P1/P2 + stage-gate 승인 목록으로 커버됨. 금전/법무 태그는 도메인 특화 분류 |
| #11-B | 팀 스택 Scaffold | 수용 불가 | tech-agnostic 원칙 훼손. 팀 내부 template 레포로 분리 필요 |
| #1 | Source Document Ingest | 재설계 필요 | 관찰 유효하나 STEP 0 추가는 과잉. QUICKSTART 사전 조건 명시로 처리 검토 |
| #5 | 환경 제약 CTX 명시 | 재설계 필요 | `Existing Constraints` 필드 이미 존재. 예시 보강으로 충분한지 재검토 필요 |
| #8 | ctx-run 실행 로그 | 재설계 필요 | 필요성 있으나 audit.md와 역할 분리 기준 설계 선행 필요 |
| #9 | 변경 영향 예측 | 재설계 필요 | requirements 템플릿이 아닌 ctx-architect-judge 산출물로 처리해야 함 |

## 참조 출처

| 출처 | 가져온 패턴 |
|------|-----------|
| meta-marketing-api-onboarding 회고 1·2차 | Implementation Slice 개념, 구현 수준 구분 필요성 |
| onboarding-meta-api-hackathon 회고 1·2차 | Runtime verification 체크리스트, self-contained execution |
| onboarding-odasiyoung-20260414 회고 1·2·3차 | Runtime verification 표준화, init-project.sh 버그 |
