# Graph Grounding

## Purpose

Single protocol for how any skill uses the code graph (graphify) as the VERIFY source for the
Hallucination Guard. Skills reference this file instead of repeating graphify commands. codegraph, if
installed, is only a fallback graph source.

## Source selection

- **MCP available** → use the structured MCP tools: `query_graph`, `get_node`, `get_neighbors`,
  `shortest_path` (and `list_prs` / `get_pr_impact` / `triage_prs` for change impact).
- **No MCP** → use the CLI: `graphify query "<question>"`, `graphify path "<a>" "<b>"`,
  `graphify explain "<entity>"`.
- **No graphify** → fall back to `codegraph explore`/`codegraph node`, then grep/Read of the real
  source, then `ctx/` docs or official upstream docs.

## Provenance handling (edge confidence)

Every graphify edge is labelled. Treat the labels as verification strength, not as fact:

- `EXTRACTED` (explicit in source) — usable as code evidence directly.
- `INFERRED` (resolved by graphify) — re-check the real source (`file:line`) before any load-bearing
  decision; do not state it as fact on the label alone.
- `AMBIGUOUS` (flagged) — do not decide. Convert it into a BLOCK question (see `question-rules.md`).

## Rules

- A query returning **no result is not proof of absence** — the graph may be stale or the entity
  unindexed. Confirm with grep/Read before concluding "it does not exist".
- Never verify a guess with another guess (Hallucination Guard Rule 0).
- Every recorded graph result must carry its **code commit SHA** and the **graph build timestamp**, so
  later readers know which code state the evidence reflects.
- Snapshot load-bearing findings into `aidlc-docs/features/<feature-slug>/graph-evidence.md`
  (template: `templates/graph-evidence.md`). The live graph moves; the snapshot preserves the evidence
  a decision was made on.
