# Units Generation

## Goal
- Decompose the requirements into implementable units of work.
- The AI leads the decomposition, and the human reviews and approves.

## Who decomposes

### AI proposes first, human approves
1. Based on the requirements and application-design artifacts, the AI **proposes first** a unit decomposition plan.
2. For each unit, it also presents the dependencies, preconditions, and expected number of questions.
3. The human reviews the unit composition and approves/adjusts it.
4. Having the human specify units directly is **not recommended**. If the human force-specifies the units, the AI's domain-cohesion judgment is ignored, causing the problem of heterogeneous features being bundled into a single unit.

### The human's role
- Feedback that "this unit is too large/too small"
- Adjusting unit execution order according to business priority
- Requesting unit merge/split (with rationale)

## Decomposition criteria
- Is the domain responsibility different
- Is the deployment unit different
- Is the team/role different
- Is the failure blast radius different
- Is the testing approach different

## Cohesion verification rules

After unit decomposition, verify cohesion by the criteria below. On violation, split the unit.

### Single-domain principle
- If a single unit contains 2 or more independent domains, consider splitting.
- Example: "chat + AI agent + file attachment + credit tracking" is 4 domains → split required.
- Judgment criterion: do these features necessarily operate together in the same transaction/request flow? Or can they be deployed/tested independently?

### Size verification based on question count
- Compute the expected number of questions per unit.
- **3 or fewer**: appropriate size
- **4-7**: caution — consider possibility of splitting
- **8 or more**: oversized — split required

### External integration separation
- Separate external API/system integrations into their own unit.
- Reason: prevents the constraints and instability of external systems from propagating into internal features.

## Default unit examples
- Domain foundation
- Admin/API
- User flow
- Payment/integration
- Notification
- Batch/scheduler
- Reporting/settlement

## Output format
- `unit-of-work.md`
- `unit-of-work-dependency.md`
- `unit-of-work-story-map.md`

## Rules
- Payment/refund/settlement are always reviewed as a separate unit.
- Notification/batch are treated as separate-unit candidates even when they depend on app features.
- If a common-module change is large, split it out into a separate unit.
- Record the **cohesion verification result** together with the unit decomposition result. If there are violations, explain the rationale at GATE-3.
