# Release & Versioning

> Platform-agnostic reference for versioning software and shipping releases: how to
> number a release, what counts as breaking, how to record change, and how to publish
> honestly. Companion procedure: [`../SKILLS.md`](../SKILLS.md).

A version number is a promise to consumers about what changed and what might break. A
release is the act of making a specific, immutable version available. The discipline is
one idea: **communicate change honestly** — breaking changes are loud, additive changes
are safe, and a published version is never rewritten.

---

## Semantic Versioning

SemVer numbers a release `MAJOR.MINOR.PATCH` (e.g. `2.4.1`). Each component signals a
different promise to consumers about compatibility.

| Component | Bump when | Signal to consumer |
| :-------- | :-------- | :----------------- |
| **MAJOR** | You make an incompatible (breaking) change to the public interface. | "Read the migration notes; your code may break." |
| **MINOR** | You add functionality in a backward-compatible way. | "Safe to upgrade; new things are available." |
| **PATCH** | You make a backward-compatible bug fix. | "Safe to upgrade; only fixes." |

Rules that fall out of this contract:

| Rule | Detail |
| :--- | :----- |
| Bump the highest applicable | A release with both a fix and a breaking change is a MAJOR, not a PATCH. |
| Reset lower components | `1.4.3` → next MINOR is `1.5.0`; next MAJOR is `2.0.0`. |
| Never reuse a number | Once published, a version is immutable (see anti-patterns). |
| The public API defines "compatible" | Document what the public surface is; internals can change freely under PATCH. |

---

## Identifying a breaking change

A change is breaking if a consumer who did nothing wrong now behaves differently or fails.
It is not only about function signatures — behavior, config, and data shape all count.

| Kind | Breaking example | Non-breaking counterpart |
| :--- | :--------------- | :----------------------- |
| **API surface** | Remove/rename a public function, param, or field; tighten a type. | Add a new optional param; add a new function. |
| **Behavior** | Same input now returns a different result or throws. | Fix a result that was documented as wrong (still note it). |
| **Config / defaults** | Rename a setting; change a default that alters output. | Add a setting with a backward-compatible default. |
| **Data / schema** | Migration that drops a column; incompatible wire/serialization format. | Add a nullable column; add an optional field. |
| **Errors** | Change an error type/code consumers catch on. | Add a new error path for a previously-undefined case. |
| **Dependencies** | Raise the minimum runtime/platform version. | Widen the supported range. |

When unsure, assume breaking. A false MAJOR costs an upgrade note; a false PATCH costs a
consumer a 3am page. Document the public surface up front so "breaking" is decidable, not
a judgment call per release.

---

## Pre-release and build identifiers

Append a pre-release tag to ship an unstable version for testing before the real release.
Pre-releases sort *below* the release they precede: `1.0.0-alpha` < `1.0.0-rc.1` < `1.0.0`.

| Identifier | Meaning | Stability |
| :--------- | :------ | :-------- |
| `-alpha` | Early, incomplete; API may still change. | Lowest |
| `-beta` | Feature-complete; hunting bugs. | Low |
| `-rc.N` | Release candidate; ship this unless a blocker appears. | High |
| `+build.N` | Build metadata (commit, timestamp). Ignored for precedence. | N/A |

Format: `1.2.0-beta.2+exp.sha.5114f85`. The `-` part affects ordering and signals
instability; the `+` part is informational only and never affects which version "wins".

---

## Version ranges and pinning

Consumers choose how tightly to depend on a version; the trade-off is stability vs.
getting fixes. This is the *consumer* side of the contract SemVer defines — see the
[dependency-management sibling](../../dependency-management/reference/guide.md) for the full
treatment.

| Strategy | Example intent | Trade-off |
| :------- | :------------- | :-------- |
| Exact pin | "Only `2.4.1`." | Reproducible; misses security patches until you act. |
| Patch range | "`2.4.x`." | Auto-gets fixes; trusts publishers not to break patches. |
| Minor range | "`2.x`." | Auto-gets features; larger surface for surprise regressions. |
| Any / unpinned | "Latest." | Never do this in a release artifact; non-reproducible builds. |

Publishers keep the contract; consumers pin according to how much they trust it. A lockfile
records the exact resolved versions for reproducibility regardless of the declared range.

---

## Changelog discipline

A changelog is written for humans deciding whether and how to upgrade — not a `git log`
dump. Follow [Keep a Changelog](https://keepachangelog.com/): newest first, an
`[Unreleased]` section at the top, one dated section per release.

| Category | Use for |
| :------- | :------ |
| **Added** | New features. |
| **Changed** | Changes to existing behavior. |
| **Deprecated** | Soon-to-be-removed features (still present). |
| **Removed** | Features taken out this release. |
| **Fixed** | Bug fixes. |
| **Security** | Vulnerability fixes — call these out so consumers prioritize. |

Rules: add to `[Unreleased]` as you merge (not scrambling at release time); rename it to the
version and date on release; link each version to its diff/tag. `Removed` and `Changed`
entries are where breaking changes live — they justify the MAJOR bump and tell the migrator
exactly what to fix.

---

## Release process

An ordered, repeatable sequence. Automate the mechanical steps; keep the human decision at
"is this ready".

| Step | Action | Note |
| :--- | :----- | :--- |
| 1. Bump | Set the new version per SemVer. | The bump *is* the compatibility claim — verify it. |
| 2. Changelog | Rename `[Unreleased]` to the version + date; confirm categories. | Breaking changes visible in Changed/Removed. |
| 3. Tag | Create an annotated, signed tag on the release commit. | Immutable pointer; see below. |
| 4. Build | Produce artifacts from the tagged commit. | Reproducible; build from the tag, not `main`. |
| 5. Publish | Push artifacts to the registry/distribution. | The point of no return — see retagging anti-pattern. |
| 6. Announce | Release notes + notify consumers (esp. Security/breaking). | Loud for breaking; link the changelog. |

If any step can fail partway (published but not tagged), make the sequence resumable and
idempotent, and never publish before the tag exists.

---

## Tags and release notes

| Artifact | What it is | Why |
| :------- | :--------- | :-- |
| **Lightweight tag** | A bare pointer to a commit. | Fine for private markers; avoid for releases. |
| **Annotated tag** | Tag object with author, date, message; signable. | Use for releases — carries provenance and can be verified. |
| **Release notes** | Human summary derived from the changelog. | What a consumer reads to decide to upgrade. |

Release notes are the changelog section rewritten for the audience: lead with breaking
changes and migration steps, then features, then fixes. A tag is a claim about *which
commit*; notes are a claim about *what it means*.

---

## Deprecation policy

Removal is a breaking change; deprecation is the humane path to it. Deprecate first, remove
later, so consumers migrate on their schedule instead of on your release.

| Stage | What happens | Version impact |
| :---- | :----------- | :------------- |
| Announce | Mark deprecated in changelog + docs; emit a runtime warning if feasible. | MINOR (still works). |
| Window | Keep it working for a stated period (e.g. N minor versions or a time window). | No bump per se. |
| Remove | Delete it; document the replacement and migration. | MAJOR. |

State the window explicitly ("removed in 3.0, no earlier than 6 months"). A deprecation with
no removal date is noise consumers learn to ignore; a removal with no prior deprecation is
an ambush.

---

## SemVer vs CalVer

Two philosophies for what a version number *means*. Pick per how consumers reason about the
project.

| Aspect | SemVer (`2.4.1`) | CalVer (`2026.09`, `26.9.1`) |
| :----- | :--------------- | :--------------------------- |
| Encodes | Compatibility promise. | Release date. |
| Best for | Libraries/APIs others build against. | Apps/distros/services shipped on a cadence. |
| "When should I upgrade?" | "Is it compatible?" | "How current am I?" |
| Weakness | Says nothing about age/support window. | Says nothing about breakage. |
| Breaking changes | Signaled by MAJOR. | Signaled out-of-band (notes, LTS lines). |

A library consumed by strangers wants SemVer; an end-user app or an OS-like product on a
time-based train (Ubuntu, some IDEs) wants CalVer. Hybrids exist; do not mix the two axes in
one number without a documented scheme.

---

## Release cadence

| Model | How it works | Fits |
| :---- | :----------- | :--- |
| **Continuous** | Ship each merged change; version bumps automatically. | Services with automated rollback and gradual rollout. |
| **Scheduled** | Batch changes into periodic releases (weekly/monthly/quarterly). | Libraries and installed software where consumers absorb upgrades manually. |
| **On-demand** | Release when a meaningful set is ready. | Small projects; low change volume. |

Cadence is orthogonal to versioning: a continuously-deployed service can still use SemVer
internally. Faster cadence needs stronger automation (changelog, tagging, tests) and cheaper
rollback — the reversibility budget goes up as batch size goes down.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Breaking change in a patch/minor | Silently breaks consumers who trusted the promise. | Bump MAJOR; announce loudly. |
| No changelog | Consumers can't tell what changed or whether to upgrade. | Maintain Keep a Changelog from merge time. |
| Retagging a published version | Two different artifacts share one number; caches and lockfiles diverge. | Publish a new version; never mutate a released one. |
| `0.x` forever | Signals "unstable" indefinitely; nobody can depend on you safely. | Cut `1.0.0` when the API is real; own the compatibility promise. |
| Deprecate-and-remove same release | Ambush; no migration window. | Deprecate in one release, remove in a later MAJOR. |
| Version bump without release notes | The number changed; the meaning didn't travel. | Every release carries notes derived from the changelog. |
| Squashing many changes into one opaque release | Consumers can't triage a regression. | Keep releases scoped; categorize the changelog. |

---

## References

- Semantic Versioning specification: <https://semver.org/>
- Keep a Changelog: <https://keepachangelog.com/>
- Calendar Versioning: <https://calver.org/>
