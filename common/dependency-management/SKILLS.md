# Dependency Management — Skills

Actionable procedure an agent (or engineer) runs when adding, pinning, updating, or auditing
a dependency. This is the *how*; the *what/why* reference is
[`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-score-loop` scores the dependency axis of a change — see
  [`../../core/dependency-score.md`](../../core/dependency-score.md) for the rubric.
- **graphify** gives blast-radius / impact for a change: use it to see what an upgrade
  ripples into *before* you bump.
- **Siblings**: [`../release-versioning/reference/guide.md`](../release-versioning/reference/guide.md)
  (versioning the artifact you publish), [`../ci-cd-automation/reference/guide.md`](../ci-cd-automation/reference/guide.md)
  (frozen installs, audit/license gates in CI).
- **Platform-agnostic**: applies on any stack. Platform-specific rules live under `platforms/<platform>/`.

## When to use

Any time the dependency graph changes: adding a package, bumping a version, reviewing an
automated update PR, responding to a CVE, or auditing the tree before a release.

## Inputs

- The change — the package to add, or the version to move from/to.
- The need it serves — the concrete behavior required. If it's speculative, stop here.
- The manifest **and** the lockfile; the resolved tree, not just direct deps.

## Outputs

- A minimal, justified graph change with the lockfile regenerated in the same commit.
- A verdict: **Add / Bump / Reject / Escalate**, with the failure each guard prevented.

## Procedure — adding a dependency

1. **Run the "should it exist" test** (guide's table). Speculative → skip. Stdlib does it →
   stdlib. Already installed → reuse. A few lines → write them. Only a genuinely hard or
   security-sensitive problem earns a new dep.
2. **Vet the candidate.** Exact name/namespace (no typosquat), maintenance signals, license
   family, and the *transitive footprint* it drags in. Reject a forest pulled in for a leaf.
3. **Constrain it.** Pin or narrow-range for an app; widest-supported range for a library.
4. **Lock it.** Regenerate the lockfile; commit manifest + lockfile together as one reviewable diff.
5. **Scan it.** Run the vulnerability + license audit on the new resolved tree; block on Critical/High.

## Procedure — upgrading a dependency

1. **Classify the bump** — security / patch / minor / major (guide's cadence table).
2. **Map blast radius** with graphify before touching anything: high in-degree = wide ripple;
   crossing a major = breaking by contract.
3. **Read the changelog** for every major crossed; upgrade one major at a time on multi-version jumps.
4. **Isolate** the bump in its own branch/PR so revert is one click.
5. **Verify** against the test suite; add a test for the behavior you depend on where coverage is thin.
6. **Re-audit** the lockfile diff — a major bump re-resolves the transitive tree.

## Decision rules

- Need is speculative, or stdlib / an installed dep / a few lines covers it → **Reject**.
- Unknown/incompatible license, or unresolved Critical/High CVE → **Reject / Block**.
- Unpinned constraint or uncommitted lockfile on an app → **Block** until pinned + locked.
- Major version bump → **manual review**; never auto-merge on green alone.
- Security patch → **fast-track**: auto-PR, merge on green.
- License policy, or a dep that reshapes the architecture → **Escalate** to a human owner.

## Stop / escalate

- License is copyleft-in-a-proprietary-product, or absent/unknown → escalate; do not ship on a guess.
- Add would introduce a large transitive tree for a trivial need → reject and write the lines.
- CVE with no fix available → escalate; decide mitigate / pin-back / accept-with-owner, don't silently mute.
- Lockfile and manifest disagree (drift) → stop; regenerate deliberately, don't let CI auto-resolve.

## Quick checklist

- [ ] "Should it exist" test climbed; stdlib / installed / few-lines ruled out
- [ ] Name/namespace verified (no typosquat); license and transitive footprint checked
- [ ] Constraint set (pin+lock for app, wide range for lib)
- [ ] Lockfile regenerated and committed *with* the manifest
- [ ] Vulnerability + license audit run on the resolved tree; Critical/High blocked
- [ ] Upgrades: blast radius mapped, changelog read, bump isolated, tests green, lockfile diff re-audited
