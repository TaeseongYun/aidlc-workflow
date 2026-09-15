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
Commit 1
- Order rationale: a single commit contains the entire grade lookup feature
- include:
    - GradeController.java (lookup endpoint)
    - GradeService.java (lookup method)
    - GradeResponse.java (response DTO)
- exclude:
    - Grade create/update/delete code
    - Test code
- message:
  feat: (grade) add user grade lookup feature

  [Background] administrators need to be able to look up user grades

  [Changes]
  - implement the grade lookup service method
  - add the controller endpoint and response DTO

  [Excluded] grade update/delete features are not included
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
Commit 1
- Order rationale: the Enum must exist first so the service can reference it
- include:
    - InquiryType.java (new Enum)
- exclude:
    - InquiryService.java
    - InquiryController.java
    - Test code
- message:
  refactor: (cscenter) add inquiry type enum

  [Background] inquiry types need to be managed in code

  [Changes]
  - create the new inquiry type Enum class

  [Excluded] applying it to the service/controller proceeds in the next commits

Commit 2
- Order rationale: after the Enum exists, the service can switch to it
- include:
    - InquiryService.java (type Enum applied)
- exclude:
    - InquiryController.java
    - Test code
- message:
  refactor: (cscenter) apply type enum to inquiry service

  [Background] the inquiry service needs to use the new type Enum

  [Changes]
  - change the existing string-based type handling to the Enum

  [Excluded] controller changes proceed in the next commit

Commit 3
- Order rationale: after the service change, the controller reflects that change
- include:
    - InquiryController.java (response format change)
- exclude:
    - Test code
- message:
  refactor: (cscenter) improve inquiry controller response format

  [Background] a consistent response format needs to be provided to clients

  [Changes]
  - reflect the type Enum in the controller response

  [Excluded] test code is added in the next commit

Commit 4
- Order rationale: tests are added after the feature implementation is complete
- include:
    - InquiryServiceTest.java (new tests)
- exclude:
    - Controller tests
    - Integration tests
- message:
  test: (cscenter) add inquiry service unit tests

  [Background] the refactored service logic needs verification

  [Changes]
  - write new unit tests for the inquiry service

  [Excluded] controller tests are not included
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
