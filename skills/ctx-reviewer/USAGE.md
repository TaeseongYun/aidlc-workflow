# How to Use ctx-reviewer

## Usage Summary

1. Invoke the Skill with the `/ctx-reviewer` command
2. Provide the referenced CTX list and the review target code
3. Specify the Executor execution mode
4. The Skill judges whether there is a CTX violation and rule recurrence, and returns the result

---

## Normal Review Invocation Example (ARCHITECT_CONFIRMED)

````
/ctx-reviewer

## Referenced Global CTX
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## Referenced Local CTX
- ctx/back-end/domain/notification.ctx.md

## Review Target Code
```java
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    @Transactional
    public void markAsRead(Long notificationId) {
        Notification notification = notificationRepository.findById(notificationId)
            .orElseThrow(() -> new NotFoundException("Notification not found."));
        notification.markAsRead();
    }

    @Transactional(readOnly = true)
    public List<NotificationDto> findByUserId(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId)
            .stream()
            .map(NotificationDto::from)
            .toList();
    }
}
```

## Executor Execution Mode
- ARCHITECT_CONFIRMED
````

**Expected output:**

## 1. CTX Violation Judgment
- No violation

## 1b. Graph Impact Conformance
- Not applicable

## 2. List of Identified Rules
- Rule A: When looking up notifications, sort in descending order by creation date

## 3. CTX Reflection Classification Result
- Rule A → Local CTX

## 4. CTX Reflection Proposal List
### Proposal 1
- Target file path: ctx/back-end/domain/notification.ctx.md
- Insertion location: lookup rules section
- Sentence to add: "When looking up the notification list, sort in descending order by creation date (createdAt)."
- AI malfunction if omitted: The AI looks up without sorting or sorts in ascending order, so the latest notification is displayed at the bottom

---

## EXECUTOR_ONLY Review Invocation Example

````
/ctx-reviewer

## Referenced Global CTX
- ctx/back-end/api/api-design.ctx.md
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## Referenced Local CTX
- ctx/back-end/domain/grade.ctx.md

## Review Target Code
```java
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/grades")
public class GradeController {

    private final GradeService gradeService;

    @GetMapping("/{userId}")
    public ResponseEntity<GradeDto> getGrade(@PathVariable Long userId) {
        Grade grade = gradeService.findByUserId(userId);
        return ResponseEntity.ok(GradeDto.from(grade));
    }
}
```

## Executor Execution Mode
- EXECUTOR_ONLY
````

**Expected output:**

## 1. CTX Violation Judgment
- Violation exists
- Violated rule: "All API responses are returned wrapped in CommonResponse."
- Code where violation occurred: `return ResponseEntity.ok(GradeDto.from(grade));`

## 1b. Graph Impact Conformance
- Not applicable

## 2. List of Identified Rules
- None

## 3. CTX Reflection Classification Result
- Not applicable

## 4. CTX Reflection Proposal List
- None

## EXECUTOR_ONLY Warning Mark
- The reviewed code was executed without Architect pre-judgment
- Whether Global CTX is complied with is included in the verification scope

---

## Incorrect Invocation Example (case that stops)

````
/ctx-reviewer

## Referenced Global CTX
- See the API response rules

## Referenced Local CTX
- Grade-related CTX

## Review Target Code
```java
// only an excerpt of the code
gradeService.findByUserId(userId);
```

## Executor Execution Mode
- (not specified)
````

**Expected output:**

## Review Halted

Halt reason:
- The referenced CTX list was provided as descriptive text rather than file paths
- The review target code was only partially provided (the full context cannot be understood)
- The Executor execution mode is not specified

Items that need confirmation:
1. The exact paths of the Global CTX files (e.g., ctx/back-end/api/api-response.ctx.md)
2. The exact paths of the Local CTX files
3. The full class/method of the review target code
4. The Executor execution mode (ARCHITECT_CONFIRMED or EXECUTOR_ONLY)
