# Release & Versioning — Skills

Actionable procedure an agent (or engineer) runs to version and ship a release. This is the
*how*; the *what/why* reference is [`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: none direct; see `/ctx-commit-planner` for changelog-linked
  commits (meaningful units map cleanly to changelog entries). This repo keeps release
  notes under a `docs/changelog/` convention.
- **Platform-agnostic**: applies on any stack. Platform-specific publish commands live under
  `platforms/<platform>/`.
- **Siblings**: release automation → [`../ci-cd-automation/reference/guide.md`](../ci-cd-automation/reference/guide.md);
  consumer-side pinning → [`../dependency-management/reference/guide.md`](../dependency-management/reference/guide.md).

## When to use

Any time you cut a release, bump a version, or decide whether a set of changes warrants one:
tagging a library, shipping a service, or deciding MAJOR vs. MINOR vs. PATCH for a diff.

## Inputs

- The changes since the last release — `git log <last-tag>..HEAD`, or the merged diff.
- The current version and the public-API definition (what "compatible" means here).
- The `[Unreleased]` changelog section, if maintained from merge time.

## Outputs

- A version number with a one-line justification of the bump level.
- An updated changelog section (categorized), an annotated tag, and release notes.
- A verdict: **Release** / **Hold** (not ready) / **Escalate** (policy decision).

## Procedure

1. **Classify the changes.** For each change, decide breaking / additive / fix using the
   guide's breaking-change table. Check API, behavior, config, and data — not just
   signatures. When unsure, treat it as breaking.
2. **Compute the bump.** Highest wins: any breaking → MAJOR; else any additive → MINOR; else
   PATCH. State it: "MINOR — added X, no breaking changes." Pre-`1.0.0`? Note the weaker
   guarantee and prefer cutting `1.0.0` if the API is stable.
3. **Update the changelog.** Move entries from `[Unreleased]` into a dated version section;
   sort into Added/Changed/Deprecated/Removed/Fixed/Security. Breaking changes must appear
   in Changed or Removed with a migration note.
4. **Bump the version** in the single source of truth (manifest/metadata). One place; let
   builds derive from it.
5. **Tag.** Create an annotated (signed, if configured) tag on the release commit. Never
   move a tag that already exists.
6. **Build from the tag**, not from the branch head. Confirm the artifact is reproducible.
7. **Publish** to the registry/distribution. This is irreversible — verify version, changelog,
   and tag are all consistent *before* this step.
8. **Announce.** Write release notes from the changelog: breaking changes and migration first,
   then features, then fixes. Flag Security entries explicitly.

## Decision rules

- Any breaking change → **MAJOR**; announce loudly with migration notes.
- Additive only → **MINOR**; PATCH only for backward-compatible fixes.
- A published version is immutable → to fix a bad release, publish a new version; never
  retag.
- Removing anything public without a prior deprecation → **Hold**; deprecate first (MINOR),
  remove in a later MAJOR.
- No changelog entry for a change → **Hold** until it's recorded.

## Stop / escalate

- Version scheme undefined (SemVer vs CalVer not chosen) → decide with the owner before
  tagging; don't guess a scheme.
- Breaking change forced by a security fix → escalate; a fast MAJOR or a backported patch
  line is a human call, not a default.
- Deprecation/removal window is a product decision (how long consumers get) → escalate to a
  human owner; an agent must not set support policy.
- A published version needs "fixing" → stop; the answer is a new version, not a retag.

## Output format

```markdown
## Release: <name> v<new-version>  —  verdict: <Release | Hold | Escalate>

Bump: <MAJOR | MINOR | PATCH> — <one-line justification>
Since: <last-tag> (<N commits>)

### Changelog delta
- Added:      <...>
- Changed:    <... breaking changes here, with migration>
- Deprecated: <...>
- Removed:    <...>
- Fixed:      <...>
- Security:   <...>

### Release steps
- [ ] version bumped in <source of truth>
- [ ] annotated tag <vX.Y.Z> on <commit>
- [ ] built from tag; artifact reproducible
- [ ] published; release notes posted
```

## Quick checklist

- [ ] Every change classified breaking / additive / fix (API, behavior, config, data)
- [ ] Bump level = highest applicable; justified in one line
- [ ] Changelog updated, categorized; breaking changes carry a migration note
- [ ] Version set in one source of truth
- [ ] Annotated tag on the release commit; no existing tag moved
- [ ] Built from the tag, not the branch head
- [ ] Publish only after version + changelog + tag agree
- [ ] Release notes lead with breaking changes
