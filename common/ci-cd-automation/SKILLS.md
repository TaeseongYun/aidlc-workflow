# CI/CD Automation — Skills

Actionable procedure an agent (or engineer) runs to design, gate, or debug a CI/CD
pipeline. This is the *how*; the *what/why* reference is [`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-score-loop` (build/test axis scoring after implementation).
- **Platform-agnostic**: applies on any CI system. Platform-specific rules live under `platforms/<platform>/`.
- **In-repo example**: this repo's `tools/evaluator/validate-*.sh` and `tools/validate-skills.sh` are offline, hermetic validators used as CI gates — deterministic, network-free, runnable locally before push. See also siblings [`../testing-strategy/reference/guide.md`](../testing-strategy/reference/guide.md) and [`../release-versioning/reference/guide.md`](../release-versioning/reference/guide.md).

## When to use

Designing a new pipeline; adding or tightening a merge gate; making a slow pipeline fast;
making a non-reproducible build reproducible; choosing a deploy strategy; or debugging why
the pipeline is red, flaky, or bypassed.

## Inputs

- The repo and its build/test commands (required). If you can't build and test locally, fix that first.
- Target environments and their promotion order (dev/staging/prod).
- The deploy target and its rollback capability (can you retain and redeploy a prior artifact?).
- Existing pipeline config and recent run history, if any.

## Outputs

- A pipeline definition: ordered stages with explicit merge gates.
- For each gate: what it checks, whether it blocks, and how to run it locally.
- A named deploy strategy and a defined rollback path.
- For a debug task: the root cause and a fix (not a retry or a `sleep`).

## Procedure

1. **State the goal in one line** — new pipeline, add a gate, speed it up, or debug a red
   run. If you can't, stop and ask; you can't build a pipeline against an unknown goal.
2. **Reproduce the build locally** from a clean checkout. If it only builds on one machine,
   that snowflake is the first bug — pin deps and toolchain before anything else.
3. **Order the stages** build → test → scan → package → deploy. Put the cheapest,
   highest-signal checks first so failures surface in seconds.
4. **Define the merge gates** (see guide's gate table). Prefer offline, hermetic checks that
   run identically on a laptop and in CI, like this repo's `validate-*.sh`.
5. **Make the build reproducible** — pinned deps/toolchain, clean environment, provenance
   stamped in. Build once; promote the same artifact through every environment.
6. **Pick a deploy strategy** from the guide's table by blast-radius tolerance and capacity,
   and **define the rollback path** — retained prior artifact, reversible (expand-then-contract) migrations.
7. **Speed pass.** Measure the slowest stage; apply caching / parallelism / test splitting to
   *that* one; re-measure. Target the gating path under ~10 minutes.
8. **Wire branch protection** so the gates actually block merge, and instrument stage timing,
   pass rate, and the DORA metrics.

## Decision rules

- Build isn't reproducible → fix that first; every other finding is unreliable until it is.
- No rollback path → **block** enabling automated deployment; delivery (manual approval) only.
- Irreversible migration in the deploy path → require expand-then-contract, or forward-fix only.
- Merge gate is flaky → quarantine with a ticket; never retry-until-green as policy.
- Gating path over ~10 min → treat as a defect: measure the bottleneck and fix that stage.
- Continuous *deployment* requested but the test suite is thin → stop at continuous *delivery*.

## Stop / escalate

- Deploy touches production data or an irreversible migration → require a human owner's approval.
- Secrets would be exposed to untrusted (fork) PR builds → block until scoped/guarded.
- Rollback path is undefined or untested for a prod-facing change → do not automate the deploy.
- A policy decision (who can bypass gates, retention, prod approval authority) → escalate to a human.

## Output format

```markdown
## Pipeline: <name>  —  goal: <new | add-gate | speed | reproducible | debug>

Build reproducible: <yes/no — deps & toolchain pinned?>

### Stages & gates
- build   — <cmd> — gate: blocking
- test    — <cmd> — gate: blocking
- scan    — <cmd> — gate: blocking (SAST, deps, secrets)
- package — <cmd> — immutable, versioned (semver + SHA)
- deploy  — strategy: <recreate|rolling|blue-green|canary>; rollback: <path>

### Local repro
- <how a dev runs the gating checks before push>

### Findings (for debug/audit)
- [Critical] <what blocks or breaks> — <fix>
- [High]     <slow/flaky/non-reproducible> — <fix>
```

## Quick checklist

- [ ] Goal stated in one line
- [ ] Build reproduces from a clean checkout; deps & toolchain pinned
- [ ] Stages ordered cheap-and-fast first; merge gates defined and blocking
- [ ] Same artifact promoted through every environment (build once)
- [ ] Deploy strategy chosen; rollback path defined and reversible
- [ ] Gating path under ~10 min; bottleneck stage measured, not guessed
- [ ] Secrets injected at runtime, scoped, masked, guarded from fork PRs
- [ ] Flaky tests quarantined with a ticket, not retried-until-green
- [ ] Branch protection enforces the gates; pipeline + DORA metrics instrumented
