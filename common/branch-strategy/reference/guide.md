# Branch Strategy

> Platform-agnostic reference for how work is branched, integrated, and released: the main
> models, when each fits, naming, protection, and where branches help versus where they rot.
> Companion procedure: [`../SKILLS.md`](../SKILLS.md).

A branch strategy is the team's agreement on how code diverges from the mainline and how it
comes back. It is not a style preference: it decides how often you integrate, how large your
merge conflicts get, and how fast you can ship or roll back. The through-line of every model
below is one principle — **integrate often, in small reversible steps** — and the models
differ mainly in how much ceremony they add around that.

---

## Core principle

The cost of merging two lines of work grows super-linearly with how long they diverge. A
branch that lives a day conflicts with a line or two; a branch that lives three weeks
conflicts with a subsystem someone else rewrote meanwhile. Every model here is a way to keep
divergence short and integration cheap. When a strategy fights that principle (long-lived
branches, big-bang merges), the strategy is wrong, not the merge.

| Lever | Short-lived branches | Long-lived branches |
| :---- | :------------------- | :------------------ |
| Merge conflict size | Small, local | Large, cross-cutting |
| Time to find a regression | Hours (small delta) | Days (huge delta) |
| Rollback granularity | One small change | An entangled batch |
| Review size | Reviewable (see code-review guide) | Skimmed, not reviewed |
| Integration feedback | Continuous | Deferred until "done" |

---

## The main models compared

| Model | How it works | Best for | Trade-offs |
| :---- | :----------- | :------- | :--------- |
| **Trunk-based development** | Everyone commits to `main` (or via <1-day branches); incomplete work hidden behind feature flags. | Teams with strong CI and continuous delivery; high-throughput repos. | Demands fast, reliable CI and flag discipline; broken `main` blocks everyone. |
| **GitHub Flow** | One `main`; each change is a short-lived branch → PR → review → merge → deploy. | Web apps / services deploying continuously from `main`. | No release isolation; needs flags or forward-fixes for staged rollout. |
| **GitFlow** | Long-lived `main` + `develop`, plus `feature/*`, `release/*`, `hotfix/*`. | Versioned/packaged software with scheduled releases and multiple supported versions. | Heavy; `develop`↔`main` divergence causes painful merges; overkill for CD. |
| **Release-branch (train)** | Trunk plus a `release/x.y` cut per version; fixes cherry-picked back. | Products shipping discrete versions (mobile, on-prem, firmware). | Cherry-pick overhead; must track what landed where. |

Default recommendation: **trunk-based development or GitHub Flow** for anything you deploy
continuously. Reach for release branches only when you genuinely ship versions you must
support in parallel. GitFlow is rarely the right answer for a service in 2020s CD — its
`develop` branch reintroduces exactly the long-lived divergence the core principle warns
against.

---

## Why short-lived branches

The single highest-leverage choice is branch lifetime, not branch topology.

| Branch lifetime | Reality |
| :-------------- | :------ |
| < 1 day | Conflicts trivial; integrates with everyone else's day cleanly. Aim here. |
| 1–3 days | Fine with daily rebase/merge from mainline. |
| 3–10 days | Drift starts; expect a real merge and a re-review. Split the work. |
| > 10 days | Divergent by definition; the merge is a project of its own. Avoid. |

Keeping branches short forces work to be decomposed into shippable slices, which is also what
makes reviews small enough to be real (see [`../../code-review/reference/guide.md`](../../code-review/reference/guide.md)).

---

## Integration frequency and CI

**Continuous integration** means every developer merges to a shared mainline frequently
(at least daily), and each merge triggers an automated build + test. It is a *practice*, not
a server — the tool that runs the build is a CI runner; CI itself is the habit of integrating
often. The two reinforce each other: frequent small merges keep the build green and fast;
a fast green build makes frequent merging painless.

| If integration is… | Then… |
| :------------------ | :---- |
| Continuous (≥ daily to mainline) | Conflicts small; `main` reflects reality; regressions caught same-day. |
| Weekly (feature branches merge when "done") | Merge days become integration hell; "works on my branch" surprises. |
| Never until release | Big-bang integration; the schedule slips on merges nobody estimated. |

---

## Feature flags vs long-lived branches

Both hide incomplete work; only one keeps you integrating. Prefer flags.

| | Long-lived feature branch | Feature flag on trunk |
| :-- | :------------------------ | :-------------------- |
| Integration | Deferred until merge | Continuous; code is on `main` now |
| Conflict risk | Grows daily | None from this work |
| Rollback | Revert a large merge | Flip a flag, no deploy |
| Testing in prod-like env | Hard until merged | Enable for staff / a cohort |
| Cost | Merge pain | Flag lifecycle to manage (remove when done) |

Rule: if a change is not done but the code is safe to have present-but-inert, put it on trunk
behind a flag rather than on a branch. Flags are debt too — delete each one once its feature
is fully rolled out, or they become their own long-lived divergence.

---

## Release and hotfix branches

Use these only when you must support a released version separately from ongoing work.

| Branch | Purpose | Lives | Merges back? |
| :----- | :------ | :---- | :----------- |
| `release/x.y` | Stabilize a version: only fixes, no new features. | Until the version is retired. | Fixes cherry-picked or merged back to trunk. |
| `hotfix/x.y.z` | Emergency fix to a production version. | Hours to days. | Yes — always land the same fix on trunk, or the bug returns. |

The classic failure is a hotfix that ships to production but never merges back to trunk; the
next release regresses the same bug. Any fix to a release branch must have a tracked path back
to the mainline.

---

## Branch naming conventions

Names are cheap coordination. A consistent prefix lets humans, CI filters, and changelog
tooling route branches without asking.

| Prefix | For | Example |
| :----- | :-- | :------ |
| `feat/` | New feature | `feat/checkout-apple-pay` |
| `fix/` | Bug fix | `fix/null-cart-on-empty-session` |
| `chore/` | Tooling, deps, config, no product behavior | `chore/bump-eslint-9` |
| `refactor/` | Behavior-preserving restructure | `refactor/extract-pricing-service` |
| `docs/` | Documentation only | `docs/api-auth-examples` |
| `hotfix/` | Emergency production fix | `hotfix/1.4.2-token-expiry` |

Conventions that pay off:

- **Prefix with the ticket id** when you have one: `feat/PROJ-123-apple-pay`. It links the
  branch, the PR, and the tracker without manual cross-referencing.
- Lowercase, hyphen-separated, short but descriptive; the prefix is the type, the rest is the
  *what*, not the *how*.
- Match the prefix vocabulary to your commit convention (e.g. Conventional Commits) so branch,
  commit, and changelog speak the same language.

---

## Branch protection rules

Protection turns a strategy from "everyone promises to be careful" into an enforced contract.
Apply these on `main` (and release branches).

| Rule | What it enforces | Why |
| :--- | :--------------- | :-- |
| Required reviews | ≥1 (often 2 for sensitive paths) approval before merge. | No unreviewed code on the mainline. |
| Required status checks | CI (build, tests, lint, scanners) must pass. | Mainline stays green and shippable. |
| Up-to-date before merge | Branch must include latest `main`. | Catches semantic conflicts CI would otherwise miss. |
| Linear history | No merge commits (squash or rebase). | Readable, bisectable history; clean revert units. |
| No force-push / no delete | Protects shared history. | Prevents rewriting what others built on. |
| Restrict who can push | Only via PR; no direct pushes. | Every change goes through the gate. |
| Signed commits (higher-trust repos) | Verified authorship. | Supply-chain / provenance assurance. |

Squash vs merge vs rebase: **squash** gives one revertible commit per PR (best for small PRs);
**rebase** preserves individual commits linearly (good when each commit is meaningful);
**merge commits** preserve branch topology but clutter bisect. Pick one per repo and enforce it.

---

## Merge queues

At scale, "up-to-date before merge" causes a race: two green PRs each pass against `main`, but
together they break it. A **merge queue** serializes merges — it rebases each PR on the queue's
head, runs CI on that exact combination, and merges only if green.

| Without a queue | With a merge queue |
| :-------------- | :----------------- |
| PRs pass individually, break when combined | Each PR tested against the actual merge result |
| Contributors manually re-sync and re-run CI | Queue re-tests and merges automatically |
| Fine below ~10 merges/day | Needed as merge volume and CI time rise |

Worth adopting when concurrent merges to `main` regularly race; unnecessary overhead for a
small team merging a few PRs a day.

---

## Interaction with CI/CD and worktrees

- **CI/CD**: branch strategy sets *when* pipelines run — PR checks per branch, deploy
  pipeline on merge to `main`, release pipeline on a `release/*` tag. Trunk-based + CD means
  every merge to `main` is a candidate release; that only works if protection keeps `main`
  green. See [`../../ci-cd-automation/reference/guide.md`](../../ci-cd-automation/reference/guide.md).
- **Worktrees**: multiple short-lived branches checked out simultaneously in separate
  directories let an agent or engineer work several features in parallel without stashing or
  clobbering. This is how short-lived branches scale to parallel work — see the `/ctx-worktree`
  skill and [`../SKILLS.md`](../SKILLS.md).
- **Cleanup**: merged short-lived branches must be deleted, or the branch list becomes noise
  that hides the live ones. See [`../../branch-cleanup/reference/guide.md`](../../branch-cleanup/reference/guide.md).

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Long-lived divergent branches | Merge cost compounds; regressions hide in a huge delta. | Short-lived branches; integrate daily; flags for incomplete work. |
| Environment branches (`dev`/`staging`/`prod`) as the deploy mechanism | Branches drift apart; "promote by merge" causes cherry-pick chaos and undeployed fixes. | Deploy one artifact built from `main` to each environment via the pipeline; branches are not environments. |
| Everyone on one branch, no protection | Unreviewed, untested code breaks the mainline for all. | Require reviews + green CI on `main`; push via PR only. |
| Merging red CI "to unblock" | Poisons the mainline; the next person inherits the breakage. | Keep `main` always green; fix or revert, never merge red. |
| Hotfix that never returns to trunk | The bug regresses on the next release. | Every release-branch fix has a tracked merge/cherry-pick back to trunk. |
| Immortal feature flags | Dead flags become their own divergence and a testing-matrix explosion. | Remove each flag once its feature is fully shipped. |
| Big-bang integration before a release | Unestimated "merge week"; schedule slips. | Continuous integration; the release is a tag, not a merge event. |

---

## Choosing (quick heuristics)

| If your situation is… | Lean toward… |
| :-------------------- | :----------- |
| Deploy continuously; strong CI | Trunk-based (flags for incomplete work) |
| Deploy from `main`; want light PR flow | GitHub Flow |
| Ship discrete supported versions | Release-branch / train |
| Regulated release cadence, multiple live versions | Release-branch; consider GitFlow only if the ceremony is truly needed |
| High merge volume racing on `main` | Add a merge queue |

When two models both fit, take the lighter one. Ceremony you add "for safety" is divergence
you pay for on every merge.

---

## References

- Trunk Based Development: <https://trunkbaseddevelopment.com/>
- Martin Fowler — "Patterns for Managing Source Code Branches": <https://martinfowler.com/articles/branching-patterns.html>
- Martin Fowler — "Feature Toggles (aka Feature Flags)": <https://martinfowler.com/articles/feature-toggles.html>
- Martin Fowler — "Continuous Integration": <https://martinfowler.com/articles/continuousIntegration.html>
- Atlassian — Git Workflows (GitFlow, feature-branch, trunk-based): <https://www.atlassian.com/git/tutorials/comparing-workflows>
- GitHub Flow: <https://docs.github.com/en/get-started/using-github/github-flow>
