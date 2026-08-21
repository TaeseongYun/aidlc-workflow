# Hallucination Ledger

Persistent, **append-only** record of AI hallucinations found by `/ctx-hallucination-audit`.
Read at the start of every session (see `CLAUDE.md` → Hallucination Guard, Rule 1).

- **Quarantine (REFUTED)** entries must never be reused as fact — use the `Correction` only.
- Never delete or overwrite an entry. Status transitions go in the `Status` field.
- Each audit round appends to the Round Log with its Hallucination-Free Score.

## Legend

- **Severity**: `Critical` (path, API sig, type/name, config key, DB field, version, CLI flag,
  security) or `Minor` (naming, non-load-bearing description).
- **Status**: `REFUTED` (proven wrong) → `CORRECTED` (artifact fixed) → `QUARANTINED`
  (locked, never reuse). `UNRESOLVED` = needs user confirmation (loop halts, does not proceed).

---

## Quarantine (REFUTED — never reference again)

<!-- Append entries below. Newest last. Template: -->

<!--
### HAL-001 · {short title}
- **Status**: QUARANTINED
- **Severity**: Critical | Minor
- **Category**: frontend | backend | ios | android | devops
- **Where**: {file:line or artifact path where the claim appeared}
- **Cause** (why the hallucination happened): {e.g. assumed a framework-conventional path
  without reading the router}
- **What** (the exact wrong claim): {verbatim false statement}
- **Fix** (correction + verified source): {correct fact} — verified by {file:line | doc URL}
- **Detected**: round {N}  ·  **Linear**: {issue URL | PENDING-LINEAR}
-->

_(none yet)_

---

## Watchlist (UNVERIFIED / UNRESOLVED — pending)

Claims harvested but not yet confirmed or refuted. `UNRESOLVED` criticals block the score
from reaching 87 — the loop stops and asks the user rather than guessing.

<!--
### WATCH-001 · {short title}
- **Status**: UNVERIFIED | UNRESOLVED
- **Severity**: Critical | Minor
- **Where**: {file:line}
- **Claim**: {the marked assumption}
- **Blocker**: {what would resolve it — read X / user confirmation on Y}
-->

_(none yet)_

---

## Round Log

Each `/ctx-hallucination-audit` round appends one row. The loop repeats until Score ≥ 87.

| Round | Timestamp | Harvested | Refuted | Corrected | Unresolved | Score | Result |
|-------|-----------|-----------|---------|-----------|------------|-------|--------|
| _(none yet)_ | | | | | | | |
