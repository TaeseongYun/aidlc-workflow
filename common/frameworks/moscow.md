# MoSCoW Prioritization

A framework that organizes scope by classifying requirements into 4 levels.

## Classification

### Must Have
- Cannot release without this.
- Legal requirements, core business logic, data integrity.

### Should Have
- Important, but release is still possible without it.
- A workaround exists or it can be replaced by manual handling.

### Could Have
- Nice to have, but can be excluded under schedule pressure.
- UX improvements, convenience features, additional notifications.

### Won't Have (this time)
- Explicitly excluded from this scope.
- Recorded as a candidate for future review.

## Usage Example

| Requirement | Classification | Rationale |
|----------|------|------|
| Apply repurchase discount | Must | Core business goal |
| Discount history dashboard | Should | Can be replaced by manual lookup |
| Discount recommendation algorithm | Could | Review after MVP |
| Third-party point integration | Won't | Not in this scope |

## requirements.md Connection
- Must → In-Scope (Functional Requirements)
- Should → In-Scope (marked as lower priority)
- Could → Out-of-Scope (recorded as future review)
- Won't → Out-of-Scope (explicit exclusion)

## Notes
- Classification is decided by a human. The AI does not judge Must/Should arbitrarily.
- If the classification criteria are unclear, raise it as a question.
- Won't means "not doing it this time," not "not doing it." Record it rather than delete it.
