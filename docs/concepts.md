# Core Concepts

## Separation of team-ai-workflow / ctx / aidlc-docs roles

| Area | Role | Location |
|------|------|----------|
| **team-ai-workflow** | Shared team judgment criteria. Defines "how to think and what deliverables to produce" | Team-shared repository |
| **ctx/** | Project-local facts. Existing structure, prohibition rules, reusable components | Each project |
| **aidlc-docs/** | Feature work deliverables. Requirements, questions, unit-of-work, status tracking | Each project |

## No-Implicit-Decisions

The core principle that keeps AI from deciding what it should not decide.

- AI does not decide business policy on its own.
- If two or more valid designs exist and the CTX has no answer, **stop and raise a question**.
- Payment/refund/settlement/permission/notification policies always require human approval.

Permitted inference:
- Reusing patterns already present in the code
- Decomposing an explicit policy into implementation units
- Documenting facts that are self-evident from the code

## Overconfidence Prevention

The rule that prevents treating uncertain judgments as if they were confirmed during AI-driven stages.

- The STEPs where AI proceeds without generating questions (6, 6.5, 6.7) carry the highest overconfidence risk.
- Attach a `⚠️ UNCERTAIN` marker to any judgment lacking grounds, and have the user confirm it at the gate.
- After writing a deliverable, perform the 3 Self-Verification questions.
- On STEP 3 completion, automatically check whether questions for high-risk areas are missing.
- In the Readiness Score, apply an 80%-of-maximum cap to any domain that has an uncertainty marker.

Details: `common/overconfidence-prevention.md`

## Error Recovery

Defines the recovery path when the workflow is interrupted, deliverables are corrupted, or state becomes inconsistent.

- On session resume, first verify that `aidlc-state.md` matches the actual deliverables.
- Recovery by mismatch type: state complete but deliverable missing → re-run; deliverable present but state incomplete → verify then update.
- Create a backup before regenerating a deliverable.
- Record every recovery event in `audit.md` as `[RECOVERY]`.

Details: `common/error-recovery.md`

## Pre-Write Validation

Before creating a deliverable file, validate structure, references, diagrams, and special characters.

- This is separate from contradiction detection (existing); it is the rule that guarantees the file quality itself.
- On validation failure, fix and record, or leave a `⚠️ TODO` marker if it cannot be fixed.

Details: `common/content-validation.md` section 0

## Per-project input priority

File composition can differ per project, so read only the files that exist, in the following order.

1. `ctx/INDEX.md`
2. `ctx/project-profile.ctx.md`
3. `AGENTS.md`
4. `CLAUDE.md`
5. `README.md`
6. Relevant detailed `ctx/*`

## aidlc-docs retention principles

- Do not delete deliverables from previous features.
- Keep shared state files at the root: `aidlc-state.md`, `audit.md`
- Separate per-feature deliverables into `aidlc-docs/features/<feature-slug>/`.
- When a new requirement comes in, create a new feature folder rather than overwriting existing documents.

## aidlc-docs version control

- Default is personal work deliverables → `.gitignore` recommended
- Exceptions: when the team adopts it as an official requirements record; when an audit/approval history is needed
- When promoting to official documentation, move only the final approved version separately to `docs/`

## Recommended feature folder structure

```text
aidlc-docs/features/<feature-slug>/
├── status.md
├── requirements.md
├── requirement-verification-questions.md
├── unit-of-work.md
├── unit-of-work-dependency.md
└── unit-of-work-story-map.md
```

For a raw request, add:

```text
├── request-intake.md
└── planning-draft.md
```

## Minimum files to put in each project

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

## Common Engineering Reference

Stack-independent engineering guides (architecture, testing, commit/branch workflow,
code review, CI/CD, releases, dependency management, incident postmortems) live under
`common/<topic>/` — a deep `reference/guide.md` plus an actionable `SKILLS.md` per topic.
Index: [common/reference-index.md](../common/reference-index.md).
Precedence stays: project `ctx/` > platform guidance > common guides > general knowledge.
