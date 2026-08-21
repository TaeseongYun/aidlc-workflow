# FAQ

## Common Mistakes

### Common

- Reading only `ctx/` and jumping straight to implementation
- Filling policy gaps in code without `aidlc-docs`
- Not reading `team-ai-workflow`, so question quality varies per project
- On a brownfield project, creating a new structure without reviewing reuse of the existing structure

### Greenfield

- Starting implementation right away because there is no ctx
- Designing the API before the product policy is decided
- Discussion staying only in chat, without aidlc-docs
- Starting implementation without a minimal ctx, so team standards scatter
- Overwriting previous feature docs, so the change history is lost

## Minimal Checklist

- [ ] Did you read `team-ai-workflow/` for the common standards?
- [ ] Did you read `ctx/INDEX.md`, `AGENTS.md` or `CLAUDE.md`, and `README.md` for the project-local context?
- [ ] Did you document requirement gaps as questions?
- [ ] Did you leave the outputs in `aidlc-docs/`?
- [ ] Did you separate per-feature outputs into `aidlc-docs/features/<feature-slug>/`?
- [ ] Did you reflect the feature status in `status.md` and `aidlc-state.md`?
- [ ] Did you separate the items requiring human approval before implementation?
