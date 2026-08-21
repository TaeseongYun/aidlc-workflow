<!-- workflow-step: all steps & gates | producer: ctx-aidlc-run, ctx-aidlc-roadmap | append-only -->
# Audit Log

Audit log writing rules:
- Timestamps use ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)
- Record user input verbatim (no summarizing/paraphrasing)
- Always append after existing content (no overwriting)
- **Record on every STEP start/completion, every GATE pass, and every user input (including question answers)**
- **Phase 0 (Roadmapping) events, GATE-0, and handoffs** are recorded under the same rules.

## Logging Triggers (mandatory)

When the events below occur, they must be appended to audit.md.

### 1. STEP start/completion
Record on entering and completing each STEP. Also record the skip reason when a conditional STEP is skipped.
For Phase 0 STEPs, write the ID as `STEP-R1` ~ `STEP-R6`, and record the Feature field as `roadmap` (the stage before a feature is determined).

```markdown
## [STEP-N] [step name] — [started / completed / skipped]
- Timestamp: [ISO 8601]
- Feature: <feature-slug>  # "roadmap" for Phase 0 stages
- Step: STEP-N
- Action: started / completed / skipped
- Reason: [reason when skipped. e.g. "entire scope is S", "applies to existing user types only", "single-feature"]
- Outputs: [list of files created/updated]
```

### 2. GATE pass
Record at each GATE on user approval / change request / skip.
GATE-0 (Roadmap Review) uses the same format, and the Feature field is recorded as `roadmap`.

```markdown
## [GATE-N] [step name]
- Timestamp: [ISO 8601]
- Feature: <feature-slug>  # "roadmap" for GATE-0
- Gate: GATE-N
- Decision: approved / change-requested / skipped
- User Input: "[user's verbatim text]"
- Notes: [summary of the requested changes when a change is requested]
```

### 3. User input (question answers)
Record when the user answers a BLOCK/ASSUME question or responds in a Discovery round.

```markdown
## [ANSWER] question answer
- Timestamp: [ISO 8601]
- Feature: <feature-slug>
- Question: [question ID or summary]
- User Input: "[user's verbatim text]"
- Impact: [BLOCK released / ASSUME confirmed / Discovery info gathered]
```

### 4. Status change
Record when a feature status changes (e.g. questions-open → approved).

```markdown
## [STATUS] status change
- Timestamp: [ISO 8601]
- Feature: <feature-slug>
- Previous: [previous status]
- Current: [current status]
- Trigger: [event that caused the change]
```

### 5. Handoff (switching between skills)
Record when one skill hands work over to another skill and blocks.
Representative case: `ctx-aidlc-run` STEP 1-A detects multi-feature → guides running `ctx-aidlc-roadmap`.

```markdown
## [HANDOFF] [from-skill] → [to-skill]
- Timestamp: [ISO 8601]
- Feature: <feature-slug or roadmap>
- From: ctx-aidlc-run
- To: ctx-aidlc-roadmap
- Reason: [e.g. "multi-feature detected, _roadmap.md absent"]
- Resume Hint: [follow-up command or next-step guidance]
```

---

## [timestamp] Feature Start
- Feature: <feature-slug>
- Raw user request captured.
- Workspace scan completed.
- Initial requirement gaps identified.

---
