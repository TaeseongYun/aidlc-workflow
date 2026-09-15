# Per-Platform Skill Families

> Retroactive entry — added 2026-09-15 to close the gap between README's Change
> History row (2026-08-26) and the changelog, per the CONTRIBUTING requirement.

## Summary

Extended every platform under `platforms/` (android, ios, backend, frontend,
flutter, rn) with a consistent family of per-platform skills alongside the
existing architecture/figma/security packs: testing, design-system,
accessibility, contract-codegen, observability, and i18n. Each skill follows
the two-tier shape — a lean `SKILL.md` (tier 1) and a deep `reference.md`
(tier 2, loaded on demand).

## Files Changed

- Added: `platforms/<platform>/skills/<platform>-{testing,design-system,accessibility,contract-codegen,observability,i18n}/` (SKILL.md + reference.md per skill)

## Rationale

The generator/guard two-axis lens needs per-platform depth for quality
dimensions (tests, a11y, i18n, observability, contracts), not only for
architecture and security.

## Impact

- Platform skill count grew to 10-13 per platform; indexes in each
  `platforms/<p>/skills/README.md`.
- No breaking changes.
