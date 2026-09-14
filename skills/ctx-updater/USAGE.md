# ctx-updater Usage Examples

## Normal Invocation Example

### Input

```markdown
## CTX Reflection Proposal List

### Proposal 1
- Target file path: CLAUDE.md
- Insertion location: end of the ## 📐 Coding Conventions > ### ✅ Java Code Style section
- Sentence to add: - Always specify the `@JoinColumn` annotation on association fields of Entity classes.
- AI malfunction if omitted: When mapping associations, the AI omits JoinColumn and unpredictable column names are generated.
```

### Output

```markdown
## CTX Reflection Result

### Reflection Success
| Proposal No. | File | Insertion Location | Added Sentence |
|-----------|------|-----------|-------------|
| 1 | CLAUDE.md | end of the ## 📐 Coding Conventions > ### ✅ Java Code Style section | - Always specify the `@JoinColumn` annotation on association fields of Entity classes. |

### Reflection Failure (if any)
None

### Reflection Summary
- Total proposals: 1
- Success: 1
- Failure: 0
```

---

## Incorrect Invocation Example (stopped)

### Input

```markdown
## CTX Reflection Proposal

### Proposal 1
- File: CLAUDE.md
- Location: somewhere in the coding conventions
- Sentence: add a JoinColumn-related rule
```

### Output

```markdown
## CTX Reflection Stopped

Stop reason:
- Input format mismatch: the required items `Target file path`, `Insertion location`, `Sentence to add`, and `AI malfunction if omitted` are missing

Stopped proposal:
- Proposal No.: 1
- Target file: cannot be identified
```
