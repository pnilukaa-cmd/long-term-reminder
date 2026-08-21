# V1 Scope — renewal-reminder

Prepared by: product-manager
Date: 2026-08-20 (amended 2026-08-20 and 2026-08-21 — see revision notes)
Inputs: `/home/user/renewal-reminder/CLAUDE.md` (pitch, positioning, constraints), `docs/research/00-problem-space.md`, `docs/design/02-v1-design.md` (ux-designer's first design pass, produced against the original scope)
Routed to: ux-designer (mockup/ladder updates), business-analyst (requirements + copy), developer (build + technical spikes), qa-tester (test criteria)

---

## Revision note (2026-08-20, user-requested amendment)

Three changes accepted into v1, all following user review of the original brief and the ux-designer pass built against it:

1. **New 7th preset type: Health check** (annual physical, dental, eye test, vaccination boosters, etc.), with a hard constraint that the app never asserts clinical guidance — recurrence is a user-set number, not a recommendation.
2. **Custom/Other gets a lead-time selector** (short/medium/long), replacing the fixed 30/7/1 guess — accepting ux-designer's suggested enhancement, scoped to a single selector, not full per-stage editing.
3. **Undo toast pulled into v1** for delete and mark-done — accepting ux-designer's suggested enhancement.

Also decided as part of this amendment: Warranty stays (see §3); the free/paid boundary *policy* is unchanged, but gets a new per-type row (see §2); the notification-volume budget ux-designer's design is built to protect (§6 of this doc) is recomputed and confirmed intact in steady state, with one new P0 requirement (notification grouping) added specifically to keep a worst-case edge case from drifting toward the fatigue threshold. **Friend/relationship check-in reminders were considered and explicitly rejected** — recorded in §7 so it isn't re-litigated.

Everything below is the full brief with these changes integrated, not an addendum.

**Framing this brief operates under:** this is a capability proof (ship, clear Play's gate, take a payment), not a business plan. Revenue target is ~$500/year (~10–25 sales/month at $2.99–$4.99). The dominant failure mode for solo first projects is over-scoping. Every cut below is deliberate and biased toward shipping smaller.

---

## Revision note (2026-08-21, product-manager resolves business-analyst's flagged conflicts)

business-analyst's v1 acceptance-criteria pass (`docs/requirements/03-v1-acceptance-criteria.md` §0) surfaced two real conflicts and flagged several stated defaults for explicit product sign-off. Resolved below. **These are locked decisions, not reopened questions** — downstream agents should build/mock/test against them, not relitigate them.

### Decision 1 — Snooze is cut from v1

Snooze was never in the P0 list (§1), never routed (§8), and — critically — never counted in the ≈1.12/month notification-volume budget (§6), which is the one number this entire revision is built to protect. It nonetheless appeared as a first-class action on every notification in `docs/design/mockups/07-notifications.html` and in design doc §4, unrouted scope creep that would have silently broken the budget the design otherwise honestly protects.

**Cutting it, not accounting for it.** Reasoning:
- The concern behind keeping it — "what does a user do with a notification they can't act on right now" — is already answered by the existing ladder/overdue cadence, which exists specifically to re-touch the user later without inventing a second scheduling mechanism. Dismissing a notification doesn't lose the item: it stays on the list at its correct status, and the next ladder stage or overdue nag (already scheduled, already budgeted) reminds them again. Even after a type's overdue sequence ends, the item stays visible as "Overdue" indefinitely per REQ-3.3 — nothing is forgotten.
- Snooze duplicates that mechanism as a second, independent, per-notification scheduling path — real added state-machine complexity (business-analyst flagged this directly as risk item 16.4, interacting with grouping and cancellation bookkeeping) for a need the existing cadence already substantially covers.
- ux-designer's own suggested-enhancements table lists "Snooze duration picker (not fixed 2 weeks)" as a P2-feeling, low-impact idea for triage — meaning even ux-designer treats a refinement of snooze as optional, while the base capability was drawn into the mockups as if already locked. That inconsistency is itself a signal this wasn't actually scoped, just assumed.
- v1's own framing (§0 above) is explicit: smallest viable version, biased toward shipping smaller, over-scoping is the dominant failure risk for a solo first project. Snooze is a convenience feature, not a gap in the core loop.

**"Mark done" is not a lie if used correctly** — it's only mis-tappable if a user acts on a notification they haven't actually resolved, which is a UX-clarity risk either way (with or without snooze) and not a reason to add a parallel scheduling system. The correct action for "I can't deal with this right now" is simply to leave the notification — the app already reminds again on schedule.

**No recompute needed** — the ≈1.12/month figure and the "6 in the worst week" ceiling in §6 stand exactly as computed, since the thing that would have invalidated them (snooze re-posts) isn't shipping.

**Status:** P1 candidate for a future release, *if* real usage data (not assumption) shows users need finer control over reminder timing than the existing ladder gives them. If revisited, it must be budgeted into the volume math honestly at that time, the same way every other notification-generating feature in this doc has been.

**Routed to ux-designer:** remove the "Snooze 2 weeks" action from both panels (`p1`, `p2`) in `docs/design/mockups/07-notifications.html`, and remove the "Snooze" action from design doc §4's text description of notification actions. No other mockup or screen is affected (snooze never appeared in-app, only in the tray mock).

**Routed to business-analyst:** lock REQ-11.3 to a single `Mark done` action (drop the "contingent on §0.1" language and the "if Snooze is confirmed out of scope" branch — there's only one branch now). Close §0.1 and the "Snooze behavior in full" line in §15 as resolved-cut, not open. Drop risk item 16.4's premise (no longer applicable).

### Decision 2 — Delete affordance: long-press confirmed

business-analyst's default is adopted: **list-level delete is reached by long-pressing a card**, which reveals a delete action; **item-detail delete lives behind the existing overflow (⋮) menu**. Reasoning:
- Long-press is the standard Android pattern for a destructive secondary action that shouldn't occupy a permanent icon on every row — consistent with the same accidental-trigger reasoning the design doc already used to reject swipe-to-delete on this same card.
- It keeps the list card visually uncluttered (one visible action — mark-done — matching the mockups as drawn), which the design doc treats as a deliberate choice elsewhere (e.g., not listing every ladder stage on the card).
- It's the cheapest option that still honors scope doc §3c's existing commitment that delete is undoable "from list quick-action or item detail" — restricting delete to item-detail-only would be a scope cut nobody asked for and would make the fastest deletion path a two-screen trip, which is a real regression for a list-first app.

This was drawn nowhere in the mockups, so it isn't fully locked as a visual — only as the interaction pattern. **Routed to ux-designer:** draw two states that don't currently exist: (1) the long-press-revealed delete affordance on a card in `docs/design/mockups/01-home-list.html`, and (2) the expanded overflow (⋮) menu on `docs/design/mockups/03-item-detail.html` showing a `Delete` entry. If long-press discoverability is a concern, a lightweight one-time hint is acceptable P2 polish — not a v1 blocker, and not a reason to add a persistent per-row icon instead.

**Routed to business-analyst:** REQ-5.4's long-press criterion (currently flagged `[BA DEFAULT, flagged in §0.2]`) is now a confirmed product decision, not a tentative default — update its framing accordingly once ux-designer's mockup states land; the acceptance criteria themselves don't need to change in substance.

### Five business-analyst defaults reviewed and confirmed as owned product decisions

Per the instruction that these are product decisions now, not analyst assumptions — reviewed against the mockups and the app's own stated positioning, and confirmed as correct, not just left standing by default:

1. **Undo-window timing (§0.3 / REQ-10.2)** — the 6-second countdown starts when the mark-done interaction fully resolves (immediately after tap for non-recurring types; immediately after the recurrence bottom sheet is dismissed for recurring types), not at the initial tap. **Confirmed.** The alternative would make Undo silently unusable for anyone who takes the manual date-picker path — a real, not theoretical, failure mode.
2. **Recurrence smart-default basis (§0.5 / REQ-9.1)** — computed from the *due date* plus the interval, not from the completion date, applied uniformly across all recurring types. **Confirmed.** This is also the objectively correct behavior for this product's category, not just the consistent one: a passport's next expiry is genuinely 10 years from the prior expiry, not 10 years from whenever the user got around to renewing it. Anchoring to completion date would silently drift a user's renewal cycle earlier every time they complete a task early.
3. **Backdated items at creation (REQ-17.1)** — accepted without validation-blocking, immediately shown `Overdue`, Day-0 nag fires immediately. **Confirmed.** Blocking backdated entry would actively work against the exact first-run scenario this app should welcome (someone logging several already-lapsed things at once).
4. **Timezone and device-clock changes (REQ-17.2)** — reminders re-evaluate against the device's current timezone at delivery time; already-fired notifications never re-fire; a clock jump forward treats missed stages as skipped, not queued for a delivery burst. **Confirmed.** The alternative (a burst of stale notifications after a clock correction) is exactly the kind of bug that would undermine trust in an app whose entire pitch is a well-calibrated cadence — the defensive default is the right call even though it's a rare scenario.
5. **Loss of paid entitlement (REQ-17.3)** — degrade gracefully to the free-tier view, no data deleted, clear path back via Restore purchase. **Confirmed.** No other outcome is compatible with the local-only-storage promise in §2/REQ-15.2 — deleting or blocking access to data on an entitlement failure (not expected to happen under normal operation, but must degrade safely if it does) would break a commitment this doc treats as load-bearing elsewhere.

No changes needed to the acceptance criteria for these five — they were already written correctly against the right defaults. This section exists so the decisions are recorded as product-owned, not analyst-assumed, per the standing instruction that BA-stated defaults on real ambiguities become product decisions once flagged.

Other scattered `[BA DEFAULT]` items not named above (e.g., label-validation copy reuse, per-type unlock-banner copy, overlapping-undo-toast behavior, restore-purchase failure copy, type-change-on-edit triggering a recompute) are accepted as reasonable analyst-level judgment calls within business-analyst's normal delegated authority — they don't rise to the level of needing individual product sign-off, and re-litigating all of them here would be its own form of scope creep.

---

## 1. V1 definition

A single-user, local-only Android app that tracks a small set of high-consequence renewals and recurring life-admin dates, reminds on an escalating ladder as the due date approaches, and tracks whether the user actually confirmed they did it. No accounts, no sync, no live data lookups.

### In scope (P0 — must ship)

- **Add/edit/delete a renewal item**: type (from 7 presets, see §3), label, due date, optional notes. Delete is undoable from either the list (long-press to reveal, see revision note 2026-08-21) or item detail (overflow menu).
- **7 preset types**, each with an icon and a default reminder ladder: Passport/Travel ID, Insurance, Professional Licence/Certification, Vehicle (registration/tax/MOT — generic, manual entry, no live lookup), Warranty, Health check (new — see §3), Custom/Other.
- **Reminder ladder**: multiple staged local notifications counting down to the due date, type-aware defaults (exact intervals are a UX-design decision, see §6).
- **Custom/Other lead-time selector (new)**: a single short/medium/long control at item creation, replacing the fixed 30/7/1 default. See §3a.
- **Follow-through state**: after the due date passes without the item marked "done," continue nagging on a reduced, de-escalating cadence until the user confirms or dismisses.
- **Mark as done / renewed**: clears current cycle; for types the user expects to recur, prompt to set the next due date. For Health check specifically, this prompt must not read as clinical guidance — see §3b.
- **Undo toast (new)**: delete and mark-done are both undoable for a short window. See §3c.
- **List/home screen**: all items with status (upcoming / due soon / overdue / done), including the true first-run empty state.
- **Local notifications**, with the Android 13+ notification permission request flow handled explicitly, **and notification grouping (new, P0)** — see §6. Notification actions are `Mark done` only — no Snooze in v1 (see revision note 2026-08-21).
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
| Custom/arbitrary document types beyond the 7 presets | A generic type-builder is a UI and data-model expansion; 7 presets + "Custom" label covers the researched high-consequence cases | P2 |
| Widgets, dark theme, search/filter/sort | Polish, not core loop | P2 |
| Multi-language / localization | English only, v1 | P1+ if a real market signal shows up |
| Editable/custom reminder-ladder timing per item (beyond Custom's short/medium/long selector) | Users get the type's default ladder; letting them hand-tune every stage is real UI complexity for marginal value at this stage | P1 |
| **Snooze (per-notification "remind me again in N")** (cut this amendment, see revision note 2026-08-21 — was drawn in mockups but never scoped, routed, or budgeted) | It's a second, independent scheduling mechanism duplicating what the already-budgeted ladder/overdue cadence already provides; it broke the notification-volume budget as drawn, and adds real state-machine complexity (interacts with grouping + cancellation bookkeeping) for a convenience, not a gap | P1, only if usage data (not assumption) shows real demand — must be budgeted into §6's volume math honestly if revisited |
| **Friend/relationship check-in reminders** (considered and rejected in this amendment, not a v1 deferral) | Three independent reasons: (1) it's a rolling interval-since-last-contact model, not a fixed-future-date model — would require a second parallel data model, not a 7th row in an existing one; (2) per-person weekly/fortnightly cadence would roughly triple total notification volume, pushing a multi-person portfolio into the 2–6/week range research associates with disabling notifications or uninstalling; (3) "reach out to a friend" is a different emotional register than "renewals that hurt when you miss them," and that category is already served by dedicated apps | **Not a v1/P1/P2 backlog item.** Candidate for a possible separate future app if ever revisited — not to be re-proposed as a feature of this one |

**The single hardest cut:** attachments/photo capture. It's a plausible, competitor-validated feature (warranty-tracker apps lead with it) and would be easy to justify adding "since we're already building a detail screen." Cutting it anyway — it pulls the product toward the crowded "document vault" category the positioning explicitly rejects, and every hour spent on camera/storage UX is an hour not spent on the actual differentiator (cadence + follow-through) or on getting a build in front of 12 testers.

---

## 2. Free / paid boundary

**Competitors already give basic tracking and basic reminding away free.** Gating item creation or notifications at all would ask users to pay for something they can get free elsewhere — indefensible.

**Decision: gate the ladder and the nagging, not the tracking. This policy is unchanged by adding Health check as a 7th type** — Health check has the same shape as every other type (fixed future date, real cost to missing it, lead time matters), so it slots into the existing boundary logic with a new per-type row, not a new rule:

- **Free:** unlimited items, all 7 types, one reminder per item (fixed default per type, see ux-designer's type-tuned table — Health check's free lead time is routed to ux-designer alongside the ladder proposal in §6, with a directional steer of "around 30 days," similar profile to Vehicle/Warranty, since booking an appointment is a days-to-weeks action, not a same-day one). This is deliberately calendar-equivalent — as good as what a free competitor or a phone calendar already gives someone.
- **Paid (one-time unlock, $2.99–$4.99):** the full type-aware, multi-stage escalating ladder, plus overdue follow-through nagging until the user confirms done, plus the Custom lead-time selector's short/long tiers (medium remains the free-eligible default shape — see §3a for exactly what's gated).

**Reasoning:** unchanged from the original brief. The ladder-plus-follow-through is the one piece of positioning this project claims is defensible. Tying the paywall directly to it means the purchase decision *is* the value-prop decision.

---

## 3. Renewal types in v1 — and geography

**V1 does not target one geography.** It targets geography-agnostic categories with manual due-date entry, not country-specific compliance or clinical logic.

**V1 types (7):** Passport/Travel ID, Insurance, Professional Licence/Certification, Vehicle (generic), Warranty, **Health check (new)**, Custom. Passport remains the flagship type for onboarding/marketing framing — clearest, least contestable case for why a real ladder beats a single calendar entry.

### Why Health check fits without a new data model

Structurally identical to the existing six: a fixed future date, real cost to missing it (a missed screening, a lapsed vaccination booster), and lead time that matters because booking an appointment takes real days-to-weeks, not because of any medical claim the app is making. It reuses the exact same item shape (type, label, due date, notes, ladder, recurrence) as everything else.

### Hard constraint: no clinical guidance (routed to business-analyst as a copy requirement, not just a design nicety)

Screening intervals vary by country, age, and history. "You should have an annual physical" is quasi-medical advice that's wrong for a meaningful share of users, and this app has no basis to assert it. Product-level decisions locking this down:

- The recurrence field on a Health check item is **"Remind me every [ ] months"** — a plain, user-editable number, not a locked or authoritative-sounding recommendation. It may carry a neutral starting value (12, for the same one-tap convenience every other recurring type gets — see design doc §4's "Same time next year" pattern) but the value must be as editable and unceremonious as any other form field. No badge, label, or copy implying the number is a standard, guideline, or "recommended."
- **Copy constraint routed to business-analyst:** draft the exact microcopy for (a) the interval field and its label, and (b) a one-time inline note shown the first time a user picks "Health check" as a type, plainly stating this is not medical advice. Explicitly avoid: "recommended interval," "doctors suggest/recommend," "standard guideline," "you should get," "due for your [checkup]" used in any authority-implying way. Status words already used generically across all types ("overdue," "upcoming") are fine — they describe the user's own set date, not a clinical judgment, and stay consistent with how every other type already uses them.
- **This broadens the existing disclaimer requirement**, not just adds a new one. The original brief flagged a legal/compliance disclaimer (MOT/insurance aren't officially authoritative). That's now a single unified disclaimer: *"This app is not a source of legal, regulatory, or medical guidance. All dates and intervals are set by you."* Placement: Settings/Privacy screen (existing screen, no new screen needed) **plus** the one-time inline note above at Health check type-selection, because the medical-advice-adjacent risk is specific enough to that one type that burying it in Settings alone isn't sufficient. Routed to business-analyst to draft final copy, to ux-designer to place it in the mockups.

### Does Health check change the free/paid boundary reasoning?

No change to the *policy* (§2), but yes, it gets its own tuned number rather than inheriting another type's — its "useful on its own" free lead time isn't obviously the same as passport's (months, because of processing backlogs) or warranty's (a pure expiry, no action to schedule). Booking a medical/dental appointment is a days-to-weeks action, closer to Vehicle/Warranty's profile than Passport's or Insurance's. Directional steer given to ux-designer: ~30 days. Final number is ux-designer's call, consistent with how the other six were set (see §6).

### Is Warranty still earning its place, now there are seven types?

**Decision: keep it.** Considered and rejected cutting it. Reasoning:

- Warranty and Health check sit in genuinely different consequence registers — financial loss vs. health/safety — both legitimately clear the "hurts when you miss it" bar the positioning sets; the bar was never "criminal-offence-level or nothing," and the original brief already built Warranty as the deliberately lighter end of that spectrum (single day-0 overdue nag, no ongoing follow-through, because there's nothing to fix by nagging further once a warranty window closes).
- Health check does arguably fit the "hurts when you miss it" positioning more viscerally than Warranty (your health vs. your wallet) — worth saying plainly, per the instruction to call this out — but that's a reason to *feel good about adding* Health check, not a forcing function to *cut* Warranty. They're not competing for the same slot.
- Cost of keeping Warranty is near zero: it's already fully speced (ladder, overdue cadence, free lead time, icon/tint) in ux-designer's design pass. Cutting it now would be scope thrash driven by the type-count feeling long, not by any actual conflict, cost, or user complaint — exactly the kind of decision this role is supposed to resist making by reflex.
- Nothing about Warranty specifically threatens the notification budget (§6) — the volume question is about portfolio size and per-type cadence generally, not this one type.

---

### 3a. Custom/Other lead-time selector (new)

ux-designer flagged Custom's fixed 30/7/1 default as an ungrounded guess (it's the one type with no competitor rationale or action-duration basis to reason from) and proposed a single selector rather than full per-stage editing. Accepted, scoped as follows:

- **One control at Custom item creation/edit: "How much lead time do you need?" — Short / Medium / Long, default Medium.** Each option maps to a complete, pre-defined 3-stage ladder (not per-stage date editing — that stays out of scope per the existing P1 deferral above). This is a single enum field on the item, not a data-model expansion.
- **Medium = the existing default (30/7/1 days)**, unchanged, so nothing regresses for the current spec if a user takes no action.
- Illustrative Short/Long values for ux-designer to finalize (consistent with how every other type's exact numbers were ux-designer's call, not locked here): Short ≈ 7/3/1 days, Long ≈ 90/30/7 days.
- **Free tier for Custom also respects the selection**, not a fixed 14-day reminder regardless of choice — otherwise a user who explicitly says "I need long lead time" would still get a free reminder tuned for the old fixed default, which defeats the point of adding the selector at all. Free tier shows the *single* reminder that would be the profile's middle stage (e.g., Medium → 7 days, matching today's free default; Short/Long scale accordingly). This is a small, low-cost extension of an already-cheap feature, not new scope.
- **What's gated stays consistent with §2:** free tier gets one reminder regardless of which profile is chosen (tracking is never gated); paid tier gets the full 3-stage ladder for whichever profile was chosen, plus overdue follow-through.
- Routed to ux-designer: finalize Short/Long numeric values and the selector's visual placement on the Add/Edit screen (item 2, §1 of the design doc). Routed to business-analyst: acceptance criteria for the selector as a first-class form field, including its interaction with the free/paid gating above.

---

### 3b. Mark-done recurrence prompt for Health check

Reuses the existing "when's the next one due?" bottom-sheet pattern from design doc §4, with one change: the smart one-tap default must read as *"same as your setting"* (i.e., re-apply whatever interval the user already set — e.g., "In 12 months," pulling from the item's own stored interval, not a fresh suggestion), never as a fresh recommendation. No new UI pattern needed — this is a copy/data-source constraint on the existing bottom sheet, routed to business-analyst alongside §3's copy work.

---

### 3c. Undo toast (new)

ux-designer flagged this as high-impact/low-effort, specifically because local-only storage means there's no cloud undo and an accidental tap on a stacked list is a real, previously-unmitigated risk for an app whose entire value proposition is "don't let this slip." Accepted into v1. Scope:

- **Covered actions: delete item, and mark-done** (both in-app, from list quick-action or item detail). These are the two actions ux-designer identified as accidental-tap risks with real consequence (data loss / cycle cleared). **List quick-action, specifically:** mark-done is the tap-target checkmark already on every card; delete is reached by long-pressing the card to reveal a delete action (confirmed 2026-08-21 — see revision note above; not yet drawn, routed to ux-designer). Item-detail delete lives behind the existing overflow (⋮) menu.
- **Not covered in v1:** edit (not flagged as an accidental-tap risk; reversible by editing again), and mark-done triggered from an expanded notification action (no foreground UI surface exists at the moment it fires). This isn't a gap in practice — mark-done never deletes data, it only changes status, and an item's status can always be manually toggled back from its detail screen regardless of whether a toast fired. Stated explicitly here so business-analyst doesn't have to guess at the boundary.
- **Window: 6 seconds**, standard Material snackbar/toast duration with an action button, long enough to react without lingering as UI clutter. Countdown starts when the triggering interaction fully resolves (immediately for non-recurring mark-done/delete; after the recurrence bottom sheet is dismissed for recurring mark-done) — confirmed 2026-08-21, see revision note above.
- **Behavior:** tapping Undo within the window fully reverts the action — for delete, the item and its exact prior ladder/history state are restored; for mark-done, the current cycle re-activates and remaining ladder stages are restored, including reverting any recurrence bottom-sheet choice made during the window.
- **No persistent trash/soft-delete bin.** After the window lapses, the action is final. A trash bin is real additional scope (storage, a new list, retention rules) for a benefit the 6-second window already covers for the accidental-tap case this is meant to solve; out of scope for v1, not proposed for P1 unless real usage says otherwise.
- Routed to ux-designer: toast/snackbar visual and copy (mockup update, item 1 and item 3 of the screen set), **plus the long-press delete affordance and item-detail overflow-menu Delete entry per the 2026-08-21 decision above.** Routed to business-analyst: acceptance criteria for both covered actions and the explicit not-covered boundary above. Routed to developer: confirm the cheapest implementation is deferring the destructive write for the 6-second window (no persistent trash table needed).

---

## 4. Riskiest assumption

Unchanged by this amendment. **The bet:** that users will pay $2.99–$4.99 specifically for an escalating ladder + overdue nagging, when free competitors already offer some form of reminder, and when research found *no organic user evidence* that a single reminder or a calendar has actually failed people for these document types.

**If this is wrong:** the app can be built well, ship cleanly, and clear Play's gate, and still not reach 10–25 sales/month — because the core monetization bet, not execution, would be the failure point.

**Cheapest test, runs in parallel with build, doesn't block it:**
1. Re-attempt store-review-text mining for language like "wish it reminded me again" / "I still forgot."
2. A 5-minute concept check with the 12-tester recruitment pool: describe free single-reminder vs. paid escalating-ladder-plus-nag, ask directly whether that's worth $3–5. Doubles as tester recruitment.

---

## 5. Sequenced plan to a shipped release

Unchanged in shape by this amendment — the three additions are scoped narrowly enough not to move any phase. One addition: Phase 1 now includes the Health check ladder/free-lead-time proposal, the Custom selector's numeric values, and the undo-toast mockup update as part of ux-designer's existing Phase 1 work, not a new phase.

- **Phase 0 (now, parallel, ongoing):** Recruit the 12 closed testers. Run the cheap monetization concept-check (§4).
- **Phase 1 — Design & requirements:** ux-designer updates mockups/ladder tables for the three changes above; business-analyst writes acceptance criteria (including the new copy constraints in §3) against agreed mockups; qa-tester defines test criteria alongside.
- **Phase 2 — Build:** developer builds core loop, notifications (including grouping — see §6), paywall, Play Console listing skeleton. Resolve the exact-alarm/Doze question early.
- **Phase 3 — Get into closed testing ASAP:** push a build into the 12-tester closed track as soon as add/edit/list/notify/mark-done work without crashing; start the 14-day clock.
- **Phase 4 — Internal QA + fixes:** in parallel with the testing window.
- **Phase 5 — Production submission:** after 14 days and fixes.

---

## 6. Notification volume — recomputed for this amendment

ux-designer's design doc built the whole notification surface to protect a headline figure: **~0.9 notifications/month for a paid 5-item portfolio** (design doc §2). Adding Health check changes the realistic portfolio size and shape, so this needed recomputing before treating the amendment as safe to build.

**Realistic 6-item portfolio (the original 5 plus one Health check item), paid tier, steady state, on-time renewals:**

| Item | Stages/cycle (pre-due) | Cycle length | Avg/month |
|---|---|---|---|
| Passport | 4 | 120 mo (10 yr) | 0.033 |
| Insurance | 3 | 12 mo | 0.25 |
| Vehicle | 3 | 12 mo | 0.25 |
| Licence | 3 | 12 mo | 0.25 |
| Warranty | 2 | 24 mo (2 yr) | 0.083 |
| **Health check (new)** | 3 (illustrative — final count is ux-designer's call, see below) | 12 mo (illustrative — modeling assumption only, not a product default) | 0.25 |
| **Total** | | | **≈ 1.12/month** |

**Steady-state verdict: budget holds.** ~1.12/month is about one notification every 3.5–4 weeks — up from one every 5–6 weeks, a real increase (~28%) but nowhere near the weekly cadence where research places the disable/uninstall risk (2–6/week). Not a regression against the budget in the sense that matters.

**Where it does move: the degenerate worst case.** Design doc §2 already accepted, as an edge case, "all items overdue simultaneously" peaking at ~5 notifications in the first week (all "day 0" overdue nags landing together), for a 5-item portfolio. Adding a 6th item's day-0 nag pushes that peak to **6 in the first week** — now sitting at, not past, the top of the cited 2–6/week danger band, for a portfolio-of-all-simultaneously-lapsed users. Two things follow from this, not one:

1. **Health check's overdue cadence should be the lightest of the "still worth nagging" types, not a copy of Insurance/Vehicle's.** Missing a checkup doesn't compound daily the way a lapsed legal document does — closer in spirit to Warranty's "the day-0 nag is the one that matters" register, but unlike Warranty there's still value in one follow-up (a checkup remains worth catching up on, unlike an expired warranty window). Directional steer to ux-designer: something like Day 0, +30d (2 stages), not the 3–4 stage pattern used for the daily-risk types. This doesn't change the peak week's *count* (day 0 always fires for every overdue type regardless of how many stages follow), but it keeps total volume in the following weeks lighter and matches the actual risk shape better.
2. **New P0 requirement: notification grouping.** When two or more items' scheduled notifications (any type — ladder stage or overdue nag) land on the same calendar day, they collapse into a single Android grouped/summary notification rather than posting N separate pushes. This is the actual fix for both the realistic clustering case (design doc §2's insurance+vehicle-same-month example) and the degenerate case — it directly protects the number the whole design is built around, in exactly the scenario where it's under the most pressure, using a standard, low-cost Android pattern (`NotificationCompat` grouping), not a scope cut. Routed to developer (implementation) and ux-designer (confirm the summary line's copy/visual treatment in the affected mockups).

**Not treated as broken, and not over-fixed:** I'm not cutting a type or reducing steady-state ladder stage counts to chase this — the steady-state number is fine, and the edge case is still, honestly, a self-selecting scenario (a user who's let every single tracked item lapse simultaneously is already at elevated disable/uninstall risk for reasons that have nothing to do with this app). Grouping plus a lighter Health check overdue cadence is a proportionate response; redesigning the whole cadence system in response to one edge-case portfolio would be overcorrecting on a budget that, in the case that actually matters (steady state), isn't in trouble.

**Update (2026-08-21):** business-analyst flagged that "Snooze 2 weeks," drawn on every notification in `07-notifications.html`, was never counted in the ≈1.12/month figure above and would have understated it if shipped as drawn. Resolved by cutting Snooze from v1 entirely (see revision note above) — the figures in this section stand exactly as computed, no recompute required. If a snoozing/re-post capability is ever revisited post-v1, it must be added to this table honestly, the same way Health check was, before being treated as budget-neutral.

---

## 7. Rejected (recorded, not re-litigated)

**Friend/relationship check-in reminders** — considered as part of this amendment's review and explicitly rejected. See the table row in §1 for the three reasons (data-model mismatch, notification-volume impact, wrong emotional register for this product's category). This is not a P1/P2 backlog item; if it resurfaces, it should be evaluated as a candidate for a separate future app, not as a feature of this one.

**Snooze (per-notification "remind me again")** — considered as part of business-analyst's acceptance-criteria pass (it had been drawn into the notification mockups without being scoped) and cut from v1 on 2026-08-21. See revision note above for full reasoning. This *is* a P1 candidate (unlike friend reminders), contingent on real usage evidence and an honest volume-budget recompute — not to be re-added to v1 without both.

---

## 8. Not decided here — routed onward

### To ux-designer (resolve before business-analyst locks acceptance criteria)

- Health check: finalize paid ladder stage count/spacing (steer: appointment-booking action, similar days-to-weeks profile to Vehicle/Warranty, not Passport's months-out profile) and free-tier single-reminder lead time (steer: ~30 days). Finalize overdue cadence per the lighter, Day-0-plus-one-follow-up steer in §6.
- Health check: icon/category tint (7th entry in the existing type table, design doc §6) and placement of the one-time "not medical advice" inline note at type-selection.
- Custom: finalize Short/Long numeric values (Medium stays 30/7/1) and the selector's placement/visual treatment on the Add/Edit screen.
- Undo toast: visual/copy for both covered actions (delete, mark-done) across list and detail screens.
- Notification grouping: confirm the grouped/summary notification's visual treatment where it appears in the mockups (list/detail unaffected; this is a system-tray-level change).
- Update design doc §2's volume math to reflect the 6-item/7-type recompute in §6 above once final numbers are locked, so the design doc's headline figure stays current rather than diverging from this brief.
- **(New 2026-08-21)** Remove the "Snooze 2 weeks" action from both notification panels in `docs/design/mockups/07-notifications.html` and from design doc §4's text — Snooze is cut from v1, only `Mark done` ships.
- **(New 2026-08-21)** Draw the long-press-revealed delete affordance on a card in `docs/design/mockups/01-home-list.html`, and the expanded overflow (⋮) menu showing `Delete` on `docs/design/mockups/03-item-detail.html` — both confirmed as the delete pattern but not yet drawn anywhere.

### To business-analyst (resolve before developer build starts)

- Full copy for: the Health check interval field/label, the one-time "not medical advice" inline note, and the broadened unified disclaimer (legal + medical) on Settings/Privacy — per the constraints and prohibited-language list in §3.
- Acceptance criteria for the Custom lead-time selector, including its interaction with free/paid gating (§3a).
- Acceptance criteria for the undo toast, including the explicit not-covered boundary (notification-triggered mark-done) so it isn't treated as a missed case later (§3c).
- Acceptance criteria for the recurrence-prompt copy constraint on Health check (§3b) — must re-apply the user's own stored interval, never suggest a fresh one.
- **(New 2026-08-21)** Lock REQ-11.3 to a single `Mark done` notification action (remove the Snooze-contingent branch); close §0.1 and the §15 "Snooze behavior in full" line as resolved-cut, not open; drop risk item 16.4's premise. Update REQ-5.4/§0.2's long-press criterion framing from tentative default to confirmed decision (criteria substance unchanged).

### To developer (resolve early, before notification architecture is locked)

- Notification grouping implementation (new, §6) — this now sits alongside the existing exact-alarm/Doze question as an early architectural decision, not a later polish item, since it protects a stated product constraint.
- Undo toast: confirm deferred-write approach (no persistent trash table needed) is sufficient for the 6-second window (§3c).
- Everything carried over unchanged: SCHEDULE_EXACT_ALARM/Doze question, Flutter stack confirmation, RevenueCat vs. direct Play Billing, local storage choice.
- **(New 2026-08-21)** Notification action set is `Mark done` only for v1 — no snooze-rescheduling logic to build.

### Flagged, not blocking

- Legal/liability copy is now a **unified legal + medical disclaimer** requirement (broadened from the original MOT/insurance-only flag) — not a build blocker, but must not ship without it. See §3.
