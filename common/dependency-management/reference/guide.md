# Dependency Management

> Platform-agnostic reference for adding, pinning, updating, and auditing the code your
> project pulls in from elsewhere: when a dependency earns its place, how to keep builds
> reproducible, and how to shrink supply-chain and upgrade risk.
> Companion procedure: [`../SKILLS.md`](../SKILLS.md).

A dependency is code you did not write but now own the risk of. Every one is a standing
liability — a bug surface, a security surface, an upgrade you will eventually be forced to
do on someone else's schedule. The cheapest dependency is the one you never add. The
default answer to "should I pull in a package for this?" is **no**, until the need clears
the bar below.

---

## The "should this dependency exist at all?" test

Climb this before every `add`. Stop at the first rung that holds.

| Rung | Ask | If yes |
| :--- | :-- | :----- |
| 1 | Do we even need this behavior, or is it speculative? | Skip it. Don't carry a dep for a maybe. |
| 2 | Does the standard library / runtime already do it? | Use stdlib. Zero new risk. |
| 3 | Does a dependency **already installed** solve it? | Reuse it. No new supply-chain surface. |
| 4 | Can a few lines of our own code do it correctly? | Write the few lines. A left-pad is not a dependency. |
| 5 | Is the problem genuinely hard, security-sensitive, or a wide standard (crypto, TLS, parsing untrusted input)? | *Then* take a well-maintained dependency — don't hand-roll it. |

The trap runs both ways. Adding a transitively-huge package to save ten lines is bloat;
hand-rolling your own crypto or date-math to avoid a dependency is a bug and a CVE. Rung 5
exists so "minimize dependencies" never becomes "reinvent the hard, security-critical
wheel badly."

---

## Direct vs transitive

| Kind | What it is | Who chose it | Your leverage |
| :--- | :--------- | :----------- | :------------ |
| **Direct** | Declared in your manifest; you import it. | You. | Full — pin, replace, or drop it. |
| **Transitive** | Pulled in by your direct deps. | Your dependencies did. | Indirect — override, or pressure/replace the parent. |

Most of the installed tree is transitive. A manifest with 20 direct deps routinely resolves
to hundreds of packages. You are trusting — and shipping — all of them. Audit the *resolved
tree*, not just the manifest. Prefer a direct dep with a shallow, well-known transitive
footprint over one that drags in a forest.

---

## Lockfiles: reproducible builds

The manifest states *intent* ("some 2.x"); the lockfile records the *exact resolved graph*
— every package, its exact version, and a content hash. Without a committed lockfile, two
machines resolve different trees and "works on my machine" becomes structural.

| Rule | Why |
| :--- | :-- |
| Commit the lockfile for applications. | The deploy must be bit-for-bit reproducible. |
| Install from the lockfile in CI (frozen / no-update mode). | CI must fail on drift, not silently re-resolve. |
| Regenerate it deliberately, in its own reviewable commit. | A lockfile diff is a supply-chain diff; it deserves eyes. |
| Verify integrity hashes on install. | Detects tampering and registry substitution. |
| Libraries usually *don't* commit a lockfile. | Their consumers resolve; a pinned lock would fight the consumer's tree. |

**Lockfile drift** — manifest and lockfile disagree, or the lockfile is stale — is a silent
correctness bug. CI installing in frozen mode is the guard; see
[`../ci-cd-automation/reference/guide.md`](../../ci-cd-automation/reference/guide.md).

---

## Version constraint styles

The constraint you write trades reproducibility against how much manual updating you sign
up for. With a committed lockfile, the constraint governs only *re-resolution*, not the
installed build.

| Style | Example intent | Accepts | Trade-off |
| :---- | :------------- | :------ | :-------- |
| **Exact pin** | `==1.4.2` | that version only | Maximum reproducibility; every update is manual and visible. Best for apps + tooling. |
| **Tilde / patch range** | `~1.4.2` → `>=1.4.2 <1.5.0` | patches | Free bug fixes; assumes the author never breaks in a patch. |
| **Caret / minor range** | `^1.4.2` → `>=1.4.2 <2.0.0` | minor + patch | Free features; trusts SemVer minors are backward-compatible (often, not always). |
| **"latest" / unbounded** | `*`, `latest` | anything | Never do this in production. Non-reproducible; a bad release breaks you with no diff. |

Application rule of thumb: **pin (or narrow-range) + committed lockfile**, and let an
automated updater propose bumps as reviewable PRs. Libraries: publish the **widest** range
you actually support, so consumers can dedupe — over-pinning a library forces version
conflicts on everyone downstream.

---

## Supply-chain security

You are running arbitrary code from strangers at install and at runtime. Treat the supply
chain as an attack surface, not plumbing.

| Threat | What it looks like | Defense |
| :----- | :----------------- | :------ |
| **Typosquatting** | `reqeusts`, `lodahs` — a name one keystroke off a popular one. | Verify the exact name/namespace before adding; block-list confusables in CI. |
| **Malicious update** | A trusted package ships a compromised version (hijacked maintainer, injected postinstall). | Pin + lockfile; review lockfile diffs; delay adoption of brand-new releases. |
| **Dependency confusion** | A public package shadows your internal one by the same name. | Scope/namespace internal packages; lock the registry source. |
| **Compromised transitive** | The malicious code is 4 levels deep, not in your manifest. | Audit the resolved tree; scan transitives, not just directs. |
| **Install-time execution** | Arbitrary code in build/postinstall hooks. | Disable install scripts by default; allow-list the few that need them. |

**Provenance** — cryptographic proof of *what source built this artifact and where* — plus
**signing** (verify the publisher's signature on install) and an **SBOM** (Software Bill of
Materials: the full inventory you actually shipped, so you can answer "are we affected?" the
day a CVE drops) are the backbone. Aim for the [SLSA](https://slsa.dev/) levels as a
maturity ladder. Prefer registries and publishers that support provenance attestation.

---

## Vulnerability scanning & audit

| Practice | What it does | Cadence |
| :------- | :----------- | :------ |
| **Audit on install/CI** | Cross-references the resolved tree against known-CVE databases. | Every CI run; block on Critical/High. |
| **Continuous scanning** | Re-checks the *already-shipped* tree as new CVEs are disclosed. | Daily/scheduled; a dep goes vulnerable without you touching it. |
| **SBOM diffing** | Flags what entered/left the shipped inventory. | Per release. |
| **Reachability triage** | Is the vulnerable code path actually called? | On each finding — cut false-positive noise, but never hand-wave a real one. |

A finding is not automatically a fire, and "no findings" is not automatically safe (the CVE
may be undisclosed). Scanning is a floor, not a ceiling. Track this as the
supply-chain/vulnerability axis of dependency scoring — see
[`core/dependency-score.md`](../../../core/dependency-score.md).

---

## Automated updates & cadence

Tools like Renovate and Dependabot open update PRs so upgrades are a steady trickle of small,
reviewable diffs instead of one terrifying quarterly leap.

| Update class | Cadence | Automation posture |
| :----------- | :------ | :----------------- |
| Security patches | Immediately | Auto-PR, fast-track review, merge on green. |
| Patch/minor (SemVer) | Weekly batch | Auto-PR; auto-merge if the test suite is trustworthy. |
| Major / breaking | Deliberate, scheduled | Manual PR; read the changelog and migration guide first. |
| Dev/tooling deps | Loose | Batch aggressively; low blast radius. |

The point is **small and continuous**. A dependency you update every week is a five-minute
diff; the same dependency untouched for two years is a multi-day migration across three
breaking majors. Trustworthy tests are the precondition for auto-merge — without them,
automation just merges breakage faster.

---

## License compliance

Every dependency's license governs how you may ship it. This is a legal blast radius, not a
detail. Scan licenses in CI; block unknown or disallowed ones before they reach a release.

| Family | Examples | Obligation | Typical stance |
| :----- | :------- | :--------- | :------------- |
| **Permissive** | MIT, BSD, Apache-2.0 | Attribution; Apache adds a patent grant. | Generally safe to use and ship. |
| **Weak copyleft** | MPL-2.0, LGPL | Share changes to *that* library; linking is usually fine. | Usually acceptable; check linking mode. |
| **Strong copyleft** | GPL, AGPL | Derivative works must be released under the same license; AGPL reaches network use. | Often incompatible with proprietary distribution — review before adopting. |
| **None / unknown** | no LICENSE file | No granted rights — legally you may have *no* right to use it. | Treat as blocking until clarified. |

---

## Blast radius before upgrading

Before you bump anything, know what depends on it and what it depends on. An upgrade to a
low-level, widely-required package can ripple through the whole tree; a leaf dep upgrade
touches nothing else.

| Signal | Read it as |
| :----- | :--------- |
| Many packages require this (high in-degree) | Wide blast radius; upgrade cautiously, expect transitive churn. |
| Leaf dependency (nothing depends on it) | Safe to bump in isolation. |
| Crosses a major version | Breaking by SemVer contract; budget migration time. |
| Changes the lockfile in hundreds of lines | The transitive graph shifted under you — re-audit. |

Map the dependency graph first. In this repo, **graphify** gives you the blast-radius /
impact view of what a change touches — use it to see the ripple before you commit to the
upgrade, not after CI goes red.

---

## Handling breaking changes on upgrade

1. **Read the changelog / migration guide** for every major crossed — do not skip intermediate majors blind.
2. **Upgrade one major at a time** when jumping several; debug against one changelog, not three at once.
3. **Isolate the bump** in its own branch/PR so a revert is one clean click.
4. **Lean on the test suite**; where coverage is thin, add a test for the behavior you depend on *before* upgrading.
5. **Check transitive fallout** — a major bump often drags peers and re-resolves the tree.

---

## Vendoring vs registry

| Approach | Get it at | Use when |
| :------- | :-------- | :------- |
| **Registry + lockfile** | Build/install time from a package registry. | Default. Reproducible via lockfile + integrity hashes, no repo bloat. |
| **Vendoring** (commit deps into your repo) | Already in-tree; no network. | Air-gapped/hermetic builds, registry-outage immunity, or a patch you must carry until upstream merges. |

Vendoring buys build hermeticity and a guarantee against a package being yanked, at the cost
of a fatter repo and manual update discipline. A lockfile with integrity hashes already
gives you most of the reproducibility; reach for vendoring when you need
network-independence or a local patch, not by default.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Unpinned deps in production | A bad upstream release breaks a deploy with no diff to blame. | Pin + commit the lockfile; install frozen in CI. |
| Ignoring lockfile drift | Silent non-reproducibility; CI and prod diverge. | Fail CI on drift; regenerate deliberately. |
| Heavy dep for a one-liner | Hundreds of transitive packages to save ten lines. | Climb the "should it exist" test; write the few lines. |
| Hand-rolling the hard stuff | Home-grown crypto/parsing = your own CVE. | Rung 5: take the vetted dependency. |
| Never updating, then a forced jump | One security fire forces a multi-major migration. | Small, continuous, automated updates. |
| Auto-merging majors on green | Green tests don't prove SemVer-major compatibility. | Manual review for majors; read the changelog. |
| Blanket-ignoring audit findings | A real CVE hides among the muted noise. | Triage by reachability; suppress with a reason and an expiry, never silently. |

---

## References

- The Twelve-Factor App — II. Dependencies: <https://12factor.net/dependencies>
- OWASP Top 10 — A06:2021 Vulnerable and Outdated Components: <https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/>
- OWASP Dependency-Check: <https://owasp.org/www-project-dependency-check/>
- SLSA — Supply-chain Levels for Software Artifacts: <https://slsa.dev/>
- Semantic Versioning 2.0.0: <https://semver.org/>
