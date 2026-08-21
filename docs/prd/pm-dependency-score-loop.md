# PM — Dependency-Aware Score Loop

> Product Requirements Document
> Created: 2026-06-23 · Target project: `aidlc-workflow`
> Authoring method: `/ouroboros:pm` Socratic interview (equivalent output written by hand due to a PM MCP environment issue)

---

## 1. Elevator Pitch

With just "a single request to implement code," add a loop-engineering feature to aidlc-workflow that **automatically and repeatedly scores** dependencies and multiple verification axes, and **fully terminates only once it clears 85 out of 100 points**. The user does not need to repeatedly ask "verify it" every time.

---

## 2. Problem

### 2-1. Current State

aidlc-workflow is a workflow responsible for **"what to build (What)."** The following assets already exist.

- `core/readiness-score.md` — scores the requirements readiness **before** implementation out of 100 (80 points = READY). **It is not for post-implementation verification; a human produces it once, just before passing a GATE.**
- `templates/component-dependency.md` — a dependency matrix template between components (includes circular-dependency checks).
- `docs/stop-conditions.md` — a GATE/score-based STOP decision tree (all gates **before entering implementation**).
- `docs/omc-ouroboros-integration.md` — **"how to run it automatically (How)"** is **delegated externally** to OMC `ralph`/`autopilot` or Ouroboros `evolve`.

### 2-2. Gap

| Dimension | Current | What's needed |
|------|------|-------------|
| When the score is produced | Once **before** implementation (readiness-score) | Repeatedly and automatically **after** implementation |
| Score axes | 6–8 areas of requirements readiness | 4 axes: **dependency resolution / build / test / AC satisfaction** |
| Dependencies | Design-stage matrix (written once) | A verification md **resident** in each feature/module, repeatedly scoring whether it's resolved |
| Termination decision | Human GATE approval | **Automatic termination when over 85 points**, automatic stop when the score stalls |
| Trigger | Human requests verification every time | The loop iterates autonomously from **a single implementation request** |

> External tools (ralph/evolve) use only "does the UOW Verification command pass" as their termination condition. The concept of a **multi-axis score based on a dependency md → automatic completion at the 85-point threshold** exists nowhere in the workflow. This PRD fills that gap.

### 2-3. User Pain

- After implementation, the user has to manually request "are all the dependencies done?", "verify again" every round → **tedious, and consistency breaks down.**
- "How far along it is" is subjective → **you cannot state completion as an objective number.**
- Dependencies come in several kinds (feature ordering / build·library / inter-module), yet there is **no mechanism to trace at a glance where it's blocked.**

---

## 3. Goals & Non-Goals

### 3-1. Goals

1. Place a verification md file **inside each feature/module directory** that needs dependencies (distributed placement, not a central collection).
2. Automatically score **4-axis / 100-point** verification based on that md.
3. Judge "fully terminated (complete)" **only when over 85 points**, and notify the user with the result.
4. Re-verify **repeatedly** from right after implementation, and **compare against the previous score**.
5. Run the entire loop above autonomously from **a single implementation request** (no additional user intervention needed).
6. If the score **stalls (no improvement)**, automatically stop and report to the user.

### 3-2. Non-Goals (out of scope this time)

- **Automatically passing GATEs (human approval)** — GATE-0~5 are still passed only by humans. This loop operates only in the segment **after GATE-3 (implementation approval)**.
- Changing the **pre-implementation** readiness-score (requirements readiness) logic — leave it as is. This loop is a **separate post-implementation score**.
- Writing a new execution engine — the loop itself is **delegated** to the existing OMC `ralph`/Ouroboros `evolve` or the Claude Code native loop, and this feature is a **"score rubric + md convention + termination decision"** layer on top of it.
- Automatically deciding business policy (refunds/settlement/permissions, etc.) — an undecided policy is still a STOP condition.

---

## 4. Personas & Scenarios

### 4-1. Primary Users

- **Solo developer** — wants to request an S/M-sized feature once and have the loop take it up to 85 points on its own.
- **Team lead** — when multiple features run in parallel, wants to grasp completion status objectively via each feature's "current score."

### 4-2. Core Scenarios

**S1 — One request, all the way to automatic completion**
1. User: "Implement this feature" (just once).
2. System: implement → create/update the dependency md → 4-axis scoring → record the score.
3. If 85 or below: implement to fill the lacking axis → re-score (repeat).
4. Over 85: report **"Complete (broke past 85 points)"** to the user as the result and terminate.

**S2 — Stopping due to a stalled score**
1. During repeated scoring, the score fails to rise N times in a row (e.g., one dependency axis blocked by an external factor).
2. System: stop the loop → report to the user with the cause, e.g., **"Stalled at 82 points. Blocked axis: inter-module dependency (core-network API not deployed)."**

**S3 — Tracking multiple kinds of dependencies**
1. One feature depends on three things: (a) a prerequisite feature being complete, (b) the `retrofit` build dependency, (c) the `core-network` module API.
2. Each item exists as a check item in the feature directory's dependency md.
3. During scoring, the score breakdown reveals which item is unresolved.

### 4-3. Edge Cases

- A dependency item can be permanently unresolvable due to an **external factor (e.g., another team's PR not yet merged)** → stall-stop + report with an explicit reason (no infinite loop).
- When the score **drops** (a regression occurs) → detect the drop versus the previous round and warn (for v1, only report on rollback; automatic rollback is a future consideration).
- When over 85 points but a specific **required axis is 0** (e.g., build is 0 but the score breaks 85 on other axes) → **a gating rule is needed** (see 6-3 below).

---

## 5. Core Concepts

### 5-1. Dependency Verification Doc

- **Location**: **inside each feature/module directory** that needs dependencies (e.g., `aidlc-docs/features/<slug>/dependency-check.md` or inside the module folder).
- **Content**: holds the items that location depends on as a checklist, classified into 3 kinds.
  - **Feature ordering** — e.g., "the login feature must be in `completed` state."
  - **Build/library dependencies** — e.g., "`retrofit`, `hilt`, `compose-bom` versions set and build passes."
  - **Inter-module dependencies** — e.g., "`feature-A` correctly calls/implements API X of `core-network`."
- **State**: each item records whether it's resolved (+evidence). This becomes the input to scoring.

### 5-2. 4-Axis Score Rubric (100 points)

| Axis | Meaning | Note |
|----|------|------|
| **Dependency resolution** | Are all dependency items in the md above satisfied | Sum of the 3 kinds of dependencies |
| **Build/compile pass** | Does the code actually build with no compile errors | Objectively checkable |
| **Test pass / coverage** | Do the relevant tests pass and is coverage above the bar | Objectively checkable |
| **Requirements / AC satisfaction** | Are the originally intended Acceptance Criteria satisfied | Based on requirements/UOW |

- **Point allocation per axis: 25 / 25 / 25 / 25 (confirmed)**. Dependency 25 · Build 25 · Test 25 · AC 25.
- **Scoring authority**: **LLM self-scoring (autonomous)**. However, for the build and test axes, the LLM is forced to score based on command execution results (objective signals) (to prevent hallucination).

### 5-3. Score-Gated Termination

- **Completion condition**: `score > 85` → judged "fully terminated (complete)," report the result, then terminate the loop.
- **Stop condition**: if the score does not improve **2 rounds in a row (confirmed)** → judged stalled, stop + report the cause.
- **Safeguard (confirmed)**: stop at whichever comes first, **10 iterations or 30 minutes** max (prevents infinite loops).

---

## 6. Requirements

### 6-1. Functional Requirements

- **FR-1** The system creates/updates a dependency verification md in each feature/module directory that needs dependencies.
- **FR-2** The dependency md holds the 3 kinds of dependencies (feature ordering / build·library / inter-module), classified as check items.
- **FR-3** The system produces a 100-point score across 4 axes (dependency/build/test/AC).
- **FR-4** The build and test axes are scored based on actual command execution results (LLM-only estimation prohibited).
- **FR-5** The system records the score each round and compares it against the previous round.
- **FR-6** If `score > 85`, it judges "complete," reports the result to the user, and then terminates.
- **FR-7** If the score stalls (no improvement N times in a row), it stops the loop and reports the blocked axis/item to the user.
- **FR-8** From a single implementation request, the entire loop above iterates autonomously with no additional user intervention.
- **FR-9** The loop operates only in the segment after GATE-3 (implementation approval) is passed, and does not automatically pass GATEs.

### 6-2. Decisions Humans Must Confirm (Open Items / Decide-Later)

> All Open Items have been confirmed with default values (user approval complete). Use them as-is in the requirements stage.

- ~~**OI-1 (point allocation)**~~ → **Confirmed: 25/25/25/25** (dependency/build/test/AC evenly).
- ~~**OI-2 (stall decision N)**~~ → **Confirmed: stalled when no improvement 2 rounds in a row**.
- ~~**OI-3 (cap)**~~ → **Confirmed: 10 iterations or 30 minutes max** (stop at whichever comes first, prevents infinite loops).
- ~~**OI-4 (behavior on regression)**~~ → **Confirmed: v1 reports only** (warn on detecting a score drop, no automatic rollback).
- ~~**(execution engine)**~~ → **Confirmed: OMC `ralph` by default** (suits S/M features, reuses the `omc-ouroboros-integration.md` §2-2 handoff path). Can be replaced with Ouroboros `evolve` when there is a strong measurable goal.

### 6-3. Gating Rules (Required)

- **GR-1** Even if it breaks 85 points, **do not judge it complete if the build axis is 0** (do not call build-failing code "complete" — consistent with the project rule "do not commit with the build broken").
- **GR-2** If there is even one unresolved dependency classified as BLOCK, cap the dependency axis at a ceiling score (same philosophy as the readiness-score BLOCK rule).

### 6-4. Non-Functional Requirements (NFR)

- **NFR-1 (conflict avoidance)** Follow the state-directory separation rule — do not overwrite `aidlc-docs/`(SoT), `.omc/state/`, `.ouroboros/` (`omc-ouroboros-integration.md` §4-1).
- **NFR-2 (audit append-only)** When recording loop events in the audit, distinguish them with a prefix like `[LOOP]`, without modifying existing entries.
- **NFR-3 (transparency)** Do not write scores as numbers alone; record them **with evidence** (inherits the readiness-score rule).
- **NFR-4 (honest termination)** Report "complete" only when verification passes. If a test fails/is skipped, state that fact explicitly.

---

## 7. Delivery Form

> Interview decision: **mixed — extend the existing loop + a standalone slash command (1+2)**.

- **A. Extend the existing loop** — inject the "dependency md + 4-axis score + 85-threshold termination" convention into the ralph/autopilot/evolve handoff prompts in `omc-ouroboros-integration.md`. That is, make ralph's termination condition extendable from "UOW Verification passes" to a **dependency-aware 4-axis score > 85**.
- **B. Standalone slash command** — a reusable command callable from any project (tentatively e.g. `/ctx-score-loop` or `/score-loop`). On its own it performs dependency md creation → scoring → loop → report.

### 7-1. New/Changed Outputs (expected)

- `core/dependency-score.md` (new) — defines the 4-axis 100-point rubric + gating rules (sibling document to readiness-score).
- `core/dependency-score.schema.yaml` (new) — a schema for programmatic scoring.
- `templates/dependency-check.md` (new) — the dependency verification md template resident in a feature/module (3-kind dependency checklist + score table).
- `docs/score-loop-guide.md` (new) — a guide to loop operation / termination conditions / handoff.
- `docs/omc-ouroboros-integration.md` (changed) — add the score-loop termination condition to the ralph/evolve handoff.
- `templates/feature-status.md` (changed) — add a post-implementation score tracking row.
- Slash command skill (new) — `skills/<name>/` + `scripts/install-skills.sh` registration.

---

## 8. Success Metrics

- The rate at which the user reaches completion with **1** implementation request and **0** additional "verify it" requests.
- Outputs reported as "complete" actually pass build/test (0 false completions).
- The rate — 100% — at which stalls/regressions are always reported to the user with a reason, **rather than silently looping infinitely**.

---

## 9. Risks

| Risk | Impact | Response |
|--------|------|------|
| Subjectivity/hallucination of LLM autonomous scoring (score inflation) | "False completion" | Force actual command results for the build·test axes (FR-4), mandatory evidence recording (NFR-3), gating rules (GR-1) |
| Infinite loop / undetected stall | Wasted resources | Stall decision N times + max iteration/time cap (OI-2,3) |
| Permanently unresolved due to an external-factor dependency (another team's PR not merged) | Never reaches 85 | Stop + report explicit reason (S2), BLOCK classification (GR-2) |
| State-directory conflict (concurrent use of OMC/Ouroboros) | Data corruption | Follow directory separation · append-only (NFR-1,2) |
| Broke 85 points but a core axis is below bar | Quality disguised | Block completion via gating rule when a required axis is 0 (GR-1) |

---

## 10. Open Questions Summary (→ confirmed in the next step)

> **All core decisions are confirmed.** What remains is only the detailed naming in the implementation stage.

1. ✅ ~~4-axis point allocation~~ — **Confirmed: 25/25/25/25**
2. ✅ ~~consecutive count N for stall decision~~ — **Confirmed: 2 rounds**
3. ✅ ~~max iteration/time cap~~ — **Confirmed: 10 iterations or 30 minutes**
4. ✅ ~~behavior on regression~~ — **Confirmed: v1 reports only (no automatic rollback)**
5. ✅ ~~score-loop execution engine~~ — **Confirmed: OMC `ralph` by default**
6. Final name of the slash command (`/ctx-score-loop`, etc.) — confirmed in the implementation stage (out of PM scope)

---

## 11. Next Step

This PM document defines the **What**. To descend to an actually implementable Seed/requirements:

1. Run a **requirements interview** with this PM document as input (`/ctx-aidlc-run` or `ooo interview`).
2. Have a human confirm the Open Items above (OI-1~4) at a GATE.
3. Proceed in the order requirements.md → unit-of-work.md → (score-loop handoff prompt).
