---
description: Run full CTX workflow
model: opus
allowed-tools: Read, Write, Edit, Bash, Skill
---

ROLE: COORDINATOR
MODE: MULTI_ROLE_AUTONOMOUS
EXECUTION_MODEL: SEQUENTIAL_WITH_ROLE_LOCK

────────────────────────────────────
DESIGN DECISION CHECKPOINT
────────────────────────────────────

- If implementation requires choosing between multiple valid designs
  (e.g. response shape, data type, aggregation strategy),
  the choice MUST NOT be made implicitly.
- Such decisions require explicit confirmation BEFORE implementation.
- Typical examples include:
    - String vs List in API responses
    - DTO structure differing from entity fields
    - Backward compatibility vs correctness
- If confirmation is required but user questioning is restricted:
    - STOP implementation immediately
    - Output a DESIGN DECISION REQUIRED notice
    - Clearly list all options and their impact


────────────────────────────────────
PROJECT CONTEXT (AUTO-INJECTED)
────────────────────────────────────

- This project is governed by CLAUDE.md / AGENTS.md
- Operating Principles and Workflow Rules are authoritative
- CTX documents are the single source of truth
- Existing code patterns override assumptions
- BUT existing code patterns MUST NOT override:
    - DESIGN DECISION rules
    - RESPONSE SHAPE LOCK rules
- Do NOT ask the user questions
- Resolve ambiguity ONLY by reading code, CTX, and documents

AUTONOMY GUARANTEES
- System-level execution or permission prompts (build, network, sandbox)
  are NOT user questions and MUST NOT block execution
- Commit plans MUST be produced even if the build fails,
  when the failure is unrelated to the modified feature
- Build or test failures caused by pre-existing configuration
  or infrastructure MUST NOT be fixed unless explicitly included
  in the task objective

SCOPE ENFORCEMENT
- Modify ONLY what is required for the described feature
- Do NOT fix build scripts, infrastructure, or unrelated modules
- "Ensure build/tests pass" means verification attempt,
  not mandatory repair

────────────────────────────────────
FEATURE
────────────────────────────────────

- Description:

- Relevant CTX Path(s):

────────────────────────────────────
OBJECTIVE
────────────────────────────────────

- Implement the feature correctly
- Verify build and tests within scope
- Keep CTX and code consistent
- Produce atomic, reviewable commit plans

────────────────────────────────────
GLOBAL ROLE RULES
────────────────────────────────────

- Roles MUST be executed strictly in order
- Only ONE role may be active at a time
- Each role has a hard scope boundary
- Once a role is completed, it MUST NOT be revisited
- Responsibilities MUST NOT overlap

AIDLC-DOCS SYNC ON ROLE TRANSITION:
- At each role transition, re-read `aidlc-docs/features/<feature-slug>/status.md`.
- If status has changed externally (e.g. user updated questions or requirements between roles), adapt accordingly.
- If a previously ASSUME'd question has been answered with a different choice, flag the conflict before proceeding.
- This ensures aidlc-docs changes made during implementation are not ignored.

────────────────────────────────────
ROLE EXECUTION PLAN
────────────────────────────────────

--------------------------------------------------
ROLE 0 — ARCHITECT
--------------------------------------------------
SCOPE:
- Requirement analysis and domain scope judgment only

RULES:
- This role MUST use the ctx-architect-judge skill
- Do NOT perform manual analysis
- Do NOT write code or make design decisions
- The skill will analyze requirements and determine scope

PARALLEL EXPLORATION (brownfield optimization):
- When the project has an existing codebase, launch parallel exploration before invoking ctx-architect-judge:
  - Agent A: Domain model exploration (entities, state machines, value objects)
  - Agent B: API/controller exploration (existing endpoints, response shapes)
  - Agent C: Test pattern exploration (existing test conventions, fixtures)
- Merge exploration results and pass to ctx-architect-judge as additional context.
- If the project is greenfield or the codebase is small, skip parallel exploration.

AIDLC-DOCS RE-READ:
- Before invoking ctx-architect-judge, re-read the following if they exist:
  - `aidlc-docs/features/<feature-slug>/status.md` (check Readiness Score)
  - `aidlc-docs/features/<feature-slug>/requirements.md`
  - `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md` (check no BLOCK remains)
- If BLOCK questions remain in the questions file, STOP and inform the user.

EXECUTION:
- Invoke the ctx-architect-judge skill using:
  /ctx-architect-judge
- Provide input format:
    - 작업 요구사항: FEATURE 내용
    - 제공된 Global CTX: 프로젝트의 모든 Global CTX 경로
    - 제공된 Local CTX: FEATURE에서 명시된 CTX 경로
    - 코드베이스 탐색 결과: (parallel exploration output, if available)
- Receive skill output

DECISION GATE:
- Check "판단 불가 / 추가 확인 필요 지점" section in skill output
- If NOT empty:
    - STOP execution immediately
    - Output the questions from skill
    - Do NOT proceed to any further ROLE
    - Do NOT produce Commit Plan
    - Wait for user clarification
- If empty:
    - Proceed to DESIGN VALIDATION PHASE
    - Pass architect output to ROLE 1

EXIT CONDITION:
- ctx-architect-judge skill completed
- Decision made: STOP or CONTINUE
- STOP


--------------------------------------------------
DESIGN VALIDATION PHASE (MANDATORY)
--------------------------------------------------

Execute ONLY if ROLE 0 CONTINUE decision.

Before starting ROLE 1 — IMPLEMENTOR, the Coordinator MUST validate:

0. Check if `aidlc-docs/features/<feature-slug>/technical-design.md` exists:
    - If it exists and was approved (GATE-3.5 passed):
        - Use it as the authoritative design reference for ROLE 1.
        - API response shapes, data models, and module structures from technical-design.md
          are pre-validated. Skip individual field validation below.
        - Check ONLY that technical-design.md Open Items section is "없음" or empty.
        - If Open Items remain: STOP and output DESIGN OPEN ITEMS UNRESOLVED.
    - If it does not exist (S-size-only feature or pre-technical-design workflow):
        - Proceed with the original validation below.

1. Whether this FEATURE requires any design decisions, including:
    - API response shape
    - DTO vs entity structure differences
    - Calculation or mapping rules not explicitly defined

2. For each modified or added API response field:
    - The response shape MUST be explicitly stated in the FEATURE section.
    - If NOT explicitly stated:
        - STOP execution immediately
        - If response shape is missing:
          Output RESPONSE SHAPE CONFIRMATION REQUIRED
          Else:
          Output DESIGN DECISION REQUIRED
        - List all available options and their impact
        - Do NOT proceed to any ROLE

If validation fails:
- Output the notice
- Do NOT execute any further ROLE
- Do NOT produce Commit Plan
- Wait for updated FEATURE section with explicit decisions
- End output immediately

--------------------------------------------------
ROLE 1 — IMPLEMENTOR
--------------------------------------------------
DEPENDENCY:
- Start ONLY after ROLE 0 completes with CONTINUE decision
- Start ONLY after DESIGN VALIDATION PHASE passes

SCOPE:
- Production code only
  (API, Service, Repository, Batch, DTO)

RULES:
- This role MUST use the ctx-domain-exec skill
- Do NOT perform manual implementation
- Do NOT modify tests, documentation, or build config
- Never guess contracts, fields, or calculations

LAZY IMPLEMENTATION (code minimization):
- Before writing ANY new code, apply the 7-rung decision ladder
  from `core/lazy-implementation.md` (default intensity: full):
    1. Does it need to exist? (skip if not — YAGNI)
    2. Already in this codebase? (reuse, don't rewrite)
    3. Stdlib does it? 4. Native platform/framework feature?
    5. Installed dependency? 6. One line? 7. Only then: minimum code.
- Rung 2 MUST honor reusable components listed in `ctx/`.
- Adding a new dependency still follows dependency-management rules
  (justify in PR); the ladder is NOT an excuse to add deps.
- NEVER trim safety guards to reduce code: trust-boundary validation,
  data-loss handling, security, accessibility, Acceptance-Criteria
  coverage, and business policy are off the chopping block.
- Leave `// ponytail: <trimmed / revisit reason>` for deferred shortcuts
  and append one line to `aidlc-docs/audit.md` with `[PONYTAIL]` prefix.
- See `docs/ponytail-integration.md` for plugin/OMC usage.

EXECUTION:
- Invoke the ctx-domain-exec skill using:
  /ctx-domain-exec
- Provide input in ARCHITECT_CONFIRMED mode format:
    - 실행 모드: ARCHITECT_CONFIRMED
    - Architect 판단 결과: (ROLE 0 output)
        - 영향 도메인 목록
        - 반드시 참조해야 할 Local CTX
        - Global CTX 영향 여부
        - 판단 불가 지점: 없음
    - 작업 요구사항: FEATURE 내용
    - 기술 설계 참조: (technical-design.md 경로, 존재하는 경우)
- If `technical-design.md` exists, the implementor MUST follow:
    - API specifications (Section 3) for endpoint contracts
    - Data model (Section 4) for entity/field structures
    - Module structure (Section 5) for file/class placement
    - ADR decisions (Section 2) for chosen design approaches
- Return skill output verbatim
- After skill completes, run ./gradlew build
- If build fails:
    - Fix ONLY failures caused by this feature
    - Retry up to 5 times
    - Otherwise, record failure and continue

## BUILD VERIFICATION RESULT
- status: FAILED
- classification: UNRELATED
- reason: bootJar mainClass not configured (pre-existing configuration)

EXIT CONDITION:
- ctx-domain-exec skill completed
- BUILD VERIFICATION RESULT recorded
- STOP


--------------------------------------------------
ROLE 2 — TEST_WRITER
--------------------------------------------------
DEPENDENCY:
- Default: Start ONLY after ROLE 1 completes
- TDD mode: Start BEFORE ROLE 1 (see TDD MODE below)

SCOPE:
- Test code only

RULES:
- Follow existing test patterns
- Do NOT modify production code
- Do NOT introduce new behavior

TDD MODE:
- If project CTX contains `test-strategy: tdd` (in ctx/project-profile.ctx.md or CLAUDE.md):
  - ROLE 2 executes BEFORE ROLE 1
  - Write failing tests first based on requirements and design decisions
  - Then ROLE 1 implements code to make tests pass
  - Execution order becomes: ROLE 0 → DESIGN VALIDATION → ROLE 2 → ROLE 1 → ROLE 3 → ...
- If `test-strategy: test-after` or not specified:
  - Default order: ROLE 1 first, then ROLE 2
- The Coordinator MUST check for this setting before starting ROLE 1.

EXECUTION:
- Write unit and/or integration tests for implemented behavior
- In TDD mode: write tests for expected behavior based on requirements
- After tests pass, complete the Runtime Verification section (Section 8)
  of `aidlc-docs/features/<feature-slug>/test-instructions.md`:
    - Record the startup command
    - Run health check and record result
    - Execute at least one representative success case and one block/error case
    - Record any environment constraints encountered (port binding, sandbox, etc.)
  - If test-instructions.md does not exist (S-only feature), skip this step.
  - If runtime cannot be started due to environment constraints,
    record the constraint in the Environment Constraints field and continue.

EXIT CONDITION:
- Tests written
- Runtime Verification section filled in (or skipped with reason)
- STOP


--------------------------------------------------
ROLE 3 — REVIEWER
--------------------------------------------------
DEPENDENCY:
- Start ONLY after ROLE 1 and ROLE 2 complete

SCOPE:
- Review and validation only (NO code or doc changes)

RULES:
- This role MUST use the ctx-reviewer skill
- Do NOT perform manual review
- Do NOT modify code, CTX, or documentation
- The skill will validate against FEATURE, CTX, and design constraints

OVER-ENGINEERING CHECK (lazy implementation, see core/lazy-implementation.md):
- In addition to CTX violations, flag over-engineering:
    - Code that dropped to rung 7 (hand-written) when an earlier rung worked.
    - New code that duplicates a reusable component already in `ctx/`/codebase.
- BLOCK FIRST (higher priority than over-engineering): a safety guard
  (validation, security, data-loss, accessibility, AC, business policy)
  removed under the name of "laziness" is a defect, not a simplification.
- If the ponytail plugin is installed, `/ponytail-review` can produce a
  delete-candidate list for the current diff; otherwise check manually.

EXECUTION:
- Invoke the ctx-reviewer skill using:
  /ctx-reviewer
- Provide all necessary context (modified files, FEATURE, relevant CTX paths)
- Return skill output verbatim

OUTPUT:
- Skill output containing:
    - CTX violations (if any)
    - Implicit design decisions (if any)
    - CTX update decision ("required" or "not required")

EXIT CONDITION:
- ctx-reviewer skill completed
- STOP


--------------------------------------------------
ROLE 4 — DOC_UPDATER
--------------------------------------------------
DEPENDENCY:
- Start ONLY after ROLE 3 completes
- Execute ONLY if ctx-reviewer states "CTX update required"

SCOPE:
- CTX and documentation only

RULES:
- This role MUST use the ctx-updater skill
- Do NOT perform manual updates
- Do NOT modify production or test code

EXECUTION:
- Invoke the ctx-updater skill using:
  /ctx-updater
- Provide input based on REVIEWER findings
- Return skill output verbatim

EXIT CONDITION:
- ctx-updater skill completed OR explicitly confirmed unnecessary
- STOP


--------------------------------------------------
ROLE 5 — REFINER
--------------------------------------------------
DEPENDENCY:
- Start ONLY after ROLE 3 completes
- Any output produced by DOC_UPDATER MUST be included as input

SCOPE:
- CTX documents ONLY
    - Global CTX
    - Local CTX

RULES:
- This role MUST use the ctx-refiner skill
- Do NOT perform manual refinement
- Do NOT modify production or test code
- This role MUST NOT touch commit messages or commit plans

EXECUTION:
- Invoke the ctx-refiner skill using:
  /ctx-refiner
- Provide:
    - REVIEWER findings
    - Updated CTX (if any from DOC_UPDATER)
    - All relevant CTX paths
- Return skill output verbatim

EXIT CONDITION:
- ctx-refiner skill completed
- STOP


--------------------------------------------------
ROLE 6 — COMMIT_PLANNER
--------------------------------------------------
DEPENDENCY:
- Start ONLY after ROLE 5 completes

SCOPE:
- Commit planning via ctx-commit-planner skill ONLY

RULES:
- This role MUST use the ctx-commit-planner skill
- This role MUST NOT directly generate commit plans
- This role MUST NOT summarize or restate commit content
- This role MUST NOT modify code, tests, or CTX
- All commit planning MUST be delegated to the ctx-commit-planner skill
- Any attempt to generate commit plans without invoking the skill
  MUST result in immediate halt

EXECUTION:
- Invoke the ctx-commit-planner skill using:
  /ctx-commit-planner
- Provide input strictly in the format required by the skill
- Do NOT add interpretation, explanation, or modification
- Return the skill output verbatim

EXIT CONDITION:
- ctx-commit-planner skill invoked
- Skill output returned verbatim
- STOP

────────────────────────────────────
FINAL OUTPUT REQUIREMENTS
────────────────────────────────────

- Commit Plan MUST always be produced
  EXCEPT when execution is halted during DESIGN VALIDATION PHASE
- Explicitly state:
    - What was changed
    - What was intentionally NOT changed
    - Whether build failures are unrelated

────────────────────────────────────
SKILL PRECEDENCE
────────────────────────────────────

- Coordinator instructions take precedence over all skills
- ROLE 0-1, 3-6 skills are MANDATORY (not optional)
- ROLE 2 (TEST_WRITER) performs direct implementation (no skill available)
- Skills MUST be invoked via the Skill tool
- Skill output MUST be returned verbatim without modification

────────────────────────────────────
EXECUTION FLOW SUMMARY
────────────────────────────────────

1. ROLE 0 (ARCHITECT) - ctx-architect-judge
   - Parallel codebase exploration (brownfield only)
   - Re-read aidlc-docs before proceeding
   → If design decision missing: STOP, output questions, wait for user
   → If design decision present: CONTINUE to step 2

2. DESIGN VALIDATION PHASE
   → If design decision missing: STOP, output notice, wait for user
   → If all decisions explicit: CONTINUE to step 3

DEFAULT ORDER (test-after):
3. ROLE 1 (IMPLEMENTOR) - ctx-domain-exec (ARCHITECT_CONFIRMED)
4. ROLE 2 (TEST_WRITER) - direct implementation

TDD ORDER (test-strategy: tdd):
3. ROLE 2 (TEST_WRITER) - write failing tests first
4. ROLE 1 (IMPLEMENTOR) - implement to pass tests

THEN:
5. ROLE 3 (REVIEWER) - ctx-reviewer
6. ROLE 4 (DOC_UPDATER) - ctx-updater (if needed)
7. ROLE 5 (REFINER) - ctx-refiner
8. ROLE 6 (COMMIT_PLANNER) - ctx-commit-planner

Re-read aidlc-docs/status.md at each role transition.
Commit Plan produced UNLESS stopped at step 1 or 2.