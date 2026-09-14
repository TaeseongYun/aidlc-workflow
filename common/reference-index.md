# Common Engineering Reference

Platform-agnostic engineering guides for LLM agents (and engineers) to consult while
working. Every topic ships two files:

- **`<topic>/reference/guide.md`** — the deep reference (concepts, taxonomies, tables, anti-patterns, sources). Read this to *understand* the domain.
- **`<topic>/SKILLS.md`** — the actionable procedure (inputs/outputs, numbered steps, decision rules, output format, checklist). Read this to *do* the task; it cross-links the relevant `/ctx-*` workflow skills.

These are stack-independent. Platform-specific rules live under `platforms/<platform>/`;
project-specific facts live under `ctx/`. Precedence: project `ctx/` > platform guidance >
these common guides > general knowledge.

## Index

| Topic | Covers | Reference | Procedure |
| :---- | :----- | :-------- | :-------- |
| **architecture-design** | Boundaries, data ownership, styles, ADRs, one-way vs two-way doors, YAGNI | [guide](architecture-design/reference/guide.md) | [skills](architecture-design/SKILLS.md) |
| **commit-workflow** | Structuring work into atomic, well-described commits | [guide](commit-workflow/reference/guide.md) | [skills](commit-workflow/SKILLS.md) |
| **commit-review** | Reviewing individual commits and their messages | [guide](commit-review/reference/guide.md) | [skills](commit-review/SKILLS.md) |
| **code-review** | Reviewing a change before merge: dimensions, severity, comments, verdict | [guide](code-review/reference/guide.md) | [skills](code-review/SKILLS.md) |
| **testing-strategy** | Test pyramid, doubles, meaningful coverage, flakiness, regression tests | [guide](testing-strategy/reference/guide.md) | [skills](testing-strategy/SKILLS.md) |
| **git-history** | Keeping history clean, bisectable, and recoverable | [guide](git-history/reference/guide.md) | [skills](git-history/SKILLS.md) |
| **branch-strategy** | Branching models, naming, protection, integration cadence | [guide](branch-strategy/reference/guide.md) | [skills](branch-strategy/SKILLS.md) |
| **branch-cleanup** | Detecting and safely removing stale branches and worktrees | [guide](branch-cleanup/reference/guide.md) | [skills](branch-cleanup/SKILLS.md) |
| **ci-cd-automation** | Pipelines, merge gates, deployment strategies, rollback | [guide](ci-cd-automation/reference/guide.md) | [skills](ci-cd-automation/SKILLS.md) |
| **release-versioning** | SemVer, changelogs, release process, deprecation | [guide](release-versioning/reference/guide.md) | [skills](release-versioning/SKILLS.md) |
| **dependency-management** | Direct/transitive deps, lockfiles, supply-chain, update cadence | [guide](dependency-management/reference/guide.md) | [skills](dependency-management/SKILLS.md) |
| **incident-postmortem** | Severity, incident lifecycle, blameless postmortems, action items | [guide](incident-postmortem/reference/guide.md) | [skills](incident-postmortem/SKILLS.md) |

## Workflow rule files (single-file rules, loaded lazily by the skills)

The standalone rules under `common/` are not topic pairs; each is loaded by the skill/STEP
that needs it (see the per-step loading table in `skills/ctx-aidlc-run/SKILL.md`):

`question-rules.md`, `question-governance.md`, `stage-gate-rules.md`, `depth-levels.md`,
`no-implicit-decisions.md`, `overconfidence-prevention.md`, `content-validation.md`,
`error-recovery.md`, `extension-rules.md`, `graph-grounding.md`, `run-logging.md`,
`diagram-standards.md`, plus `frameworks/` (JTBD, RICE, MoSCoW prioritization).

## Conventions

- English only (repo language policy — see CONTRIBUTING.md); avoid emojis in these guides.
- Guides open with a one-line `>` summary and end with a `## References` section citing well-known sources.
- Cross-links between topics are relative (`../<topic>/reference/guide.md`).
- Related workflow skills are referenced in command form (e.g. `/ctx-reviewer`).
