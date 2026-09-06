# CI/CD Automation

> Platform-agnostic reference for continuous integration and delivery: what the
> pipeline stages are, which checks gate a merge, how to keep the pipeline fast and
> reproducible, and how to ship and roll back safely.
> Companion procedure: [`../SKILLS.md`](../SKILLS.md).

CI/CD is the automation that carries a commit from a branch to a running system without a
human hand-carrying it. It is a *conveyor with gates*: every change rides the same path,
each gate is a machine check that passes or blocks, and the path is fast enough that
developers trust it rather than route around it. The goal is a change that is correct,
reproducible, and reversible — not a green badge.

---

## CI vs CD vs continuous deployment

Three terms, often conflated. The distinction is *where automation stops*.

| Term | Definition | Human gate |
| :--- | :--------- | :--------- |
| **Continuous Integration (CI)** | Every commit is merged to a shared mainline frequently and automatically built and tested. | Merge decision (review). |
| **Continuous Delivery (CD)** | Every change that passes CI is automatically prepared into a deployable, release-ready artifact. Deployment is one button press. | Deploy-to-prod is a manual approval. |
| **Continuous Deployment** | Every change that passes the pipeline is deployed to production automatically, no human in the loop. | None; gates are all automated. |

You cannot have CD without CI, or continuous deployment without CD. Reach solid CI and
continuous *delivery* first; automated deployment to prod is earned by a trustworthy test
suite and a proven rollback path, not adopted for its own sake.

---

## Pipeline stages

A pipeline is a sequence of stages; a failure in any stage stops the ones after it. Keep
the fast, cheap, high-signal stages first so failures surface in seconds, not minutes.

| Stage | Purpose | Fails when | Typical output |
| :---- | :------ | :--------- | :------------- |
| **Build** | Compile / bundle from a clean checkout. | Won't compile; missing dep. | Build artifact, cached layers |
| **Test** | Unit, integration, e2e. | Any required test red. | Test report, coverage |
| **Scan** | Static analysis, lint, type check, SAST, dependency/secret scan, license check. | Vuln, leaked secret, type error. | Findings report |
| **Package** | Produce the immutable, versioned deployable (image, tarball, binary). | Non-reproducible or unsigned. | Signed, tagged artifact |
| **Deploy** | Promote the artifact into an environment. | Health check / smoke test fails. | Running release + status |

The same artifact flows through every downstream environment — **build once, deploy many.**
Rebuilding per environment reintroduces the "works in staging, breaks in prod" bug the
pipeline exists to eliminate.

---

## Required checks / merge gates

A merge gate must be green before code enters the mainline. Gate on what a machine judges
reliably; leave judgment to review.

| Gate | Enforces | Blocking? |
| :--- | :------- | :-------- |
| Build succeeds | Change compiles from clean. | Yes |
| Required tests pass | No regression on the covered paths. | Yes |
| Lint / format | Style is uniform (formatter-owned, not debated). | Yes |
| Type check | No type errors on typed code. | Yes |
| Security scan | No known-vulnerable deps, no leaked secrets. | Yes |
| Coverage threshold | New code is exercised (a floor, not a target). | Often |
| Human approval | Correctness, design, intent. | Yes |

Offline, hermetic validators make excellent gates: no network, identical on a laptop and in
CI. This repo's `tools/evaluator/validate-*.sh` and `tools/validate-skills.sh` are exactly
that pattern — deterministic checks that fail the pipeline on a malformed artifact, runnable
locally before push.

---

## Fast feedback and pipeline speed

Pipeline speed is a correctness feature: a slow pipeline gets bypassed, and bypassed gates
catch nothing. Target under ~10 min for the merge-gating path.

| Lever | What it does | Cost / caveat |
| :---- | :----------- | :------------ |
| **Caching** | Reuse dependencies, build layers, compiled outputs across runs. | Stale cache hides breakage — key the cache on a content hash, not a branch name. |
| **Parallelism** | Run independent stages/jobs concurrently. | Only true independents; a fake dependency serializes the whole pipeline. |
| **Test splitting** | Shard the suite across runners by timing. | Rebalance shards as the suite grows or one shard dominates. |
| **Fail fast** | Order cheap, high-signal checks first; stop on first failure. | Don't fail-fast a matrix you need full results from (e.g. cross-platform). |
| **Incremental / affected-only** | Build and test only what the change touches. | Needs a correct dependency graph; a wrong one skips a real break. |

Measure before optimizing: find the slowest stage, fix that, re-measure. Optimizing a
non-bottleneck stage adds complexity and buys nothing.

---

## Reproducible and idempotent builds

A build is **reproducible** when the same source yields a byte-equivalent (or at least
behavior-equivalent) artifact anywhere, anytime. Non-reproducible builds make every failure
un-debuggable: you can't tell a code bug from an environment drift.

| Practice | Why |
| :------- | :-- |
| Pin dependency versions (lockfile, committed). | "Latest" changes under you; the build stops being a function of the source. |
| Pin the toolchain (compiler, runtime, base image by digest). | A minor toolchain bump silently changes output or behavior. |
| Build in a clean, isolated environment. | Ambient state on a runner leaks into the artifact. |
| No network at build time where avoidable (vendored / hermetic). | A network fetch makes the build depend on the outside world's mood. |
| Stamp provenance (commit SHA, build time, inputs) into the artifact. | You can trace a running binary back to its exact source. |

**Idempotent** deploy steps are the deploy-side analogue: re-running converges to the same
state instead of stacking side effects. Declarative infra (desired-state, applied
repeatedly) gives idempotency by construction; imperative scripts must be written for it.

---

## Artifact management and versioning

The artifact — not the source branch — is the unit of deployment. Treat it as immutable.

| Rule | Rationale |
| :--- | :-------- |
| Artifacts are immutable once published. | A mutated artifact breaks "deploy the exact thing you tested." |
| Version every artifact uniquely and traceably. | You must name precisely what is in each environment to roll back. |
| Prefer semantic version + build metadata (commit SHA). | Humans read the semver; the SHA is the exact source pointer. |
| Store in a versioned registry with retention. | You need the *previous* good artifact instantly to roll back. |
| Sign and verify artifacts. | Prevents deploying a tampered or wrong build. |

Never let `latest` (a moving tag) into a promotion path — it makes "which version is in
prod?" unanswerable. For the versioning scheme itself, see
[`../release-versioning/reference/guide.md`](../../release-versioning/reference/guide.md).

---

## Environment promotion

A change earns its way to production through progressively more production-like environments.
The *same artifact* is promoted; only config and secrets differ.

| Environment | Purpose | Data | Who gates promotion |
| :---------- | :------ | :--- | :------------------ |
| **dev** | Fast iteration, may be broken. | Synthetic. | Automatic on green build. |
| **staging** | Production-like rehearsal; e2e and smoke. | Prod-like, anonymized. | Automatic or one approval. |
| **prod** | Live traffic. | Real. | Human approval (delivery) or automated (deployment). |

Per-environment config stays *outside* the artifact (env vars, config service) so the same
build runs everywhere — the Twelve-Factor "config in the environment" rule.

---

## Deployment strategies

How the new version replaces the old determines blast radius and rollback speed.

| Strategy | How | Rollback | Trade-off |
| :------- | :-- | :------- | :-------- |
| **Recreate** | Stop old, start new. | Redeploy old. | Simplest; incurs downtime. Fine for jobs and non-critical services. |
| **Rolling** | Replace instances in batches. | Roll the batches back. | No downtime, no extra fleet; mixed versions serve traffic mid-roll. |
| **Blue-green** | Stand up a full new fleet, switch traffic at once. | Flip traffic back instantly. | Instant rollback; needs double the capacity briefly. |
| **Canary** | Route a small % to the new version, watch metrics, ramp up. | Route the % back to zero. | Limits blast radius; needs good metrics and automation to judge the canary. |

Choose by blast-radius tolerance and capacity: recreate for a batch job, rolling as the
default web service, blue-green for instant rollback, canary when a bad release is expensive
and you have the observability to catch it small.

---

## Rollback and forward-fix

Every deploy needs a defined way back. "We'll figure it out if it breaks" is not a rollback
plan.

| Approach | When | Requirement |
| :------- | :--- | :---------- |
| **Rollback** | Fastest path to a known-good state; default for an outage. | Previous artifact retained; deploys are reversible; no one-way migration in the path. |
| **Forward-fix** | The bug is small and rollback is riskier than fixing (e.g. after an irreversible migration). | A fast pipeline — forward-fix is only safe when you can ship a fix in minutes. |

Make schema/data migrations **backward-compatible** (expand-then-contract): the old code
must run against the new schema, so a rollback doesn't corrupt data. This is what makes
rollback safe.

---

## Secrets management in CI

CI runners are a high-value target — they can touch every environment. Treat secrets as
never-in-source, least-privilege, short-lived.

| Rule | Why |
| :--- | :-- |
| Never commit secrets; scan every commit for them. | A leaked secret in history is leaked forever. |
| Inject at runtime from a secrets manager / vault. | Central rotation and audit; no copies scattered in configs. |
| Scope credentials to the job (least privilege, short TTL). | A compromised job can't reach beyond its blast radius. |
| Prefer short-lived OIDC / federated tokens over long-lived keys. | Nothing durable to steal; expires on its own. |
| Mask secrets in logs; forbid `echo`-ing them. | Build logs are widely readable. |
| Guard secrets from untrusted PRs (fork builds). | A malicious PR must not exfiltrate prod credentials. |

---

## Flaky-test handling and quarantine

A flaky test — one that passes and fails on the same code — is worse than no test: it trains
the team to ignore red. Root-cause it; quarantine only to stop the bleeding.

| Step | Action |
| :--- | :----- |
| **Detect** | Track pass/fail history per test; flag ones that fail non-deterministically. |
| **Quarantine** | Move the flaky test out of the merge gate (still run, don't block) so it stops blocking unrelated work. |
| **Ticket** | File the flake with its failure signature — quarantine without a ticket is deletion in disguise. |
| **Root-cause** | Fix the real cause (timing, shared state, order dependence, real race) — not `sleep()` and retry. |
| **Return or delete** | Restore to the gate once stable, or delete it if it tests nothing real. |

A retry-until-green policy on the whole suite is an anti-pattern: it hides real races and
inflates pipeline time. Quarantine is a bounded, tracked exception, not a standing policy.
For what makes a test reliable, see [`../testing-strategy/reference/guide.md`](../../testing-strategy/reference/guide.md).

---

## Branch-protection integration

Merge gates are only real if the platform *enforces* them. Branch protection wires the
pipeline's checks to the merge button.

| Setting | Effect |
| :------ | :----- |
| Require status checks to pass | The gating jobs must be green to merge. |
| Require branch up-to-date | The change is tested against current mainline, not a stale base. |
| Require review approval | A human signs off on correctness/design. |
| Restrict force-push / deletion on mainline | Protects the shared history the pipeline builds on. |
| No bypass (including admins, in spirit) | A gate anyone can skip is not a gate. |

---

## Pipeline observability

You cannot improve or trust a pipeline you can't see. Instrument it like production.

| Signal | Answers |
| :----- | :------ |
| Stage duration & trend | Where is time going? Is the pipeline getting slower? |
| Pass/fail rate per stage | Which gate breaks most? Which is flaky? |
| Queue / wait time | Are runners a bottleneck before work even starts? |
| Deploy frequency & lead time | DORA throughput — how fast does change reach prod? |
| Change-failure rate & MTTR | DORA stability — how often do deploys break, how fast do we recover? |

The four DORA metrics (deploy frequency, lead time for changes, change-failure rate,
time-to-restore) measure the *system*, not individuals — use them to find the bottleneck,
never to rank people.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Manual deploy steps | Un-repeatable; breaks at 3am when the one person who knows is asleep. | Script every step; the pipeline is the only way to deploy. |
| Snowflake runners | Builds pass only on one hand-tuned machine; new runners fail mysteriously. | Ephemeral, declaratively-provisioned runners; disposable and identical. |
| No rollback path | An outage becomes a scramble; forward-fix under pressure ships new bugs. | Retain prior artifacts; keep migrations reversible; test the rollback. |
| Slow pipelines | Developers batch changes or route around gates; feedback loses its value. | Cache, parallelize, split tests; keep the gate under ~10 min. |
| Non-reproducible builds | Can't tell a code bug from environment drift; "works on my machine" forever. | Pin deps and toolchain; build hermetically; stamp provenance. |
| Rebuild per environment | The prod artifact was never the tested one. | Build once, promote the same artifact. |
| Gate on flaky tests | Red is ignored; real failures hide in the noise. | Quarantine and root-cause; never retry-until-green as policy. |

---

## References

- *Continuous Delivery* — Jez Humble & David Farley (deployment pipeline, build once, reproducibility)
- *The Twelve-Factor App* — <https://12factor.net/> (config in the environment, build/release/run separation)
- *Accelerate* — Forsgren, Humble & Kim; DORA metrics — <https://dora.dev/>
- Google SRE Book — release engineering & canarying: <https://sre.google/books/>
- OWASP CI/CD Security — <https://owasp.org/www-project-top-10-ci-cd-security-risks/>
