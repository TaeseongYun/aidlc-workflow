# graphify Soft Dependency + CI

## Summary

Two portability/operations improvements. First, `graphify` is no longer a hard,
setup-blocking prerequisite: when the tool is missing, the Hallucination Guard now runs
in a supported **degraded mode** (VERIFY falls back to grep/Read) instead of aborting
initialization or blocking routing. Second, a GitHub Actions workflow now runs the
existing validators on every PR and on pushes to `main`. Wiring up CI immediately
surfaced a pre-existing bug — `validate-questions.sh` only matched Korean field labels
while the repo's artifacts are English — which is fixed here by making the validator
bilingual.

## Files Changed

- Modified: `scripts/check-graphify.sh` (exit-code 2 reworded to degraded; still a diagnostic signal)
- Modified: `scripts/init-project.sh` (missing tool → warn + continue in degraded mode instead of `exit 1`; final message branches on gate result)
- Modified: `skills/team-ai-workflow-start/SKILL.md` (CASE 0: HARD GATE → non-blocking install / degraded / cancel dialog)
- Modified: `skills/team-ai-workflow-start/CLAUDE_COMMAND.md` (same non-blocking behavior)
- Modified: `templates/aidlc-state.md` (added `Hallucination Guard Mode: full | degraded` field)
- Modified: `common/graph-grounding.md` (added "Degraded mode" section)
- Modified: `extensions/hallucination-guard/hallucination-guard.md`, `extensions/hallucination-guard/README.md` (recommended, not mandatory)
- Modified: `docs/hallucination-guard.md`, `README.md`, `README.ko.md`, `README.zh.md` (wording: required → strongly recommended + degraded)
- Modified: `tools/evaluator/validate-questions.sh` (field / answer / confidence labels now match both Korean and English)
- Modified: `CONTRIBUTING.md` (documented the CI validation loop)
- Added: `.github/workflows/validate.yml` (runs `validate-skills.sh` + golden-baseline `validate-all.sh`)

## Rationale

The graphify hard gate was the single biggest adoption barrier for new teams (it requires
Python/uv and blocks setup entirely if absent), while the guard's fallback chain
(graphify → codegraph → grep/Read) was already specified in `common/graph-grounding.md`.
Only the initialization gate enforced the block, so loosening it to a warning unlocks
degraded operation that the skills already support. CI closes the gap where rule changes
were never regression-tested against the golden baselines.

## Impact

- Teams without graphify can now initialize and run the workflow in degraded mode.
- graphify remains the strongly recommended default; when present, behavior is unchanged.
- `validate-questions.sh` now passes on the (English) golden baselines and still accepts
  Korean-labeled question files (backward compatible).
- No breaking changes.

## Migration

None required. To restore graph-backed verification after a degraded init, install
graphify (`uv tool install "graphifyy[mcp]"`) and re-run `/team-ai-workflow-start`.
