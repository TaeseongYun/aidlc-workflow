# Upstream Sync State — AWS AI-DLC

Tracks the last content-level sync between this repo and its upstream
methodology source. Updated only inside sync PRs (`ctx-aidlc-sync`), so state
lands when the sync merges.

- Upstream: https://github.com/awslabs/aidlc-workflows (branch `main`)
- lastSyncedSha: `22ed2d101f4f01196b76d5725cf8d9aabe5fef9e`
- Last sync date: 2026-09-07
- Sync mode: incremental (a277af21..22ed2d10, 2 commits)

## Disposition table (last run)

| Upstream change | Disposition | Target / Reason |
|---|---|---|
| `22ed2d10` test: make plugin compose assertions portable on Windows (#1015) — tests/harness/plugin-kit.ts, tests/integration/t188-plugin-compose.test.ts | SKIP | Windows-compatibility fix in upstream's own plugin test harness — adoption filter "What we did not take: implementation/deployment automation" (repo-internal implementation infrastructure, not a methodology pattern) |
| `c46f500a` chore: remove docs/rfcs from the repository (#1029) — deletes docs/rfcs/*, adds .gitignore | SKIP | Upstream-internal RFC document cleanup (housekeeping) — this repo has never adopted or referenced those RFCs (grep confirmed: 0 references) |

## Notes

- Adoption filter: `docs/methodology-references.md` §1 ("What we took" / "What we did not take").
- This is a content-level port relationship — the two repos share no git history; never git-merge.
- This round: 0 PORTs — no upstream change touches the adopted patterns (artifact structure, adaptive depth, extension opt-in, input validation, contradiction detection, state/audit). No update to `methodology-references.md` §1 needed.
