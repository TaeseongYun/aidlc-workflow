# Lazy Implementation

This document is the **shared rule for minimizing the amount of code at the implementation step**.
Its source is the "lazy senior developer" philosophy of [ponytail](https://github.com/DietrichGebert/ponytail),
transcribed so that it does not conflict with aidlc-workflow's CTX, gate, and overconfidence-prevention rules.

> Core principle: **"The best code is the code you never wrote."**
> But: **"Be lazy about the solution, never lazy about reading."** To write less code,
> read the problem and the existing code more deeply.

Apply this rule **right before writing new code (mainly `ctx-run`'s ROLE 1 — IMPLEMENTOR)**.
Do not apply it during the requirements analysis/design steps (before ROLE 0, before GATE-3).
"What to build" at those steps is already controlled by human gates.

---

## 1. The 7-Rung Decision Ladder

Before writing even a single new line of code, ask yourself top-down, in order.
If you can stop at a higher rung, do not descend to a lower one.

1. **Does this code need to exist?** — if not, don't build it (YAGNI).
2. **Is it already in this codebase?** — if so, reuse it. Don't rewrite it.
3. **Does the standard library do it?** — if so, use the standard library.
4. **Is it a platform/framework built-in feature?** — if so, use that.
5. **Does an already-installed dependency do it?** — if so, use that.
6. **Can it be one line?** — if so, do it in one line.
7. **Only then** write the minimum working code yourself.

Relation to CTX priority:
- Rung 2 (codebase reuse) is directly linked to the **reusable component list** in `ctx/`.
  If a reuse candidate is specified in the CTX, use it first.
- Rungs 4·5 (built-in features/existing dependencies) are judged based on the
  **tech stack and allowed dependencies** in `ctx/project-profile.ctx.md`.
- Adding a new dependency follows the dependency-management rule (specify the reason in the PR description) as-is.
  Do not arbitrarily add a dependency using the ladder as an excuse.

---

## 2. Safety Guards (things never trimmed)

Laziness applies only to the **amount of the solution**. The following cannot be trimmed by the ladder.

- **Trust-boundary validation** — input validation, authorization checks, authentication (`core/input-validation.md`).
- **Data-loss prevention** — transaction boundaries, rollback, idempotency.
- **Security** — no secret exposure, injection prevention, least privilege.
- **Accessibility** — a11y requirements when there is a user screen.
- **Requirements fulfillment** — the Acceptance Criteria in `requirements.md`.
- **Business policy** — payment/refund/settlement/authorization/notification are always a human decision (`core/core-workflow.md` §13).

Omitting any of the above on the grounds that you "reduced it to one line" is a defect, not laziness.

---

## 3. When it applies and when it does not

### It applies
- In `ctx-run` ROLE 1 (IMPLEMENTOR), right before writing production code.
- When delegating implementation to OMC autopilot / ralph (inject the ladder into the prompt).
- In refactoring/extension work, when about to rebuild existing code (rung 2 takes priority).

### It does not apply
- Requirements analysis, question generation, UOW decomposition, technical design (before GATE-3).
  The goal of artifacts at these steps is **no omissions**, not amount.
- For test code (ROLE 2), **coverage/reproducibility** takes priority over laziness.
  However, reduce duplicate tests and unnecessary mocks.
- Code that falls under the safety guards (§2).

---

## 4. Restraint note (deferred shortcut)

While applying the ladder, if a "keep it minimal for now but worth revisiting later" situation arises,
leave a clue of the following form in the code and record one line in `aidlc-docs/audit.md`.

```
// ponytail: <what was reduced / reason to revisit later>
```

- This note is a **deferral of a decision**, not an omission.
- When consolidating them for review, use `/ponytail-debt` if the ponytail plugin is installed, or,
  if it is not installed, check them manually in ROLE 3 (REVIEWER).

---

## 5. Checks at review time (ROLE 3 linkage)

ROLE 3 — REVIEWER (`ctx-reviewer`), in addition to checking CTX violations, confirms the following.

- Is there a place where you could have stopped at rungs 1~6 but descended to rung 7 (writing it yourself)?
- Is there newly written code where a reusable existing component was available?
- Was any §2 safety guard dropped on the grounds of "restraint"? (This is blocked with priority over restraint violations.)

If the ponytail plugin is installed, you can use `/ponytail-review` to scan the diff and
receive a list of deletion candidates. If it is not installed, perform the above checks manually.

---

## 6. Intensity and modes

If you use the ponytail plugin together, you can adjust the intensity. Even without the plugin,
you can specify the same meaning in the ROLE 1 prompt.

| Mode | Meaning | aidlc-workflow recommendation |
|------|------|--------------------|
| `lite` | Apply the ladder lightly | Simple change (change-on-existing-feature) |
| `full` | Standard application (default) | General feature implementation |
| `ultra` | Maximum restraint for heavily over-engineered code | Legacy cleanup / large-scale refactoring |
| `off` | Restraint disabled | When intentionally increasing code, e.g. prototyping |

The default is `full`. Regardless of intensity, the §2 safety guards are always maintained.

---

## 7. Priority relative to other workflow rules

On conflict, the priority is as follows (higher wins).

1. Safety guards (§2) and the `core/core-workflow.md` §13 prohibitions.
2. CTX facts (`ctx/`) and the approved `requirements.md` / `technical-design.md`.
3. Human gate (GATE) decisions.
4. This document's restraint ladder (§1).

In other words, the restraint ladder is a rule that makes you pick the **least code** among
"several equally-correct implementations"; it is not authority to trim requirements, design, or safety.
