# Hallucination Guard (Vibe Blocker) Guide

An **always-on** layer that prevents the AI's baseless guesses from leaking into artifacts as dev facts.
It ports the hallucination guard validated in `ai-bloc-hallucination` into the team-ai-workflow main body,
and strongly recommends a **code graph (graphify)** as the primary source of verification. (codegraph is an optional fallback.)

## Why a code graph is recommended

The guard's core rule is "verify every dev fact against a concrete source. Read the code, don't remember it.
Never verify a guess with another guess." The most trustworthy source for this is a **code graph** —
`graphify query "<question>"` / `graphify explain "<entity>"` / `graphify path "<a>" "<b>"` (or the MCP
`query_graph`/`get_node`) return nodes, call paths, and source locations (`file:line`). Without a graph,
VERIFY falls back to grep/Read, which is the weak surface where hallucinations arise most easily. That is why the
`graphify` + `graphify-out/graph.json` graph is **strongly recommended** — but not required. Without it, the guard
operates in **degraded mode** (a supported fallback: grep/Read + aggressive `⚠️ UNCERTAIN` tagging).
If codegraph is installed, it is used as a secondary fallback.

## Components

| Component | Location | Role |
|---|---|---|
| Guard rules (Rule 0–5) | `extensions/hallucination-guard/hallucination-guard.md` | Original text of the dev fact verification, quarantine, scoring, and Linear routing rules |
| Module map | `extensions/hallucination-guard/README.md` | How it is wired together |
| Prerequisite gate | `scripts/check-graphify.sh` | Detects graphify and graph.json (codegraph is an optional fallback; TOOL REGISTRY single source) |
| Marker harvester | `scripts/harvest-assumptions.sh` | HARVEST input for the audit loop |
| Quarantine ledger | `templates/hallucination-ledger.md` → `aidlc-docs/` | Append-only quarantine list (first loaded in Rule 1) |
| Lesson log | `templates/knowledge-log.md` → `aidlc-docs/` | Lessons pushed to Linear |
| Audit loop skill | `skills/ctx-hallucination-audit/` | `/ctx-hallucination-audit` — iterate until score ≥ 87 |

## Code graph check (non-blocking)

The exit code of `scripts/check-graphify.sh [project-root] [--mode=brownfield|greenfield]` is a
**diagnostic signal**, not policy. Each consumer (script/skill) handles it on its own:

- `0` — satisfied (`graphify` + `graphify-out/graph.json`). Can proceed. (In greenfield, a not-yet-generated
  graph is also `0`+`WARN` — generate it after the first implementation.)
- `2` — `graphify` tool missing. **Degraded is possible** (not a block) — VERIFY falls back to grep/Read. Installation recommended.
- `3` — brownfield but the graph has not been generated. Generate it with `graphify .` and pass.

Wiring:

- **CLI path** — `scripts/init-project.sh` runs the gate at startup. On code 2 it only leaves a warning and
  **continues in degraded mode** (it no longer does `exit 1`). On code 3 it generates the graph with
  `graphify .`, and even if that fails it warns and continues degraded.
- **Claude path** — diagnostic F of `/team-ai-workflow-start` evaluates the gate, and on code 2, in **CASE 0**,
  instead of a free-text "continue" prompt it asks via an **AskUserQuestion dialog**: (1) install, (2) proceed in degraded mode,
  (3) cancel. If (1) is approved, it runs the install command + `graphify .`, confirms the pass with a re-check, then routes.
  If (2) is chosen, it records `Hallucination Guard Mode: degraded` in `aidlc-docs/aidlc-state.md` and continues.

> graphify is installed as the PyPI package `graphifyy` (double y; the console command is `graphify`):
> `uv tool install "graphifyy[mcp]"`. The exact package/install strings are specified in only one place, the
> `GRAPHIFY_PKG`/`GRAPHIFY_INSTALL` variables in `scripts/check-graphify.sh` (detection is `command -v graphify`).

## Audit loop

`/ctx-hallucination-audit [scope]` — repeats HARVEST → VERIFY (graphify first) → SCORE → RECORD → QUARANTINE
→ CAPTURE (→ Linear) until the Hallucination-Free Score is ≥ 87. It never declares itself done while
Score < 87, and when blocked on facts only the user can confirm, it stops and asks. For the rules and the scoring
table, see the original guard rules text.
