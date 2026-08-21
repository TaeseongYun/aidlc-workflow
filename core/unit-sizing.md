# Unit Sizing

This is the sizing standard for units of work (UOW). Every UOW must be assigned exactly one of the sizes below.

## Sizing criteria

| Size | Criteria |
|------|------|
| **S** | Single-file or single-function level change. Within half a day. |
| **M** | Changes across multiple files, tests included. 1~2 days. |
| **L** | Module-level change, including external integration or migration. 3 days or more. |

## Size field rules
- The size field of every UOW is mandatory. Do not leave an empty value or a "S/M/L" placeholder.
- Before passing GATE-3, the size of every UOW must be filled in.
- If there is one or more M or L sized units, run technical design (STEP 6.5).
- If all are S sized, skip technical design.
