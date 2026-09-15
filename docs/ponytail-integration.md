# Ponytail Integration Guide

[ponytail](https://github.com/DietrichGebert/ponytail) is a plugin that makes AI agents **write less code**.
On the principle that "the best code is the code you never write," it runs code through a
7-rung decision ladder before writing it, preventing over-engineering.

Its area of responsibility differs from team-ai-workflow, so the two **complement without overlapping**.

```text
┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│ team-ai-workflow   │   │ OMC / Ouroboros    │   │ ponytail           │
│ - requirements/dsgn│ → │ - automation loop   │ + │ - 7-rung trim ladder│
│ - human GATE        │   │ - repeated verify   │   │ - remove over-eng   │
└────────────────────┘   └────────────────────┘   └────────────────────┘
      (What)                   (How, automation)          (Trim, thin the How)
```

- **What** — what to build: team-ai-workflow (CTX + GATE)
- **How** — how to run it automatically: OMC / Ouroboros
- **Trimming** — how little to build while still building it: ponytail

All three areas share the principle that **humans approve gates**. ponytail only reduces code
volume; it never trims requirements, design, or safety.

---

## 1. Where It Plugs In

In team-ai-workflow, the one place code is actually written is `ctx-domain-exec`.
ponytail's trimming acts right before that point, and `ctx-reviewer` checks the result.

```text
/ctx-aidlc-run            ← requirements/design (GATE-2/3, human approval)
  ↓ (GATE-3 passed)
/ctx-architect-judge      ← no trimming (scope judgment)
/ctx-domain-exec          ← ★ apply the 7-rung ladder just before writing code
/ctx-reviewer             ← ★ over-engineering check (maps to /ponytail-review)
/ctx-updater ~ /ctx-commit-planner ← no trimming
```

The source of the trimming rules is in [`core/lazy-implementation.md`](../core/lazy-implementation.md).
`ctx-domain-exec` applies the ladder and `ctx-reviewer` checks it, based on this document.
**Even without installing the ponytail plugin**, you get the trimming effect from these rules alone.

---

## 2. The 7-Rung Trimming Ladder

Before writing new code, question it from the top down and stop at the first rung where you can.

1. Does this code need to exist? → If not, don't build it (YAGNI)
2. Is it already in the codebase? → Reuse it (prefer CTX reusable components)
3. Does the standard library do it? → Use it
4. Is it a built-in platform/framework feature? → Use it
5. Does an already-installed dependency do it? → Use it
6. Can it be one line? → Do it in one line
7. Only then, write the minimum code that works

Safety guards (validation / security / data protection / accessibility / AC satisfaction / business policy)
are never trimmed by the ladder. For details and precedence, see [`core/lazy-implementation.md`](../core/lazy-implementation.md).

---

## 3. How to Use It — Three Levels

Pick one of three depending on how heavily you want to apply it. Higher up takes less effort;
lower down is more powerful.

### 3-A. Rules Only (No Plugin Install, Default Recommendation)

`ctx-domain-exec` applies it automatically based on `core/lazy-implementation.md`.
No extra install is needed, and it follows along on other accounts/repos just by running install-skills.sh.

```text
/ctx-domain-exec
Implement based on the following outputs. Apply the 7-rung ladder from core/lazy-implementation.md (full).
- aidlc-docs/features/<slug>/requirements.md
- aidlc-docs/features/<slug>/unit-of-work.md
```

### 3-B. Inject into the OMC autopilot/ralph Prompt

When delegating automatic implementation to OMC, state the ladder explicitly in the autopilot/ralph prompt.

```text
/oh-my-claudecode:autopilot

Implement based on the following outputs. GATE-3 passed.
- aidlc-docs/features/<slug>/requirements.md
- aidlc-docs/features/<slug>/unit-of-work.md

Implementation constraint: apply the 7-rung trimming ladder from core/lazy-implementation.md.
- Before writing new code, first check for reuse/stdlib/existing dependencies.
- However, never omit input validation·security·data protection·AC satisfaction.
Repeat until each AC in unit-of-work.md passes. After implementation, verify with ctx-reviewer.
```

### 3-C. Actually Install the ponytail Plugin (Optional)

If you need dedicated commands like `/ponytail-review`, `/ponytail-audit`, `/ponytail-gain` and
measured metrics, install the plugin. Installation **changes the user environment**, so run it yourself.

```text
# Add from the Claude Code marketplace (run with the ! prefix in the shell, or directly)
/plugin marketplace add DietrichGebert/ponytail
```

Dedicated commands used after installation:

| Command | Purpose | aidlc-workflow linkage |
|------|------|--------------------|
| `/ponytail [lite\|full\|ultra\|off]` | Adjust trimming intensity | Match it to the ROLE 1 intensity |
| `/ponytail-review` | Over-engineering deletion candidates in the current diff | Call from ROLE 3 REVIEWER |
| `/ponytail-audit` | Scan the whole repo for unnecessary code | On legacy cleanup / brownfield entry |
| `/ponytail-debt` | Organize deferred `ponytail:` notes into a ledger | §4 organizing trimming notes |
| `/ponytail-gain` | Show savings metrics (LOC/cost/speed) | For effect reporting |

The plugin requires Node.js on PATH for its lifecycle hooks to work.

---

## 4. Intensity (mode) Mapping

Map ponytail's intensity modes to aidlc-workflow task types.

| ponytail mode | Meaning | Recommended task |
|--------------|------|----------|
| `lite` | Apply lightly | Simple changes (change-on-existing-feature) |
| `full` | Standard (default) | General feature implementation |
| `ultra` | Maximum trimming | Legacy cleanup / large-scale refactoring |
| `off` | Disabled | Prototyping and other deliberate code expansion |

The default is `full`. Regardless of intensity, safety guards are always maintained.

---

## 5. Conflict-Avoidance Rules

When team-ai-workflow + OMC/Ouroboros + ponytail operate in the same repo.

### 5-1. Responsibility Boundary

- **Before GATE-3** (requirements/design), do not apply ponytail.
  The goal of this stage is not minimizing volume but **no omissions**.
- Apply the trimming ladder **only after GATE-3** (implementation).

### 5-2. Safety Guards First

- When trimming and safety conflict, **safety always wins**.
- Input validation / security / data protection / accessibility / AC / business policy cannot be
  dropped on the grounds of "I reduced it to one line." If they are dropped, that is not trimming
  but a defect, and ROLE 3 blocks it.

### 5-3. State Directory

- The notes/ledger ponytail produces (`ponytail:` comments, `/ponytail-debt` output) do not
  overwrite `aidlc-docs/`.
- Trimming-related decisions may be appended to `aidlc-docs/audit.md` on one line with a `[PONYTAIL]` prefix.

### 5-4. Precedence (top wins)

1. Safety guards + `core/core-workflow.md` §13 prohibitions
2. CTX facts + approved requirements / technical-design
3. Human GATE decisions
4. ponytail trimming ladder

---

## 6. Recommended Scenarios

| Scenario | Recommended combination |
|---------|-----------|
| Light trimming with rules only | `/ctx-domain-exec` (core/lazy-implementation.md applied automatically) |
| Automatic implementation + trimming | `/ctx-aidlc-run` → `/oh-my-claudecode:autopilot` (inject the ladder) |
| Need metrics / dedicated commands | Install the ponytail plugin + `/ponytail-review`, `/ponytail-gain` |
| Cleaning up legacy/over-engineered code | ponytail `ultra` + `/ponytail-audit` |
| Simple change | `/ctx-domain-exec` + `lite` |

---
---
