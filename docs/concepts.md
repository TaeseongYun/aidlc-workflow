# 핵심 개념

## team-ai-workflow / ctx / aidlc-docs 역할 분리

| 영역 | 역할 | 위치 |
|------|------|------|
| **team-ai-workflow** | 팀 공통 판단 기준. "어떻게 생각하고 어떤 산출물을 만들지" 정의 | 팀 공유 저장소 |
| **ctx/** | 프로젝트 로컬 사실. 기존 구조, 금지 규칙, 재사용 컴포넌트 | 각 프로젝트 |
| **aidlc-docs/** | 기능 작업 산출물. 요구사항, 질문, unit-of-work, 상태 추적 | 각 프로젝트 |

## 추정 금지 (No-Implicit-Decisions)

AI가 결정하면 안 되는 것을 결정하지 않게 하는 핵심 원칙.

- AI는 비즈니스 정책을 스스로 결정하지 않는다.
- 2개 이상 유효한 설계가 존재하고 CTX에 답이 없으면 **멈추고 질문을 올린다**.
- 결제/환불/정산/권한/알림 정책은 반드시 사람 승인이 필요하다.

허용되는 추론:
- 이미 코드에 있는 패턴 재사용
- 명시적 정책을 구현 단위로 분해
- 코드에서 자명한 사실을 문서화

## 과신 방지 (Overconfidence Prevention)

AI 주도 단계에서 불확실한 판단을 확정처럼 취급하는 것을 막는 규칙.

- AI가 질문 생성 없이 진행하는 STEP(6, 6.5, 6.7)이 과신 위험이 가장 높다.
- 근거 없는 판단에는 `⚠️ UNCERTAIN` 마커를 붙이고, 게이트에서 사용자가 확인한다.
- 산출물 작성 후 자체 검증(Self-Verification) 3가지 질문을 수행한다.
- STEP 3 완료 시 고위험 영역 대비 질문 누락 여부를 자동 점검한다.
- Readiness Score에서 불확실 마커가 있는 도메인은 만점의 80% 상한을 적용한다.

상세: `common/overconfidence-prevention.md`

## 오류 복구 (Error Recovery)

워크플로우 중단, 산출물 손상, 상태 불일치 시 복구 경로를 정의한다.

- 세션 재개 시 `aidlc-state.md`와 실제 산출물의 일치 여부를 먼저 검증한다.
- 불일치 유형별 복구: 상태 완료인데 산출물 없음 → 재실행, 산출물 있는데 상태 미완료 → 검증 후 갱신.
- 산출물 재생성 시 백업을 먼저 만든다.
- 모든 복구 이벤트는 `audit.md`에 `[RECOVERY]`로 기록한다.

상세: `common/error-recovery.md`

## 산출물 사전 검증 (Pre-Write Validation)

산출물 파일을 생성하기 전에 구조, 참조, 다이어그램, 특수문자를 검증한다.

- 모순 감지(기존)와 별개로, 파일 품질 자체를 보장하는 규칙이다.
- 검증 실패 시 수정 후 기록하거나, 수정 불가 시 `⚠️ TODO` 마커를 남긴다.

상세: `common/content-validation.md` 섹션 0

## 프로젝트별 입력 우선순위

프로젝트마다 파일 구성이 다를 수 있으므로 아래 순서대로 있는 파일만 읽는다.

1. `ctx/INDEX.md`
2. `ctx/project-profile.ctx.md`
3. `AGENTS.md`
4. `CLAUDE.md`
5. `README.md`
6. 관련 세부 `ctx/*`

## aidlc-docs 보관 원칙

- 이전 기능 산출물은 지우지 않는다.
- 공용 상태 파일은 루트에 유지한다: `aidlc-state.md`, `audit.md`
- 기능별 산출물은 `aidlc-docs/features/<feature-slug>/`로 분리한다.
- 새 요구사항이 들어오면 기존 문서를 덮어쓰기보다 새 feature 폴더를 만든다.

## aidlc-docs 버전 관리

- 기본값은 개인 작업 산출물 → `.gitignore` 권장
- 예외: 팀이 공식 요구사항 기록으로 채택한 경우, 감사/승인 이력이 필요한 경우
- 공식 문서 승격 시 최종 승인본만 별도 `docs/`로 이동

## 추천 feature 폴더 구조

```text
aidlc-docs/features/<feature-slug>/
├── status.md
├── requirements.md
├── requirement-verification-questions.md
├── unit-of-work.md
├── unit-of-work-dependency.md
└── unit-of-work-story-map.md
```

raw request인 경우 추가:

```text
├── request-intake.md
└── planning-draft.md
```

## 각 프로젝트에 넣을 최소 파일

```text
<project-root>/
├── AGENTS.md or CLAUDE.md
├── ctx/
└── aidlc-docs/
    ├── aidlc-state.md
    ├── audit.md
    └── features/
        └── <feature-slug>/
            └── status.md
```
