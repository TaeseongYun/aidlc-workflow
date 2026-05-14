# Project Layout Example

```text
my-project/
├── AGENTS.md
├── ctx/
│   ├── INDEX.md
│   └── project-profile.ctx.md
├── .aidlc/
│   └── project-profile.md
└── aidlc-docs/
    ├── aidlc-state.md
    ├── audit.md
    └── features/
        ├── feature-a/
        │   ├── status.md
        │   ├── requirements.md
        │   ├── requirement-verification-questions.md
        │   └── unit-of-work.md
        └── feature-b/
            ├── status.md
            ├── requirements.md
            └── unit-of-work.md
```

## 채워진 산출물 예제
실제 내용이 채워진 예제는 `examples/filled-outputs/`를 참고한다.

## 연결 방식
- `team-ai-workflow/core/*`를 공통 판단 기준으로 사용한다.
- 프로젝트 로컬 문서는 `AGENTS.md`, `ctx/`를 우선 사용한다.
- `.aidlc/project-profile.md`는 `ctx/`가 약한 프로젝트에서만 선택적으로 사용한다.
- 실제 기능별 산출물은 `aidlc-docs/`에 생성한다.
