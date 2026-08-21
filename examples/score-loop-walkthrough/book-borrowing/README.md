# Walkthrough Example — Book Borrowing

An example that takes **a single feature from start to finish**, from `/ctx-aidlc-run` (requirements analysis) through `/ctx-score-loop` (dependency-aware score loop).
So that anyone can follow this flow exactly, it shows what you input and what comes out at each step.

> This is a **documentation example**. There is no actual code — it shows the outputs and the loop's progression in prose.
> In a real project, you just run the same commands against your own codebase.

## Fictional Scenario

- Project: a small library backend (fictional)
- Request: **"Let members borrow books. If stock is available, lend it out; up to 3 books per person, with a 14-day loan period."**
- Classification: prepared-requirement (the requirements are relatively clear)
- Depth: standard (single domain, 1–2 design decisions)

## Order of Steps

| Step | Command | Output | This example's file |
|------|------|--------|-------------|
| 1 | `/ctx-aidlc-run` | Requirements/questions/UOW analysis | `requirements.md`, `requirement-verification-questions.md`, `unit-of-work.md`, `status.md` |
| 2 | (implementation) | Write actual code after passing GATE-3 | (omitted in this example — fictional) |
| 3 | `/ctx-score-loop` | Automatic repeated scoring of dependencies/4 axes | `dependency-check.md` (per-round changes) |

## Step 1 — `/ctx-aidlc-run` (requirements analysis)

Input:
```
/ctx-aidlc-run

Let members borrow books.
If stock is available, lend it out; up to 3 books per person, with a 14-day loan period.
```

Key flow:
- Classified as prepared-requirement → input validation → question generation (1–2 BLOCKs) → GATE-2 → UOW decomposition → GATE-3.
- For the outputs, see `requirements.md`, `requirement-verification-questions.md`, `unit-of-work.md`, and `status.md` in the same directory.

The key point is how the **question** raised in this step (e.g., "what if a member tries to borrow a book they already have on loan?") gets caught as a BLOCK and answered.

## Step 2 — Implementation (fictional)

After passing GATE-3, write actual code in UOW order. In this example the code is omitted, and we assume a situation where the 3-round score loop scores the "implemented code".

## Step 3 — `/ctx-score-loop` (dependency-aware score loop)

Input (just once):
```
/ctx-score-loop book-borrowing
```

Then, without the user requesting "verify it" each time, the loop repeats **implement → score → improve** on its own.

- It uses the dependency checklist in `dependency-check.md` as scoring input.
- It scores the 4 axes (dependency/build/test/AC, 25 points each) every round.
- When it **exceeds 85 points (`> 85`)**, it reports completion and ends.
- On 2 consecutive rounds without improvement (stall) / 10 rounds or 30 min (cap) / a score drop (regression), it immediately stops and reports.

Looking at how the **Score History** table in `dependency-check.md` fills in per round gives you an at-a-glance view of the loop's behavior.

For detailed per-round progress, see `LOOP-RUN.md`.

## Follow Along (Quick Start)

```bash
# 0. Install framework skills (once, first time)
bash scripts/install-skills.sh

# 1. Analyze requirements in your own project
/ctx-aidlc-run
> "Let members borrow books. ..."

# 2. Proceed with GATE approvals → implementation

# 3. After implementation, run the score loop once
/ctx-score-loop book-borrowing
> Auto-repeats until over 85 points. Stops and reports on stall/cap.
```
