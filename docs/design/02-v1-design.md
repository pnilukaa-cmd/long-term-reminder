# V1 Design Direction — renewal-reminder

Prepared by: ux-designer
Date: 2026-08-20 (amended 2026-08-20, 2026-08-21, and 2026-08-21 dark-theme pass — see revision notes)
Inputs: `CLAUDE.md`, `docs/product/01-v1-scope.md` (amended — §8 routes five items here, then two more targeted changes on 2026-08-21), `docs/research/00-problem-space.md`, this doc's own first pass, `lib/theme/` (developer's placeholder dark derivation, corrected in this pass — see §7a)
Routed to: product-manager (react/prioritize), business-analyst (lock acceptance criteria against this), developer (implement), user (react)
Mockups: `docs/design/mockups/*.html` — open directly in a browser, no build step, no external dependencies. New: `08-dark-theme.html` (full dark palette + status legibility + Home/List and Item detail in dark, all states).

No shared theme/token source exists yet for this app — §7 below **is** the theme. It's inlined into every mockup's `<style>` block rather than linked, since these files are meant to be opened standalone.

---

## Revision note (2026-08-21, dark theme design pass)

`developer` flagged the dark theme explicitly: it shipped only as their own algorithmic tonal derivation (`ColorScheme.fromSeed` for the stock M3 roles, hand-guessed values for the two custom semantic roles and the seven category tints), because no dark mockup existed to design against — and said so plainly in code comments in `lib/theme/`, rather than quietly treating it as done. This pass replaces that placeholder with a designed dark palette. Summary of what changed and why is in new **§7a**; the reviewable artifact is `docs/design/mockups/08-dark-theme.html`.

**What's new, in one paragraph:** every dark role was retoned from its own light-mode hue/chroma (measured in CIELAB, not guessed or inverted) onto M3's standard dark tonal targets — this is real color-science work, not a lightness flip. Two confirmed bugs in the *shared* (light+dark) theme code were found and are flagged with fixes: `cardTheme` uses `surfaceContainerLowest`, which in dark is *darker* than the scaffold (wrong direction — cards would look like holes, not elevated surfaces), and `snackBarTheme` hardcodes a literal `#2B2B33` that nearly disappears against dark surfaces (it was implicitly relying on being the opposite brightness of the page, which only holds in light). The warning role needed a genuine hue correction, not just a lightness retone, because a naive version rendered as salmon — nearly on top of error's dark hue. Health check's tint is resolved against error with a quantified fix (hue separation increased from ~43° to ~56°, verified under simulated protanopia/deuteranopia, not just eyeballed) — full writeup in §7a.

---

## Revision note (2026-08-21, focused cleanup following product-manager decisions)

Two small, targeted changes, not a redesign:

1. **Snooze cut from v1.** Removed the "Snooze 2 weeks" notification action from both notification-tray mockup panels (`docs/design/mockups/07-notifications.html`, p1 and p2) and from §4's text — the notification action set is now **Mark done only**. This was never scoped, routed, or counted in §2's ≈1.12/month volume budget; it was drawn into the mockups as though already locked, which it wasn't. Full reasoning, and a note on how this slipped past me (my own suggested-enhancements table treated a *refinement* to Snooze as optional while the base capability was drawn as settled — that inconsistency is what should have caught it earlier), is in §4 and §4a.
2. **Delete affordance drawn.** Two new mockup states, previously undrawn anywhere despite being committed to in scope doc §3c: long-press-revealed delete on a list card (`01-home-list.html`, new tab) and the expanded overflow (⋮) menu showing `Delete` on item detail (`03-item-detail.html`, new tab). Both feed the existing undo toast (§4a). New §4b covers the design and the rejected persistent-icon alternative.

I did a full pass over this doc and all seven mockups specifically looking for other drawn-but-never-scoped material after finding the Snooze issue — nothing else turned up; see the note at the end of §4a.

---

## Revision note (2026-08-20, against the amended scope)

product-manager amended the v1 scope after this doc's first pass — three of the five changes are things I flagged as suggested enhancements or open questions myself (undo toast, Custom's lead-time selector), which is a nice loop to close. This revision integrates all of it into one document rather than bolting on an addendum:

1. **Health check — 7th preset type.** New §2a: icon/tint, ladder (30/14/3, mirrors Vehicle/Warranty's action-duration profile), free lead time (30 days), and a lighter 2-stage overdue cadence (Day 0, +30d). The recurrence field ("Remind me every [ ] months") gets real design attention below, not just a copy pass — the hard constraint that it must never read as clinical guidance is genuinely a visual-weight problem, not only a wording one, and I've treated it as such.
2. **Custom/Other lead-time selector.** New §2b: finalized Short = 7/3/1 days, Medium = 30/7/1 (unchanged default), Long = 90/30/7 days, plus free-tier scaling and placement on the Add/Edit screen.
3. **Undo toast.** New §4a: visual treatment, copy, and placement relative to the FAB (there's no bottom nav to worry about — see §1). Covers delete and mark-done only, per scope.
4. **Notification grouping (P0).** New §6a and new mockup `07-notifications.html`: what the grouped/summary notification says and how it expands. This doesn't touch any in-app screen — it's a system-tray-level change — so 01–06 are otherwise unaffected by this item specifically.
5. **Volume math recomputed.** §0 and §2's math table now reflect the 6-item/7-type portfolio. I re-verified product-manager's ≈1.12/month figure independently rather than taking it on trust (see §2) — it holds, using the same ladder I'm proposing for Health check. I also found and flagged a real gap in what grouping actually protects against in the degenerate worst case — see the caveat at the end of §2.

Warranty is unchanged — product-manager kept it, no action needed on my end. Everything below is the full document with these changes integrated.

---

## 0. Headline answer: notification volume (routed question 2, recomputed)

**A fully-paid user tracking a realistic 6-item portfolio (5 original types + 1 Health check) receives roughly 1.12 push notifications per month on average, in steady state, assuming on-time renewals.** That's about one notification every 3.5–4 weeks — up from one every 5–6 weeks at 5 items, a real ~28% increase, but still nowhere near the 2–6/week range research places disable/uninstall risk in. Full math, and an honest look at where the increase actually bites (the degenerate worst-case week, not steady state), is in §2. **I independently re-derived this number rather than accepting product-manager's recompute on trust — it checks out exactly, using the same Health check ladder (3 stages, 12-month default cycle) I'm proposing in §2a.** This is still the number the rest of the design is built to protect; if any later change pushes the average up, treat it as a regression against this constraint, not a free variable.

---

## 1. Screen set and navigation

**Nav model: single-stack, no bottom tabs.** The app has one real hub (the list) and everything else is a pushed screen from it (detail, add/edit, settings, paywall). A bottom nav bar would imply 3+ co-equal top-level destinations this app doesn't have — it'd be chrome for chrome's sake on an app this narrow, and more surface for a solo developer to build and QA. Top app bar carries a settings (gear) icon and the list carries the add (+) FAB.

**Screens (all four states — loading / empty / error / success — covered in the mockups except where a screen structurally can't be empty):**

1. **Home / List** — the hub. States: loading (skeleton cards), empty (first-run — see §1a, this is the one that matters most), error (local read failure — rare but must not be a blank white screen), success (grouped by status).
2. **Add / Edit item** — states: empty (blank form + type picker), loading (brief local save), error (validation), success (saved, returns to detail).
3. **Item detail** — states: loading (skeleton), error (item not found / read failure), success × 2 meaningful variants — free-tier item (single reminder, locked ladder preview) and paid-tier item (full ladder track). This is also where the free/paid distinction is surfaced contextually (routed question 5 — see §5).
4. **Paywall / Upgrade** — states: default, loading (billing check), error (purchase failed / billing unavailable), success (purchased confirmation).
5. **Notification-permission prompt** — our own priming screen ahead of the OS dialog, plus the two outcomes (granted, denied-with-recovery-path).
6. **Exact-alarm prompt — conditional, and I recommend against needing it.** Day/week-granularity reminders (the coarsest stage is 6 months, the finest is 1 day) do not need minute-precision delivery. `WorkManager`/inexact `AlarmManager` should comfortably deliver a notification within the same day, which is all this product promises. I've mocked this screen so it exists if developer's spike concludes otherwise, but designed it as an **optional settings-screen link, not an onboarding blocker** — if developer confirms it's unnecessary, this screen is cut with zero rework elsewhere, because nothing else depends on it being in the onboarding flow.
7. **Settings / Privacy** — mostly static: privacy disclosure (local-only, nothing leaves the device — worth stating even though it's table stakes per research, users still expect to see it), notification settings deep-link, restore purchase, about/version. The disclaimer text here is now the broadened legal+medical version — see §5's update.
8. **Notification tray previews (new, `docs/design/mockups/07-notifications.html`)** — not an in-app screen; a mock of what actually lands in the Android notification shade. Covers: a single ladder-stage notification, a single overdue nag, the **grouped/summary notification** (new, P0) when two or more items collapse onto one calendar day, and its expanded state. See §6a.

Two existing screens gained new states rather than new files: Add/Edit (`02-add-edit-item.html`) now has a Health check tab and a Custom-with-selector tab; Item detail (`03-item-detail.html`) now has a Health check tab, the mark-done recurrence bottom sheet (both the generic version and the Health check "same as your setting" version), an undo-toast state, and (new 2026-08-21) the expanded overflow (⋮) menu showing `Delete` — see §4b. Home/List (`01-home-list.html`) gained a 7th empty-state tile, a Health check and a Custom card in the success state, an undo-toast state, and (new 2026-08-21) the long-press-revealed delete affordance on a card — see §4b.

### 1a. First-run empty state — treated as a primary design problem

A generic "No items yet — tap + to add" empty state is a dead end: it names the problem but doesn't reduce the effort of solving it, and data entry here is exactly the tedious step research flags as the real first-run risk. Instead, the empty home screen **is** the add flow's first step: it shows the six type presets as large tappable tiles directly on the empty state ("What do you want to track first?"), so the fastest path from cold launch to first tracked item is one tap on a tile, not "notice empty state → find FAB → open form → pick type from a dropdown." The copy also does one job the blank state usually skips: it states the value proposition at the exact moment the app has nothing else to show for itself yet ("We'll remind you early enough to actually act — not just in time to panic.") See `docs/design/mockups/01-home-list.html`, empty state panel.

---

## 2. Reminder ladders — proposals for all seven types, with reasoning

Travel Document Vault's 6mo/3mo/6wk/2wk/1wk is the given reference for passport. I trimmed it to four stages (merging the 6wk/2wk pair into a single "1 month" stage) — the 6-month and 3-month stages are the ones doing the real work given US passport processing backlogs (research: 4–6 weeks routine processing, guidance to renew with 12+ months validity, common 6-month-remaining entry rules), while a 5th stage in the final month adds volume without adding a materially different action window.

The other five types have no competitor-cited rationale in research, only competitor *convention* (Autodue 60/30/14/7, Expiro 30/7/1) with no stated reasoning behind the numbers. I grounded each proposal in **how long the type's actual renewal action takes**, not just how severe the consequence is — severity tells you how much it matters, action-duration tells you how early the reminder needs to fire to be useful. A reminder that fires with more lead time than the action needs is just extra noise; the research's own core complaint about naive "remind harder" design.

| Type | Paid ladder (before due date) | Why this spacing |
|---|---|---|
| **Passport / Travel ID** | 6 months, 3 months, 1 month, 1 week | Action takes weeks of processing + mail; early stages are the ones that matter, per research |
| **Insurance** | 21 days, 7 days, 1 day | Shopping/renewing insurance is a same-day action (compare, pay); no need for a months-out stage, but daily risk while lapsed is severe (research: criminal offence in UK), so it stays close to the deadline |
| **Professional Licence/Certification** | 90 days, 30 days, 7 days | Renewal usually requires accumulating CE/CPD hours plus board processing time (research: reinstatement after a lapse gets materially worse the longer it runs) — needs lead time an insurance-style reminder doesn't |
| **Vehicle (generic)** | 30 days, 14 days, 3 days | Same action-duration profile as insurance (book a test/renew tax online, a same-day-to-few-days task); mirrors insurance's shape rather than passport's |
| **Warranty** | 30 days, 7 days | Pure financial-loss, no legal exposure (research explicitly separates this from the criminal-offence types) — lighter ladder is deliberate, not an oversight |
| **Health check (new — see §2a)** | 30 days, 14 days, 3 days | Booking a medical/dental/vision appointment is a days-to-weeks action, same shape as Vehicle/Warranty, not Passport's months-out profile — mirrors Vehicle exactly on the same reasoning |
| **Custom / Other (selector — see §2b)** | Short 7/3/1, **Medium 30/7/1 (default, unchanged)**, Long 90/30/7 | Was a single ungrounded guess (Expiro's 30/7/1 convention); now a 3-way selector so the user can say which action-duration profile fits, without full per-stage editing |

**Overdue follow-through (paid only) — de-escalating, not escalating, and type-aware:**

| Type | Overdue nags after due date | Reasoning |
|---|---|---|
| Passport | Day 0, +10d, +30d (3 total, then list-status only) | Ongoing but slow-moving risk; wide spacing matches the slow-moving nature |
| Insurance | Day 0, +3d, +10d, +30d (4 total) | Daily risk while lapsed, closer spacing early on |
| Professional Licence | Day 0, +7d, +21d (3 total) | Consequence compounds gradually (per research), not immediately punitive |
| Vehicle | Day 0, +3d, +10d, +30d (4 total) | Same daily-risk profile as insurance |
| Warranty | Day 0 only, then stops | **There is nothing to fix by nagging further** — the warranty window just closes. Continuing to nag about something the user cannot un-expire is the punitive pattern the working relationship should avoid. This is a deliberate type-specific exception, not a missed case. |
| Health check (new) | Day 0, +30d (2 total, then list-status only) | Deliberately the lightest of the "still worth nagging" types — see §2a for why this isn't Warranty's single-nag pattern, but also isn't Insurance/Vehicle's 3–4 stage daily-risk pattern |
| Custom | Day 0, +7d, +21d (3 total) | Generic default, all three selector profiles |

Every ladder gets **wider, not tighter**, as it goes — the spacing between nags increases (3d → 10d → 30d, not 30d → 10d → 3d) after the due date. This is the mechanical answer to routed question 4 (how follow-through reads as non-punitive): the app checks in less urgently over time, the opposite of an escalating alarm, and copy never uses blame language ("you forgot") — see §4.

---

### 2a. Health check — the hardest open question in this revision

This is the one item in this amendment I spent the most time on, because it's a genuine unresolved interaction-design problem, not a pick-between-two-known-good-patterns question. The scope doc's constraint is specific: the recurrence field ("Remind me every [ ] months") must *look* like a setting the user chose, never a recommendation the app is making — and that's a visual-weight and placement problem as much as a copy one.

**Why this is hard, not just a copy pass:** every existing visual pattern this app already has for "here's something important about your reminder" reads, by design, as the app being confident and directive — that's the entire point of the ladder-preview card (§1a is even sold on it: "we'll remind you early enough to actually act"). The `ladder-preview` component (see the Add/Edit mockup) is a tinted `primary-container` card with a bold title, a checkmark-adjacent icon, and system-generated copy ("Reminders scheduled"). If the Health check interval field lived inside that same visual language — a tinted card, an icon, a confident headline — it would read exactly like the app asserting "here's your interval," which is precisely the authority implication the scope doc prohibits, regardless of what the copy underneath it says. Copy alone can't undo a container that looks like guidance.

**Rejected approach 1: a labeled dropdown of common intervals** ("Every 6 months / Every 12 months / Every 2 years / Custom"). This is the most common real-world pattern for this kind of field, and I rejected it specifically for this feature — a dropdown of pre-set intervals, even unlabeled ones, implies the app curated a shortlist of *valid* answers, which reintroduces the authority problem one level down (why these four numbers, if not because they're "recommended"?). A freely editable number sidesteps that entirely: there's no implied menu of "correct" answers to compare your own choice against.

**Rejected approach 2: a card with explanatory copy directly under the field** (e.g., "This is your own setting — not medical advice" as a persistent caption under the input, every time). I rejected this as the *primary* mechanism because it fights the field's own visual design instead of fixing it — if the container still looks like a recommendation card, a disclaimer sentence bolted underneath reads as legal boilerplate the user learns to skip, not as something that changes how the field itself is perceived in the half-second before it's read closely. (The one-time inline note at type-selection, which *is* explanatory copy, is a different and correct use of this pattern — see below — because it's about the type generally, once, not a running caption on a form field the user interacts with repeatedly.)

**What I did instead:** the interval field is a plain stepper row — `− [12] months +` — styled with the exact same neutral container, border, and type-scale as the ordinary `Label` and `Due date` fields directly above it in the form, not the tinted `ladder-preview` card. A stepper control is itself a meaningful signal here: steppers read as "a quantity you're setting" (alarm repeat interval, screen-timeout duration) in a way a styled callout never does, because the interaction pattern itself is "adjust this," not "receive this." The only text near it is a single neutral-grey helper line, the same weight as every other field's helper text: "Your call — change this any time." No icon, no badge, no checkmark, no shield, no tinted background. The *ladder preview* generated from that number still appears below in the normal tinted card — but it's visibly downstream of the field, not fused with it, so the causality reads correctly: the user set the number, the app is showing what follows from it, not the reverse.

**The one-time inline note**, shown once when Health check is picked as a type for the first time, is a separate, narrower, and lower-frequency intervention — a plain-text banner (not the primary-tinted callout style used elsewhere), dismissible, sitting between the type row and the rest of the form. Business-analyst owns the exact copy (routed in scope doc §3), but I've placed it here — at the moment of type selection, once — rather than only in Settings, because the medical-advice-adjacent risk is specific to the moment this type is chosen, and burying it in a settings screen the user may never open doesn't cover that moment. See the mockup's dedicated "Health check — first selection" state.

**Ladder, free lead time, overdue cadence (the more mechanical parts of this):**
- **Icon/tint:** a heart-with-pulse-line glyph, in a dusty rose/berry tonal pair (`--cat-health-c` / `--cat-health-on`) — the 7th and last available tint that doesn't collide with an existing category (blue, teal, violet, terracotta, slate, grey are taken) or a status hue (amber, red, green are reserved). It sits ~30° away from the error-container's red-orange on the hue wheel and reads clearly distinct in the mockups; I'm flagging the hue proximity explicitly here rather than assuming it away, since it's the one category tint sharing a warm-pink family anywhere near status red. If a future qa-tester colorblind-simulation pass finds it's too close, this is the one tint I'd revisit first.
- **Paid ladder: 30 / 14 / 3 days before** — identical shape to Vehicle, on identical reasoning (booking an appointment is a days-to-weeks action, not a same-day one or a months-out one).
- **Free lead time: 30 days before** — takes product-manager's directional steer as-is; it's the same number as Warranty's free reminder and sits on the same "useful without being alarmist" logic as §5's table.
- **Overdue cadence: Day 0, +30 days, then stops.** Lighter than Insurance/Vehicle's 3–4 stage daily-risk pattern, per product-manager's steer, but not Warranty's single-nag pattern either — a missed checkup doesn't compound daily like a lapsed legal document, but unlike an expired warranty window, there's still a real action to catch up on a month later, so one follow-up earns its place. This also directly supports the volume math below: Health check contributes only 2 nag stages to any overdue pile-up, not 3–4.
- **Mark-done recurrence prompt (scope doc §3b):** reuses the existing bottom-sheet pattern from §4, with the one-tap smart default reading **"Same as your setting — In 12 months"**, sourced from the item's own stored interval value, never a freshly computed suggestion. See the mockup's bottom-sheet state on item detail, and §4's write-up of both the generic and Health-check-specific copy.

---

### 2b. Custom/Other lead-time selector — finalized values

A single 3-way segmented control — **Short / Medium / Long**, default **Medium** — placed on the Add/Edit screen directly below the Due date field when Custom is the selected type, above the ladder preview (so the preview updates live as the selection changes — the user sees the consequence of their choice immediately, not on a separate confirmation).

| Profile | Paid ladder | Free-tier single reminder | Reasoning |
|---|---|---|---|
| Short | 7 / 3 / 1 days | 3 days before | Same-day-ish actions — mirrors Insurance's shape at a smaller scale |
| **Medium (default, unchanged)** | 30 / 7 / 1 days | 7 days before | The existing fixed default — nothing regresses if the user takes no action |
| Long | 90 / 30 / 7 days | 30 days before | Mirrors Professional Licence's shape — for custom items that need real preparation lead time |

Free tier always shows the profile's **middle stage** as its single reminder, per scope doc §3a — this is what makes the selector meaningful for free users too, not just a paid-tier convenience: choosing "Long" changes what free users see, not only what paid users get escalated.

**Visual treatment:** a segmented control, not a dropdown — three equal-width pill buttons in a single outlined track, matching the existing pill/chip shape language (`--shape-full`) already used for status chips elsewhere, so it reads as a settings-style choice rather than a new component family. This is the same "make it look like the interaction it is" reasoning as §2a's stepper — a segmented control is legible at a glance as "pick one of three," where a dropdown would require an extra tap to even see the options, adding friction to a field product-manager scoped specifically to be low-effort.

---

### The math behind the headline number

**Steady-state average, realistic 6-item portfolio (1 passport, 1 insurance, 1 vehicle, 1 licence, 1 warranty, 1 Health check), on-time renewals, paid tier — recomputed for this amendment, independently re-derived, not taken on trust:**

| Item | Stages/cycle | Cycle length | Avg/month |
|---|---|---|---|
| Passport | 4 | 120 mo (10 yr) | 0.033 |
| Insurance | 3 | 12 mo | 0.25 |
| Vehicle | 3 | 12 mo | 0.25 |
| Licence | 3 | 12 mo | 0.25 |
| Warranty | 2 | 24 mo (2 yr) | 0.083 |
| Health check (new — §2a: 3 stages, 12-month default cycle) | 3 | 12 mo | 0.25 |
| **Total** | | | **≈ 1.12/month** |

**Verdict: budget holds.** 1.12/month is one notification roughly every 3.5–4 weeks — a real ~28% increase over the 5-item figure (0.87/month), but still well under the weekly cadence where research places disable/uninstall risk (2–6/week). Not a regression against the constraint in the sense that matters (steady state, on-time use).

**Worst-case realistic clustering** (insurance and vehicle happen to renew the same month): peak single week still only reaches ~2 notifications, or now collapses to a single grouped notification if they land the exact same day — see §6a.

**Degenerate worst case** (all 6 items overdue simultaneously): the day-0 nag for a 6th item pushes the theoretical peak week from ~5 to **6 notifications** — now sitting at, not past, the top of the 2–6/week band. Two things follow, and I want to be precise about what grouping actually fixes here rather than wave at it as solved:

- If all six items' day-0 nags happen to land on the **same calendar day** (the scenario the original 5-item version of this doc implicitly assumed — "everything lapsed at once"), grouping collapses that into **one** summary notification instead of six. That's a real, complete fix for that specific shape of worst case.
- **But grouping only collapses notifications that share a calendar day** — it does not cap a week's total if a user's six items happen to go overdue on six *different* days within the same week (e.g., one every day, Monday through Saturday). In that staggered shape, the user still gets up to 6 separate notifications across the week; grouping doesn't touch it, because there's never more than one notification on any single day to group. I want this stated plainly rather than implied away: **grouping is the right, cheap fix for the same-day-clustering case, but it is not, by itself, a hard cap on weekly volume for every possible overdue distribution.** Whether that residual gap matters is a judgment call, not a design defect — a user with six items overdue in the same week, on any distribution, is already in the self-selecting "let everything lapse" scenario product-manager correctly identifies as elevated disable-risk for reasons unrelated to this app. I'm not asking to redesign around it, but the team should know precisely what "grouping fixes this" does and doesn't mean before treating the degenerate case as closed.

**If this number ever becomes uncomfortable** (e.g., a tester's portfolio is more concentrated than this example, with several annual items sharing a renewal season), the lever to pull is the *paid* ladder's stage count per short-cycle type, not the free tier — free tier is already a single notification and can't be cut further without breaking the calendar-equivalence promise in §2 of the scope doc.

---

## 3. How the ladder is surfaced (routed question 3)

Two levels, deliberately different in density:

- **List/home card:** shows only the *next* upcoming stage as a compact chip ("Next: 1 month before · Jul 12"), plus a minimal stage-progress indicator — a small row of dots, one per ladder stage, filled for stages already fired. This answers "is my cadence active and how far through it am I" in about a quarter-second glance, without listing every date on every card. Listing every stage on every list row would be the clutter failure mode the brief warns about.
- **Item detail:** the full ladder as a horizontal timeline/track running from "today" to the due date, with a marker at each stage (fired stages filled, upcoming stages outlined, due date marked distinctly). This is the moment the differentiator gets to be fully legible — the user is already looking at one item and deciding whether the app's cadence design is trustworthy, so this is where it earns the fuller treatment. See `docs/design/mockups/03-item-detail.html`.

**Rejected alternative:** a vertical checklist of stages (like a to-do list). It's easier to build but reads as a generic task list, not as *time* — and time-to-act is the actual product. A horizontal timeline visually encodes the axis that matters (how much runway is left) in a way a checklist doesn't.

---

## 4. Mark-as-done and follow-through tone (routed question 4)

- **From the list:** a quick action on the card (tap a "Mark done" affordance, no swipe-only gesture — swipe-to-dismiss is easy to trigger accidentally on a screen full of stacked cards, and this data doesn't have cloud undo). For types that typically recur (insurance, vehicle, licence, and passport at a longer horizon), marking done opens a small bottom sheet: "Nice — when's the next one due?" with a one-tap smart default ("Same time next year" / "+10 years" for passport) plus a manual date picker. Warranty skips the recur prompt (nothing to renew); Custom asks a yes/no "does this repeat?" first, since we don't know its cadence. **Health check (new) uses the same bottom sheet, but the one-tap default reads "Same as your setting — In 12 months," pulling from the item's own stored interval, never a freshly computed suggestion** — this is the mechanical enforcement of §2a's constraint at the one other moment (besides the field itself) where the interval resurfaces. See the mockup's bottom-sheet state on item detail.
- **From a notification:** the expanded notification carries a single action, **Mark done** — no Snooze in v1 (cut 2026-08-21, see note below), so most resolutions never require opening the app. Tapping "Mark done" from a notification clears the current cycle and cancels remaining ladder stages immediately; the recurrence question ("when's the next one due?") is deferred to a small inline banner on the item's detail screen the next time the app is opened — **not** a follow-up push notification. Firing a second notification to ask about the first one is exactly the kind of self-inflicted fatigue the research warns about. Per scope doc §3c, notification-triggered mark-done does **not** get an undo toast (no foreground UI surface exists at that moment) — status can always be manually reverted from item detail regardless.
- **Tone:** overdue notifications never use blame language ("you forgot," "you failed to..."). Copy stays collaborative and matter-of-fact: *"Insurance renewal — still open"* / *"Still need to sort this?"* with a single **Mark done** action, not a bare dismiss. The visual treatment leans on the existing error/overdue color to carry urgency rather than stacking urgent copy on top of urgent color — see status language in §6. If a user isn't ready to act, the correct response is simply to leave the notification — it isn't lost: the item stays on the list at its correct status, and the ladder/overdue cadence (§2) already re-touches them later without a second scheduling mechanism.

**Revision note (2026-08-21) — Snooze cut from v1:** earlier drafts of this doc and of `docs/design/mockups/07-notifications.html` (panels p1, p2) drew a second notification action, **"Snooze 2 weeks,"** on every notification. product-manager cut it from v1: it was never in the P0 list, never routed to me, and — critically — never counted in the ≈1.12/month notification-volume budget in §2, which every other notification-generating decision in this doc is built to protect. It's removed from both notification-tray panels and from the bullets above. **How this slipped through, for the record:** my own suggested-enhancements table (bottom of this doc) listed "Snooze duration picker (not fixed 2 weeks)" as a low-impact P2-feeling refinement, while the base Snooze capability itself was drawn into the mockups as though already locked — treating a refinement to something as optional while the thing itself was undrawn scope creep is an inconsistency I should have caught. I did a pass over the rest of this doc and the mockups specifically looking for anything else drawn-as-settled that was never actually scoped or routed — nothing else surfaced (see the note at the end of §4a below).

---

### 4a. Undo toast (new — scope doc §3c)

Covers delete and mark-done, in-app only (list quick-action or item detail), 6-second window, full revert on tap — see the scope doc for the behavioral contract. My job here is the visual treatment and where it sits.

**Visual treatment:** reuses the dark snackbar component already established in the Add/Edit "Saved" confirmation (`docs/design/mockups/02-add-edit-item.html`, success state) rather than inventing a second toast style — same dark surface (`#2b2b33`), same pill shape, same left-icon-plus-text layout. The only addition is a right-aligned **UNDO** action in the primary-container color (so it reads as tappable and distinct from the message text), consistent with standard Material snackbar conventions. Copy is plain and specific, not generic: *"Deleted — Car insurance"* / *"Marked done — MOT, Honda Civic"*, each with an **UNDO** action, so a user managing several toasts in a row (e.g., clearing a backlog of overdue items) can tell at a glance which item each toast refers to without it reading as an error state — deliberately not using the error/warning color roles here, since undo is a safety net, not a problem.

**Placement relative to the FAB (there's no bottom nav — see §1's nav model, so this is a simpler problem than it would be with tab chrome to clear):** the toast sits full-width at the bottom of the content area, and the FAB elevates to sit directly above it for the toast's duration, rather than the toast rendering underneath/behind the FAB or the FAB staying put and getting overlapped. This is standard `CoordinatorLayout`-equivalent behavior on Android (a snackbar anchored to a FAB pushes it up automatically) and costs nothing extra to implement idiomatically. On item detail, where there's no FAB but there is the bottom action bar (Edit / Mark as done), the toast sits above that bar on the same principle — never covering an actionable button. See the new undo-toast states in `01-home-list.html` and `03-item-detail.html`.

**Check for other undrawn-but-assumed scope (2026-08-21):** prompted by the Snooze miss above, I re-read this doc end to end plus all seven mockup files looking specifically for anything else presented as a finished, locked visual when it was actually still an open question or an unrouted addition. Nothing else surfaced. The two remaining open items in this doc (the Health check category tint, §2a/§6/open-questions; the free-tier reminder-timing table, §5/open-questions) are already explicitly flagged as open rather than drawn-as-settled, which is the behavior I want — so I'm treating this as a one-off process gap on Snooze specifically, not a pattern across the doc.

---

### 4b. Delete affordance: long-press (list) + overflow menu (detail) — new, confirmed 2026-08-21

Neither state existed in any mockup before this revision, despite scope doc §3c already committing to delete being reachable "from list quick-action or item detail." business-analyst's default — long-press on a list card, item-detail delete behind the existing overflow (⋮) menu — was confirmed by product-manager on 2026-08-21. Both feed the existing undo toast (§4a); neither adds a confirmation dialog on top of it (redundant friction over a safety net that already exists).

**List — long-press reveals delete:** holding a card elevates it (2px primary-colored border, raised shadow, a small "Held" tag) and swaps its single quick-done checkmark for a two-button column — quick-done (unchanged) stacked above a new quick-delete action in the error-container tint. Other cards on screen dim to ~40% opacity, the standard Android cue that the list has entered a contextual-selection state and that the held card is the one an action will apply to. This is the same accidental-trigger reasoning §3 already used to reject swipe-to-delete on this exact card (a screen full of stacked cards makes a single persistent swipe/icon target for a destructive action too easy to trigger by accident) — long-press requires a deliberate, sustained gesture, and it keeps the card's resting state exactly as drawn everywhere else in this doc (one visible action, mark-done), rather than adding a second permanent icon to every row. See the new tab in `docs/design/mockups/01-home-list.html`.

**Item detail — overflow (⋮) menu:** tapping the existing three-dot icon (drawn on every item-detail panel already, previously non-interactive in the mockups) opens a small popover anchored under it with a single **Delete** entry in the error color, over a light scrim. Kept deliberately minimal — one entry, not a menu shell built out for hypothetical future items (duplicate, share, etc.) that aren't in scope — so it reads as "the destructive action lives here" without implying more menu structure than actually exists. See the new tab in `docs/design/mockups/03-item-detail.html`.

**Discoverability — flagged, not designed against:** long-press is a well-established Android pattern (this app already uses no other primary gesture that would collide with it — cards aren't otherwise draggable or expandable by touch), but it is inherently less discoverable than a visible icon for a first-time user. Per the scope doc's own allowance, a lightweight one-time hint (e.g., a brief coach-mark the first time a card is rendered, "Long-press a card to delete it") is acceptable low-cost P2 polish if user testing shows people don't find it — not a v1 blocker, and not a reason to add a persistent per-row icon instead. Not designed or mocked here; flagging it so it isn't silently forgotten as a possible follow-up.

**Rejected alternative — a persistent trailing delete icon on every card** (mirroring the always-visible quick-done checkmark). Rejected because it clutters the card's resting state for an action every row would rarely use, and reintroduces exactly the "easy to hit by accident on a stacked list" risk that ruled out swipe-to-delete in the first place — a checkmark is a low-consequence, reversible-by-re-tapping action; a delete icon in the same visual weight class is not, and shouldn't invite the same casual tap.

---

## 5. Free vs. paid communication (routed question 5)

**Correction to a literal reading of the scope doc's free-tier description.** §2 of the scope doc describes free tier as "one reminder... fixed default, e.g. a single notification ahead of the due date," without specifying *which* point in the ladder. I did not default this to the ladder's closest-to-due stage (e.g., "1 week before" for passport) — for passport specifically, research says a short-notice reminder is close to useless given processing time. A free user whose only reminder fires a week before a passport renewal they can't complete in a week is likely to blame the app for failing them, not to feel motivated to upgrade — that's a trust risk, not just a lost upsell. Instead, **free tier's single reminder is type-tuned to be genuinely useful on its own**, just clearly inferior to the full ladder (no escalation, no repeat, no overdue follow-up):

| Type | Free single reminder |
|---|---|
| Passport | 3 months before |
| Insurance | 7 days before |
| Professional Licence | 30 days before |
| Vehicle | 14 days before |
| Warranty | 30 days before |
| Health check (new) | 30 days before — same logic as Warranty/Vehicle, per §2a |
| Custom (new — scales with selector, §2b) | 3 / 7 / 30 days before, matching Short/Medium/Long |

This reframes the upgrade pitch from "we deliberately gave you a bad reminder" to "we'll remind you once — upgrade for the full countdown, plus we'll check that you actually did it." That's the honest difference (escalation + follow-through), and it's the one the positioning already claims is defensible.

**Where the difference is shown:** not a separate promotional screen the user has to seek out or dismiss as an ad. On a free-tier item's detail screen, the ladder track (§3) renders the unlocked reminder as normal and the *would-be* additional stages as greyed-out, locked markers in their correct time positions on the same timeline — the user can see exactly where the extra warnings would have fired, at the exact moment they're evaluating whether this item's cadence is trustworthy. A small "Unlock full ladder" affordance sits inline on that visual, not as a separate interstitial. This is the direct answer to "make the difference legible at the moment it matters" — the moment is item detail, not app launch or list view. See the free-tier variant in `docs/design/mockups/03-item-detail.html`.

The dedicated paywall screen still exists (accessible from settings and from that inline prompt) for the actual purchase transaction, but its job is completing a decision the user already made looking at the ladder track, not making the pitch from scratch — so it can afford to be short: what you get, price, one button. See `docs/design/mockups/04-paywall.html`.

---

## 6. Visual language: type icons and status language (routed question 6)

**Two separate encoding systems, deliberately not sharing a color space:**

- **Category tint** (which of the 7 types this is) — a tonal container color pair per type, used only on the type icon/badge.
- **Status color** (upcoming / due soon / overdue / done) — a semantic role, used on status chips and the ladder track.

If both systems drew from the same hue family, an amber vehicle icon next to an amber "due soon" chip would be genuinely ambiguous at a glance. Category tints deliberately avoid amber, red, and green — those three hues are reserved for status.

| Type | Icon motif | Category tint |
|---|---|---|
| Passport/Travel ID | booklet + wing/globe mark | Blue |
| Insurance | shield | Teal |
| Professional Licence | ribbon/certificate | Violet |
| Vehicle | car | Terracotta/clay (not amber) |
| Warranty | box + check | Slate blue-grey |
| Health check (new) | heart + pulse line | Dusty rose/berry (`--cat-health-c` / `--cat-health-on`) — see §2a for why this is the one tint I'd revisit first if colorblind testing flags it |
| Custom | star/asterisk | Neutral grey |

**Status language — encoded on four channels at once (shape, icon glyph, color, text label), not color alone**, both for accessibility (colorblind-safe) and because the brief specifically asks status to read in form as well as color:

| Status | Shape | Icon | Color role | Label |
|---|---|---|---|---|
| Upcoming | Outlined circle | Clock outline | Neutral (outline/on-surface-variant) | "Upcoming" |
| Due soon | Filled circle | Clock filled | **Warning** (proposed new role, §7) | "Due soon" |
| Overdue | Filled circle + small pennant/flag notch | Exclamation | Error | "Overdue" |
| Done | Filled circle | Check | **Success** (proposed new role, §7) | "Done" |

Done items also drop to reduced opacity and collapse into a "Done" group below the active sections on the list, so a long history of completed renewals doesn't bury the items that actually need attention — this matters more here than in a typical list because the whole point of the app is surfacing what needs action next.

---

### 6a. Notification grouping (new, P0 — scope doc §6)

Not an in-app screen — a system-tray-level change, confirmed against the mockups in `docs/design/mockups/07-notifications.html` (new file). List and item detail are otherwise unaffected, per the scope doc's own routing note.

**What it looks like collapsed:** when two or more items' notifications land on the same calendar day, Android's standard grouped/summary pattern applies — one visible notification in the shade, using `NotificationCompat`'s group summary mechanism (developer's implementation call, already scoped in §8 of the scope doc). Summary line: **"3 renewals need attention"** (count-driven, not a generic app-name repost) with a secondary line listing the item labels, truncated with "+N more" past two or three: *"Car insurance, MOT — Honda Civic +1 more."* This is deliberately specific rather than a bare "You have new notifications" — the whole point of this product is that each reminder is about something concrete, and a vague summary would undercut that at the exact moment several concrete things are competing for attention.

**What it looks like expanded:** standard Android expanded/inbox-style grouped notification — each underlying notification's own line is visible (item label + its specific stage, e.g., "MOT — Honda Civic · 3 days before," "Car insurance · overdue"), each independently tappable to that item's detail screen. This preserves per-item specificity once the user chooses to look closer, rather than forcing them into the app just to find out what's in the bundle.

**Tone/type mixing inside one group:** a grouped notification can legitimately contain a mix of upcoming-ladder-stage and overdue-nag notifications on the same day. I did not design a separate visual treatment to distinguish these within the group beyond each line's own status language (the overdue one still reads "· overdue," matching the app's existing status vocabulary) — a second layer of grouping logic (e.g., splitting into an "overdue" group and an "upcoming" group on the same day) would be real added complexity for a genuinely rare double-collision, and the per-line status text already disambiguates without it.

**What this does and doesn't fix:** see §2's worst-case math — grouping fully resolves same-day clustering, but does not cap weekly volume when overdue items are staggered across different days within a week. Stated once there in full; not re-litigated here.

---

## 7. Proposed theme tokens (new — no prior theme exists for this app)

Material 3 Expressive baseline: tonal color roles, larger/varied corner radii, bolder type. Full CSS custom-property block is inlined in every mockup; summarized here for developer handoff.

**Two roles proposed as additions beyond stock Material 3**, since the base M3 spec only ships an `error` semantic role, not `warning`/`success`, and this app's status language needs both:
- `--md-warning` / `--md-warning-container` / `--md-on-warning-container` — used only for "due soon" status.
- `--md-success` / `--md-success-container` / `--md-on-success-container` — used only for "done" status.

Everything else (primary/secondary/surface containers/error/outline) follows stock M3 role naming so developer can map directly onto Android's `MaterialTheme` / `ColorScheme` (Compose) without renaming.

**One category-tint pair added this revision:** `--cat-health-c` (`#F6D9E6`) / `--cat-health-on` (`#4A1030`) — Health check's dusty rose/berry tint (§2a, §6). No other token roles needed adding for this amendment; the undo toast and grouped notification both reuse existing roles (surface/primary-container) rather than introducing new ones.

**Shape scale:** `--shape-xs 8px, --shape-sm 12px, --shape-md 16px, --shape-lg 20px, --shape-xl 28px, --shape-full 999px` — cards at `lg`, the FAB and stage markers at `xl`/`full`, chips at `full`. M3 Expressive leans into rounder, larger radii than M2; this scale reflects that.

**Spacing:** 4dp grid — `--sp-1` through `--sp-7` = 4/8/12/16/24/32/48px.

**Type:** system font stack (`'Google Sans', 'Roboto', system-ui, sans-serif`) — deliberately not bundling a custom font family. A solo developer shipping on Android gets Roboto/Google Sans for free from the platform; bundling a font is a dependency with zero payoff here.

Exact values are in the `:root` block at the top of each mockup file — identical across all of them for consistency.

---

## 7a. Dark theme — full palette, resolved (new, 2026-08-21)

`developer`'s comment in `lib/theme/app_theme.dart` says it plainly: the dark scheme was generated algorithmically via `ColorScheme.fromSeed` for the stock M3 roles, with the two custom semantic roles and the seven category tints hand-guessed as "roughly inverting each pair's tonal relationship" — flagged as needing a real design pass before being treated as shippable. This section is that pass. Mockup: `docs/design/mockups/08-dark-theme.html`.

**Methodology, stated plainly so it's checkable, not just asserted:** I did not naively invert the light palette (swap the container/on-container pair and call it done) or trust `ColorScheme.fromSeed`'s single-seed-hue guess for roles that already have designer-chosen hues in light. Instead, for every role I measured the light-mode value's actual hue and chroma in CIELAB space, then retoned it to M3's standard dark tonal target for that role (primary→tone 80, primaryContainer→tone 30, category container/on-container→tone 30/90, the surface ladder→tones 4/6/10/12/17/22, etc. — the same tone-role assignments M3's own spec uses, computed by hand against this app's actual seed instead of run through the generic seed algorithm). Error keeps the M3 baseline dark tones as-is, since this app's light error is already the unmodified M3 baseline (`#BA1A1A`/`#FFDAD6`) — no reason to deviate there. Every container/on-container pair checks ≥6.5:1 contrast (most ≥7:1) against its own text.

**What I changed from `developer`'s derivation, explicitly:**
- **All seven category tints** — `developer`'s were a rough tonal inversion; these are hue/chroma-anchored retones, and one (vehicle) needed its chroma deliberately reined in to avoid a new collision — see below.
- **Both custom semantic roles (warning, success)** — `developer`'s warning in particular needed correcting past a simple retone: a same-hue version reads as salmon, not amber, at dark-appropriate lightness. See the warning callout below.
- **Two bugs in the shared (non-brightness-specific) theme code**, not really a "light vs. dark palette" issue but found during this pass: `cardTheme.color` and `snackBarTheme.backgroundColor` in `_themeFrom()` use light-appropriate logic unconditionally. See the elevation section below.
- **Health check's category tint hue** is rotated further in dark (335°) than a literal retone of light's hue (348°) would give — the one deliberate light-vs-dark hue deviation in the whole set, and the direct answer to this task's core ask. Full resolution below.
- **Stock M3 roles** (primary, secondary, surface ladder, error) — recomputed via the Lab-retone method above rather than `ColorScheme.fromSeed`'s output, but landed close to what a well-tuned seed-based generation would produce; the point of doing it by hand was to keep every role's hue *exactly* anchored to this app's actual light-mode values (which themselves aren't a pure single-seed derivation — the surface ladder has its own subtle hue, slightly different from primary's) rather than re-deriving everything from one seed color and accepting whatever drift that introduces.

### Status legibility in dark

Shape + icon + color role + text label — all four channels — carry over completely unchanged; only the color role's hex value changes per scheme, which is the entire point of building status language on a role system rather than literal colors. Verified in the mockup's populated Home/List state (§6 of the mockup) with all four statuses present at once (Overdue, Due soon, Upcoming, Done) plus a second Upcoming card specifically to keep Health check in frame next to Overdue's card.

**Overdue specifically** — the one status the brief says must not lose force: dark `errorContainer` is `#93000A` (a deep, saturated red — not lightened or muted for dark), `onErrorContainer` is `#FFDAD6`. Contrast against the dark scaffold is 10.9:1. The pennant-notch silhouette (the one status dot with an asymmetric corner, distinct from every other status and never reused on a category badge) is pixel-identical in shape to light. Nothing about overdue reads softer in dark.

### The warning role needed a hue fix, not just a lightness retone

A literal same-hue retone of light's warning (Lab hue ≈41°, the same hue direction as "amber/brown") up to a dark-appropriate high lightness produces `#FFAC90` — a salmon-peach, sitting only ~14° from dark error's hue (≈31°) at a similar lightness and chroma. This is a real instance of the brief's warning that "saturated hues that work on white frequently vibrate or muddy on near-black" — in this case, a hue that reads clearly as amber/gold-brown at low-to-mid lightness (in light mode) reads as pink-salmon at the high lightness dark mode needs, because the perceptual "amber" direction shifts as lightness increases. I swept hue values at the target lightness and found the point where it reads as gold again: **hue 83°**, giving `#EBC070` (warning) / `#634700` (warningContainer) — a proper amber, 52° from error's dark hue, no ambiguity. This is the single largest hue correction in the whole set and the clearest example of why "just invert the light values" would have failed.

**Second-order consequence, also fixed:** Vehicle's category tint (terracotta/clay in light, deliberately *not* amber, per §6's own rule that category tints avoid amber/red/green) risked drifting back into amber territory in dark if its chroma were boosted by the same ratio as the other categories — a straight 3.1× chroma scale-up lands at `#693C0D`, only 18° from the corrected warning hue and getting close in chroma too. Fixed by keeping Vehicle's dark chroma more muted (1.6× rather than 3.1×) and nudging its hue down slightly (65°→59°), landing at `#5E402D` — still reads as clay/brown, not amber, 24° clear of warning and much lower chroma. This preserves the *reason* Vehicle was made terracotta in the first place (so it wouldn't collide with the status-amber role) into the mode where the collision risk is actually higher.

### Health check vs. error — resolved (the core ask of this pass)

Flagged in light as "the closest hue in the system to error, worth a colorblind check." I did the check, rather than carry the flag forward into dark unresolved, since the brief is explicit that dark makes this harder (less usable hue range near-black) and asks for a resolution, not another flag.

**The fix:** rotated Health check's dark hue to **335°** (still reads as "berry/plum" — the family the copy already promises, e.g. "dusty rose/berry") rather than a literal retone of light's hue (348°). This gives:
- **~56° separation from dark error's hue (31°)**, up from ~43° a naive same-hue retone would have given.
- **Checked against the next-nearest category, not just error in isolation** — 335° sits ~26° from Professional Licence's violet (309°), which is a comfortable margin; I didn't fix one collision by creating another.

**Verified under simulated colorblindness, not just hue-angle math.** I ran both candidate hues through the Machado et al. (2009) protanopia and deuteranopia simulation matrices against dark `errorContainer` (`#93000A`). Under simulated deuteranopia, error-container renders as an olive-brown (`#5C5100`); the chosen Health-container (hue 335°) renders as a blue-slate (`#434A5F`) — a CIELAB ΔE of **56** (ΔE >10 is the conventional threshold for "clearly distinguishable"; this is over 5× that). The naive same-hue candidate (348°) scored ΔE 46 under the same simulation — probably already fine, but the rotation adds real, quantified margin rather than being a cosmetic gesture. The mechanism is worth stating because it generalizes: pink/magenta carries more blue than red-orange does, and dichromats retain blue-axis discrimination even when red-green discrimination collapses — so rotating a warm-pink hue *toward violet* is specifically the right move when it needs to stay clear of a red, not an arbitrary tweak.

**Resolved by hue separation — reinforced by form, not dependent on it.** The two never had to be told apart by color alone even in principle: Health's badge carries its own heart+pulse glyph and sits in a card's *type-badge* slot (left); Overdue's status dot carries the pennant-notch silhouette and sits in the *status* slot (right) — different UI regions, different icons, per §6's own "shape+icon+color+label, not color alone" rule. The hue fix removes the risk at the color layer specifically because that's the layer that was actually close; form differentiation was already sound and unchanged.

**I'm treating this as resolved, not re-flagged.** Given the hue-angle margin, the simulated-colorblindness verification, and the pre-existing form differentiation, I don't think this needs another look before `developer` implements it — but the deltaE numbers and hue angles above are reproducible from the hex values in the token table, so `qa-tester` can re-check with a proper CVD-simulation tool during their pass if they want an independent confirmation.

### Elevation and shadow — the light-mode assumption that breaks in dark

Material 3's dark mode conveys elevation with a **tonal surface ladder** (each higher surface uses a progressively lighter tone of the same near-black neutral), not primarily with shadow — a drop shadow is always literally black, and black-on-near-black is nearly invisible. The light theme's cue is the opposite: a card that's *whiter* than its scaffold (`surfaceContainerLowest`, tone 100, on a tone-98 scaffold) plus a shadow that reads clearly against a light background. That specific pairing doesn't survive a straight port to dark, and I found two places in the current shared theme code where it wasn't ported at all — both are real, confirmed defects, not hypothetical risk:

1. **`cardTheme.color` is `colorScheme.surfaceContainerLowest` unconditionally.** In dark, `surfaceContainerLowest` is tone 4 — *darker* than the tone-6 scaffold sitting behind it. A card would render as a faint recessed hole, the opposite of "elevated." **Fix:** in dark, cards should sit on `surfaceContainer` (tone 12) at rest and `surfaceContainerHigh` (tone 17) when held/raised (long-press) — both lighter than the tone-6 scaffold, correct direction, matching the tonal-ladder approach.
2. **`snackBarTheme.backgroundColor` hardcodes the literal `Color(0xFF2B2B33)`.** In light this works precisely because it's a fixed dark neutral against a light page — it's implicitly playing the role of "the opposite scheme's surface." In dark, `#2B2B33` sits almost exactly inside the `surfaceContainerHigh`/`surfaceContainerHighest` range (`#2A2932`–`#35343D`) — the toast would nearly vanish into the page it's meant to float above. **Fix:** use the role M3 actually defines for this — `inverseSurface`/`onInverseSurface`, which by construction always renders as the opposite scheme's surface. Dark's `inverseSurface` computes to `#E3E2E9` with `onInverseSurface` `#303036` (i.e., a light toast on a dark screen — also standard platform behavior elsewhere on Android).

The FAB (`primaryContainer`) and the bottom sheet / overflow menu popover need no fix beyond the same tonal-ladder logic: bottom sheet and menu popover should sit at `surfaceContainerHighest` (tone 22, the brightest floating tier) rather than `surfaceContainerLowest` in dark. Full mapping table, plus a visual elevation-ladder strip, is at the top of `08-dark-theme.html`.

### Full token table (developer handoff)

Every dark hex value — `ColorScheme` fields, both custom semantic roles, all seven category tints — is tabulated in `08-dark-theme.html` §5, keyed to the exact field names already used in `lib/theme/app_theme.dart`, `app_semantic_colors.dart`, and `category_tint.dart` (`kCategoryTintsDark`), so this is a value-swap for `developer`, not a re-interpretation. Light-mode values are repeated alongside each dark value in the same table for direct comparison and to make clear which values are genuinely unchanged (error's base tones, the FAB's color role) versus corrected.

---

## Rejected alternatives (summary)

- **Bottom nav / tabs** — rejected as unnecessary chrome for an app with one real hub.
- **Vertical checklist for the ladder** — rejected in favor of a horizontal timeline; a checklist reads as generic tasks, not as time-to-act, which is the actual product.
- **Sharing status and category color spaces** — rejected; kept structurally separate to stay scannable once multiple types share a list.
- **Escalating (tightening) overdue cadence, matching a more aggressive competitor pattern** — rejected on fatigue data; used a de-escalating cadence instead.
- **Exact-alarm permission as a mandatory onboarding step** — designed as optional and deferred instead, pending developer's feasibility check, specifically so it can be cut with zero rework if unneeded.
- **Free tier's single reminder at the ladder's closest-to-due stage** (a literal reading of the scope doc) — rejected for long-lead types; tuned per type instead so the free tier doesn't set users up to fail on items like passport.
- **(New this revision) A labeled dropdown of common recheck intervals for Health check** (e.g., "6 months / 12 months / 2 years / Custom") — rejected in favor of a freely editable stepper; see §2a for the full reasoning — a curated shortlist reintroduces the "the app is telling you what's valid" problem one level down from a locked recommendation.
- **(New this revision) A persistent disclaimer caption directly under the Health check interval field, as the primary mechanism for the "not medical advice" constraint** — rejected in favor of fixing the field's *container* (plain stepper, not a tinted callout) so the constraint is satisfied by what the field looks like, not only by a sentence a user learns to skip. See §2a.
- **(New this revision) A second grouping layer splitting overdue vs. upcoming notifications within the same day's summary** — rejected as complexity for a rare double-collision; per-line status text inside the expanded group already disambiguates. See §6a.
- **(New, dark theme pass) Naive light-to-dark inversion** (swap each pair's container/on-container and call it done) — rejected as the whole premise of this pass; every role was retoned from its own hue/chroma in Lab space instead. See §7a for why a literal inversion specifically fails for the warning role (reads as salmon, not amber) and for elevation (shadow-led cues don't survive the swap at all).
- **(New, dark theme pass) A persistent disclaimer or badge distinguishing Health check's badge from Overdue's status dot, as the primary fix for the hue-proximity risk** — rejected as unnecessary once the hue itself was properly separated and verified under CVD simulation (§7a); the two already differ in form (icon, silhouette, position) and don't need a third signal bolted on for a risk that no longer measures as close.

---

## Open questions for product-manager / user

1. **(Carried over, now resolved)** Custom's lead-time selector — accepted into scope; Short/Long values finalized in §2b.
2. **(Carried over, now resolved)** Undo toast — accepted into scope; treatment in §4a.
3. **(New)** §2's worst-case math note: grouping fully fixes same-day-clustering but not a staggered-across-the-week overdue pile-up. I'm not proposing to design further against the staggered case — flagging it so the team is choosing to accept it explicitly, not by omission.
4. **(Resolved in the dark theme pass, 2026-08-21)** The Health check category tint's proximity to the error role — originally flagged in light as worth a colorblind check. I ran that check for the dark palette (§7a): hue separation from error increased from ~43° to ~56°, verified under simulated protanopia/deuteranopia (ΔE 56, well past the ΔE >10 "clearly distinguishable" threshold). Light's tint is unchanged and, on the same reasoning, was already far enough from error there not to need a hue change — only dark did. I'm treating this as closed; still worth a glance at `08-dark-theme.html`'s side-by-side swatches if anyone wants to sanity-check my read independently, but it's no longer an open question from my side.
5. Does the free-tier reminder-timing table in §5 (deviating from a literal "single reminder ahead of due date" reading) match intent, or was a fixed single lead time actually preferred for simplicity? Still open from the original pass — unchanged by this amendment.
6. **(New, dark theme pass)** Two bugs found in the *shared* theme code while doing this pass (not a dark-palette question, but adjacent) — `cardTheme` and `snackBarTheme` in `app_theme.dart` use light-appropriate role choices unconditionally for both schemes (§7a). I've specified the fix; routing to `developer` to confirm before/while applying the dark token table, since these affect how every other dark screen actually looks regardless of the palette values being correct.

---

## Suggested enhancements (beyond what was asked — for triage, not commitments)

Two items from the previous pass's table are now in scope (undo toast, Custom selector) and have been removed from this list accordingly — they're specified above, not pending triage anymore. **(Revision 2026-08-21)** "Snooze duration picker (not fixed 2 weeks)" is also removed from this table — Snooze itself was cut from v1 (§4), so a refinement of it isn't a meaningful suggestion right now. If Snooze is ever revisited per-usage-data as a P1 candidate (scope doc §7), a duration picker would be a reasonable follow-on suggestion at that time, not before.

| Idea | Why | Impact |
|---|---|---|
| Tap-to-explain on the ladder track ("Based on typical passport processing time") | Builds trust in the ladder's timing specifically where research couldn't fully validate the numbers — directly supports the paid pitch | Medium |
| Home-screen summary line for paid users ("6 items · full ladder active") | Cheap, ongoing reminder of what was purchased, without another notification | Low–Medium |
| A visible, persistent "N items overdue" count somewhere in the app icon/list header, distinct from any individual notification | If the team ever revisits the staggered-overdue-week gap noted in §2/§6a, an in-app aggregate view is a cheaper lever than more notification-side engineering — it moves the "catch up" moment into the app instead of the tray | Low, speculative — only worth it if the staggered-week gap turns out to matter in practice |
| **(New 2026-08-21)** A one-time coach-mark hint for long-press-to-delete, shown the first time a card renders | Long-press is a well-established Android pattern but is inherently less discoverable than a visible icon; a first-use hint is the cheap mitigation if testing shows people don't find it (see §4b) — not designed here, flagged for triage | Low |
| **(New, dark theme pass)** `qa-tester` re-verifies the Health check vs. error hue separation with a proper device-level CVD-simulation tool (e.g. Android Accessibility Scanner or a browser CVD emulation extension) against the actual rendered app, not just the token hex values | My simulation used a standard published matrix (Machado et al. 2009) against the palette in isolation — a strong signal, not a substitute for seeing it rendered on-device with real icon glyphs at real size | Low — I'm confident in the result, this is a cheap independent confirmation, not a sign something's wrong |
| System (not just app) dark mode: verify the notification-tray mockups (`07-notifications.html`) against the OS's own dark notification shade styling, which this pass didn't touch | Notifications render in OS chrome the app doesn't control — grouped/expanded notification legibility in a dark shade wasn't part of this pass's scope (which was the in-app dark theme) and is worth a separate, smaller look | Low–Medium |

---

## States coverage checklist (per working agreement)

| Screen | Loading | Empty | Error | Success |
|---|---|---|---|---|
| Home/List | ✓ skeleton | ✓ first-run type-picker (now 7 tiles) | ✓ read-failure retry | ✓ grouped by status, + ✓ undo-toast (delete/mark-done), + ✓ long-press delete revealed (new 2026-08-21) |
| Add/Edit | ✓ saving spinner | ✓ blank form | ✓ validation error | ✓ saved confirmation, + ✓ Health check selected (recurrence field + one-time note), + ✓ Custom with lead-time selector |
| Item detail | ✓ skeleton | n/a (always has data) | ✓ not found | ✓ free-tier + ✓ paid-tier + ✓ Health check + ✓ mark-done recurrence bottom sheet + ✓ undo-toast + ✓ overflow (⋮) menu — Delete (new 2026-08-21) |
| Paywall | ✓ billing check | n/a | ✓ purchase failed | ✓ purchased |
| Notification permission | n/a (instant) | n/a | ✓ denied-recovery | ✓ granted |
| Exact-alarm (conditional) | n/a | n/a | ✓ denied-recovery | ✓ granted |
| Settings/Privacy | ✓ | n/a (static) | ✓ load failure | ✓ populated (broadened legal+medical disclaimer) |
| Notification tray (new, `07-notifications.html`) | n/a | n/a | n/a | ✓ single stage (Mark done only, no Snooze), ✓ single overdue nag (Mark done only), ✓ grouped/collapsed, ✓ grouped/expanded |
| **Dark theme (new, `08-dark-theme.html`)** | ✓ Home/List + Item detail skeletons | ✓ Home/List first-run (7 tiles) | ✓ Home/List read-failure, ✓ Item detail not-found | ✓ Home/List populated (all 4 statuses in one screen), ✓ Item detail free/paid/Health check, + elevation-fix demos (undo toast, overflow menu) |
