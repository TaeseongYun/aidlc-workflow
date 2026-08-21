# Stage Gate Rules

## Purpose
Place an explicit approval gate at the completion of each major artifact to prevent entering the next stage in an unconfirmed state.

## Items Requiring Approval

The following items are not finalized before human approval.

- API response shape
- Refund/cancellation policy
- Settlement criteria
- Discount priority
- Permission/role rules
- Operator manual-intervention points
- External integration methods
- New project policies not present in `ctx/`

Stages requiring approval:
- Requirements finalization
- Application design finalization
- NFR finalization
- Implementation scope finalization

## Gate List

| Gate | Trigger Timing | Review Target | Pass Condition |
|--------|----------|----------|----------|
| GATE-0 | _roadmap.md writing complete | _roadmap.md | Triggered only for a multi-feature prepared-requirement. The user confirms the feature decomposition/dependencies/shared resources and approves or requests changes. Without approval, per-feature entry into ctx-aidlc-run is blocked. |
| GATE-1 | planning-draft writing complete | planning-draft.md | Triggered only for a raw-request. The user confirms the draft and approves or requests changes. |
| GATE-2 | requirements + questions writing complete | requirements.md, requirement-verification-questions.md | All BLOCK questions are resolved, or the user has explicitly approved conditional progress. |
| GATE-2.5 | user-stories writing complete | personas.md, stories.md | Conditionally triggered. When User Scenarios >= 3 or a new user type exists. The user confirms the personas and stories and approves or requests changes. |
| GATE-2.7 | application-design writing complete | components.md, services.md, component-dependency.md | Conditionally triggered. When UOW >= 3 is expected or new components are created. The user confirms the system structure and approves or requests changes. |
| GATE-3 | unit-of-work writing complete | unit-of-work.md | The user confirms the work decomposition and approves or requests changes. |
| GATE-3.5 | technical-design writing complete | technical-design.md | Triggered only when there are M/L-sized units. The user confirms the technical design and approves or requests changes. |
| GATE-4 | infrastructure-design writing complete | infrastructure-design.md, deployment-architecture.md | Conditionally triggered. When infrastructure changes are needed. The user confirms the infrastructure design and approves or requests changes. |
| GATE-5 | build/test-instructions writing complete | build-instructions.md, test-instructions.md | Conditionally triggered. When there are M/L-sized units. The user confirms the build/test guide and approves or requests changes. |

## Gate Rules

### Do-Not-Proceed Conditions
- If the user does not explicitly approve at a gate, do not proceed to the next stage.
- Do not move on with silence in place of explicit approval such as "keep going."
- Before approval, present a summary of the artifact content to the user.

### Gate Skipping (Whitelist)

A gate may be skipped only under the conditions specified in the table below. Gates not in the table are not skipped under any classification or condition.

| Gate | Skippable Condition |
|--------|--------------|
| GATE-0 | single-feature (multi-feature not detected) |
| GATE-1 | `prepared-requirement` or `change-on-existing-feature` |
| GATE-2.5 | User Scenarios < 3 AND no new user type |
| GATE-2.7 | UOW < 3 expected AND no new components |
| GATE-4 | No infrastructure changes |
| GATE-5 | All S-sized |

#### Explicitly Non-Skippable Gates
- **GATE-0** (Roadmap): Required for a multi-feature prepared-requirement. Once triggered, it is not skipped even by a user's batch approval.
- **GATE-2** (Requirements): Required for all request classifications. Not skippable even for a `prepared-requirement`.
- **GATE-3** (Unit-of-Work): Required for all requests.
- **GATE-3.5** (Technical Design): Required if there is 1 or more M/L-sized UOW. It is only left un-triggered when everything is S-sized.

#### User Batch Approval
- If the user specifies "skip gate" or "approve all," only the skippable gates in the table above may be batch-skipped.
- GATE-2 / GATE-3 / GATE-3.5 are not skipped even if the user specifies batch approval. At each of these gates, present the artifact summary and obtain separate confirmation.

## Standard Approval Message Format

Upon reaching a gate, output a message with the structure below.

```markdown
## [Stage Name] Complete

> **Progress**: {Request Anchor summary} → Current: {current stage} → Next: {next stage}

### Artifact Summary
- [Core content summary — fact-focused, 2-5 items]

### Review Request
> Please review the following files:
> - `aidlc-docs/features/<feature-slug>/[filename]`

### Next Steps
> A) Request changes — let us know what needs to be changed
> B) Approve and continue — proceed to the next stage ([next stage name])
```

### Format Rules
- Write the artifact summary short and fact-focused. Do not mix in workflow guidance phrasing.
- State the path of the file to review.
- Always provide only 2 choices (request changes / approve and continue).
- Do not arbitrarily add 3 or more choices or extra options.

## Audit Log Integration

Record in `audit.md` when a gate is passed. In addition to gates, also record on STEP start/complete/skip, user question answers, and state changes. Refer to `templates/audit.md` for the full logging triggers and format.

```markdown
## [GATE-N] [Stage Name]
- Timestamp: [ISO 8601]
- Feature: <feature-slug>
- Gate: GATE-N
- Decision: approved / change-requested / skipped
- User Input: "[user's verbatim input]"
- Notes: [summary of the request content when a change is requested]
```

### Audit Log Rules
- Record user input verbatim. Do not summarize or paraphrase.
- Use ISO 8601 format for timestamps.
- Always append to audit.md. Do not overwrite existing content.

## Per-Gate Review Items

### GATE-0: Roadmap
- Is the feature decomposition appropriate as responsibility units (no heterogeneous domains mixed into one feature)?
- Are all ⚠-marked items (duplicate resources) in the resource matrix resolved or extracted into `foundation-*`?
- Are there no circular dependencies in the dependency graph?
- Does the division-of-work recommendation distinguish parallelizable groups from mandatory serial segments?
- Does each feature slug follow the kebab-case naming convention?
- Is the `aidlc-state.md` Cross-Feature Dependencies table synchronized?

### GATE-1: Planning Draft
- Do the goal/background reflect the original request intent?
- Is nothing missing from the scope/policy draft?
- Are the success metrics measurable?

### GATE-2: Requirements
- Does it include functional/policy/operational perspectives?
- Are the BLOCK question answers complete?
- Is the Out-of-Scope clear, and are risks identified?
- If the Readiness Score is below 60, keep implementation prohibited even if the gate passes

### GATE-2.5: User Stories
- Do the personas reflect actual user types?
- Do the user stories meet the INVEST criteria?
- Are the Acceptance Criteria verifiable in Gherkin format?
- Are the relationships/permission boundaries between personas clear?

### GATE-2.7: Application Design
- Is the component identification appropriate and the responsibilities clear?
- Is the service layer separation reasonable?
- Are there no cycles in the dependencies?
- Brownfield: whether connection points to the existing structure are stated

### GATE-3: Unit of Work
- Is the work-unit decomposition appropriate?
- Are the dependency relationships/size estimates reasonable?
- Are the acceptance criteria verifiable?
- All UOW size fields (S/M/L) must be filled in to pass

### GATE-3.5: Technical Design
- Are the ADR decisions grounded (not guesses)?
- Is the API response shape explicit and complete?
- Are data model changes compatible with the existing schema?
- Does the module structure match the UOW decomposition?
- Are there no implicit design decisions left?

### GATE-4: Infrastructure Design
- Does the resource configuration meet the requirements?
- Are the security/network settings appropriate?
- Is the cost estimate reasonable?
- Are there a migration plan and a rollback strategy?

### GATE-5: Build & Test Instructions
- Is the build procedure reproducible?
- Does the per-UOW build order reflect the dependencies?
- Do the test scenarios cover the Acceptance Criteria?
- Are the edge-case/exception tests and Quality Gate criteria clear?
- If all gates pass + Readiness Score is 80 or above, it is in an implementable state
