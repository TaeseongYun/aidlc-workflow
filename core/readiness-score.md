# Readiness Score

This is the standard for quantitatively evaluating whether requirements.md is at an implementable level.

## Scoring areas

### 1. Feature scope definition (15 points)
- The Goal is clear (5)
- In-Scope / Out-of-Scope are distinguished (5)
- There are no BLOCK questions about scope (5)

### 2. Policy/exception finalization (20 points)
- Core business policies are specified (10)
- There is a policy for handling exceptions/errors/cancellations (5)
- There are no policy-related BLOCK questions (5)

### 3. User scenarios (15 points)
- The main user types are identified (5)
- The core scenarios are described (5)
- Edge cases are identified (5)

### 4. NFR confirmation (15 points)
- Performance requirements are confirmed or "not applicable" is specified (5)
- Security/authorization requirements are confirmed (5)
- Operational requirements (notifications, monitoring, batch) are confirmed (5)

### 5. Resolution of approval items (20 points)
- All items listed in Approval Preconditions are resolved (10)
- There are 0 BLOCK questions (10)
- If even one BLOCK remains, this area is capped at 5 points

### 6. Risk assessment (15 points)
- Risks are identified (5)
- Each risk has a mitigation plan or an acceptance judgment (5)
- The impact on the existing system (brownfield) is understood (5)

### 7. User story quality (conditional bonus, max 10 points)
- This area is scored only when GATE-2.5 is triggered.
- If GATE-2.5 is not triggered, skip this area and do not include it in the total.
- The personas reflect actual user types (3)
- The user stories satisfy the INVEST criteria (4)
- The Acceptance Criteria are verifiable in Gherkin format (3)

### 8. System structure design (conditional bonus, max 10 points)
- This area is scored only when GATE-2.7 is triggered.
- If GATE-2.7 is not triggered, skip this area and do not include it in the total.
- Component identification and separation of responsibilities are appropriate (4)
- The service layer and API boundaries are clear (3)
- The dependency matrix has no cycles (3)

## Verdict criteria

| Score | Verdict | Meaning |
|------|------|------|
| 80~100 | READY | Implementable. 0 BLOCK questions. |
| 60~79 | CONDITIONAL | Conditional proceed. ASSUME assumptions must be specified in status.md. |
| 0~59 | NOT_READY | Implementation prohibited. BLOCK questions need resolution. |

The verdict criteria are applied against a base of 100 points.
When conditional bonus areas (7, 8) are activated the maximum increases, but the verdict thresholds (80/60) are converted using the ratio based on the base 100 points.
- Example: when base 100 points + 20 bonus points = 120 points maximum, the READY threshold is 96 points (120 × 80%).

## Timing of computation
- Compute it after STEP 5 (requirements authoring) completes and before STEP 7 (stop judgment).
- Record it in the Readiness Score table of `status.md`.
- If the score is below 60, keep the status as `questions-open`.

## Structured schema
Schema for automated scoring and programmatic reference: `core/readiness-score.schema.yaml`

## Rules
- If there is even one BLOCK question, the "Resolution of approval items" area is capped at 5 points.
- Do not arbitrarily change a BLOCK to ASSUME in order to raise the score.
- Record the score together with rationale. Do not write the number alone.
- Score conditional bonus areas only when the corresponding GATE is triggered. Areas that are not triggered are excluded from the maximum calculation.
- When scoring a conditional bonus area, if the corresponding artifact was omitted, mark it as "not applicable" rather than 0 points.
