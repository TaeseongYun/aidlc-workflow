# Incident Response & Postmortem

> Platform-agnostic reference for handling production incidents and learning from them:
> how to classify severity, run the response, and turn the aftermath into durable fixes.
> Companion procedure: [`../SKILLS.md`](../SKILLS.md).

An *incident* is any unplanned disruption or degradation of a service that matters to users.
Incident response is the discipline of restoring service fast, then extracting every lesson
the incident is willing to teach. The two halves are inseparable: a fast fix that leaves the
cause in place buys a repeat outage. The goal is **restore, then learn** — not assign blame
and not close the ticket the moment the graphs go green.

---

## Goals (in priority order)

1. **Stop the harm** — restore service and stop data loss before anything else.
2. **Communicate** — keep users and stakeholders informed at a predictable cadence.
3. **Preserve evidence** — capture the timeline, logs, and metrics while they still exist.
4. **Find the systemic cause** — the condition that let this happen, not the person who tripped it.
5. **Prevent recurrence** — ship tracked action items that make this class of failure impossible or loud.

Mitigation outranks diagnosis. A reviewer who blocks a rollback to keep debugging in prod
has inverted the priority list. Understand *why* later; stop the bleeding *now*.

---

## Severity levels

Severity sets the response, not the blame. Declare it early and re-declare as you learn more —
over-declaring briefly is cheaper than under-declaring for an hour.

| Severity | Impact | Response expectation |
| :------- | :----- | :------------------- |
| **SEV1** | Full outage, data loss/corruption, or security breach; core function unusable for most users. | Page immediately, all-hands, Incident Commander named, continuous updates, exec awareness. |
| **SEV2** | Major degradation or a key feature down; workaround exists but users are clearly hurt. | Page on-call, IC named, updates every 30 min, resolve before deferring to normal work. |
| **SEV3** | Partial/minor degradation; limited users or non-critical path; no data risk. | Handle in business hours, ticket + owner, update stakeholders; no all-hands. |
| **SEV4** | Negligible user impact; cosmetic or internal-only; latent risk found before it bit. | Track as a normal bug/task; no incident bridge. Still worth a lightweight note if it revealed a gap. |

Rule of thumb: if you are debating whether it is SEV1 or SEV2, treat it as SEV1 until proven
otherwise. The cost of a false SEV1 is one apology; the cost of a missed one is the outage.

---

## Incident lifecycle

Run these phases in order, but expect to loop (a mitigation that fails sends you back to triage).

| Phase | Objective | Exit when |
| :---- | :-------- | :-------- |
| **Detect** | Notice the incident — alert, monitor, or user report. | Someone owns it and has declared a severity. |
| **Triage** | Assess blast radius, assign roles, open a channel/bridge. | IC named, severity set, comms started. |
| **Mitigate** | Stop the harm — roll back, fail over, feature-flag off, scale up. | User impact stopped or contained, even if the cause is unknown. |
| **Resolve** | Confirm full recovery; verify metrics are healthy and stable. | Service normal for a defined window; incident declared over. |
| **Review** | Blameless postmortem: timeline, causes, action items. | Postmortem published and action items assigned with owners + dates. |

The single most common failure is collapsing *mitigate* and *resolve* into "find and fix the
bug." They are different jobs with different urgency: mitigation buys time; resolution and
review use it.

---

## Roles

For anything SEV2 or worse, name roles explicitly. One person can hold two roles on a small
incident, but the roles are always named so nothing falls between them.

| Role | Owns | Does NOT do |
| :--- | :--- | :---------- |
| **Incident Commander (IC)** | Coordination, decisions, delegation, declaring severity and "resolved". | Debug hands-on — the IC directs, they don't disappear into a terminal. |
| **Comms / Scribe** | Status updates to stakeholders on cadence; timestamped log of actions and findings. | Make technical decisions; that is the IC's and Ops' job. |
| **Ops / Subject expert** | Hands-on mitigation and diagnosis; proposes and executes fixes. | Own coordination or comms; report to the IC and keep the scribe informed. |

The IC's job is to keep the response coherent, not to be the smartest engineer in the room.
If the IC is also head-down debugging, no one is steering — hand off the IC role first.

---

## Mitigate first

The instinct to understand the bug before touching anything is the wrong instinct during an
incident. Mitigation and root-cause analysis are separate phases for a reason.

| Situation | Mitigate-first move | Root-cause later |
| :-------- | :------------------ | :--------------- |
| Bad deploy | Roll back to last known-good. | Diff the release; find what broke. |
| Overload / traffic spike | Scale out, shed load, rate-limit. | Why did capacity planning miss this? |
| Bad feature/config | Toggle the flag off; revert the config. | Why did it pass review/canary? |
| Dependency down | Fail over, degrade gracefully, serve cached. | Harden the dependency or remove it. |

Prefer the reversible mitigation you can execute in minutes over the "correct" fix that takes
an hour to write and verify. Roll back first; write the real fix under no time pressure.

---

## Communication cadence

Silence during an incident reads as "no one is handling this." Predictable updates — even
"no change yet, next update in 30 min" — are the product of the comms role.

| Severity | Internal update cadence | External (status page) |
| :------- | :---------------------- | :--------------------- |
| SEV1 | Every 15–30 min, continuous bridge. | Post within minutes; update every 30 min until resolved. |
| SEV2 | Every 30 min. | Post if user-visible; update on state changes. |
| SEV3 | On state change; summary at close. | Usually internal only. |

A status update states: **what is affected, what you are doing, and when the next update
comes** — not a root-cause theory you are not yet sure of. Speculation posted to a status
page becomes a commitment you did not mean to make.

---

## The blameless postmortem

Every incident above trivial gets a written postmortem, and it is **blameless**: it describes
what happened and why the *system* allowed it, naming actions and conditions, never assigning
fault to individuals.

Blameless is not politeness — it is engineering. It exists **because**:

- People who fear punishment hide information; you lose the very facts the review needs.
- "Who" is almost never the useful lever. A competent engineer following normal process
  triggered the failure means the *process/system* let a normal action cause harm — that is
  the fixable thing.
- Punishing the individual leaves the trap set for the next person, who is equally human.

A postmortem that concludes "Alice pushed a bad config" has stopped one step short of the
finding: *the config had no validation and no canary, so any single push could take prod
down.* Fix the second sentence; the first is just where the trap happened to spring.

---

## Root-cause analysis

There is rarely one root cause. Complex failures are a chain of contributing factors that had
to line up; fixing any one of them breaks the chain. Hunting for a single cause is a bias to
resist.

| Technique | Use | Trap to avoid |
| :-------- | :-- | :------------ |
| **5 Whys** | Push past the surface symptom toward a systemic condition. | Stopping at "human error"; letting one chain hide the others. |
| **Contributing factors** | List every condition that had to hold for the incident to occur. | Treating the list as ranked blame instead of a set of fixes. |
| **Timeline analysis** | Reconstruct exactly what happened and when; find the detection and response gaps. | Editing the timeline to look tidier than reality was. |
| **Counterfactuals (careful)** | "What would have caught this?" to find missing guardrails. | Hindsight bias — "they should have known" is not a finding. |

Test any candidate root cause against: *if we fix only this, does this class of incident stop
recurring?* If the answer is "no, they'd just have to be more careful," you have found a
symptom, not the cause. "Be more careful" is not an action item — a validation check, a
canary, or an alert is.

---

## Building the timeline

The timeline is the spine of the postmortem; build it from evidence, not memory, and while it
is fresh. Capture, with UTC timestamps:

| Marker | What to record |
| :----- | :------------- |
| **Change** | The deploy/config/traffic event that set up the failure. |
| **Impact start** | When users were first actually affected (often before detection). |
| **Detection** | When and how you found out — and the gap from impact start (feeds MTTD). |
| **Key actions** | Each mitigation tried, who, when, and its effect. |
| **Mitigation** | When user impact stopped. |
| **Resolution** | When service was fully, stably normal. |

The gaps between these markers are where the lessons hide: a long impact-to-detection gap is a
monitoring problem; a long detection-to-mitigation gap is a runbook or access problem.

---

## Action items

A postmortem's output is action items — otherwise it is a story, not a fix. Every action item
has an **owner** and a **due date**, and is tracked to done like any other work.

| Property | Requirement |
| :------- | :---------- |
| Owner | A named person, not a team. A team owns nothing. |
| Due date | A real date, prioritized against other work — not "someday". |
| Tracked | Lives in the normal backlog/tracker; reviewed until closed. |
| Systemic | Changes the system (validation, canary, alert, capacity), not "we'll be careful". |
| Prioritized | Recurrence-preventing items compete with feature work honestly, by risk. |

An action item with no owner is a wish. Categorize each as *prevent* (stop the cause),
*detect* (find it faster next time), or *mitigate* (limit blast radius) — a healthy postmortem
produces some of each, not five "add more logging" lines.

> In this repo, durable engineering lessons from an incident or audit are also captured to
> `aidlc-docs/knowledge-log.md` by `/ctx-hallucination-audit`. Treat that log as the
> knowledge-capture parallel to postmortem action items: the postmortem tracks the *fixes*;
> the knowledge log records the *lesson* so the same wrong assumption is not repeated.

---

## Runbooks and on-call

The response is only as fast as the responder's ability to act. Two standing investments pay
off during every incident:

- **Runbooks** — per-alert playbooks: what the alert means, how to confirm, first mitigations
  to try, and who to escalate to. A runbook turns a 3am "what do I even do" into a checklist.
  Every recurring incident should leave its runbook better than it found it.
- **On-call** — a clear, humane rotation with defined escalation paths and the access needed
  to act. On-call without the permissions to roll back is a pager that only forwards panic.

---

## Metrics (use with care)

Measure the response to improve the system, never to rank responders. Incident metrics are
noisy and easy to game; a single bad week is data, not a verdict.

| Metric | Measures | Misuse warning |
| :----- | :------- | :------------- |
| **MTTD** (mean time to detect) | Impact start → detection. | Gaming by widening what counts as "detected"; small samples swing wildly. |
| **MTTR** (mean time to recover) | Detection → mitigation/resolution. | Conflating mitigate vs resolve inflates or hides it; averages hide the bad tail. |
| **MTBF** (mean time between failures) | Reliability trend over time. | Meaningless over short windows; discourages declaring small incidents. |
| **Change-failure rate** | Share of deploys causing an incident. | Punishing it suppresses deploys or discourages *declaring* incidents — worse than the metric. |

The most dangerous failure mode of every metric here is that punishing it teaches people to
stop *declaring* incidents. Under-reporting looks like improvement and is the opposite.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Instead |
| :----------- | :----------- | :------ |
| Blame culture | People hide facts; you lose the data the review needs. | Blameless postmortems; fix the system, not the person. |
| Root cause = "human error" | Stops one step short of the fixable systemic gap. | Ask why a normal human action could cause harm; fix that. |
| Action items with no owner | Nothing happens; the incident recurs. | Named owner + due date, tracked to done. |
| Skipping the postmortem for "small" incidents | Repeat near-misses; the pattern is never seen. | Lightweight review for small ones; every incident teaches something. |
| Debugging in prod before mitigating | Prolongs user pain to satisfy curiosity. | Roll back / fail over first; diagnose from evidence after. |
| No comms during an incident | Stakeholders assume it's unhandled; trust erodes. | Predictable cadence, even "no change yet". |
| Single-cause bias | Fixing one factor leaves the chain intact. | Enumerate contributing factors; break the chain in more than one place. |

---

## References

- Google SRE Book — Postmortem Culture: Learning from Failure: <https://sre.google/sre-book/postmortem-culture/>
- Google SRE Book — Managing Incidents: <https://sre.google/sre-book/managing-incidents/>
- PagerDuty Incident Response documentation: <https://response.pagerduty.com/>
- "Blameless PostMortems and a Just Culture" — John Allspaw, Etsy: <https://www.etsy.com/codeascraft/blameless-postmortems/>
