# How to Use ctx-domain-exec

## Usage Summary

### Selection Criteria by Execution Mode

| Mode | When to Use | Global CTX | Local CTX |
|------|----------|------------|-----------|
| ARCHITECT_CONFIRMED | When Architect judgment results exist | Per the judgment result | Per the judgment result |
| EXECUTOR_ONLY | When Architect judgment is omitted | Forced reference | User-specified |

### Workflow

1. **Recommended**: Perform judgment first with `/ctx-architect-judge`
2. Pass the judgment result to `/ctx-domain-exec` for implementation
3. **Exceptional**: Use EXECUTOR_ONLY only when a single domain is certain

---

## ARCHITECT_CONFIRMED Invocation Example

```
/ctx-domain-exec

## Execution Mode
- ARCHITECT_CONFIRMED

## Architect Judgment Result

### 1. Affected Domain List
- Grade: The user grade lookup feature belongs to the Grade domain

### 2. Local CTX That Must Be Referenced
- ctx/back-end/domain/grade.ctx.md

### 3. Whether Global CTX Is Impacted
- Impacted
- Compliance with the ctx/back-end/api/api-response.ctx.md response format is required

### 4. Points That Cannot Be Judged / Require Additional Confirmation
- None

## Task Requirements
- Add a method to GradeService that looks up the grade by user ID
- Return the default grade (BRONZE) if no grade exists
```

**Expected output:**

## Execution Mode Declaration
- ARCHITECT_CONFIRMED

## Implementation Summary
- Referenced Global CTX: ctx/back-end/api/api-response.ctx.md
- Referenced Local CTX: ctx/back-end/domain/grade.ctx.md

## Implementation Content

```java
@Service
@RequiredArgsConstructor
public class GradeService {

    private final GradeRepository gradeRepository;

    public Grade findByUserId(Long userId) {
        return gradeRepository.findByUserId(userId)
            .orElse(Grade.defaultBronze(userId));
    }
}
```

## CTX Compliance Confirmation
Confirmed that the implementation above does not go beyond the CTX scope provided as input.

---

## EXECUTOR_ONLY Invocation Example

```
/ctx-domain-exec

## Execution Mode
- EXECUTOR_ONLY

## Task Requirements
- Add a mark-as-read method to NotificationService
- Look up by notification ID and update the readAt field to the current time

## User Guarantee Declaration (required)
- I guarantee this task is limited to a single domain scope
- I specify the Local CTX to reference directly

## Global CTX (forced reference)
- ctx/back-end/api/api-design.ctx.md
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## Local CTX (optional reference)
- ctx/back-end/domain/notification.ctx.md
```

**Expected output:**

## Execution Mode Declaration
- EXECUTOR_ONLY

## Implementation Summary
- Referenced Global CTX: ctx/back-end/api/api-design.ctx.md, ctx/back-end/api/api-response.ctx.md, ctx/back-end/api/error-handling.ctx.md
- Referenced Local CTX: ctx/back-end/domain/notification.ctx.md

## Implementation Content

```java
@Transactional
public void markAsRead(Long notificationId) {
    Notification notification = notificationRepository.findById(notificationId)
        .orElseThrow(() -> new NotFoundException("Notification not found."));
    notification.markAsRead();
}
```

## CTX Compliance Confirmation
Confirmed that the implementation above does not go beyond the CTX scope provided as input.

## Judgment-Omitted Notice
- Architect judgment was omitted
- All Global CTX was referenced and complied with
- Local CTX suitability depends on the user's declaration

---

## Incorrect Invocation Examples (cases that stop)

### Example 1: Global CTX section missing in EXECUTOR_ONLY

```
/ctx-domain-exec

## Execution Mode
- EXECUTOR_ONLY

## Task Requirements
- Implement the payment cancellation feature

## User Guarantee Declaration (required)
- I guarantee this task is limited to a single domain scope
- I specify the Local CTX to reference directly

## Local CTX (optional reference)
- ctx/back-end/domain/kcp-payment.ctx.md
```

**Expected output:**

## Execution Stopped

Stop reason:
- The Global CTX section is missing in EXECUTOR_ONLY mode
- Global CTX must always be referenced and cannot be omitted

Items that need confirmation:
1. Please add the Global CTX (forced reference) section and request again
2. Please include the project's Global CTX list

---

### Example 2: Points that cannot be judged exist in ARCHITECT_CONFIRMED

```
/ctx-domain-exec

## Execution Mode
- ARCHITECT_CONFIRMED

## Architect Judgment Result

### 1. Affected Domain List
- Settlement: settlement processing feature
- Payment: payment integration feature

### 2. Local CTX That Must Be Referenced
- ctx/back-end/domain/settlement.ctx.md
- ctx/back-end/domain/kcp-payment.ctx.md

### 3. Whether Global CTX Is Impacted
- Impacted

### 4. Points That Cannot Be Judged / Require Additional Confirmation
- The transaction boundary between the Settlement and Payment domains is unclear
- The payment rollback policy on settlement failure is not specified in the CTX

## Task Requirements
- Change the payment status when settlement completes
```

**Expected output:**

## Execution Stopped

Stop reason:
- The Architect judgment result contains "Points that cannot be judged / require additional confirmation"
- Unresolved points:
  1. The transaction boundary between the Settlement and Payment domains is unclear
  2. The payment rollback policy on settlement failure is not specified in the CTX

Items that need confirmation:
1. Please clearly define the transaction boundary between the two domains
2. Please decide the payment rollback policy on settlement failure and add it to the CTX
3. After the above items are resolved, please perform the Architect judgment again

---

### Example 3: Possibility of multiple domains detected (EXECUTOR_ONLY)

```
/ctx-domain-exec

## Execution Mode
- EXECUTOR_ONLY

## Task Requirements
- Send a notification when a friend registers a program

## User Guarantee Declaration (required)
- I guarantee this task is limited to a single domain scope
- I specify the Local CTX to reference directly

## Global CTX (forced reference)
- ctx/back-end/api/api-design.ctx.md
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## Local CTX (optional reference)
- ctx/back-end/domain/friends.ctx.md
```

**Expected output:**

## Execution Stopped

Stop reason:
- A possibility of multiple domains was detected in EXECUTOR_ONLY mode
- The requirement "send a notification when a friend registers a program" affects the following domains:
  1. Friends domain (friends)
  2. Program domain (program registration)
  3. Notification domain (notification sending)
- The single-domain guarantee does not match the actual requirement

Items that need confirmation:
1. Please use `/ctx-architect-judge` to judge the domain scope first
2. Or split the requirement into a single-domain scope and request again
