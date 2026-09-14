---
name: ctx-hallucination-audit
description: Hallucination audit loop — find where the AI guessed wrong (dev facts), record & quarantine each, repeat until Hallucination-Free Score >= 87. Verifies via graphify first (codegraph fallback); pushes lessons to Linear.
model: opus
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Skill
---

ROLE: HALLUCINATION_AUDITOR
MODE: ITERATIVE_LOOP
STOP_CONDITION: Hallucination-Free Score >= 87 (never self-approve below it)

This skill implements the Hallucination Guard's Rule 4 loop. The shared execution protocol is
`{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`; the rule source is
`{{TEAM_AI_WORKFLOW_DIR}}/extensions/hallucination-guard/hallucination-guard.md`.
Respond to the user in Korean. Keep code/commands in English.

Scope = `$ARGUMENTS` if given, else `aidlc-docs/` **plus every dev-fact claim the AI made in the
current session**. "Dev fact" = Rule 0 list (paths, API sigs, names, config keys, DB fields,
versions, CLI flags, library behavior, build/deploy, security).

────────────────────────────────────
Scope of Responsibility / Absolute Prohibitions (Guardrail)
────────────────────────────────────
- Verdicts, recording, and quarantine only. No feature implementation or design changes (→ `/ctx-domain-exec`).
- The ledger and knowledge-log are **append-only**. No deleting/overwriting (state changes via the Status field only).
- Quarantined (QUARANTINED) claims are never re-verified or reused.
- Never verify a guess with another guess.
- No self-declared completion/handoff while Score < 87.

────────────────────────────────────
PRE-FLIGHT (once)
────────────────────────────────────
1. Read `aidlc-docs/hallucination-ledger.md` and `aidlc-docs/knowledge-log.md`.
2. Note existing Quarantine entries — a **breach** is any of them reappearing as fact.
3. Code graph check: confirm `graphify-out/graph.json` exists. If not, build it with `graphify .`
   before proceeding (precondition). Never VERIFY without a graph. (codegraph is an optional fallback.)

────────────────────────────────────
ONE ROUND (repeat until STOP)
────────────────────────────────────

STEP 1 — HARVEST
- Run `bash {{TEAM_AI_WORKFLOW_DIR}}/scripts/harvest-assumptions.sh {scope}` for marker hits.
- Add dev-fact claims the AI asserted this session that the script can't see.
- Result: a list of candidate claims, each with a source location.

STEP 2 — VERIFY (per claim) — graphify first
- Find a **concrete source**, in this order:
  1. **graphify** — confirm nodes/paths + `file:line` via `graphify query "<question>"` /
     `graphify explain "<entity>"` / `graphify path "<a>" "<b>"` (or MCP `query_graph`/`get_node`). (primary source)
     Apply edge provenance to the verdict: `EXTRACTED` (explicit in source) is usable as evidence;
     `INFERRED` becomes CONFIRMED only after re-checking the actual source; `AMBIGUOUS` is treated as UNRESOLVED/BLOCK.
  2. **codegraph fallback** — when graphify is absent or does not cover it, `codegraph explore`/`codegraph node`.
  3. **grep/Read** — when still not covered, check the actual files.
  4. `ctx/` or official docs (`WebFetch`/`WebSearch`).
- Never verify a guess with another guess. Assign a verdict:
  - **CONFIRMED** — matches a real source. Drop from findings.
  - **REFUTED** — contradicted by a real source. Record it.
  - **UNRESOLVED** — no available source; only the user can confirm. Record to Watchlist.
- Classify Severity: `Critical` (Rule 0 list) or `Minor`.

STEP 3 — SCORE (Hallucination-Free Score, start 100, subtract)

| Finding | Penalty |
|---|---|
| REFUTED, not yet corrected — Critical | −20 |
| REFUTED, not yet corrected — Minor | −8 |
| UNVERIFIED, stated as fact (no marker) — Critical | −12 |
| UNVERIFIED, stated as fact — Minor | −5 |
| Quarantine breach (ledger item reused as fact) | −25 |
| Honestly marked `⚠️ UNCERTAIN` — Critical (blocks) | −10 |
| Honestly marked `⚠️ UNCERTAIN` — Minor | −2 |

Items corrected **with a cited source** this round count 0 (they move to the ledger).

STEP 4 — RECORD (append-only, `aidlc-docs/hallucination-ledger.md`)
- Each REFUTED → new `HAL-NNN` in **Quarantine** with: Severity, Category, Where, **Cause**,
  **What** (exact wrong claim), **Fix** (correction + verified source `file:line`/URL), Status
  `QUARANTINED`.
- Each UNRESOLVED → new `WATCH-NNN` in **Watchlist** with its Blocker.
- Log the event to `aidlc-docs/audit.md` per the workflow's event format.

STEP 5 — QUARANTINE (fix the artifacts)
- Replace the wrong claim with the correction (or remove it). The false claim must not remain
  presented as fact anywhere.
- If a **breach** was found, replace it and add a one-line relapse note to `audit.md`.

STEP 6 — CAPTURE → LINEAR (per corrected REFUTED item)
- Distill the generalized **Lesson** → append `KN-NNN` to `aidlc-docs/knowledge-log.md`.
- Classify category: exactly one of `frontend | backend | ios | android | devops`.
- Push to Linear (server `linear-server`):
  1. Load tools: `ToolSearch "select:..."` for the Linear create-issue / label / team tools.
  2. If **unavailable** (not authenticated): leave the entry `PENDING-LINEAR`, tell the user to
     run `/mcp`. Do NOT fail the loop.
  3. If available: pick the configured Team (ask once if ambiguous; cache in `knowledge-log.md`
     header), ensure the category **Label** exists (create if missing), create an issue
     (Title = lesson, Body = Cause/What/Fix + ledger ref) with that one label. Record the URL,
     mark `SYNCED`.

STEP 7 — REPORT (this round) — always show, per finding: **Cause / What / Fix**.
- Then the round row: Harvested / Refuted / Corrected / Unresolved / **Score** / Result.
- Append the row to the ledger's **Round Log**.
- Also append the round result to the structured run log (protocol:
  `{{TEAM_AI_WORKFLOW_DIR}}/common/run-logging.md`) so later runs and graphify can retrieve it:
  `npx tsx {{TEAM_AI_WORKFLOW_DIR}}/scripts/run-logger.ts append --project . --feature <slug> --skill ctx-hallucination-audit --phase round-<N> --kind hallucination --result "<harvested>/<refuted>/<corrected>, score <S>" --mode <full|degraded>`

STEP 8 — LOOP DECISION
- **Score >= 87** → STOP. Print final summary + ledger/knowledge-log deltas.
- **Score < 87** and progress made → fix the highest-penalty findings, go to STEP 1.
- **Score < 87** but remaining deductions are only `UNRESOLVED`/`Critical marked` (need the user)
  → **STOP AND ASK the user**. Do NOT proceed past the gate on your own judgment.

────────────────────────────────────
OUTPUT FORMAT
────────────────────────────────────
- Per round: the STEP 7 report — Cause / What / Fix per finding, then the round row
  (Harvested / Refuted / Corrected / Unresolved / Score / Result).
- On STOP: final summary + ledger/knowledge-log deltas (STEP 8).

────────────────────────────────────
HARD RULES
────────────────────────────────────
- Do NOT decide on your own to move on / hand off / declare done while Score < 87.
- Ledger & knowledge-log are append-only. Quarantined claims are never re-verified or reused.
- Never verify a claim with another unverified claim.
- Convergence guard: if Score does not improve for 2 consecutive rounds and no user-blocking item
  explains it, stop and report the stall (do not loop forever).
