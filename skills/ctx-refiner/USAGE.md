# ctx-refiner Usage Examples

## Normal Invocation Example (success)

### Input

```markdown
## Refinement Target CTX
- File paths:
  - ctx/global/coding-conventions.ctx.md

## Refinement Purpose
- Generate the final rule set before development

## Applicable Scope
- Global CTX
```

### Output

```markdown
## Deleted Rules

### Deletion 1
- Rule sentence: "Write code with readability in mind."
- Deletion reason: ambiguous (Q3 failure: cannot be made concrete as a single imperative sentence)

### Deletion 2
- Rule sentence: "Strive to write good code."
- Deletion reason: not directly connected to AI malfunction (Q1 failure)

### Deletion 3
- Rule sentence: "Develop with performance in mind."
- Deletion reason: ambiguous (Q2 failure: does not lead to a specific error)

## Merged Rules

### Merge 1
- Before merge:
  - Rule A: "Attach the @Entity annotation to Entity classes."
  - Rule B: "JPA Entities must declare @Entity."
- After merge:
  - Rule C: "Declare the @Entity annotation on Entity classes."

## Final CTX

### Coding Conventions

- Rule: "Declare the @Entity annotation on Entity classes."
  - Without this rule the AI would: omits @Entity so JPA does not recognize the class and table mapping fails

- Rule: "Specify @JoinColumn on association fields."
  - Without this rule the AI would: omits JoinColumn and unpredictable FK column names are generated

- Rule: "Repository interfaces extend JpaRepository."
  - Without this rule the AI would: extends CrudRepository and paging/sorting methods are missing

## Refinement Judgment

- Rule count before refinement: 8
- Rules after refinement: 3
- Reduction rate: 62.5%
- Judgment: success
- Reason: rule count reduced by 62.5%, malfunction stated for every rule, no explanatory sentences
```

---

## Normal Invocation Example (failure)

### Input

```markdown
## Refinement Target CTX
- File paths:
  - ctx/local/user-service.ctx.md

## Refinement Purpose
- Refine the service-layer rules

## Applicable Scope
- Local CTX
```

### Output

```markdown
## Refinement Failed

- Failure reason:
  - The rule count did not decrease substantially (reduction rate 5%)
  - Only 1 rule is deletable; all the rest are directly connected to AI malfunction

- Rule count before refinement: 20
- Current rule count: 19
- Reduction rate: 5%
```

---

## Incorrect Invocation Example (stopped)

### Input

```markdown
## Refinement Target
- ctx/global/coding.md

## Purpose
- Cleanup
```

### Output

```markdown
## Refinement Stopped

Stop reason:
- Input format mismatch: the `Refinement Target CTX`, `Refinement Purpose`, and `Applicable Scope` section format is not followed

Items that need confirmation:
1. Use the `## Refinement Target CTX` section with the `- File paths:` format
2. Add the `## Refinement Purpose` section
3. In the `## Applicable Scope` section, specify one of Global CTX | Local CTX | mixed
```
