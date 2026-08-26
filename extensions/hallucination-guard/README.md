# extensions/hallucination-guard

The **hallucination guard** ("바이브 블로커" / vibe blocker) module. It stops the AI's ungrounded
guesses from being stated as dev facts, and grounds verification on a **code graph** substrate
(graphify; codegraph is an optional fallback).

**Mandatory, not opt-in.** The other `extensions/` modules (security, performance, api-contract) ship
a `*.opt-in.md` loader and only apply when a user opts in. This one is always on: it is wired into
initial project setup and referenced from every project's `CLAUDE.md`, so there is no opt-in file.

## Files

| File | Purpose |
|---|---|
| `hallucination-guard.md` | The canonical ruleset (Rules 0–5), the Hallucination-Free Score rubric, and Linear routing. Referenced by each project's `CLAUDE.md`. |
| `README.md` | This map. |

## How it is wired (all parts)

1. **Precondition gate** — `scripts/check-graphify.sh` enforces `graphify` + a built
   `graphify-out/graph.json` before setup proceeds. Missing the tool = setup blocked.
   - `scripts/init-project.sh` hard-fails on a missing tool and auto-builds a missing graph (brownfield).
   - `/team-ai-workflow-start` (skill) opens an **AskUserQuestion dialog** to install the missing
     tool — never a free-text "continue anyway" prompt.
2. **Guard rules** — `init-project.sh` appends a "Hallucination Guard (ALWAYS ON)" pointer to the
   generated `CLAUDE.md`, referencing `hallucination-guard.md`. Every `ctx-*` run bootstraps it.
3. **Per-project state** (scaffolded by `init-project.sh` from `templates/`):
   - `aidlc-docs/hallucination-ledger.md` — append-only quarantine list (read at Rule 1).
   - `aidlc-docs/knowledge-log.md` — distilled lessons, pushed to Linear (Rule 5).
4. **The audit loop** — `/ctx-hallucination-audit` (skill) runs HARVEST → VERIFY (graphify) → SCORE →
   RECORD → QUARANTINE → CAPTURE, looping until the Hallucination-Free Score ≥ 87.
   `scripts/harvest-assumptions.sh` feeds it the deterministic marker hits.
5. **Execution hook** — `skills/ctx-run` references Rule 0 so dev facts get verified via graphify
   during implementation.

## Why the code graph (graphify) is required

The guard verifies dev facts against a **concrete source**, preferring reading the code over recalling
it. `graphify query` / `graphify explain` / `graphify path` (or the MCP tools) give nodes, call paths,
and verbatim `file:line` in one shot — the best such source. Without the graph, VERIFY falls back to
grep/memory, which is what causes hallucination in the first place. Hence the substrate is a hard
precondition, not a nicety. (codegraph, if installed, is only a fallback.)
