# Hallucination Guard (ALWAYS ON)

The "vibe blocker": a layer on top of team-ai-workflow that stops the AI's ungrounded guesses from
leaking into artifacts or downstream reasoning as if they were facts. It **consumes, persists, and
quarantines** the uncertainty markers the workflow already produces.

Unlike `extensions/security|performance|api-contract`, this module is **mandatory, not opt-in** — it
is wired into initial project setup and referenced from every project's `CLAUDE.md`, so it applies to
all `ctx-*` skill runs automatically. See `README.md` for how it is wired.

**Grounding substrate:** verification quality is only as good as the source you check against. The
highest-quality source is a **code graph** — `graphify query "<q>"` / `graphify explain "<entity>"` /
`graphify path "<a>" "<b>"` (or the MCP tools) return nodes, call paths, and verbatim `file:line`
locations. That is why `graphify` + a built `graphify-out/graph.json` are **strongly recommended** at
setup (`scripts/check-graphify.sh`); codegraph, if present, is a fallback source. graphify is not
mandatory: when it is absent the guard runs in **degraded mode** — a supported fallback where VERIFY
drops to grep/Read (see `common/graph-grounding.md`) and dev facts are marked `⚠️ UNCERTAIN` more
aggressively, since grep/Read is the failure surface where hallucination is most likely. Prefer the
graph whenever it is available.

---

## Rule 0 — Verify every dev fact, on every prompt

**Whenever a response pulls in development-related information, it MUST be verified for hallucination
before it is stated as fact.** Non-negotiable, no matter how the user phrased the prompt.

"Development-related information" includes: file paths, function/type/class names, API endpoints &
signatures, config keys, env vars, DB schema/fields, CLI flags, version numbers, library/framework
behavior, build/deploy steps, and security-relevant behavior.

For each such claim, before presenting it:
1. Verify against a **concrete source**, in this order of preference:
   - **graphify** — `graphify query "<question>"` / `graphify explain "<entity>"` / `graphify path
     "<a>" "<b>"` (or MCP `query_graph`/`get_node`) for nodes, call paths, and verbatim `file:line`.
     This is the primary source. Weigh edge provenance: `EXTRACTED` is usable evidence; `INFERRED`
     must be re-checked against real source before it is treated as fact; `AMBIGUOUS` → mark UNCERTAIN.
   - **codegraph** — `codegraph explore`/`codegraph node`, if installed, as a fallback graph source.
   - **grep/Read** of the actual code when the graph doesn't cover it (e.g. non-indexed config).
   - project `ctx/` docs, or official upstream docs (`WebFetch`/`WebSearch`).
2. If it cannot be verified, **do not state it as fact**. Mark it `⚠️ UNCERTAIN: … — {why}` and treat
   it as an audit target (Rule 4).
3. **Never verify a guess with another guess.** If the only "source" is your own memory, it is
   unverified. Prefer reading the code (via graphify) over recalling it.

## Rule 1 — Load the ledger first

Before producing any artifact or dev-fact claim (including at the start of any skill run), **read
`aidlc-docs/hallucination-ledger.md`** (the quarantine list). Do not skip it.

## Rule 2 — Quarantine (never reuse a refuted claim)

Any entry in the ledger's **Quarantine (REFUTED)** section:
- MUST NOT be restated, reused, or cited as fact. If the topic comes up, use only the **Correction**
  recorded in the ledger.
- If your reasoning reproduces a quarantined claim, **stop immediately**, replace it with the
  correction, and append a one-line note to `aidlc-docs/audit.md` explaining the relapse.
- A quarantined item is not "unknown" — it is "already proven wrong." Do not re-open it for
  verification; treat the recorded correction as settled.

## Rule 3 — Markers are unverified, not facts

These workflow markers are all **unverified guesses**. Never present them as settled fact:
`⚠️ UNCERTAIN: …`, `[Confidence: Estimated]`, `[Confidence: AI-Recommended]` (legacy `[확신: 추정]` / `[확신: AI추천]`), `⚠️ RISK:`, `⚠️ TODO:`. They are the raw input
for the audit loop (Rule 4). Do not delete them, and do not promote them to fact without user
confirmation or a verified source.

## Rule 4 — The loop (run until score ≥ 87)

Run `/ctx-hallucination-audit` to find "where the AI guessed wrong." The loop:
1. **HARVEST** unverified assumptions (`scripts/harvest-assumptions.sh` + session claims).
2. **VERIFY** each against graphify / code / `ctx/` / docs (Rule 0 order).
3. **SCORE** a Hallucination-Free Score (0–100, rubric below).
4. **RECORD** every refuted claim in the ledger with **Cause / What / Fix**.
5. **QUARANTINE** — remove/correct the claim in the artifacts.
6. **CAPTURE** the lesson to `aidlc-docs/knowledge-log.md`, categorized, and push to Linear.
7. **LOOP** — if score < 87, fix the biggest deductions and repeat from step 1.

**Hallucination-Free Score** (start 100, subtract; ≥ 87 to stop):

| Finding | Penalty |
|---|---|
| REFUTED, not yet corrected — Critical | −20 |
| REFUTED, not yet corrected — Minor | −8 |
| UNVERIFIED, stated as fact (no marker) — Critical | −12 |
| UNVERIFIED, stated as fact — Minor | −5 |
| Quarantine breach (ledger item reused as fact) | −25 |
| Honestly marked `⚠️ UNCERTAIN` — Critical (blocks) | −10 |
| Honestly marked `⚠️ UNCERTAIN` — Minor | −2 |

Corrected-with-source items score 0 (they move to the ledger). *Critical* = anything in the Rule 0
list. Every round must show, per finding: **Cause** (why it happened), **What** (the exact wrong
claim), **Fix** (correction + source `file:line`/URL).

## Rule 5 — Knowledge → Linear (categorized)

When a refuted claim is corrected, the generalized lesson is pushed to **Linear** via the Linear MCP
(server `linear-server`, endpoint `https://mcp.linear.app/mcp`):
- **One Team, category as Label.** Classify each lesson as exactly one of:
  `frontend` / `backend` / `ios` / `android` / `devops`, and apply it as a Linear label.
- If Linear MCP is not yet authenticated, write the lesson to `knowledge-log.md` with status
  `PENDING-LINEAR` and tell the user to run `/mcp`. Push and mark `SYNCED` once available.

### Category routing heuristic

| Category | Signals |
|----------|---------|
| `frontend` | web UI, React/Vue/Svelte, CSS, components, browser APIs, client routing |
| `backend` | server, REST/GraphQL, DB/schema, auth, services, background jobs |
| `ios` | Swift, SwiftUI, UIKit, Xcode, Podfile, `.xcodeproj`, iOS SDK |
| `android` | Kotlin/Java (Android), Gradle, Jetpack/Compose, Android SDK/manifest |
| `devops` | CI/CD, Docker, k8s, Terraform, cloud infra, deploy pipelines, secrets/env |

---

## DO NOT

- **Do NOT decide on your own to move on before the score reaches 87.** No self-approval, no "good
  enough," no handoff while score < 87. If blocked on a fact only the user can confirm, **stop and
  ask** — never proceed past it on your own judgment.
- The ledger and knowledge-log are **append-only** — never delete/overwrite entries (state changes go
  in the Status field only).
- Never verify a claim with another unverified claim.
