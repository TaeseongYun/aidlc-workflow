# Architecture Design — Skills

Actionable procedure an agent (or engineer) runs to design or evaluate software structure.
This is the *how*; the *what/why* reference is [`reference/guide.md`](reference/guide.md).

- **Related aidlc skills**: `/ctx-architect-judge` (decide domain scope + CTX references before designing), `/ctx-domain-exec` (judge affected domains before development work).
- **Platform-agnostic**: applies on any stack. Platform architecture baselines live in `platforms/<platform>/guidance.md`.
- **Siblings**: [`../code-review/reference/guide.md`](../code-review/reference/guide.md) (reviewing the resulting code), [`../testing-strategy/reference/guide.md`](../testing-strategy/reference/guide.md) (proving the design behaves).

## When to use

Before a change that crosses module/service boundaries, introduces a new pattern, adds a
service/queue/datastore, or changes data ownership. Also when reviewing such a proposal. A
change that lives inside one module and touches no boundary does not need this — just build it.

## Inputs

- The requirement (required) — the functional need and the ranked non-functional targets (load, latency, availability, consistency), with numbers where they exist. If missing, ask before designing.
- Current structure — the existing modules/services, data owners, and dependency directions the change touches.
- Constraints — team shape, deadline, existing platform baseline (`platforms/<platform>/guidance.md`).

## Outputs

- A design at the right level (system / service / module / component) with named boundaries and data owners.
- An ADR for each one-way-door decision — Context / Decision / Consequences / Status.
- A one-line simplicity justification: what was *not* added, and the concrete need that would trigger it.

## Procedure

1. **State the requirement in one line**, plus the top two or three ranked NFRs with numbers.
   If you cannot, stop and ask — you cannot size a design against an unknown load.
2. **Climb the simplicity ladder.** Ask in order: Does this need to exist at all (YAGNI)?
   Does the current structure already hold it? Can it stay in one module? Only add a
   boundary/service/queue/store when a *present, concrete* requirement forces it.
3. **Pick the level.** Push the decision to the cheapest level that can hold it (component <
   module < service < system). Do not solve at system level what a module split solves.
4. **Place boundaries by change, not by layer.** Group things that change together; split
   things that change or scale independently. If a likely change would span all the parts,
   the boundary is wrong.
5. **Assign data ownership.** One writer per datum; others read via its interface, never its
   store. Name the owner for each piece of data the change touches.
6. **Set dependency direction.** Arrows point toward stability — volatile edges depend on the
   stable core, never the reverse. Check for cycles; break any you find.
7. **Choose a style** from the guide's table only if the default (modular monolith) doesn't
   fit. Name the concrete requirement that forces the more complex style.
8. **Classify each decision as a one-way or two-way door.** Decide two-way doors fast. For
   one-way doors, write an ADR and get a second opinion before committing.
9. **Review against the guide's lenses** and emit the design + ADRs.

## Decision rules

- No present, concrete requirement forces the structure → **do not add it**; note what would trigger it later.
- Decision is a **two-way door** → decide fast, no ADR, move on.
- Decision is a **one-way door** (data model, public API, service split, storage choice) → **write an ADR**, get a second opinion; delay if you can.
- Parts change together but are split → **merge them** (or justify the split by independent scaling/deployment/ownership).
- One implementation only → **concrete, no interface**; extract the interface when the second implementation is real.
- "Might need it later" → **no**; later can add it with better information.

## Stop / escalate

- Requirement or NFR targets unknown → ask the owner; do not design against a guessed load.
- Decision is a business/policy one (data retention, tenancy model, region/compliance) → escalate to a human owner; an agent must not commit policy.
- A proposed one-way door has no clear present need → stop and question whether it should exist at all.
- Change spans many teams/services → this is a system-level decision; surface it, don't decide it solo.

## Output format

```markdown
## Design: <title>  —  level: <system | service | module | component>

Requirement: <one line>
Top NFRs: <e.g. P99 < 200ms; 99.9% availability; strong consistency in checkout>

### Structure
- Boundaries: <parts and why each is separate — the change it isolates>
- Data ownership: <owner per datum>
- Dependency direction: <arrows point toward … ; cycles: none>
- Style: <modular monolith | … > — forced by <requirement>

### Decisions
- [two-way] <decision> — decided, no ADR
- [one-way] <decision> — see ADR-NNN

### Simplicity
- Not added: <service/queue/abstraction> — add when <concrete trigger>
```

## Quick checklist

- [ ] Requirement + ranked NFRs stated with numbers
- [ ] Simplicity ladder climbed; nothing added without a present, concrete need
- [ ] Decision made at the cheapest level that holds it
- [ ] Boundaries drawn by what changes together, not by layer
- [ ] One writer per datum; others read via interface
- [ ] Dependencies point toward stability; no cycles
- [ ] Each decision classified one-way / two-way; ADR for every one-way door
- [ ] Stated what was *not* added and what would trigger it
