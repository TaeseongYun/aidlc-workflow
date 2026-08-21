<!-- workflow-step: post-implementation | producer: ctx-score-loop | EXAMPLE -->
# Dependency Check — book-borrowing

> Walkthrough example. Shows the state after running `/ctx-score-loop book-borrowing`, **completed in 3 rounds (92 points)**.
> Scoring criteria: `core/dependency-score.md`. Procedure: `core/dependency-score-eval.md`.

## Loop Config (using defaults — left blank)

| Parameter | Default | This feature's setting |
|----------|--------|-------------|
| complete_threshold (completion cutoff) | 85 | |
| stall_rounds (stall detection) | 2 | |
| max_rounds (max iterations) | 10 | |
| max_minutes (max time) | 30 | |

---

## 1. Ordering Dependencies Between Features (Functional Order)

| # | Prerequisite | Expected state | Resolved | BLOCK | Rationale | Source |
|---|-----------|-----------|------|-------|------|------|
| F-1 | Member domain exists | Available | ☑ | ☐ | Existing member table/entity confirmed | <!-- src: human --> |
| F-2 | Book domain exists | Includes stock field | ☑ | ☐ | Book.availableCopies field confirmed | <!-- src: human --> |

## 2. Build / Library Dependencies (Build / Library)

| # | Dependency | Expected version/config | Resolved | BLOCK | Rationale | Source |
|---|--------|----------------|------|-------|------|------|
| B-1 | ORM/DB transaction support | Pessimistic lock possible | ☑ | ☐ | SELECT FOR UPDATE support confirmed | <!-- src: auto --> |

## 3. Inter-Module Dependencies (Module)

| # | From → To | Expected contract | Resolved | BLOCK | Rationale | Source |
|---|-----------|-----------|------|-------|------|------|
| M-1 | loan → book | Stock decrement API (atomic) | ☑ | ☐ | Book.decreaseStock() call/implementation confirmed | <!-- src: auto --> |
| M-2 | loan → member | Query member's loan count | ☑ | ☐ | Member.activeLoanCount() confirmed | <!-- src: auto --> |

---

## 4. Current Score (latest round = 3)

| Axis | Weight | Score | Rationale (required) |
|----|------|------|-------------|
| 1. Dependency resolution | 25 | 25 | F-1/F-2/B-1/M-1/M-2 all resolved, 0 BLOCKs |
| 2. Build/compile | 25 | 25 | `gradle build` exit code 0, 0 warnings (per execution log) |
| 3. Tests/coverage | 25 | 20 | Unit/integration 12/12 passing (per report), -5 for 1 concurrency test not written |
| 4. Requirements/AC satisfaction | 25 | 22 | UOW-1~3 acceptance criteria met, -3 for room to improve on 1 FR-6 (duplicate rejection) edge case |
| **Total** | **100** | **92** | |

**Verdict**: COMPLETE (92 > 85 AND build 25 ≠ 0 → GR-1 passed)

---

## 5. Score History (append-only)

| round | total | per_axis (Dep/Build/Test/AC) | verdict | timestamp (UTC) |
|-------|-------|----------------------|---------|-----------------|
| 1 | 75 | 18 / 25 / 12 / 20 | CONTINUE | 2026-06-23T01:30:00Z |
| 2 | 82 | 22 / 25 / 15 / 20 | CONTINUE | 2026-06-23T01:33:00Z |
| 3 | 92 | 25 / 25 / 20 / 22 | COMPLETE | 2026-06-23T01:37:00Z |

> Each round improved the weak axes (tests, AC), climbing 75 → 82 → 92, and round 3 exceeded 85 so it **auto-completed**.
> If round 3 had also stayed at 82 and round 4 was still 82 → it would have stopped and reported as **2 consecutive rounds without improvement = STALLED**.
