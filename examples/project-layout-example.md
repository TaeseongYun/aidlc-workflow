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

## Filled Output Examples
For examples with actual content filled in, see `examples/filled-outputs/`.

## How Things Connect
- Use `team-ai-workflow/core/*` as the shared judgment criteria.
- Prefer the project-local documents `AGENTS.md` and `ctx/`.
- Use `.aidlc/project-profile.md` only optionally, for projects where `ctx/` is weak.
- Generate the actual per-feature outputs in `aidlc-docs/`.
