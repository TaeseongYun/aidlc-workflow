# Contributing to aidlc-workflow

이 워크플로우는 많은 팀이 공유하는 도구입니다. 개선 사항과 버그 리포트를 환영합니다.

---

## 기여 방법

### Issues

기능 요청, 버그 리포트, 질문은 [GitHub Issues](https://github.com/TaeseongYun/aidlc-workflow/issues)로 제출해주세요.

- 명확한 제목과 설명
- 재현 가능한 단계 (버그인 경우)
- 사용 중인 스킬과 프로젝트 타입

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-improvement`)
3. Make changes (see below)
4. Test locally
5. Commit with a clear English message
6. Push and open a PR

---

## Repository Layout

```text
skills/                       # Skill source files (you edit here)
├── team-ai-workflow-start/   # Entry point skill
├── ctx-aidlc-roadmap/        # Phase 0 roadmapping
├── ctx-aidlc-run/            # Phase A-C analysis
├── ctx-run/                  # Implementation
└── ... (7 skills total)

common/                       # Shared rules (rules library)
core/                         # Core analysis logic
docs/                         # User guides, concepts, changelog
templates/                    # Document templates
tools/                        # Validation tools
scripts/
├── install-skills.sh         # Deploy skills to ~/.claude and ~/.codex
└── init-project.sh           # Initialize project in any repo
```

**Never edit**:
- `~/.claude/commands/`
- `~/.codex/skills/`
- Installed copies anywhere

**Always edit**:
- `skills/` directory in this repo
- Common rule files under `common/` and `core/`
- Docs under `docs/`

---

## Editing Skills

### Skill File Structure

Each skill is a directory with:

```text
skills/<skill-name>/
├── SKILL.md           # Main skill definition (frontmatter + role + rules)
├── CLAUDE_COMMAND.md  # Optional: alternative for Claude commands
└── other files        # Supplementary docs, templates
```

### Frontmatter (Required)

```markdown
---
description: What this skill does in one sentence
model: haiku | sonnet | opus
allowed-tools: Read, Write, Edit, Bash, Skill
---
```

- `description`: One line, user-facing
- `model`: Recommended model size
- `allowed-tools`: Tools this skill uses

### Content Structure

```markdown
# Skill Name

ROLE: <ROLE_NAME>
MODE: <MODE>
EXECUTION_MODEL: <SEQUENTIAL | PARALLEL>

────────────────────────────────────
PURPOSE
────────────────────────────────────

(User-facing explanation)

────────────────────────────────────
CORE RULES
────────────────────────────────────

(Behavior rules)

────────────────────────────────────
WORKFLOW
────────────────────────────────────

(Step-by-step execution)
```

- Use Korean for user-facing text
- Use English for code, commands, variable names
- Keep roles focused (one skill = one job)

### Testing Your Changes

After editing, test by reinstalling:

```bash
bash scripts/install-skills.sh
```

Then invoke the skill in Claude Code:

```text
/your-skill-name

Your test input here
```

Verify:
1. Skill loads without errors
2. Prompts and output are clear
3. All referenced tools/skills work
4. File paths are correct

---

## Editing Common Rules

Common rules live under `common/` and `core/`:

```text
common/
├── question-governance.md
├── depth-levels.md
├── stage-gate-rules.md
├── overconfidence-prevention.md
└── ... (shared rules)

core/
├── input-validation.md
├── units-generation.md
├── reverse-engineering.md
└── ... (core logic)
```

When updating a rule:
1. Be precise — don't add subjective guidance
2. Cross-reference related files
3. Update the changelog entry

---

## Style Guide

### Korean Conventions

- Headers: 한국어 주제 + 선택적 영문 부제 `(English Subtitle)`
- Content: 한국어
- Code/commands: English only
- Filenames: `kebab-case`, English

### Examples

```markdown
# CTX 문서 작성 (Writing Context Documents)

## 기술 스택 (Tech Stack)

이 섹션에서는 프로젝트의 기술 스택을 정의한다.

```bash
npm install
```
```

### No Emojis

Don't use emoji in documentation (per project standards).

---

## Updating the Changelog

Before committing, update `docs/changelog/YYYY-MM-DD-<topic>.md` with:

```markdown
# Update Title

## Summary

(One paragraph explaining the change)

## Files Changed

- Modified: `skills/ctx-aidlc-run/SKILL.md`
- Modified: `common/question-governance.md`
- Added: `docs/new-feature.md`

## Rationale

(Why this change was needed)

## Impact

- Affects users who [condition]
- No breaking changes / Breaking if [condition]

## Migration

(If users need to take action)
```

Link from main `README.md`:

```markdown
| 2026-05-15 | Changelog title | [상세](docs/changelog/2026-05-15-topic.md) |
```

---

## Code Review Checklist

Before submitting a PR, ensure:

- [ ] Edited only under `skills/`, `common/`, `core/`, `docs/`, `templates/`
- [ ] Ran `bash scripts/install-skills.sh` and tested locally
- [ ] Commit message in English
- [ ] No hardcoded paths (use placeholders like `{{TEAM_AI_WORKFLOW_DIR}}`)
- [ ] No NHN-internal references or jargon
- [ ] Tested on at least one project
- [ ] Updated CHANGELOG if it's a feature/rule change
- [ ] Used Korean for user text, English for code/commands

---

## Language Policy

- **Documentation content**: Korean (사용자 가이드, 규칙, 개념)
- **Code, commands, commit messages**: English
- **Skill prompts/output**: Korean (사용자와 상호작용)
- **Comments in skill files**: English preferred (international readability)

---

## Asking Questions

- **Usage questions**: [GitHub Discussions](https://github.com/TaeseongYun/aidlc-workflow/discussions)
- **Bug reports**: [Issues](https://github.com/TaeseongYun/aidlc-workflow/issues)
- **Design feedback**: Open a discussion before large PRs

---

## License

By contributing, you agree your work is licensed under MIT (see LICENSE).
