# V1 Scope — renewal-reminder

Prepared by: product-manager
Date: 2026-08-20 (amended same day, see revision note)
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

## 1. V1 definition

A single-user, local-only Android app that tracks a small set of high-consequence renewals and recurring life-admin dates, reminds on an escalating ladder as the due date approaches, and tracks whether the user actually confirmed they did it. No accounts, no sync, no live data lookups.

### In scope (P0 — must ship)

- **Add/edit/delete a renewal item**: type (from 7 presets, see §3), label, due date, optional notes.
- **7 preset types**, each with an icon and a default reminder ladder: Passport/Travel ID, Insurance, Professional Licence/Certification, Vehicle (registration/tax/MOT — generic, manual entry, no live lookup), Warranty, Health check (new — see §3), Custom/Other.
- **Reminder ladder**: multiple staged local notifications counting down to the due date, type-aware defaults (exact intervals are a UX-design decision, see §6).
- **Custom/Other lead-time selector (new)**: a single short/medium/long control at item creation, replacing the fixed 30/7/1 default. See §3a.
- **Follow-through state**: after the due date passes without the item marked "done," continue nagging on a reduced, de-escalating cadence until the user confirms or dismisses.
- **Mark as done / renewed**: clears current cycle; for types the user expects to recur, prompt to set the next due date. For Health check specifically, this prompt must not read as clinical guidance — see §3b.
- **Undo toast (new)**: delete and mark-done are both undoable for a short window. See §3c.
- **List/home screen**: all items with status (upcoming / due soon / overdue / done), including the true first-run empty state.
- **Local notifications**, with the Android 13+ notification permission request flow handled explicitly, **and notification grouping (new, P0)** — see §6.
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

- **Covered actions: delete item, and mark-done** (both in-app, from list quick-action or item detail). These are the two actions ux-designer identified as accidental-tap risks with real consequence (data loss / cycle cleared).
- **Not covered in v1:** edit (not flagged as an accidental-tap risk; reversible by editing again), and mark-done triggered from an expanded notification action (no foreground UI surface exists at the moment it fires). This isn't a gap in practice — mark-done never deletes data, it only changes status, and an item's status can always be manually toggled back from its detail screen regardless of whether a toast fired. Stated explicitly here so business-analyst doesn't have to guess at the boundary.
- **Window: 6 seconds**, standard Material snackbar/toast duration with an action button, long enough to react without lingering as UI clutter.
- **Behavior:** tapping Undo within the window fully reverts the action — for delete, the item and its exact prior ladder/history state are restored; for mark-done, the current cycle re-activates and remaining ladder stages are restored, including reverting any recurrence bottom-sheet choice made during the window.
- **No persistent trash/soft-delete bin.** After the window lapses, the action is final. A trash bin is real additional scope (storage, a new list, retention rules) for a benefit the 6-second window already covers for the accidental-tap case this is meant to solve; out of scope for v1, not proposed for P1 unless real usage says otherwise.
- Routed to ux-designer: toast/snackbar visual and copy (mockup update, item 1 and item 3 of the screen set). Routed to business-analyst: acceptance criteria for both covered actions and the explicit not-covered boundary above. Routed to developer: confirm the cheapest implementation is deferring the destructive write for the 6-second window (no persistent trash table needed).

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

---

## 7. Rejected (recorded, not re-litigated)

**Friend/relationship check-in reminders** — considered as part of this amendment's review and explicitly rejected. See the table row in §1 for the three reasons (data-model mismatch, notification-volume impact, wrong emotional register for this product's category). This is not a P1/P2 backlog item; if it resurfaces, it should be evaluated as a candidate for a separate future app, not as a feature of this one.

---

## 8. Not decided here — routed onward

### To ux-designer (resolve before business-analyst locks acceptance criteria)

- Health check: finalize paid ladder stage count/spacing (steer: appointment-booking action, similar days-to-weeks profile to Vehicle/Warranty, not Passport's months-out profile) and free-tier single-reminder lead time (steer: ~30 days). Finalize overdue cadence per the lighter, Day-0-plus-one-follow-up steer in §6.
- Health check: icon/category tint (7th entry in the existing type table, design doc §6) and placement of the one-time "not medical advice" inline note at type-selection.
- Custom: finalize Short/Long numeric values (Medium stays 30/7/1) and the selector's placement/visual treatment on the Add/Edit screen.
- Undo toast: visual/copy for both covered actions (delete, mark-done) across list and detail screens.
- Notification grouping: confirm the grouped/summary notification's visual treatment where it appears in the mockups (list/detail unaffected; this is a system-tray-level change).
- Update design doc §2's volume math to reflect the 6-item/7-type recompute in §6 above once final numbers are locked, so the design doc's headline figure stays current rather than diverging from this brief.

### To business-analyst (resolve before developer build starts)

- Full copy for: the Health check interval field/label, the one-time "not medical advice" inline note, and the broadened unified disclaimer (legal + medical) on Settings/Privacy — per the constraints and prohibited-language list in §3.
- Acceptance criteria for the Custom lead-time selector, including its interaction with free/paid gating (§3a).
- Acceptance criteria for the undo toast, including the explicit not-covered boundary (notification-triggered mark-done) so it isn't treated as a missed case later (§3c).
- Acceptance criteria for the recurrence-prompt copy constraint on Health check (§3b) — must re-apply the user's own stored interval, never suggest a fresh one.

### To developer (resolve early, before notification architecture is locked)

- Notification grouping implementation (new, §6) — this now sits alongside the existing exact-alarm/Doze question as an early architectural decision, not a later polish item, since it protects a stated product constraint.
- Undo toast: confirm deferred-write approach (no persistent trash table needed) is sufficient for the 6-second window (§3c).
- Everything carried over unchanged: SCHEDULE_EXACT_ALARM/Doze question, Flutter stack confirmation, RevenueCat vs. direct Play Billing, local storage choice.

### Flagged, not blocking

- Legal/liability copy is now a **unified legal + medical disclaimer** requirement (broadened from the original MOT/insurance-only flag) — not a build blocker, but must not ship without it. See §3.
