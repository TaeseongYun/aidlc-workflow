# Change: Add commit-workflow CTX template to init-project.sh

## Change date
2026-03-24

## Background

The `/ctx-commit-planner` skill requires `ctx/workflow/commit-workflow.ctx.md`.
It is designed so that the skill halts immediately if that CTX is missing.

However, `init-project.sh` did not create this file, so `/ctx-commit-planner`
was unusable even after project initialization.

## What changed

### Before

```
init-project.sh generated files:
├── ctx/INDEX.md
├── ctx/project-profile.ctx.md
├── CLAUDE.md
└── aidlc-docs/ (aidlc-state.md, audit.md, features/)
```

Run `/ctx-commit-planner` → no CTX → halts immediately

### After

```
init-project.sh generated files:
├── ctx/INDEX.md
├── ctx/project-profile.ctx.md
├── ctx/workflow/commit-workflow.ctx.md  ← added
├── CLAUDE.md
└── aidlc-docs/ (aidlc-state.md, audit.md, features/)
```

Run `/ctx-commit-planner` → CTX reference succeeds → proceed to commit design

---

## Template contents

The generated `commit-workflow.ctx.md` holds the per-project commit policy:

| Section | Content |
|------|------|
| Branch strategy | main/dev/feature/fix branch rules |
| Commit unit criteria | Principle of splitting by meaning units |
| Allowed scope list | scope definitions per project module/domain |
| Forbidden patterns | WIP, mixed commits, empty messages, etc. |
| Required pre-commit checks | whether build/lint/test pass |

Every section includes a `(TODO)` marker to prompt per-project customization.

### Role separation from SKILL.md

| File | Role |
|------|------|
| `skills/ctx-commit-planner/SKILL.md` | Skill-internal behavior rules (message format, language rules, split rules) |
| `ctx/workflow/commit-workflow.ctx.md` | Per-project commit policy (branch, scope, forbidden patterns) |

SKILL.md's rules are not duplicated into the CTX. This is to prevent double management.

---

## List of changed files

### Modified files

| File | Change content |
|------|----------|
| `scripts/init-project.sh` | Create `ctx/workflow/` directory, generate `commit-workflow.ctx.md` template, reflect in output tree |

---

## Compatibility

- Backward compatible: no impact on projects created by the existing init-project.sh
- Skipped if `commit-workflow.ctx.md` already exists
- No change to the skill execution flow

---

## Follow-up change: CTX template refinement and separation into an external file

### Background

The existing `init-project.sh` generated content directly via heredoc.
This duplicated rules with SKILL.md and had the problem that the shell script had to be edited directly when the policy changed.

### Change content

#### 1. Separate the template into an external file

```
Before: generated directly via inline heredoc in init-project.sh
After: templates/commit-workflow.ctx.md → copied via cp
```

#### 2. Remove duplicate rules from SKILL.md

| Removed item | Reason |
|-----------|------|
| Section 4 (include/exclude criteria) | Enforced by SKILL.md 5-2 as output format |
| The "no mixed commits" forbidden pattern | Internally duplicates the commit-split criteria of section 1 |
| Body structure (why/what/excluded) | Handled by the SKILL.md 5-2 body rules |

#### 3. Final CTX structure

| Section | Role |
|------|------|
| 1. Commit split criteria | Split policy per project layer |
| 2. Commit order rules | Commit order based on dependency direction |
| 3. File inclusion scope rules | Include only files of the same responsibility |
| 4. Commit message rules | Defines only the title format, delegates the body to SKILL.md |
| Allowed scope list | Per-project TODO |
| Forbidden patterns | WIP, empty messages, standalone commits of auto-generated files |
| Required pre-commit checks | build/lint/test TODO |

### Changed files

| File | Change content |
|------|----------|
| `templates/commit-workflow.ctx.md` | Newly created — a CTX template with SKILL.md duplication removed |
| `scripts/init-project.sh` | Removed heredoc, changed to template-cp approach |
