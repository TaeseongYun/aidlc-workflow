# Workflow Guide

## Phase 0: Roadmapping (multi-feature only)

When a large prepared planning document decomposes into **multiple features**, run **Phase 0** (Roadmapping) before entering Phase A. For single-feature work, skip Phase 0.

| Item | Content |
|------|------|
| Skill | `/ctx-aidlc-roadmap` |
| Input | prepared-requirement original planning document |
| Output | `aidlc-docs/_roadmap.md` (single project-level file) |
| Gate | GATE-0 — Roadmap Review |
| Session end point | After GATE-0 passes |

Entry paths (bidirectional):
1. **Direct call**: The user receives a large planning document and runs `/ctx-aidlc-roadmap` right away.
2. **Handoff**: Even if the user ran `/ctx-aidlc-run` first, if round 1 of STEP 1-A answers "multiple independent features" AND `_roadmap.md` does not exist → ctx-aidlc-run blocks and directs to `/ctx-aidlc-roadmap`.

After GATE-0 passes, run each feature separately with `/ctx-aidlc-run` (each feature is classified as prepared-requirement, with the relevant section of the original planning document as input).

For detailed operating procedures, see `docs/multi-feature-coordination.md`.

## Session separation (default execution model)

Every `/ctx-aidlc-run` execution uses **per-Phase session separation** by default.
Running STEP 1~9 all in one session causes **inconsistent answers and contradictions between outputs** due to LLM context limits.

### Phase breakdown

| Phase | Included STEPs | Key outputs | Session end point |
|-------|----------|-----------|--------------|
| **0. Roadmapping** (multi-feature only) | R1, R2, R3, R4, R5, R6 | `_roadmap.md` | After GATE-0 passes |
| **A. Discovery** | 1, 1-A, 1-B, 1-C, 1.5, 2, 3 | `planning-draft.md`, `requirement-verification-questions.md` | After GATE-1 passes |
| **B. Definition** | 4, 5, 5.5, 5.7, 6 | `requirements.md`, `unit-of-work.md` | After GATE-3 passes |
| **C. Design** | 6.5, 6.7, 7, 8, 9 | `technical-design.md`, `build-instructions.md` | After GATE-5 passes |

### Application criteria

| Depth Level | Session separation | Reason |
|-------------|----------|------|
| minimal | Optional | The whole context is small enough to fit in one session |
| standard | Recommended | As question count and outputs grow, risk of inconsistency |
| comprehensive | **Required** | Prevents inconsistent answers from context overflow |

### Session separation principles

1. **Each Phase references only the previous Phase's outputs.** It does not reference the conversation from the previous session. Outputs are the only interface.
2. **On session resume, read aidlc-state.md first.** Check the current Phase, completed STEPs, and number of open questions.
3. **On a Phase transition, GATE approval must already be complete.**

### Session resume pattern

```text
/ctx-aidlc-run

Start Phase B.
Read aidlc-state.md first and check the current state.
Based on the Phase A outputs, proceed with finalizing requirements and unit decomposition.

Related outputs:
- aidlc-docs/features/<feature-slug>/planning-draft.md
- aidlc-docs/features/<feature-slug>/requirement-verification-questions.md
```

```text
/ctx-aidlc-run

Start Phase C.
Read aidlc-state.md first and check the current state.

Related outputs:
- aidlc-docs/features/<feature-slug>/requirements.md
- aidlc-docs/features/<feature-slug>/unit-of-work.md
```

---

## Order of use

### 1. Requirements analysis stage
- Purpose:
  - Identify requirement gaps
  - Extract pre-implementation questions
  - Author the unit-of-work
  - (Conditional) Define user stories, design system structure, design infrastructure
- Skills used:
  - `/ctx-aidlc-run`
- Results of this stage:
  - Create or update the project `aidlc-docs/`
  - Compile a list of questions that must be resolved before implementation
  - For a new feature, create `aidlc-docs/features/<feature-slug>/`
  - Create `status.md` and record the initial state
  - (Conditional) Create `user-stories/`, `application-design/` sub-outputs
  - (Conditional) Create `infrastructure-design.md`, `deployment-architecture.md`

### 2. Human answer/approval stage
- Purpose:
  - Finalize items that a human must decide on, such as policy, UX, settlement, and refunds
  - Review and approve outputs at each Gate (GATE-1 ~ GATE-5)
- Input:
  - `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
  - The outputs to be reviewed at each Gate
- Results:
  - Fix into implementable requirements
  - Update the state in `status.md` and `aidlc-state.md`
  - Append the Gate approval record to `audit.md`

### 3. Implementation stage
- Purpose:
  - Make actual code changes based on the approved requirements
- Skills used:
  - `/ctx-run`
- Results of this stage:
  - Code changes
  - Tests
  - Augment `ctx/` if needed

## Standard usage patterns

### Pattern A. Starting a new feature
1. Start requirements analysis with `/ctx-aidlc-run`
2. Create `aidlc-docs/features/<feature-slug>/` outputs
3. Collect planning/owner answers to the questions document
4. Implement with `/ctx-run`

### Pattern A-1. Starting from a raw requirement
1. Enter the original request from marketing/operations/the business as-is.
2. First create `request-intake.md` and `planning-draft.md` with `/ctx-aidlc-run`.
3. Organize policy, exceptions, operations, and success criteria into a questions document.
4. After incorporating answers, promote `requirements.md` to an implementation-ready state.
5. Then implement with `/ctx-run`.

### Pattern A-2. Request to add to an existing feature
1. First use `/ctx-aidlc-run` to determine whether it can be linked to an existing `feature-slug`.
2. If it is a follow-up change to the same feature, update the existing feature folder.
3. If it is an independent feature, create a new feature folder.

### Pattern B. Simple implementation request
- If `ctx/` and `aidlc-docs` already contain all the needed decisions, go straight to `/ctx-run`

### Pattern C. Large change mixed with policy
- Always start from `/ctx-aidlc-run`
- If there is any impact on payments, refunds, settlement, permissions, notifications, or operations, write a questions document before implementation

For the session separation guide, see the "Session separation (default execution model)" section at the top of this document.

---

## When should I use /ctx-aidlc-run
- When a raw request from marketing/operations/sales comes in directly
- When the requirements have many policy gaps
- When adding a new domain
- When it connects to existing payments/refunds/settlement/permissions/notifications
- When it is a feature viewed by multiple teams together
- When you need to check the scope of impact first in a brownfield
- When starting a new greenfield project

## When is /ctx-run alone enough
- When the answer is already clear in the CTX and existing docs
- When it is a small change that simply follows an existing pattern
- When no new API/policy/settlement judgment is needed

## Request classification principles
- `raw-request`
  - A request at the level of original text from marketing/operations/the business
  - There is a goal, but the scope, policy, and success criteria are not organized
  - Only in this case do you create `request-intake.md`, `planning-draft.md`.
- `prepared-requirement`
  - Already-structured requirements
  - In this case, proceed directly with `requirements.md` as the center.
- `change-on-existing-feature`
  - An additional change or follow-up requirement to an existing feature
  - In this case, prioritize updating the existing feature folder over a new folder.

## Greenfield / Brownfield criteria
- `greenfield`
  - A completely new project
  - Effectively no existing code/DB/API/operational flows
  - Start from requirements and domain definition
- `brownfield`
  - An existing project
  - You must read existing code/DB/API/operations/deployment constraints
  - New features must also fit into the existing structure

Practical criteria:
- If you must read the existing system before you can start, it is `brownfield`
- If there is no existing system to read and you build up from requirements, it is `greenfield`

## Greenfield usage flow

In greenfield, `ctx` is not an input but an intermediate output.

### 1. First /ctx-aidlc-run
- Purpose:
  - Structure the requirements
  - Extract questions
  - Define the unit-of-work
  - Create an initial project-structure draft
- Input:
  - Product goals
  - Users/operators
  - Core features
  - Constraints

### 2. Create aidlc-docs first
- Minimum outputs:
  - `aidlc-docs/aidlc-state.md`
  - `aidlc-docs/audit.md`
  - `aidlc-docs/features/<feature-slug>/status.md`
  - `aidlc-docs/features/<feature-slug>/requirements.md`
  - `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`
  - `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- For a raw request, add:
  - `aidlc-docs/features/<feature-slug>/request-intake.md`
  - `aidlc-docs/features/<feature-slug>/planning-draft.md`
- Conditional outputs (when applicable):
  - `aidlc-docs/features/<feature-slug>/user-stories/personas.md`
  - `aidlc-docs/features/<feature-slug>/user-stories/stories.md`
  - `aidlc-docs/features/<feature-slug>/application-design/components.md`
  - `aidlc-docs/features/<feature-slug>/application-design/services.md`
  - `aidlc-docs/features/<feature-slug>/application-design/component-dependency.md`
  - `aidlc-docs/features/<feature-slug>/infrastructure-design.md`
  - `aidlc-docs/features/<feature-slug>/deployment-architecture.md`
  - `aidlc-docs/features/<feature-slug>/build-instructions.md`
  - `aidlc-docs/features/<feature-slug>/test-instructions.md`
  - `aidlc-docs/features/<feature-slug>/extensions/security-baseline.md`

### 3. Human answers/approval
- Fill in the requirement gaps.
- Finalize policy, exceptions, and operational methods.

### 4. Create minimal ctx
- In greenfield, `ctx` is the project knowledge base created before implementation.
- You do not need to create many documents from the start.
- Minimum recommended structure:

```text
ctx/
├── INDEX.md
├── project-profile.ctx.md
├── common/
│   ├── global.ctx.md
│   └── decisions.ctx.md
└── workflow/
    └── commit-workflow.ctx.md
```

### 5. Implement with /ctx-run
- From this point, use both `ctx` and `aidlc-docs` together as the basis.

## Principles for handling raw requirements
- Preserve the original marketing/operations text first in `request-intake.md`.
- The AI does not turn a raw requirement directly into a confirmed requirement.
- First structure the goal, target users, scope, non-scope, operational assumptions, and success criteria in `planning-draft.md`.
- Separate policy/exception/permission/notification/settlement/operation gaps into `requirement-verification-questions.md`.
- Use `requirements.md` as the implementation-basis document only after the questions are resolved.

## Actual start examples

### Example of starting a raw-requirement analysis

```text
/ctx-aidlc-run

This request is a raw request with no planning document.
First write a planning draft based on team-ai-workflow.
If ctx/INDEX.md exists, read it first; otherwise read CLAUDE.md or README.md.
Read only the relevant ctx in addition.
Write the documents in the following order:
- request-intake.md
- planning-draft.md
- requirement-verification-questions.md
- requirements.md
- unit-of-work.md

Rules:
- Do not fix marketing phrasing directly as implementation rules
- Mark assumptions as assumptions
- Raise policies that a human must answer as questions
- If questions remain, do not judge it to be in an implementable state

Feature:
- We want to give a discount benefit for a certain period to repeat customers and drive re-visits.
```

### Example of starting a requirements analysis

```text
/ctx-aidlc-run

Analyze this requirement based on team-ai-workflow.
If ctx/INDEX.md exists, read it first; otherwise read AGENTS.md or CLAUDE.md, README.md.
Read only the relevant ctx in addition.
Create the aidlc-docs outputs, and if there are policy gaps, stop at the questions document.
If it is a new requirement, write it under `aidlc-docs/features/<feature-slug>/`.
Also create `status.md` in that feature folder.

Feature:
- Add a new payment feature that includes a reservation cancellation policy

Relevant CTX Path(s):
- ctx/INDEX.md
- ctx/project-profile.ctx.md
```

### Example of starting implementation

```text
/ctx-run

Implement based on the approved content in aidlc-docs and ctx.
Do not assume new policy; use only existing decisions.
Implement based only on the outputs in that feature folder.

Feature:
- Reservation state transitions and API implementation among the approved requirements

Relevant CTX Path(s):
- ctx/INDEX.md
- ctx/project-profile.ctx.md
- ctx/domain/*.ctx.md
```

### Greenfield start example

```text
/ctx-aidlc-run

This is a new project. There is no ctx yet.
Perform a greenfield requirements analysis based on team-ai-workflow.
Create aidlc-docs first, and organize the needed questions and unit-of-work.
Also propose an initial minimal ctx structure.

Feature:
- Build a new B2B approval-request processing system
- Users must be able to register requests, check status, and confirm results
- Operators must manage the approval policy and processing status
```
