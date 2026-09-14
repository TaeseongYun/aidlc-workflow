# Session Separation Notice (template)

Emitted by `ctx-aidlc-run` after a Phase-ending GATE passes, appended after the
GATE approval message. Loaded lazily at that moment (see SKILL.md SESSION MANAGEMENT).

```markdown
---
### Session Separation Notice

Phase {current} work is complete. The current depth level is **{depth}**.

> {comprehensive: "Please start a new session (required)." / standard: "Starting a new session is recommended." / minimal: "You may continue in this session."}

Enter the following in the next session to continue with Phase {next}:

\`\`\`
/ctx-aidlc-run

Start Phase {next}.
Read aidlc-state.md first and check the current state.

Related outputs:
- {list of the previous Phase's key output paths}
\`\`\`
```

Post-notice behavior by depth:
- comprehensive: after the notice, **stop responding and wait for the user's next session**.
- standard: after the notice, if the user says "continue", work may proceed in the same session.
- minimal: output only the notice and automatically continue with the next Phase.
