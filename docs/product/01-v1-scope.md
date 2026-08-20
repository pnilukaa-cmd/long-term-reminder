# V1 Scope — renewal-reminder

Prepared by: product-manager
Date: 2026-08-20
Inputs: `/home/user/renewal-reminder/CLAUDE.md` (pitch, positioning, constraints), `docs/research/00-problem-space.md`
Routed to: ux-designer (mockups), business-analyst (requirements), developer (build + technical spikes), qa-tester (test criteria)

**Framing this brief operates under:** this is a capability proof (ship, clear Play's gate, take a payment), not a business plan. Revenue target is ~$500/year (~10–25 sales/month at $2.99–$4.99). The dominant failure mode for solo first projects is over-scoping. Every cut below is deliberate and biased toward shipping smaller.

---

## 1. V1 definition

A single-user, local-only Android app that tracks a small set of high-consequence renewal types, reminds on an escalating ladder as the due date approaches, and tracks whether the user actually confirmed they renewed. No accounts, no sync, no live data lookups.

### In scope (P0 — must ship)

- **Add/edit/delete a renewal item**: type (from 6 presets, see §3), label, due date, optional notes.
- **6 preset types**, each with an icon and a default reminder ladder: Passport/Travel ID, Insurance, Professional Licence/Certification, Vehicle (registration/tax/MOT — generic, manual entry, no live lookup), Warranty, Custom/Other.
- **Reminder ladder**: multiple staged local notifications counting down to the due date, type-aware defaults (exact intervals are a UX-design decision, see §6).
- **Follow-through state**: after the due date passes without the item marked "done," continue nagging on a reduced cadence until the user confirms or dismisses.
- **Mark as done / renewed**: clears current cycle; for types the user expects to recur, prompt to set the next due date.
- **List/home screen**: all items with status (upcoming / due soon / overdue / done), including the true first-run empty state.
- **Local notifications**, with the Android 13+ notification permission request flow handled explicitly.
- **One-time unlock (paywall)** — see §2.
- **Local-only storage.** No account, no cloud, no sync. Nothing leaves the device.
- Every screen (list, add/edit, detail, paywall, permission prompts) covers loading/empty/error/success per working agreement.

### Explicitly out of v1 (deferred, not forgotten)

| Cut | Why | Revisit |
|---|---|---|
| OCR / scan-to-fill from photos | Unvalidated feature pattern in research — no evidence on real accuracy; camera + OCR pipeline is real build cost for a guess | P2, only if users ask |
| Live DVLA/vehicle-data lookups | Explicit known-constraint de-scope; can't structurally compete with Autodue/PitSync/CarFile here | Not planned |
| Calendar/contacts import | Research flags this as bigger privacy/technical scope than it looks, no competitor precedent, no evidence of demand | P2 |
| Family / multi-profile support | Real feature in Travel Document Vault, but adds a whole ownership model for zero validated need in v1 | P1, if paid users ask |
| Document photo/receipt attachments | Core feature for warranty-tracker apps, but that's not our differentiator (cadence/follow-through is) — adds camera + storage scope | P1 |
| Custom/arbitrary document types beyond the 6 presets | A generic type-builder is a UI and data-model expansion; 6 presets + "Custom" label covers the researched high-consequence cases | P2 |
| Widgets, dark theme, search/filter/sort | Polish, not core loop | P2 |
| Multi-language / localization | English only, v1 | P1+ if a real market signal shows up |
| Editable/custom reminder-ladder timing per item | Users get the type's default ladder; letting them hand-tune every stage is real UI complexity for marginal value at this stage | P1 |

**The single hardest cut:** attachments/photo capture. It's a plausible, competitor-validated feature (warranty-tracker apps lead with it) and would be easy to justify adding "since we're already building a detail screen." Cutting it anyway — it pulls the product toward the crowded "document vault" category the positioning explicitly rejects, and every hour spent on camera/storage UX is an hour not spent on the actual differentiator (cadence + follow-through) or on getting a build in front of 12 testers.

---

## 2. Free / paid boundary

**Competitors already give basic tracking and basic reminding away free.** Gating item creation or notifications at all would ask users to pay for something they can get free elsewhere — indefensible.

**Decision: gate the ladder and the nagging, not the tracking.**

- **Free:** unlimited items, all 6 types, one reminder per item (fixed default, e.g. a single notification ahead of the due date). This is deliberately calendar-equivalent — as good as what a free competitor or a phone calendar already gives someone.
- **Paid (one-time unlock, $2.99–$4.99):** the full type-aware, multi-stage escalating ladder, plus overdue follow-through nagging until the user confirms done.

**Reasoning:** the ladder-plus-follow-through is the one piece of positioning this project claims is defensible (per CLAUDE.md's revised positioning). Tying the paywall directly to it means the purchase decision *is* the value-prop decision — someone converts specifically because they want the escalating cadence and the "did you actually do it" nag, not because we arbitrarily capped something unrelated (like item count) to force a purchase. It also avoids the failure mode of capping item count, which would actively work against the core promise ("track your high-consequence renewals") and risks uninstalls rather than purchases given documented fatigue/friction sensitivity.

---

## 3. Renewal types in v1 — and geography

**V1 does not target one geography.** It targets geography-agnostic document categories with manual due-date entry, not country-specific compliance logic.

Reasoning:
- UK MOT/insurance are the most "high consequence" (criminal offence, ANPR enforcement) but that value is already owned by apps doing live DVLA lookups we structurally can't match — competing there on manual entry alone is competing on the competitors' strongest ground.
- US passport processing timelines make the strongest case in the whole research set for "the ladder actually matters" (weeks of processing time means a short-notice reminder is nearly useless), and passports as a document type aren't US-specific — the mechanism generalizes even if the specific 12-months-validity guidance is US-sourced.
- Building one **generic "Vehicle" type** (manual due date, no MOT-specific fields, no DVLA anything) captures the UK MOT/tax use case *and* the US state-registration use case with the same code — geography-specific depth becomes a later content/localization layer, not a v1 architecture decision.

**V1 types:** Passport/Travel ID, Insurance, Professional Licence/Certification, Vehicle (generic), Warranty, Custom. Passport is the flagship type for onboarding/marketing framing — it has the clearest, least contestable case for why a real ladder beats a single calendar entry.

---

## 4. Riskiest assumption

**The bet:** that users will pay $2.99–$4.99 specifically for an escalating ladder + overdue nagging, when free competitors already offer some form of reminder, and when research found *no organic user evidence* (reviews, forum posts) that a single reminder or a calendar has actually failed people for these document types. The "calendar objection" is only partially evidence-backed per research — the mechanical argument is real, the user-voice confirmation is not.

**If this is wrong:** the app can be built well, ship cleanly, and clear Play's gate, and still not reach 10–25 sales/month — because the core monetization bet, not execution, would be the failure point.

**Cheapest test, runs in parallel with build, doesn't block it:**
1. Re-attempt the store-review-text mining the researcher couldn't complete (Play/App Store fetch was blocked, not "no evidence exists") — look specifically for language like "wish it reminded me again" or "I still forgot" in reviews of the named free competitors. Cheap, no build cost.
2. A 5-minute concept check with the same people being recruited for the 12-tester closed-testing pool: describe the free single-reminder vs. paid escalating-ladder-plus-nag split, ask directly whether that's worth $3–5 to them. This doubles as tester recruitment and costs nothing extra.

Given this release's goal is proving the pipeline end-to-end, this validation runs *alongside* development, not as a gate in front of it — consistent with "the risk is never shipping."

---

## 5. Sequenced plan to a shipped release

Rough phases, not a schedule. The 14-consecutive-day, 12-tester closed-testing window is the single biggest calendar lever — it should start as soon as a build is good enough to not embarrass the team in front of 12 real people, not after the app feels "done."

- **Phase 0 (now, parallel, ongoing):** Start recruiting the 12 closed testers immediately — this has the longest lead time of anything in the plan. Run the cheap monetization concept-check (§4) with the same people.
- **Phase 1 — Design & requirements:** ux-designer produces mockups for the full screen set (§6). business-analyst writes acceptance criteria against agreed mockups. qa-tester defines test criteria alongside, not after.
- **Phase 2 — Build:** developer builds core loop, notifications, paywall, Play Console listing skeleton. Resolve the exact-alarm/Doze question (§6) *early* in this phase, before the notification architecture is locked — the answer may simplify or complicate everything downstream.
- **Phase 3 — Get into closed testing ASAP:** as soon as add/edit/list/notify/mark-done work without crashing, push a build into the 12-tester closed track and start the 14-day clock. Final polish, paywall hardening, and store-listing copy continue *while the clock runs* — they don't need to finish first.
- **Phase 4 — Internal QA + fixes:** run in parallel with the testing window; fix anything testers or QA surface.
- **Phase 5 — Production submission:** after the 14 days and any fixes, submit for production review and release. Budget slack for Play's own review turnaround.

---

## 6. Not decided here — routed onward

### To ux-designer (resolve before business-analyst locks acceptance criteria)

- Full screen set and nav: home/list, add/edit item, item detail, paywall/upgrade, notification-permission prompt, exact-alarm-permission prompt (if developer confirms it's needed — see below), settings/privacy-disclosure screen. Cover all four states per screen, including the true cold-launch empty state.
- How the ladder is surfaced to the user (see every stage vs. just "next reminder in X days") and how "mark as done" is triggered.
- How free vs. paid is visually communicated without reading as an ad, given documented notification/UI fatigue sensitivity.
- Proposed default ladder intervals per type (Travel Document Vault's 6mo/3mo/6wk/2wk/1wk is a reasonable starting reference for Passport; other 5 types need proposals).
- Icon/visual language for the 6 preset types.

### To developer (resolve early, before notification architecture is locked)

- **The SCHEDULE_EXACT_ALARM / Doze question, specifically reframed:** confirm whether these reminders (day/week granularity, not minute-precision) actually need exact alarms at all, or whether inexact `AlarmManager`/`WorkManager` scheduling is good enough. If inexact alarms are acceptable, that removes an entire user-facing permission-gate and friction step research flagged as real risk — check this before assuming the exact-alarm permission flow is required.
- Confirm or overturn Flutter as the stack (currently "not yet decided" per CLAUDE.md) — don't inherit it uncritically.
- RevenueCat vs. calling Play Billing directly for a single one-time SKU — RevenueCat may be more infrastructure than one SKU needs.
- Local storage choice once Flutter (or an alternative) is confirmed.

### Flagged, not blocking

- Legal/liability copy: given MOT/insurance-type consequences are criminal-offence-level, the app should not imply it's an official or authoritative source for compliance deadlines. business-analyst should draft cautious disclaimer language as part of requirements — not a v1 build blocker, but must not ship without it.
