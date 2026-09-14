# ctx-commit-planner Usage Examples

## Normal Invocation Example (single commit)

### Input

```markdown
## Change Description
- Added a user grade lookup API
- Implemented the grade lookup method in GradeService
- Added the endpoint to GradeController

## Changed File List
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/admin/grade/GradeController.java
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/admin/grade/GradeService.java
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/admin/grade/dto/GradeResponse.java
```

### Output

```markdown
## Commit Design Result

### Commit 1
- title: feat: (grade) add user grade lookup feature
- body:
  - Administrators need to be able to look up user grades
  - Implement the grade lookup service method and controller endpoint
  - Grade update/delete features are not included in this commit
- include:
  - GradeController.java (lookup endpoint)
  - GradeService.java (lookup method)
  - GradeResponse.java (response DTO)
- exclude:
  - Grade create/update/delete code
  - Test code

## Commit Order Explanation
- A single commit contains the entire grade lookup feature
```

---

## Normal Invocation Example (multiple commits)

### Input

```markdown
## Change Description
- Refactored the inquiry feature
- Added an inquiry type Enum
- Split the inquiry service logic
- Changed the controller response format
- Added related test code

## Changed File List
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/cscenter/InquiryType.java (new)
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/cscenter/InquiryService.java
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/cscenter/InquiryController.java
- center/back-end/src/test/java/com/nhnad/ohdasiyoung/cscenter/InquiryServiceTest.java (new)
```

### Output

```markdown
## Commit Design Result

### Commit 1
- title: refactor: (cscenter) add inquiry type enum
- body:
  - Inquiry types need to be managed in code
  - Create the new inquiry type Enum class
  - Applying it to the service/controller proceeds in the next commits
- include:
  - InquiryType.java (new Enum)
- exclude:
  - InquiryService.java
  - InquiryController.java
  - Test code

### Commit 2
- title: refactor: (cscenter) apply type enum to inquiry service
- body:
  - The inquiry service needs to use the new type Enum
  - Change the existing string-based type handling to the Enum
  - Controller changes proceed in the next commit
- include:
  - InquiryService.java (type Enum applied)
- exclude:
  - InquiryController.java
  - Test code

### Commit 3
- title: refactor: (cscenter) improve inquiry controller response format
- body:
  - A consistent response format needs to be provided to clients
  - Reflect the type Enum in the controller response
  - Test code is added in the next commit
- include:
  - InquiryController.java (response format change)
- exclude:
  - Test code

### Commit 4
- title: test: (cscenter) add inquiry service unit tests
- body:
  - The refactored service logic needs verification
  - Write new unit tests for the inquiry service
  - Controller tests are not included in this commit
- include:
  - InquiryServiceTest.java (new tests)
- exclude:
  - Controller tests
  - Integration tests

## Commit Order Explanation
- Commit 1 → 2: the Enum must exist first so the service can reference it
- Commit 2 → 3: after the service change, the controller reflects that change
- Commit 3 → 4: tests are added after the feature implementation is complete
```

---

## Incorrect Invocation Example (halted)

### Input

```markdown
## Change Description
- Fixed various things

## Changed File List
- Several files
```

### Output

```markdown
## Commit Design Halted

- Halt reason: the change information is insufficient
- Problem points:
  - The change description "Fixed various things" is ambiguous
  - The changed file list "Several files" is not specific
  - There is no information to separate the changes into commit units
```

---

## Halt Example (unclear include/exclude boundary)

### Input

```markdown
## Change Description
- Full refactoring of UserService and UserController
- Method renames, logic separation, and response format changes are mixed together

## Changed File List
- UserService.java
- UserController.java
```

### Output

```markdown
## Commit Design Halted

- Halt reason: the include/exclude boundary cannot be drawn clearly
- Problem points:
  - Method renames, logic separation, and response format changes are mixed in the same files
  - To commit each change type separately, the changes must be broken down further
  - With the current information, separation into meaningful units is impossible
```
