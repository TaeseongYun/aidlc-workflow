# extensions/hallucination-guard

The **hallucination guard** ("바이브 블로커" / vibe blocker) module. It stops the AI's ungrounded
guesses from being stated as dev facts, and grounds verification on a **code graph** substrate
(codegraph + graphify).

**Mandatory, not opt-in.** The other `extensions/` modules (security, performance, api-contract) ship
a `*.opt-in.md` loader and only apply when a user opts in. This one is always on: it is wired into
initial project setup and referenced from every project's `CLAUDE.md`, so there is no opt-in file.

## Files

| File | Purpose |
|---|---|
| `hallucination-guard.md` | The canonical ruleset (Rules 0–5), the Hallucination-Free Score rubric, and Linear routing. Referenced by each project's `CLAUDE.md`. |
| `README.md` | This map. |

## How it is wired (all parts)

1. **Precondition gate** — `scripts/check-codegraph.sh` enforces `codegraph` + `graphify` + a built
   `.codegraph/` index before setup proceeds. Missing a tool = setup blocked.
   - `scripts/init-project.sh` hard-fails on a missing tool and auto-builds a missing index.
   - `/team-ai-workflow-start` (skill) opens an **AskUserQuestion dialog** to install the missing
     tool(s) — never a free-text "continue anyway" prompt.
2. **Guard rules** — `init-project.sh` appends a "Hallucination Guard (ALWAYS ON)" pointer to the
   generated `CLAUDE.md`, referencing `hallucination-guard.md`. Every `ctx-*` run bootstraps it.
3. **Per-project state** (scaffolded by `init-project.sh` from `templates/`):
   - `aidlc-docs/hallucination-ledger.md` — append-only quarantine list (read at Rule 1).
   - `aidlc-docs/knowledge-log.md` — distilled lessons, pushed to Linear (Rule 5).
4. **The audit loop** — `/ctx-hallucination-audit` (skill) runs HARVEST → VERIFY (codegraph) → SCORE →
   RECORD → QUARANTINE → CAPTURE, looping until the Hallucination-Free Score ≥ 87.
   `scripts/harvest-assumptions.sh` feeds it the deterministic marker hits.
5. **Execution hook** — `skills/ctx-run` references Rule 0 so dev facts get verified via codegraph
   during implementation.

## Why codegraph + graphify are required

The guard verifies dev facts against a **concrete source**, preferring reading the code over recalling
it. `codegraph explore` / `codegraph node` give verbatim symbol source + call paths in one shot — the
best such source. Without the graph, VERIFY falls back to grep/memory, which is what causes
hallucination in the first place. Hence the substrate is a hard precondition, not a nicety.
