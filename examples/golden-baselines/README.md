# Golden Baselines

A reference output set for detecting quality regressions when the workflow changes.

## Usage

```bash
# Run the validation tool against a specific baseline
bash tools/evaluator/validate-all.sh examples/golden-baselines/standard-feature
```

After modifying workflow rules, confirm that all 3 baselines pass.

## Baseline List

| Baseline | Depth | Scenario | Characteristics |
|----------|-------|---------|------|
| `minimal-bugfix/` | minimal | Bug fix reusing an existing pattern | 3 or fewer questions, most conditional STEPs skipped, 1 UOW |
| `standard-feature/` | standard | Mid-sized new feature | 7 or fewer questions, proceeds through GATE-3, 3–5 UOWs |
| `comprehensive-platform/` | comprehensive | Large-scale platform feature | 12 questions, all GATEs active, 5+ UOWs, technical design included |

## Baseline Update Principles

- When workflow rules change, update the baselines together.
- Back up the existing baselines before updating.
- Record the reason for the update in the changelog.
