# renewal-reminder

**Pitch:** An Android app for the renewals that actually hurt when you miss them — MOT, insurance, passport, professional registration. It reminds you on a ladder that starts early enough to act, and keeps track of whether you've actually done it.

**Positioning (revised after first research pass — read this before scoping):** this is deliberately *not* an all-in-one document tracker, and "everything stays on your phone" is not the pitch. Both of those are the category default: at least eight named competitors already claim whole-category coverage, and all of them already lead with the local-only privacy claim. One (Travel Document Vault) already ships a staggered passport reminder ladder.

The defensible ground is narrower: **high-consequence renewals, a cadence that escalates properly, and follow-through state** — knowing that you were reminded, and whether you acted. Breadth and privacy are table stakes to match, not reasons anyone switches.

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

**Decided (2026-08-21) — see `docs/technical/04-scheduling-and-stack.md` for the full reasoning, citations, and device-verification checklist.**

- **Framework:** Flutter, confirmed (not overturned) against the prior research default.
- **Scheduling:** no exact alarms — inexact `AlarmManager` (`flutter_local_notifications`, `AndroidScheduleMode.inexactAllowWhileIdle`) plus a self-healing reconciliation pass (on app launch, and via a `workmanager` periodic background task) that recomputes and re-arms/cancels notifications from the local database, rather than trusting any single scheduling call to survive reboot/update/force-stop. `05-permissions.html`'s exact-alarm screens (p4–p6) are cut from the build.
- **Local storage:** `drift` (type-safe SQL over `sqflite`).
- **Billing:** direct Play Billing via Flutter's official `in_app_purchase` plugin — **this overturns** the prior RevenueCat default; single one-time non-consumable SKU, Android-only in v1, doesn't need RevenueCat's cross-platform/subscription complexity. Revisit if an iOS port ever happens.
- **Notification permission:** still required (Android 13+ runtime permission), unchanged from known constraints.
- One real residual risk that's architectural, not solvable by code: a force-stopped app has all pending alarms/background work cancelled by Android's own design until the user manually reopens it. Self-heal-on-launch repairs this the moment the app is reopened, but there's no way to prevent the gap if the app stays force-stopped through a due date. This needs to be named in Settings/help copy, not silently assumed away.

## Known constraints carried in from research

These came from the research that led to this project existing. They are inputs to decisions, not decisions themselves — challenge any of them if the evidence changes.

- **Monetization shape: one-time unlock, not ads or subscription.** At the target revenue scale, a one-time unlock needs roughly 10–25 sales a month; ad-supported needs 1,600–3,500 monthly active users for the same money. The unlock model also doesn't depend on retention.
- **Google Play gate:** personal developer accounts created after Nov 2023 must run a closed test with 12 testers, continuously opted in for 14 consecutive days, before a production release. This is calendar time on the critical path and should be scheduled, not discovered late.
- **Local-first is a real architectural argument, not a preference.** Play defines "collection" as data leaving the device; if nothing syncs, the Data Safety disclosure surface is much smaller.
- **Two Android permission gates, not one.** Android 13+ requires a runtime permission for notifications, *and* Android 13/14+ deny `SCHEDULE_EXACT_ALARM` by default to non-exempt apps. The second lands directly on the app's core job — firing a reminder months out. `developer` should establish early what actually survives Doze and inexact alarms, because the answer may constrain the whole cadence design.
- **The calendar objection is only partly answerable, and we should not pretend otherwise.** Prospective-memory research gives a real mechanical argument that a bare calendar entry underperforms — it doesn't bind to an actionable moment and doesn't escalate when dismissed. But no organic user voices were found describing calendar reminders actually failing them for these documents. Treat "cadence design plus follow-through state" as the strongest available answer, not an evidence-backed one.
- **Notification fatigue caps how hard we can lean on reminding.** Users disable notifications or uninstall after as few as 2–6 unwanted pushes a week. "Remind harder" is a losing strategy; the ladder has to earn each interruption.
- **Do not chase live-data vehicle apps.** UK competitors (Autodue, PitSync, CarFile) pull live DVLA data, which a local-only app structurally cannot match. Explicit v1 de-scope.

## Working agreements

Starting defaults, inherited from the template. This project's team can revise them as it learns what actually matters here.

- A feature isn't done until it actually runs — a real toolchain run, not a code read-through.
- Design before requirements, requirements before code, for anything with a real UI surface.
- Evidence over guesswork — loop in research before locking a plan when a decision would benefit from it.
- Every screen handles four states: loading, empty, error, success.
