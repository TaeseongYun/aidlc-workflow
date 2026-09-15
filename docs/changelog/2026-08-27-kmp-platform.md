# KMP as the 7th Platform

> Retroactive entry — added 2026-09-15 to close the gap between README's Change
> History row (2026-08-27) and the changelog, per the CONTRIBUTING requirement.

## Summary

Added Kotlin Multiplatform (KMP) as the seventh platform: `platforms/kmp/`
with `guidance.md` (architecture baseline: shared commonMain domain/data,
expect/actual boundaries, per-target hosts) and 13 skills including
figma-to-kmp, a vibe-coding security guard, testing, design-system,
state-management, navigation-platform, and performance.

## Files Changed

- Added: `platforms/kmp/guidance.md`
- Added: `platforms/kmp/skills/` (13 skill directories + README index)

## Rationale

Teams shipping shared-KMP mobile code needed the same guidance + skill-family
coverage the other six platforms already had.

## Impact

- Platform count 6 → 7 everywhere (README table, platforms/README.md).
- No breaking changes.
