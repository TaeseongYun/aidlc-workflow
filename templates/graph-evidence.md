<!-- workflow-step: STEP-3..6.5 | producer: ctx-aidlc-run + ctx-architect-judge | condition: graph substrate available -->
# Graph Evidence

It is recommended to create this file at `aidlc-docs/features/<feature-slug>/graph-evidence.md`.

Grounding protocol: `common/graph-grounding.md`. This is a **snapshot** — the live graph keeps
changing, so record the code state a decision was made on. Update it (do not overwrite history) when
the graph is refreshed.

- Code revision: {git commit SHA}
- Graph updated at: {YYYY-MM-DD build timestamp}
- Feature: {feature-slug}

## Queries

The graph questions asked for this feature.

- "{question asked against the graph}"

## Confirmed (EXTRACTED — usable as code evidence)

- {NodeA → NodeB}
  - Confidence: EXTRACTED
  - Source: {path:line}

## Needs confirmation (INFERRED — re-check real source before relying on it)

- {NodeA → NodeB}
  - Confidence: INFERRED
  - Action: verify against actual source ({path})

## Ambiguous (AMBIGUOUS — converted to BLOCK questions)

- {entity pair} → question raised in requirements. If none, "none".

## Impact

- Communities: {affected graph communities}
- God nodes touched: {high-degree hub nodes}
- Reusable components: {existing nodes/modules to reuse}
- Expected tests: {regression tests implied by the impact}
