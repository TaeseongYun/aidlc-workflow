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

1. **Precondition check** — `scripts/check-graphify.sh` looks for `graphify` + a built
   `graphify-out/graph.json`. graphify is strongly recommended, not mandatory: missing the tool
   drops the guard to **degraded mode** (VERIFY via grep/Read), it does not block setup.
   - `scripts/init-project.sh` warns and continues in degraded mode on a missing tool, and
     auto-builds a missing graph (brownfield).
   - `/team-ai-workflow-start` (skill) opens an **AskUserQuestion dialog** offering install /
     proceed-in-degraded-mode / cancel — never a free-text "continue anyway" prompt.
2. **Guard rules** — `init-project.sh` appends a "Hallucination Guard (ALWAYS ON)" pointer to the
   generated `CLAUDE.md`, referencing `hallucination-guard.md`. Every `ctx-*` run bootstraps it.
3. **Per-project state** (scaffolded by `init-project.sh` from `templates/`):
   - `aidlc-docs/hallucination-ledger.md` — append-only quarantine list (read at Rule 1).
   - `aidlc-docs/knowledge-log.md` — distilled lessons, pushed to Linear (Rule 5).
4. **The audit loop** — `/ctx-hallucination-audit` (skill) runs HARVEST → VERIFY (graphify) → SCORE →
   RECORD → QUARANTINE → CAPTURE, looping until the Hallucination-Free Score ≥ 87.
   `scripts/harvest-assumptions.sh` feeds it the deterministic marker hits.
5. **Execution hook** — `skills/ctx-domain-exec` references Rule 0 so dev facts get verified via graphify
   during implementation.

## Why the code graph (graphify) is strongly recommended

The guard verifies dev facts against a **concrete source**, preferring reading the code over recalling
it. `graphify query` / `graphify explain` / `graphify path` (or the MCP tools) give nodes, call paths,
and verbatim `file:line` in one shot — the best such source. Without the graph, VERIFY falls back to
grep/Read, which is a weaker surface where hallucination is more likely. That is why graphify is the
strongly recommended default. It is not a hard precondition, though: when it is absent the guard runs
in degraded mode (grep/Read, with `⚠️ UNCERTAIN` applied more aggressively). (codegraph, if installed,
is a fallback graph source.)
