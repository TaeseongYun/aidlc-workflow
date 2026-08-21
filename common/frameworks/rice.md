# RICE Prioritization

A framework that quantitatively evaluates feature priority.

## Formula

```
RICE Score = (Reach x Impact x Confidence) / Effort
```

## Item Definitions

### Reach
- The number of users/transactions affected by this feature within a given period
- Example: "Exposed to about 5,000 repurchasing customers per quarter"

### Impact
- The size of the effect on an individual user/transaction
- 3: massive / 2: high / 1: medium / 0.5: low / 0.25: minimal

### Confidence
- The strength of the evidence behind the estimates above
- 100%: data-based / 80%: based on similar cases / 50%: gut-feel level

### Effort
- The amount of team work required for implementation (person-months)
- Example: 2 = 2 people for 1 month, or 1 person for 2 months

## Usage Example

| Feature | Reach | Impact | Confidence | Effort | Score |
|---------|-------|--------|------------|--------|-------|
| Repurchase discount | 5000 | 2 | 80% | 2 | 4000 |
| VIP tier | 500 | 3 | 50% | 3 | 250 |

## Notes
- RICE is a priority comparison tool, not an implementation decision tool.
- Even with a high Score, a feature cannot be implemented if there is a BLOCK question.
- Always record the figures used to compute the Score together with their rationale.
