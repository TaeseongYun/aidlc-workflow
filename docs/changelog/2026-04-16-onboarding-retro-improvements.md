# 2026-04-16: Onboarding-Retrospective-Driven Improvements — Implementation Scope, Runtime Verification, init bug fix

## Background

By comparatively analyzing 7 retrospective documents from three onboarding projects (`meta-marketing-api-onboarding`, `onboarding-meta-api-hackathon`, `onboarding-odasiyoung-20260414`), we derived 11 common improvement points.

After critically reviewing the derived 11 items against the existing workflow design:

- **5 not accepted**: already implemented (#2 AI decision log, #6 MVP scope cut), or destroys the gate design philosophy (#7 self-approval), or inappropriate to put a domain-specific classification into a general-purpose workflow (#10 money/legal tag), or undermines the tech-agnostic principle (#11-B scaffold helper)
- **4 need redesign**: the observation is valid but the proposed solution is wrong (#1 #5 #8 #9) — separate judgment needed
- **3 acceptable**: reflected this time

## Changes

### 1. New Implementation Scope section (technical-design.md)

**File**: `templates/technical-design.md`

Added an `## Implementation Scope` section right after `## Authoring Conditions`.

Background: the design document is written to a production standard, but when the actual implementation is a prototype or local-MVP, that fact is recorded nowhere, causing a common problem across 3 projects where the implementation level is later misunderstood.

Fields added:
- `Implementation level`: `production` / `prototype` / `local-MVP`
- `Mock allowance scope`: `none` / `external-api-only` / `storage-only` / `all-external`
- `Items excluded from this implementation`
- `Additional work for production conversion`

### 2. New Runtime Verification section (test-instructions.md + ctx-run)

**Files**: `templates/test-instructions.md`, `skills/ctx-run/SKILL.md`

Background: passing tests and the actual service working are different things, yet the existing workflow did not define a runtime-verification routine after build/test pass. All 3 projects wasted time at the server-startup confirmation stage due to omissions or environment constraints.

Added an `## 8. Runtime Verification` section to `test-instructions.md`:
- Startup command
- Health check
- Representative use-case verification (success case + block/exception case)
- Execution log check
- Environment-constraint record (sandbox, port binding, etc.)

Skip allowed for a standalone S-size case or when there is no server startup.
When startup is impossible due to environment constraints, record the constraint and continue.

Added, to ROLE 2 (TEST_WRITER) of `skills/ctx-run/SKILL.md`, an instruction to write the Runtime Verification section after tests pass.

### 3. Fix for init-project.sh target-folder auto-creation bug

**File**: `scripts/init-project.sh`

Before: passing a non-existent path as an argument terminated the script due to `cd` failure
Fix: added `mkdir -p "${PROJECT_ROOT}"` before `cd`

## Full list of modified files

| File | Change type |
|------|------------|
| `templates/technical-design.md` | Added section (Implementation Scope) |
| `templates/test-instructions.md` | Added section (Runtime Verification) |
| `skills/ctx-run/SKILL.md` | Added ROLE 2 execution instruction |
| `scripts/init-project.sh` | Bug fix (mkdir -p) |

## Items not reflected and why

| # | Item | Classification | Reason |
|---|------|------|------|
| #2 | AI interim-decision log | Not accepted | Already implemented in `requirement-verification-questions.md` (AI recommendation, confidence tag, AI auto-decision P2 table) |
| #6 | MVP Scope Cut section | Not accepted | Already implemented as `planning-draft.md` Section 6 Scope Draft |
| #7 | Self-Approval mode | Not accepted | Destroys the gate design philosophy. Already possible via explicit "skip gate" |
| #10 | Policy risk-level tag | Not accepted | Covered by P0/P1/P2 + stage-gate approval list. Money/legal tags are a domain-specific classification |
| #11-B | Team-stack Scaffold | Not accepted | Undermines the tech-agnostic principle. Needs to be split into a team-internal template repo |
| #1 | Source Document Ingest | Needs redesign | Observation valid, but adding STEP 0 is excessive. Consider handling by stating it as a QUICKSTART precondition |
| #5 | Environment constraints in CTX | Needs redesign | The `Existing Constraints` field already exists. Needs reconsideration whether reinforcing examples is sufficient |
| #8 | ctx-run execution log | Needs redesign | There is a need, but a role-separation design against audit.md must come first |
| #9 | Change-impact prediction | Needs redesign | Should be handled as a ctx-architect-judge deliverable, not in the requirements template |

## Reference sources

| Source | Pattern borrowed |
|------|-----------|
| meta-marketing-api-onboarding retrospective, rounds 1 & 2 | Implementation Slice concept, need to distinguish implementation level |
| onboarding-meta-api-hackathon retrospective, rounds 1 & 2 | Runtime verification checklist, self-contained execution |
| onboarding-odasiyoung-20260414 retrospective, rounds 1, 2 & 3 | Runtime verification standardization, init-project.sh bug |
