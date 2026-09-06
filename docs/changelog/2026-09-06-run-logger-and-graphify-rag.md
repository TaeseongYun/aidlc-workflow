# Run-Result Logger + graphify RAG Accumulation

## Summary

Adds a TypeScript logger that records "what results the AI processed" as typed, append-only data, and
shapes that data so graphify can re-ingest it as retrieval (RAG) grounding for later runs. The framework
already wrote a rich *human-readable* trail (`audit.md`, ledgers, per-feature score history) but nothing
*machine-structured*, and nothing deliberately shaped for graphify's document side. `scripts/run-logger.ts`
appends `RunLogEntry` records to `aidlc-docs/run-log.ndjson` (source of truth) and regenerates a
graphify-ingestible `aidlc-docs/run-log.md` mirror on every append. Ingestion is **passive** — the logger
never calls graphify; the mirror rides the `graphify .` / `--update` rebuilds skills already run — so
graphify stays a soft dependency (consistent with the graphify-soft-dependency change). When graphify is
absent, `run-logger.ts recall` reads the NDJSON locally. Wired into existing skills at key result points
only (GATE decisions, score-loop verdicts, unit completions, hallucination rounds) plus a recall at
session entry — complementing `audit.md`, not duplicating it.

## Files Changed

- Added: `scripts/run-logger.ts` (typed `append` / `recall` CLI + `--selftest`; Node stdlib only, run via `npx tsx`)
- Added: `templates/run-log.md` (seed for the mirror; copied by `init-project.sh`)
- Added: `common/run-logging.md` (protocol: schema, when to append, recall, passive ingestion, degraded mode)
- Modified: `scripts/init-project.sh` (seed `run-log.ndjson` + `run-log.md`; list them in the final tree)
- Modified: `skills/ctx-score-loop/SKILL.md` (STEP E appends a `score` entry — the verdict/total/round)
- Modified: `skills/ctx-hallucination-audit/SKILL.md` (STEP 7 appends a `hallucination` entry per round)
- Modified: `skills/ctx-aidlc-run/SKILL.md` (STEP LIFECYCLE appends `gate`/`unit` entries at decisions/completions)
- Modified: `skills/team-ai-workflow-start/SKILL.md` (STEP 1.7 recalls prior results before routing)
- Modified: `README.md` (changelog row)

## Rationale

Everything the framework logged was prose, so results could not be reliably parsed, queried, or re-fed to
an agent, and graphify — used only as a *code* graph — never saw run history. graphifyy ingests Markdown
docs into its traversable graph, so emitting a Markdown mirror turns accumulated results into retrievable
graph nodes with zero new coupling. Recording at result points (not every event) keeps the log signal-dense
and avoids duplicating the `audit.md` event trail.

## Impact

- New per-project artifacts under `aidlc-docs/`: `run-log.ndjson` and `run-log.md`. Existing projects get
  them on the next `init-project.sh` run, or on the first `append` (the logger creates them if missing).
- graphify remains a soft dependency; run logging and recall work in degraded mode via `recall`.
- No breaking changes.

## Migration

None required. To surface run history in the graph, rebuild after appends (`graphify . --update`), or if
graphify does not scan `aidlc-docs/` by default, `graphify extract aidlc-docs/run-log.md`.
