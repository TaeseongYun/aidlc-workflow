# Multi-Feature Coordination Guide

An operations guide for resolving, in advance, the duplication, upstream ordering, and conflicts that arise when a team divides work as a large prepared planning document naturally decomposes into **multiple features**.

Not applied to single-feature work. For a single feature, enter `/ctx-aidlc-run` directly.

## 1. When is Phase 0 needed

Do Phase 0 (Roadmapping) first if any of the following applies.

- The planning document explicitly lists 2 or more features
- The planning document covers ≥3 independent domains (e.g., payment + notification + settlement)
- Multiple tasks touch the same component/table/module simultaneously
- The team has agreed to divide the work and needs to decide who handles what

If the signal is ambiguous, run `/ctx-aidlc-roadmap` first and get the single/multiple verdict at STEP R1.

## 2. Entry paths (bidirectional)

### 2-1. Direct call
Right after receiving a large planning document:

```text
/ctx-aidlc-roadmap

Write a Phase 0 roadmap from the following prepared-requirement planning document.
- Source: <planning document path or body>
- depth level: standard
```

### 2-2. Handoff (blocked after detection)
When the user runs `/ctx-aidlc-run` first without knowing it is multi-feature:

1. Answer "multiple" in the first round of STEP 1-A ("Is this a single feature or multiple independent features?")
2. If `_roadmap.md` is missing, `ctx-aidlc-run` STOPs and advises `/ctx-aidlc-roadmap`
3. Record a `[HANDOFF] ctx-aidlc-run → ctx-aidlc-roadmap` event in `audit.md`
4. The user proceeds with Phase 0 using the advised command

## 3. Interpreting Phase 0 outputs

Running `/ctx-aidlc-roadmap` generates `aidlc-docs/_roadmap.md`. The key sections are as follows.

| Section | Meaning | Use when dividing work |
|------|------|-------------|
| 2. Feature List | feature slug + one-line responsibility | Unit of assignee allocation |
| 3. Resource Matrix | per-feature occupancy of components/tables/APIs | ⚠ marks a possible conflict |
| 4. Dependency Graph | inter-feature dependency + Resolution | Serial/parallel decision |
| 5. Allocation Recommendation | execution Phase grouping + role recommendation | Who starts when |
| 6. Handoff Plan | per-feature input excerpt + `/ctx-aidlc-run` call guidance | Execution after division |

The following areas of `aidlc-state.md` are also synced:
- Roadmap State
- Feature Index (Roadmap Source column)
- Cross-Feature Dependencies

## 4. Work-split patterns

### 4-1. Foundation-First (recommended default)

Extract common domain models·tables·base modules into a `foundation-*` feature and have **one person go first**. The remaining features proceed in parallel on top of it.

```
Phase 1 (serial): foundation-domain-model
Phase 2 (parallel): feature-a, feature-b, feature-c
Phase 3 (serial): feature-d (← needs feature-b's output)
```

Advantage: minimized merge conflicts, a consistent domain model.
Cost: other teammates wait during Phase 1.

### 4-2. Vertical Slice

Split each feature end-to-end vertically. Minimize the common base and have each feature own its own components.

Advantage: fully parallel, fast feedback.
Cost: later commonization work may be needed.
Condition: only when coupling between domains is very weak.

### 4-3. Sequential

When dependencies are strong and parallelization is hard, run serially. The value of Phase 0 lies in clarifying "how far it must be serialized."

## 5. Conflict resolution procedure

### 5-1. Resource duplication (⚠)
Two or more features try to build the same component.
- **Extract**: create a new `foundation-*` feature and change both to depend on it
- **Single-owner assignment**: one feature builds it and other features use it read-only
- **When separation is impossible**: merge the two features into one

### 5-2. Policy conflict
Different features hold different assumptions about the same policy (e.g., refund rules).
- Promote the policy to a `ctx/` global rule to make it a single source
- Ensure the same question is not repeated at each feature's STEP 4

### 5-3. Cyclic dependency
If a form feature A → B → A is found, do not pass GATE-0.
- Change the feature split
- Reverse the dependency direction (decouple via events)
- Extract the common part

## 6. Per-feature `/ctx-aidlc-run` execution

After GATE-0 approval, each teammate, for their own feature:

```text
/ctx-aidlc-run

Start the F-2(<slug>) task based on the Phase 0 roadmap.
- Input: prepared-requirement (source §3.2 ~ §3.4)
- Depends on: aidlc-docs/features/foundation-domain-model/requirements.md
- Read aidlc-docs/_roadmap.md first.
```

`ctx-aidlc-run` reads `_roadmap.md` in BOOTSTRAP, verifies at STEP 1 that the slug is in the roadmap, and then cites the dependencies and shared resources in the "Roadmap Context" section of `status.md`.

When parallel-safe features should use isolated branches and directories, run
`/ctx-worktree` after GATE-0 approval. It reads the allocation phase from
`_roadmap.md`, shows the proposed paths and branches, and creates them only after
explicit approval. See [Worktree Mode](worktree-mode.md).

## 7. Frequently asked questions

**Q. It's a single feature but a large planning document. Do I have to do Phase 0?**
A. No. If STEP R1 judges it a single feature, all R-steps are skipped as `[-]`, and you get guidance to use `/ctx-aidlc-run` directly.

**Q. What if a new feature is added after making the roadmap?**
A. Re-run `/ctx-aidlc-roadmap` to update `_roadmap.md` and `aidlc-state.md`, then re-obtain GATE-0. Existing feature folders are unaffected.

**Q. What if I run ctx-aidlc-run with a slug not in the roadmap?**
A. ctx-aidlc-run warns and asks the user to choose one of (a) add to the roadmap (b) proceed standalone (c) abort. The answer is recorded in audit.md.

**Q. May a human edit the Phase 0 result directly?**
A. Yes. But before GATE-0 approval, it is safer to re-run from the relevant R-step. Changes after approval record an additional GATE-0 round in audit.md along with the reason for the change.
