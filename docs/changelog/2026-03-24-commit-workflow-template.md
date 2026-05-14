# 변경 사항: init-project.sh에 commit-workflow CTX 템플릿 추가

## 변경 일자
2026-03-24

## 배경

`/ctx-commit-planner` 스킬은 `ctx/workflow/commit-workflow.ctx.md`를 필수 참조한다.
해당 CTX가 없으면 스킬이 즉시 중단되도록 설계되어 있다.

그런데 `init-project.sh`가 이 파일을 생성하지 않아,
프로젝트 초기화 후에도 `/ctx-commit-planner`를 사용할 수 없는 상태였다.

## 무엇이 바뀌었나

### 변경 전

```
init-project.sh 생성 파일:
├── ctx/INDEX.md
├── ctx/project-profile.ctx.md
├── CLAUDE.md
└── aidlc-docs/ (aidlc-state.md, audit.md, features/)
```

`/ctx-commit-planner` 실행 → CTX 없음 → 즉시 중단

### 변경 후

```
init-project.sh 생성 파일:
├── ctx/INDEX.md
├── ctx/project-profile.ctx.md
├── ctx/workflow/commit-workflow.ctx.md  ← 추가
├── CLAUDE.md
└── aidlc-docs/ (aidlc-state.md, audit.md, features/)
```

`/ctx-commit-planner` 실행 → CTX 참조 성공 → 커밋 설계 진행

---

## 템플릿 내용

생성되는 `commit-workflow.ctx.md`는 프로젝트별 커밋 정책을 담는다:

| 섹션 | 내용 |
|------|------|
| 브랜치 전략 | main/dev/feature/fix 브랜치 규칙 |
| 커밋 단위 기준 | 의미 단위 분리 원칙 |
| 허용 scope 목록 | 프로젝트 모듈/도메인별 scope 정의 |
| 금지 패턴 | WIP, 혼합 커밋, 빈 메시지 등 |
| 커밋 전 필수 검증 | 빌드/린트/테스트 통과 여부 |

모든 섹션에 `(TODO)` 마커가 포함되어 프로젝트별 커스터마이징을 유도한다.

### SKILL.md와의 역할 분리

| 파일 | 역할 |
|------|------|
| `skills/ctx-commit-planner/SKILL.md` | 스킬 내부 동작 규칙 (메시지 포맷, 언어 규칙, 분리 규칙) |
| `ctx/workflow/commit-workflow.ctx.md` | 프로젝트별 커밋 정책 (브랜치, scope, 금지 패턴) |

SKILL.md의 규칙을 CTX에 복제하지 않는다. 이중 관리를 방지하기 위함이다.

---

## 변경 파일 목록

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `scripts/init-project.sh` | `ctx/workflow/` 디렉터리 생성, `commit-workflow.ctx.md` 템플릿 생성, 출력 트리 반영 |

---

## 호환성

- 하위 호환: 기존 init-project.sh로 생성된 프로젝트에 영향 없음
- 이미 `commit-workflow.ctx.md`가 존재하면 스킵됨
- 스킬 실행 흐름 변경 없음

---

## 후속 변경: CTX 템플릿 정제 및 외부 파일 분리

### 배경

기존 `init-project.sh`는 heredoc으로 내용을 직접 생성했다.
SKILL.md와 규칙이 중복되고, 정책 변경 시 셸 스크립트를 직접 수정해야 하는 문제가 있었다.

### 변경 내용

#### 1. 템플릿 외부 파일 분리

```
변경 전: init-project.sh 내부 heredoc으로 직접 생성
변경 후: templates/commit-workflow.ctx.md → cp로 복사
```

#### 2. SKILL.md 중복 규칙 제거

| 제거 항목 | 사유 |
|-----------|------|
| 섹션 4 (include/exclude 기준) | SKILL.md 5-2가 출력 포맷으로 강제 |
| 금지 패턴의 "혼합 커밋 금지" | 섹션 1 커밋 분리 기준과 내부 중복 |
| 본문 구조 (왜/무엇/제외) | SKILL.md 5-2 body 규칙이 담당 |

#### 3. 최종 CTX 구조

| 섹션 | 역할 |
|------|------|
| 1. 커밋 분리 기준 | 프로젝트 계층별 분리 정책 |
| 2. 커밋 순서 규칙 | 의존 방향 기반 커밋 순서 |
| 3. 파일 포함 범위 규칙 | 동일 책임 파일만 포함 |
| 4. 커밋 메시지 규칙 | 제목 형식만 정의, 본문은 SKILL.md 위임 |
| 허용 scope 목록 | 프로젝트별 TODO |
| 금지 패턴 | WIP, 빈 메시지, 자동 생성 파일 단독 커밋 |
| 커밋 전 필수 검증 | 빌드/린트/테스트 TODO |

### 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `templates/commit-workflow.ctx.md` | 신규 생성 — SKILL.md 중복 제거된 CTX 템플릿 |
| `scripts/init-project.sh` | heredoc 제거, 템플릿 cp 방식으로 변경 |
