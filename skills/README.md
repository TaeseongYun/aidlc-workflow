# Skills

This directory is the source repository for the team's shared Codex skills.

## Principles
- The files here are the source of the team's shared skills.
- The global execution path is `~/.codex/skills/`.
- The Claude global path is `~/.claude/commands/`.
- Do not edit the global skills/commands directly; edit them here and then deploy with the install script.
- All skills follow the common execution protocol in `_shared/skill-protocol.md`.

## Included Skills
- `ctx-aidlc-roadmap`
  - For Phase 0 multi-feature roadmapping (decompose a large prepared planning document by feature)
  - Output: `aidlc-docs/_roadmap.md`. After passing GATE-0, enter `ctx-aidlc-run` per feature.
- `ctx-worktree`
  - Plans and creates one isolated git worktree per parallel-safe roadmap feature
  - Always shows the target paths and waits for approval before creation
- `ctx-aidlc-run`
  - For requirements/design analysis
  - Uses the `team-ai-workflow + ctx + aidlc-docs` flow
- `ctx-architect-judge`
  - Requirement/impact scope judgment
- `ctx-domain-exec`
  - Domain implementation execution
- `ctx-reviewer`
  - CTX-based review
- `ctx-updater`
  - CTX update
- `ctx-refiner`
  - CTX refinement
- `ctx-commit-planner`
  - Commit separation planning
- `ctx-aidlc-sync`
  - One-shot content-level sync with upstream AWS AI-DLC (`awslabs/aidlc-workflows`)
  - Dispositions upstream changes via `docs/methodology-references.md` (PORT/SKIP/ESCALATE),
    works in a git worktree branch, and opens a PR only when the 4-axis sync score exceeds 90
- `mobile-webview-bridge`
  - JS ↔ native WebView bridge for Android / iOS / KMP / React Native / Flutter
  - One shared protocol (envelope, handshake, security, threading, lifecycle) +
    per-platform reference bindings; generator mode (scaffold from a message
    contract) and guard mode (severity-rated review checklist)
  - Offline envelope validator: `scripts/validate_envelope.py`
- `ctx-hallucination-audit`
  - Hallucination Guard audit loop. Verifies dev facts with graphify (codegraph
    fallback), isolates refuted items in the ledger, repeats until the
    Hallucination-Free Score is at least 87, and pushes lessons learned to Linear.
  - Rule source: `extensions/hallucination-guard/hallucination-guard.md`.
    Prerequisite: graphify (codegraph is an optional fallback).

## Installation

```bash
bash scripts/install-skills.sh
```

## Update Procedure
1. Edit the source under `skills/`
2. If needed, update `README.md` or the usage examples
3. Run `bash scripts/install-skills.sh`
4. Verify operation in the global `~/.codex/skills/`
5. Verify operation in the global `~/.claude/commands/`

## Recommended Usage Flow

### Single Feature
1. Requirements analysis: `/ctx-aidlc-run`
2. Reflect human approval/answers
3. Implementation execution: `/ctx-domain-exec` (or an OMC/Ouroboros handoff)

### Multi-feature (large prepared planning document)
1. Roadmap: `/ctx-aidlc-roadmap` → generate `aidlc-docs/_roadmap.md`, approve GATE-0
2. Optional isolated allocation: `/ctx-worktree` → approve the detected worktree plan
3. Each team member runs `/ctx-aidlc-run` for their own feature (input: the excerpt of the relevant section from the source)
4. Reflect human approval/answers
5. Implementation execution: `/ctx-domain-exec` (per feature, or an OMC/Ouroboros handoff)

Detailed operating procedure: `docs/multi-feature-coordination.md`
