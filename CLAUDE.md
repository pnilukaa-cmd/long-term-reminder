# renewal-reminder

**Pitch:** An Android app that tracks expiry and renewal dates for the documents people forget about — passports, driving licences, insurance, MOT/registration, warranties, professional certifications — and reminds them early enough to actually do something about it.

## Template provenance

This project's `.claude/agents/` and orchestration skill were bootstrapped from
https://github.com/pnilukaa-cmd/agent-pipeline-template (local path at bootstrap
time: `/home/user/agent-pipeline-template`). The `retrospective` agent proposes
improvements back to that repository, not this one.

## The team

Nine agents, copied verbatim from the template. Their `.md` files are the source of truth for how each one works — this is only a map.

**Pre-launch, in pipeline order:**
- `researcher` — evidence: comparable products, platform guidelines, real tester feedback
- `product-manager` — vision, prioritization, scope calls, release readiness
- `ux-designer` — mockups, wireframes, interaction and visual direction
- `business-analyst` — requirements, user flows, acceptance criteria
- `developer` — implementation, technical feasibility, estimates
- `qa-tester` — test criteria, test runs, bug hunts
- `retrospective` — end of each cycle; proposes edits back to the template repo

**Post-release only** (do not spawn until something has actually shipped to a real device or a live URL):
- `growth` — store listing, positioning, distribution channels
- `insights` — measurement design and structured feedback mining

## Stack

**Not yet decided.** The `developer` agent owns this section and should fill it in as soon as a first technical decision is made — framework, language, state management, local storage, toolchain, CI.

Prior research (from the session that produced this project) points toward Flutter, local-only storage, local notifications rather than push, and RevenueCat for a one-time unlock — but none of that is a decision yet, and `developer` should confirm or overturn it rather than inherit it uncritically.

## Known constraints carried in from research

These came from the research that led to this project existing. They are inputs to decisions, not decisions themselves — challenge any of them if the evidence changes.

- **Monetization shape: one-time unlock, not ads or subscription.** At the target revenue scale, a one-time unlock needs roughly 10–25 sales a month; ad-supported needs 1,600–3,500 monthly active users for the same money. The unlock model also doesn't depend on retention.
- **Google Play gate:** personal developer accounts created after Nov 2023 must run a closed test with 12 testers, continuously opted in for 14 consecutive days, before a production release. This is calendar time on the critical path and should be scheduled, not discovered late.
- **Local-first is a real architectural argument, not a preference.** Play defines "collection" as data leaving the device; if nothing syncs, the Data Safety disclosure surface is much smaller.
- **Android 13+ requires a runtime permission for notifications.** Ask for it at a moment the user understands why — after they add their first item, not on first launch.
- **The main competitive risk is "why not just use a calendar reminder?"** The product's answer has to be the prompting and the cadence, not the storage. Whatever v1 becomes, it should make that answer obvious.

## Working agreements

Starting defaults, inherited from the template. This project's team can revise them as it learns what actually matters here.

- A feature isn't done until it actually runs — a real toolchain run, not a code read-through.
- Design before requirements, requirements before code, for anything with a real UI surface.
- Evidence over guesswork — loop in research before locking a plan when a decision would benefit from it.
- Every screen handles four states: loading, empty, error, success.
