# Commit Workflow CTX

It is recommended to create this file at `ctx/workflow/commit-workflow.ctx.md`.
It is generated automatically when `init-project.sh` runs.

---

## 1. Commit Separation Criteria

Without this rule, the AI mixes domain changes and response changes into a single commit.

- Always separate changes to the query-result structure in the domain layer from changes to response exposure in the application layer into different commits.
- Even for the same purpose, never merge changes when the change location splits between domain/response.
- (TODO: make the separation criteria concrete to match the project's layer structure)

## 2. Commit Ordering Rules

Without this rule, the AI reverses the dependency order.

- When a response-layer change depends on a domain query-result change, always commit the domain change first.
- Place documentation-cleanup commits after the related code-change commits.
- (TODO: define the order to match the project's layer dependency direction)

## 3. File Inclusion Scope Rules

Without this rule, the AI mixes files and breaks per-commit tracking.

- Include only files of the same responsibility in a single commit.
- Do not put files from different layers in the same commit.
- Compose each commit so it is reproducible with file-level `git add` alone.

## 4. Commit Message Rules

Without this rule, the AI omits or mixes up messages.

- Always follow the title format `type: (scope) summary`.
- The body structure and language rules are defined by the `ctx-commit-planner` Skill. Do not redefine them here.

## Allowed scope list

- (TODO: define to match the project's modules/domains)

## Forbidden patterns

- No WIP commits
- No empty commit messages
- No commits composed solely of auto-generated files

## Required pre-commit checks

- (TODO: enable to match the project)
- [ ] Build passes
- [ ] Lint passes
- [ ] Tests pass
