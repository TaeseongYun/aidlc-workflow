# Skill Validator

team-ai-workflow 스킬의 품질을 검증하는 규칙이다.
자동 검증(`validate-skills.sh`)과 추론 검증(AI 리뷰)으로 나뉜다.

## 자동 검증 규칙 (Deterministic)

스크립트로 검증 가능한 규칙.

### SKILL-01: 엔트리포인트 존재
- `skills/<name>/SKILL.md` 또는 `skills/<name>/CLAUDE_COMMAND.md`가 존재해야 한다.
- 둘 다 없으면 FAIL.

### SKILL-02: Frontmatter 필수 필드
- YAML frontmatter에 `description` 필드가 존재해야 한다.
- 비어 있으면 FAIL.

### PATH-01: 내부 참조는 상대경로
- 같은 skill 디렉토리 내 파일 참조는 `./` 또는 `../`로 시작해야 한다.
- 절대경로 사용 시 FAIL.

### PATH-02: 외부 참조는 변수 사용
- skill 디렉토리 밖 team-ai-workflow 파일 참조는 `{{TEAM_AI_WORKFLOW_DIR}}` 변수를 사용해야 한다.
- 하드코딩된 절대경로 사용 시 FAIL.

### REF-01: 참조 파일 존재
- skill 내에서 참조하는 모든 파일이 실제로 존재해야 한다.
- 존재하지 않는 파일 참조 시 FAIL.

### SCOPE-01: 크로스 스킬 참조 금지
- repo 내 다른 skill 디렉토리(`skills/<other-name>/`)의 소스 파일을 직접 참조하지 않아야 한다.
- 크로스 스킬 참조 시 FAIL.
- 예외: 진입점 스킬이 **설치 여부를 진단**하기 위해 글로벌 설치 경로
  (`~/.claude/.../`, `~/.codex/skills/<name>/`)를 확인하는 것은 허용한다.
  이는 다른 스킬의 소스에 의존하는 것이 아니라 환경 상태를 점검하는 것이다.

## 추론 검증 규칙 (AI Review)

AI가 내용을 읽고 판단하는 규칙. `validate-skills.sh`로는 검증 불가.

### SKILL-03: 공통 프로토콜 참조
- `_shared/skill-protocol.md`의 핵심 규칙(역할, 입력, 가드레일, 출력)을 따르고 있어야 한다.

### SKILL-04: Guardrail 섹션 존재
- 스킬이 하지 말아야 할 것(예: 구현 금지, 설계 제안 금지)이 명시되어 있어야 한다.

### SKILL-05: Output Format 섹션 존재
- 산출물의 형태와 위치가 명시되어 있어야 한다.

### PROTO-01: 공통 프로토콜 준수
- `_shared/skill-protocol.md`에 정의된 실행 흐름(CTX 읽기 → 판단 → 산출물)을 따르고 있어야 한다.

## 검증 실행

### 자동 검증
```bash
bash tools/validate-skills.sh
```

### 추론 검증
AI에게 이 문서를 참조하여 특정 skill을 리뷰하도록 요청한다:
```
"tools/skill-validator.md의 추론 규칙으로 skills/<name>/SKILL.md를 검증해줘"
```

## 검증 결과 포맷

```
[PASS] SKILL-01: skills/ctx-aidlc-run — 엔트리포인트 존재 (SKILL.md + CLAUDE_COMMAND.md)
[FAIL] PATH-02: skills/ctx-run — 하드코딩 경로 발견: /Users/nhn/workspace/...
[SKIP] SKILL-03: 추론 검증 — 스크립트로 검증 불가
```
