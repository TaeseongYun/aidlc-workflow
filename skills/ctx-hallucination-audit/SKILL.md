---
description: Hallucination audit loop — find where the AI guessed wrong (dev facts), record & quarantine each, repeat until Hallucination-Free Score >= 87. Verifies via codegraph first; pushes lessons to Linear.
model: opus
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch, Skill
---

ROLE: HALLUCINATION_AUDITOR
MODE: ITERATIVE_LOOP
STOP_CONDITION: Hallucination-Free Score >= 87 (never self-approve below it)

이 스킬은 Hallucination Guard의 Rule 4 루프를 구현한다. 공통 실행 프로토콜은
`{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`, 규칙 원문은
`{{TEAM_AI_WORKFLOW_DIR}}/extensions/hallucination-guard/hallucination-guard.md`를 따른다.
한국어로 응답하되 코드/명령은 영문 유지.

Scope = `$ARGUMENTS` if given, else `aidlc-docs/` **plus every dev-fact claim the AI made in the
current session**. "Dev fact" = Rule 0 list (paths, API sigs, names, config keys, DB fields,
versions, CLI flags, library behavior, build/deploy, security).

────────────────────────────────────
책임 범위 / 절대 금지 (Guardrail)
────────────────────────────────────
- 판정·기록·격리만 한다. 기능 구현이나 설계 변경은 하지 않는다 (→ `/ctx-run`).
- ledger·knowledge-log는 **append-only**. 삭제/덮어쓰기 금지 (상태 변경은 Status 필드로만).
- 격리(QUARANTINED)된 주장은 재검증·재사용하지 않는다.
- 추측을 다른 추측으로 검증하지 않는다.
- Score < 87에서 스스로 완료/핸드오프 판정 금지.

────────────────────────────────────
PRE-FLIGHT (once)
────────────────────────────────────
1. Read `aidlc-docs/hallucination-ledger.md` and `aidlc-docs/knowledge-log.md`.
2. Note existing Quarantine entries — a **breach** is any of them reappearing as fact.
3. 코드 그래프 확인: `.codegraph/` 인덱스가 있는지 `codegraph status` 로 확인한다. 없으면
   `codegraph init` 후 진행(전제조건). 인덱스 없이 VERIFY하지 않는다.

────────────────────────────────────
ONE ROUND (repeat until STOP)
────────────────────────────────────

STEP 1 — HARVEST
- Run `bash {{TEAM_AI_WORKFLOW_DIR}}/scripts/harvest-assumptions.sh {scope}` for marker hits.
- Add dev-fact claims the AI asserted this session that the script can't see.
- Result: a list of candidate claims, each with a source location.

STEP 2 — VERIFY (per claim) — codegraph first
- Find a **concrete source**, in this order:
  1. **codegraph** — `codegraph explore "<symbols/question>"` 또는 `codegraph node <name>` 로
     verbatim source + caller/callee (`file:line`)를 확인한다. (1차 소스)
  2. **grep/Read** — 그래프가 못 덮는 경우(비인덱스 설정 등) 실제 파일 확인.
  3. `ctx/` 또는 공식 문서 (`WebFetch`/`WebSearch`).
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

STEP 8 — LOOP DECISION
- **Score >= 87** → STOP. Print final summary + ledger/knowledge-log deltas.
- **Score < 87** and progress made → fix the highest-penalty findings, go to STEP 1.
- **Score < 87** but remaining deductions are only `UNRESOLVED`/`Critical marked` (need the user)
  → **STOP AND ASK the user**. Do NOT proceed past the gate on your own judgment.

────────────────────────────────────
HARD RULES
────────────────────────────────────
- Do NOT decide on your own to move on / hand off / declare done while Score < 87.
- Ledger & knowledge-log are append-only. Quarantined claims are never re-verified or reused.
- Never verify a claim with another unverified claim.
- Convergence guard: if Score does not improve for 2 consecutive rounds and no user-blocking item
  explains it, stop and report the stall (do not loop forever).
