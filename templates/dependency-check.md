<!-- workflow-step: post-implementation | producer: ctx-score-loop | location: feature/module directory | append-only-history -->
# Dependency Check — {feature-slug or module name}

Place this file **inside each feature/module directory** that needs dependencies (distributed placement, not a central collection).
Recommended path example: `aidlc-docs/features/<feature-slug>/dependency-check.md` or inside the corresponding module folder.

`/ctx-score-loop` reads this file and scores it on 4 axes. Scoring criteria: `core/dependency-score.md`.

> **Merge rule**: determine the automatic-update scope from the source marker at the end of an item.
> - `<!-- src: human -->` — written by a human. The loop **only reads** it; it never modifies/deletes it.
> - `<!-- src: auto -->` — created/updated by the loop. Subject to automatic merge.
> - If there is no marker, treat it as human and preserve it.

---

## Loop Config (optional — override defaults)

Write this only when changing the defaults. If left empty, the defaults in `core/dependency-score.schema.yaml` are used.

| Parameter | Default | This Feature's Setting |
|----------|--------|-------------|
| complete_threshold (exceed criterion) | 85 | |
| stall_rounds (stall determination) | 2 | |
| max_rounds (max iterations) | 10 | |
| max_minutes (max time) | 30 | |

---

## 1. Inter-Feature Ordering Dependencies (Functional Order)

Other features/tasks that must come first. If not satisfied, this is reflected in the dependency axis score.

| # | Prerequisite Item | Expected State | Resolved | BLOCK | Rationale | Source |
|---|-----------|-----------|------|-------|------|------|
| F-1 | {e.g. login feature} | completed | ☐ | ☐ | | <!-- src: human --> |

## 2. Build / Library Dependencies (Build / Library)

Build-level dependencies such as Gradle and library configuration.

| # | Dependency | Expected Version/Config | Resolved | BLOCK | Rationale | Source |
|---|--------|----------------|------|-------|------|------|
| B-1 | {e.g. retrofit} | {version} + build passes | ☐ | ☐ | | <!-- src: human --> |

## 3. Inter-Module Dependencies (Module)

Whether another module's API is called/implemented correctly.

| # | From → To | Expected Contract | Resolved | BLOCK | Rationale | Source |
|---|-----------|-----------|------|-------|------|------|
| M-1 | {e.g. feature-A → core-network} | call/implement API X | ☐ | ☐ | | <!-- src: human --> |

---

## 4. Current Score (latest round)

Scoring criteria: `core/dependency-score.md` (4 axes · 25 points each). **The build and test axes are grounded only in actual command execution results. Score 0 if not executed.**

| Axis | Points | Score | Rationale (required) |
|----|------|------|-------------|
| 1. Dependency resolution | 25 | | (max 12 if a BLOCK dependency exists — GR-2) |
| 2. Build/compile | 25 | | (cite build command exit code/log) |
| 3. Test/coverage | 25 | | (cite test report) |
| 4. Requirements/AC satisfaction | 25 | | (based on UOW acceptance criteria + requirements FR) |
| **Total** | **100** | | |

**Verdict**: COMPLETE (>85 & build≠0) / INCOMPLETE

---

## 5. Score History (append-only)

Add 1 row every round. Used for stall (2 consecutive rounds without improvement) and regression (decline) determination. Do not modify existing rows.

| round | total | per_axis (dep/build/test/AC) | verdict | timestamp (UTC) |
|-------|-------|----------------------|---------|-----------------|
| 1 | | / / / | CONTINUE / COMPLETE / STALLED / EXHAUSTED / REGRESSED | |

verdict values:
- `CONTINUE` — incomplete, proceed to next round
- `COMPLETE` — over 85 & build≠0, finished
- `STALLED` — 2 consecutive rounds without improvement, halt and report
- `EXHAUSTED` — max iterations/time reached, halt and report
- `REGRESSED` — declined versus previous, warn and report (no automatic rollback in v1)
