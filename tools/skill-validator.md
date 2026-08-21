# Skill Validator

Rules that validate the quality of team-ai-workflow skills.
Divided into automated validation (`validate-skills.sh`) and inferential validation (AI review).

## Automated Validation Rules (Deterministic)

Rules that can be validated by a script.

### SKILL-01: Entry point exists
- `skills/<name>/SKILL.md` or `skills/<name>/CLAUDE_COMMAND.md` must exist.
- FAIL if neither exists.

### SKILL-02: Required frontmatter fields
- The YAML frontmatter must contain a `description` field.
- FAIL if empty.

### PATH-01: Internal references use relative paths
- References to files within the same skill directory must start with `./` or `../`.
- FAIL if an absolute path is used.

### PATH-02: External references use a variable
- References to team-ai-workflow files outside the skill directory must use the `{{TEAM_AI_WORKFLOW_DIR}}` variable.
- FAIL if a hardcoded absolute path is used.

### REF-01: Referenced files exist
- Every file referenced within a skill must actually exist.
- FAIL if a reference points to a nonexistent file.

### SCOPE-01: Cross-skill references prohibited
- Source files in another skill directory within the repo (`skills/<other-name>/`) must not be referenced directly.
- FAIL on a cross-skill reference.
- Exception: it is allowed for the entry point skill to check the global install paths
  (`~/.claude/.../`, `~/.codex/skills/<name>/`) in order to **diagnose whether skills are installed**.
  This checks the environment state rather than depending on another skill's source.

## Inferential Validation Rules (AI Review)

Rules where the AI reads the content and makes a judgment. Cannot be validated by `validate-skills.sh`.

### SKILL-03: Common protocol reference
- Must follow the core rules of `_shared/skill-protocol.md` (role, input, guardrails, output).

### SKILL-04: Guardrail section exists
- What the skill must not do (e.g., no implementation, no design proposals) must be specified.

### SKILL-05: Output Format section exists
- The form and location of the artifact must be specified.

### PROTO-01: Common protocol adherence
- Must follow the execution flow defined in `_shared/skill-protocol.md` (read CTX → judge → artifact).

## Running Validation

### Automated validation
```bash
bash tools/validate-skills.sh
```

### Inferential validation
Ask the AI to review a specific skill with reference to this document:
```
"Validate skills/<name>/SKILL.md using the inferential rules in tools/skill-validator.md"
```

## Validation Result Format

```
[PASS] SKILL-01: skills/ctx-aidlc-run — entry point exists (SKILL.md + CLAUDE_COMMAND.md)
[FAIL] PATH-02: skills/ctx-run — hardcoded path found: /Users/nhn/workspace/...
[SKIP] SKILL-03: inferential validation — cannot be validated by a script
```
