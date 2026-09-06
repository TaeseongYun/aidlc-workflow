# Architecture Design

> Platform-agnostic reference for designing software structure that stays changeable:
> what decisions are load-bearing, how to compare styles, how to record a decision, and
> where a boundary earns its keep versus where it is speculative cost.
> Companion procedure: [`../SKILLS.md`](../SKILLS.md).

Architecture is the set of decisions that are expensive to reverse: where boundaries sit, who
owns which data, what talks to what and how. Good architecture is not the most structure but
the *least* that meets the real requirements and can still change when they do. Every
boundary, service, and abstraction must earn its keep against the simplest thing that works.

---

## Goals (in priority order)

1. **Change-friendliness** — the parts that will change independently can change independently, without a coordinated rewrite.
2. **Clear boundaries** — each part has one job and a small, explicit interface; you can reason about it without reading the rest.
3. **Fits real requirements** — sized to the load, consistency, and availability the system actually needs — not a speculative future one.
4. **Operability** — you can deploy, observe, and debug it in production.
5. **Simplicity** — the fewest moving parts that satisfy the above. A structure you don't need is a liability, not an asset.

A design that optimizes for an imagined future at the cost of today's clarity has failed.
Boundaries are bets; only place one where the change it isolates is likely.

---

## Levels of design

Design happens at nested scales; a decision at one level constrains the ones below it.

| Level | Unit | Decides | Cost to change |
| :---- | :--- | :------ | :------------- |
| **System** | Whole product + its externals | Which systems exist, who owns data, integration points | Highest |
| **Service / deployable** | A separately deployed process | Service boundaries, sync vs async, ownership | High |
| **Module** | A cohesive package within a deployable | Public interface, dependency direction | Medium |
| **Component / class** | A unit inside a module | Responsibilities, collaborators | Low |

Push decisions down to the cheapest level that can hold them: a component-level choice is a
refactor to undo; the same choice at system level is a migration.

---

## Load-bearing decisions

The ones worth slowing down for: each is expensive to reverse and shapes everything downstream.

| Decision | The question | Default when unsure |
| :------- | :----------- | :------------------ |
| **Module / service boundaries** | Where does one part end and the next begin? Do these change together? | Keep it in-process; split only when parts change or scale independently. |
| **Data ownership** | Who is the single writer of this data? Who reads it and how? | One owner per piece of data; others read via its interface, not its store. |
| **Sync vs async communication** | Does the caller need the result now, or can it react later? | Sync for a needed answer; async only when decoupling or load-leveling is real. |
| **State vs stateless** | Does this unit hold state between requests? | Stateless where possible; push state to a store you can scale and back up. |
| **Consistency model** | Must reads see the latest write immediately, or is eventual OK? | Strong within one owner's boundary; eventual across boundaries. |

A decision not on this list and not hard to reverse needs no deliberation — pick the obvious option and move on.

---

## Coupling and cohesion

The two forces that decide whether a structure stays changeable:

| Term | Definition | Aim for |
| :--- | :--------- | :------ |
| **Coupling** | How much one part must know about another to work. | **Low** — parts interact through small, stable interfaces. |
| **Cohesion** | How much the things inside one part belong together. | **High** — a part does one job; its pieces serve that job. |

Low coupling keeps a change local; high cohesion keeps a part understandable on its own, and
they reinforce each other. When a change forces edits in five "unrelated" places, coupling is
too high or cohesion too low — the signal that a boundary is in the wrong place.

---

## Dependency direction

A dependency is a compile- or run-time "needs to know about," and the direction of those
arrows is a design choice, not an accident.

**The dependency rule: dependencies point toward stability.** The things that change least —
core domain logic, policies, contracts — depend on nothing volatile. The things that change
most — UI, frameworks, external APIs, databases — depend inward on the stable core, never the
reverse. When the core needs something from the volatile edge, it declares an interface and
the edge implements it (dependency inversion), so the arrow still points inward. You can then
swap a database, framework, or vendor without touching domain logic. A dependency cycle means
neither module can change or be tested alone; break it by extracting the shared contract.

---

## Architecture styles

No style is "best." Each trades simplicity for some property; start at the top and move down
only when a concrete requirement forces it.

| Style | Core idea | Use when | Trade-off / cost |
| :---- | :-------- | :------- | :--------------- |
| **Modular monolith** | One deployable, strong internal module boundaries | Default for most systems; one team or a few; boundaries still shifting | Scales as one unit; discipline needed to keep modules from leaking |
| **Layered (n-tier)** | Presentation → domain → data, each depending downward | Simple CRUD-shaped apps; familiar to any team | Business logic drifts into the wrong layer; hard to test in isolation |
| **Hexagonal (ports & adapters)** | Domain core + interfaces (ports); externals are pluggable adapters | You must swap or mock externals; testability of core matters | More indirection; overkill if externals never change |
| **Event-driven** | Parts communicate via published events, not direct calls | Real decoupling, load-leveling, or many reactors to one fact | Eventual consistency; harder to trace and debug flows |
| **CQRS** | Separate write model from read model(s) | Read and write loads/shapes genuinely diverge | Two models to keep in sync; only pays off under real asymmetry |
| **Microservices** | Many small independently deployed services | Parts must scale, deploy, or be owned by teams independently | Network failures, distributed data, ops overhead — a real tax |

Prefer the highest row that meets the requirement: a modular monolith gives most of the
boundary benefit of microservices with none of the distributed-systems tax. Reach for
services only when independent scaling, deployment, or team ownership is a *present* need.

---

## Non-functional requirements

Functional requirements say what it does; these say how well, and they drive most
architecture decisions. Name the actual target — "P99 < 200ms," not "fast."

| NFR | The target to quantify | Architectural lever |
| :-- | :----------- | :------------------ |
| **Scalability** | How much load, and does it grow on read, write, or data? | Statelessness, partitioning, caching, async |
| **Availability** | What uptime, and what is the cost of downtime? | Redundancy, graceful degradation, failure isolation |
| **Latency** | What response time at what percentile? | Locality, caching, fewer network hops, async where the answer can wait |
| **Security** | What are the trust boundaries and the threat model? | Authz at boundaries, least privilege, encryption, blast-radius limits |
| **Cost** | What is the budget per request / per tenant? | Right-sizing, managed vs self-run, avoiding premature distribution |
| **Operability** | Can you deploy, observe, and debug it at 3am? | Logging, metrics, tracing, health checks, safe rollout/rollback |

You cannot maximize all of these; they trade against each other (availability vs
consistency, latency vs cost). Rank them for *this* system and design to the top two or
three — an NFR nobody has quantified is a wish, not a requirement.

---

## Architecture Decision Records (ADR)

Record decisions that are expensive to reverse so the next person knows *why*, not just
*what*. An ADR is short, immutable once accepted, superseded rather than edited, kept numbered in-repo.

```markdown
# ADR-007: Single relational store for orders and inventory

## Status
Accepted   (Proposed | Accepted | Superseded by ADR-NNN | Deprecated)

## Context
Orders and inventory are read/written together in checkout and need a consistent
view. Load is moderate; one squad owns both. Splitting stores now buys a
distributed transaction we have no reason for yet.

## Decision
One relational DB, separate schemas, behind separate modules. Revisit if either
exceeds its independent-scaling threshold.

## Consequences
+ Strong consistency in checkout for free; simple ops; one thing to back up.
- Both scale together; a future split is a migration — a known one-way door.
```

The value is the **Context** and **Consequences**: a decision without its reasoning is
noise, and one that hides its costs is a trap for whoever inherits it.

---

## Trade-offs and reversibility

The useful question is not "is this right?" but "how hard is this to undo?"

| Door type | Meaning | How to treat it |
| :-------- | :------ | :-------------- |
| **Two-way door** | Cheap to reverse; decide, ship, learn | Decide fast, don't over-analyze, don't write an ADR for it |
| **One-way door** | Expensive or impossible to reverse (data model, public API, service split, storage choice) | Slow down, write an ADR, get a second opinion, delay if you can |

Most decisions are two-way doors dressed up as one-way doors, and treating them as
irreversible is how teams stall. Name the door type before deciding: a one-way door chosen
lightly is the most expensive mistake here; a two-way door agonized over, the most common waste.

---

## YAGNI at the architecture level

"You aren't gonna need it" applies hardest here — architectural speculation is the most
expensive kind. Do **not** add a service, queue, cache, abstraction layer, second datastore,
or config knob for a need that is not present and concrete.

| Speculative move | What it actually costs | Do instead |
| :--------------- | :--------------------- | :--------- |
| Split into services "for scale" before load exists | Distributed-systems tax with no benefit | Modular monolith; split the one module that measurably needs it |
| Add a queue "to decouple" with one producer and one consumer | Async complexity, harder debugging, eventual consistency | Direct call until decoupling or load-leveling is real |
| Abstract behind an interface with one implementation | Indirection with no swap ever coming | Concrete class; extract the interface when the second implementation arrives |
| Add a cache before measuring | Invalidation bugs, stale reads | Measure; cache the proven hot path |
| Generic "plugin" framework for one plugin | A framework to maintain for no variance | Write the one case directly |

The test for any new structure: *what concrete, present requirement forces this?* If the
answer is "we might need it later," the answer is no — adding structure is cheap to defer
and expensive to remove, and later can add it with better information.

---

## How to review an architecture

| Lens | Ask |
| :--- | :-- |
| **Requirement fit** | Which real requirement drives each boundary and service? Any driven by speculation? |
| **Boundaries** | Do these parts change together? If yes, why are they split? If a change spans all of them, why are they separate? |
| **Data ownership** | Single writer per datum? Any part reaching into another's store? |
| **Dependency direction** | Do arrows point toward stability? Any cycles? Does the volatile edge leak into the core? |
| **Coupling / cohesion** | Would a likely change stay local, or ripple? Does each part do one job? |
| **NFR fit** | Are the ranked NFRs met by the design, with numbers — not adjectives? |
| **Reversibility** | Which decisions are one-way doors? Are those the ones with an ADR and extra scrutiny? |
| **Simplicity** | What can be removed and still meet the requirements? What is here "for later"? — the most valuable question, since deletion at design time is free and after build is a rewrite. |

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| **Speculative generality** | Abstractions, layers, and config for needs that never arrive; complexity with no payoff. | Build for the present requirement; generalize when the second case is real. |
| **Distributed monolith** | Services that must deploy together and share a database — all the ops cost of microservices, none of the independence. | Merge them back into a modular monolith, or give each true data ownership. |
| **Big-bang rewrite** | Replace the whole system at once; long dark period, high risk, requirements drift mid-flight. | Strangle incrementally: route slices to the new path, retire the old piece by piece. |
| **One-way door chosen lightly** | Irreversible decision (data model, public API, service split) made without an ADR or a second look. | Name the door type; write the ADR; get a second opinion before committing. |
| **Boundary by layer, not by change** | Splitting on technical layers when features cut across all of them, so every change touches every layer. | Draw boundaries around things that change together (features/domains), not tiers. |
| **Framework-driven design** | The framework's shape becomes the architecture; domain logic depends on it. | Keep the domain framework-free; the framework is an adapter at the edge. |

---

## References

- Martin Fowler — Software Architecture Guide: <https://martinfowler.com/architecture/>
- Fowler — *Patterns of Enterprise Application Architecture* (PoEAA)
- Robert C. Martin — *Clean Architecture* (dependency rule, boundaries, screaming architecture)
- Michael Nygard — "Documenting Architecture Decisions" (the ADR): <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>
- Skelton & Pais — *Team Topologies* (boundaries follow team cognitive load and ownership)
