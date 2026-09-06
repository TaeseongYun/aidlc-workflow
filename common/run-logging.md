# Run Logging

## Purpose

Single protocol for how any skill records "what results the AI processed" as typed, append-only data,
and how a later run recalls it. This complements `audit.md` (which logs *every* STEP/GATE event as prose):
run logging captures **results** — the outcomes worth retrieving next time — in a machine-structured form
that graphify can re-ingest as retrieval (RAG) grounding. Skills reference this file instead of repeating
the logger command.

Tool: `{{TEAM_AI_WORKFLOW_DIR}}/scripts/run-logger.ts` (run with `npx tsx`, Node stdlib only).

## Artifacts (per project, under `aidlc-docs/`)

- `run-log.ndjson` — source of truth. One `RunLogEntry` per line. **Append-only** (never edit/delete;
  a later state change is a new entry, mirroring the ledger/knowledge-log rule).
- `run-log.md` — deterministic Markdown mirror, regenerated on every append. graphify ingests Markdown,
  so the run history becomes graph-queryable. Do not hand-edit — the logger overwrites it.

## Schema (`RunLogEntry`)

| field | required | notes |
|-------|----------|-------|
| `ts` | auto | ISO 8601 UTC (stamped if omitted) |
| `feature` | yes | feature slug, or `_project` for project-level |
| `skill` | yes | e.g. `ctx-score-loop` |
| `phase` | yes | e.g. `GATE-2`, `score-round-3`, `hallucination-audit` |
| `kind` | yes | `gate` \| `score` \| `unit` \| `hallucination` \| `note` |
| `result` | yes | short outcome, e.g. `COMPLETE (over 85)`, `GATE-2 approved` |
| `detail` | no | rationale / longer note |
| `artifacts` | no | comma-separated files produced/touched |
| `refs` | no | comma-separated `file:line`, `HAL-NNN`, Linear URL, git SHA |
| `confidence` | no | `certain` \| `estimated` \| `ai-recommended` \| `undecided` |
| `mode` | no | Hallucination Guard mode at record time: `full` \| `degraded` |

## When to append (key result points only — not every event)

Append one entry at each of these; keep prose-level STEP events in `audit.md`.

- **GATE decision** (`--kind gate`) — a GATE is approved/rejected. `phase = GATE-N`.
- **Score-loop verdict** (`--kind score`) — each `ctx-score-loop` round's total + verdict.
- **Unit-of-work completion** (`--kind unit`) — a unit finished (or its `ctx-score-loop` closed COMPLETE).
- **Hallucination round** (`--kind hallucination`) — each `ctx-hallucination-audit` round's score/result.
- **Note** (`--kind note`) — anything else a future run should retrieve.

```bash
npx tsx {{TEAM_AI_WORKFLOW_DIR}}/scripts/run-logger.ts append --project . \
  --feature <slug> --skill <name> --phase <p> --kind <k> --result "<text>" \
  [--detail "..."] [--artifacts a,b] [--refs a,b] [--confidence certain] [--mode full]
```

Structured callers may pass `--json '<entry>'` or pipe a JSON entry on stdin instead of flags.

## Recall (at run entry / when prior context matters)

- **Graph present** → prefer graphify (it has already ingested `run-log.md` on the last rebuild):
  `graphify query "prior results for <feature>"` (or the MCP tools). See `common/graph-grounding.md`.
- **Degraded (no graphify)** → read locally:
  `npx tsx {{TEAM_AI_WORKFLOW_DIR}}/scripts/run-logger.ts recall --project . [--feature <slug>] [--kind <k>] [--limit N]`
  — prints matching entries as JSON lines for the agent to consume.

## Rules

- Passive ingestion only: the logger never calls graphify. Skills already rebuild the graph
  (`graphify .` / `--update`); the mirror rides those rebuilds. This keeps graphify a **soft dependency**
  — run logging works fully in degraded mode via `recall`.
- Append-only. Do not edit `run-log.ndjson` or `run-log.md` by hand.
- English content only (repo policy), same as every other committed artifact.
- If graphify does not scan `aidlc-docs/` by default, ingest the mirror explicitly with
  `graphify extract aidlc-docs/run-log.md` (or add it to graphify's include set).
