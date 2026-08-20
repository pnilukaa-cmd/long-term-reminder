# V1 Design Direction — renewal-reminder

Prepared by: ux-designer
Date: 2026-08-20
Inputs: `CLAUDE.md`, `docs/product/01-v1-scope.md` (§6 routes six questions here), `docs/research/00-problem-space.md`
Routed to: product-manager (react/prioritize), business-analyst (lock acceptance criteria against this), developer (implement), user (react)
Mockups: `docs/design/mockups/*.html` — open directly in a browser, no build step, no external dependencies

No shared theme/token source exists yet for this app (first design pass on a brand-new project) — §7 below **is** the theme, proposed for the first time here. It's inlined into every mockup's `<style>` block rather than linked, since these files are meant to be opened standalone.

---

## 0. Headline answer: notification volume (routed question 2)

**A fully-paid user tracking 5 items receives roughly 0.9 push notifications per month on average, in steady state, assuming on-time renewals.** That's about one notification every five to six weeks. Full math and the worst-case bound are in §2. This is the number the rest of the design is built to protect — if any later change (more stages, tighter spacing, per-item customization) pushes that average up, treat it as a regression against this constraint, not a free variable.

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
7. **Settings / Privacy** — mostly static: privacy disclosure (local-only, nothing leaves the device — worth stating even though it's table stakes per research, users still expect to see it), notification settings deep-link, restore purchase, about/version.

### 1a. First-run empty state — treated as a primary design problem

A generic "No items yet — tap + to add" empty state is a dead end: it names the problem but doesn't reduce the effort of solving it, and data entry here is exactly the tedious step research flags as the real first-run risk. Instead, the empty home screen **is** the add flow's first step: it shows the six type presets as large tappable tiles directly on the empty state ("What do you want to track first?"), so the fastest path from cold launch to first tracked item is one tap on a tile, not "notice empty state → find FAB → open form → pick type from a dropdown." The copy also does one job the blank state usually skips: it states the value proposition at the exact moment the app has nothing else to show for itself yet ("We'll remind you early enough to actually act — not just in time to panic.") See `docs/design/mockups/01-home-list.html`, empty state panel.

---

## 2. Reminder ladders — proposals for all six types, with reasoning

Travel Document Vault's 6mo/3mo/6wk/2wk/1wk is the given reference for passport. I trimmed it to four stages (merging the 6wk/2wk pair into a single "1 month" stage) — the 6-month and 3-month stages are the ones doing the real work given US passport processing backlogs (research: 4–6 weeks routine processing, guidance to renew with 12+ months validity, common 6-month-remaining entry rules), while a 5th stage in the final month adds volume without adding a materially different action window.

The other five types have no competitor-cited rationale in research, only competitor *convention* (Autodue 60/30/14/7, Expiro 30/7/1) with no stated reasoning behind the numbers. I grounded each proposal in **how long the type's actual renewal action takes**, not just how severe the consequence is — severity tells you how much it matters, action-duration tells you how early the reminder needs to fire to be useful. A reminder that fires with more lead time than the action needs is just extra noise; the research's own core complaint about naive "remind harder" design.

| Type | Paid ladder (before due date) | Why this spacing |
|---|---|---|
| **Passport / Travel ID** | 6 months, 3 months, 1 month, 1 week | Action takes weeks of processing + mail; early stages are the ones that matter, per research |
| **Insurance** | 21 days, 7 days, 1 day | Shopping/renewing insurance is a same-day action (compare, pay); no need for a months-out stage, but daily risk while lapsed is severe (research: criminal offence in UK), so it stays close to the deadline |
| **Professional Licence/Certification** | 90 days, 30 days, 7 days | Renewal usually requires accumulating CE/CPD hours plus board processing time (research: reinstatement after a lapse gets materially worse the longer it runs) — needs lead time an insurance-style reminder doesn't |
| **Vehicle (generic)** | 30 days, 14 days, 3 days | Same action-duration profile as insurance (book a test/renew tax online, a same-day-to-few-days task); mirrors insurance's shape rather than passport's |
| **Warranty** | 30 days, 7 days | Pure financial-loss, no legal exposure (research explicitly separates this from the criminal-offence types) — lighter ladder is deliberate, not an oversight |
| **Custom / Other** | 30 days, 7 days, 1 day | Unknown risk profile; defaults to the most generic competitor convention (Expiro's 30/7/1) since we can't reason about the specific action |

**Overdue follow-through (paid only) — de-escalating, not escalating, and type-aware:**

| Type | Overdue nags after due date | Reasoning |
|---|---|---|
| Passport | Day 0, +10d, +30d (3 total, then list-status only) | Ongoing but slow-moving risk; wide spacing matches the slow-moving nature |
| Insurance | Day 0, +3d, +10d, +30d (4 total) | Daily risk while lapsed, closer spacing early on |
| Professional Licence | Day 0, +7d, +21d (3 total) | Consequence compounds gradually (per research), not immediately punitive |
| Vehicle | Day 0, +3d, +10d, +30d (4 total) | Same daily-risk profile as insurance |
| Warranty | Day 0 only, then stops | **There is nothing to fix by nagging further** — the warranty window just closes. Continuing to nag about something the user cannot un-expire is the punitive pattern the working relationship should avoid. This is a deliberate type-specific exception, not a missed case. |
| Custom | Day 0, +7d, +21d (3 total) | Generic default |

Every ladder gets **wider, not tighter**, as it goes — the spacing between nags increases (3d → 10d → 30d, not 30d → 10d → 3d) after the due date. This is the mechanical answer to routed question 4 (how follow-through reads as non-punitive): the app checks in less urgently over time, the opposite of an escalating alarm, and copy never uses blame language ("you forgot") — see §4.

### The math behind the headline number

**Steady-state average, 5-item mixed portfolio (1 passport, 1 insurance, 1 vehicle, 1 licence, 1 warranty), on-time renewals, paid tier:**

| Item | Stages/cycle | Cycle length | Avg/month |
|---|---|---|---|
| Passport | 4 | 120 mo (10 yr) | 0.033 |
| Insurance | 3 | 12 mo | 0.25 |
| Vehicle | 3 | 12 mo | 0.25 |
| Licence | 3 | 12 mo | 0.25 |
| Warranty | 2 | 24 mo (2 yr) | 0.083 |
| **Total** | | | **≈ 0.87/month** |

**Worst-case realistic clustering** (insurance and vehicle happen to renew the same month — common, since people often insure a car right when they register it): peak single week still only reaches ~2 notifications. Comfortably under the 2–6/week range research cites as where a meaningful share of users disable notifications or uninstall.

**Degenerate worst case** (all 5 items overdue simultaneously — everything lapsed at once, an edge case, not the design center): 15 overdue nags spread across ~5 weeks, peaking around 5 notifications in the first week (all five "day 0" nags landing together) and tapering. That peak week sits at the edge of, but still inside, the research-cited 2–6/week threshold — worth stating honestly rather than rounding it away, but it only occurs for a user who has let every single tracked item lapse at once, which is a self-selecting scenario already at elevated disable/uninstall risk regardless of what this app does.

**If this number ever becomes uncomfortable** (e.g., business-analyst or a tester's portfolio is more concentrated than this example, with several annual items sharing a renewal season), the lever to pull is the *paid* ladder's stage count per short-cycle type, not the free tier — free tier is already a single notification and can't be cut further without breaking the calendar-equivalence promise in §2 of the scope doc.

---

## 3. How the ladder is surfaced (routed question 3)

Two levels, deliberately different in density:

- **List/home card:** shows only the *next* upcoming stage as a compact chip ("Next: 1 month before · Jul 12"), plus a minimal stage-progress indicator — a small row of dots, one per ladder stage, filled for stages already fired. This answers "is my cadence active and how far through it am I" in about a quarter-second glance, without listing every date on every card. Listing every stage on every list row would be the clutter failure mode the brief warns about.
- **Item detail:** the full ladder as a horizontal timeline/track running from "today" to the due date, with a marker at each stage (fired stages filled, upcoming stages outlined, due date marked distinctly). This is the moment the differentiator gets to be fully legible — the user is already looking at one item and deciding whether the app's cadence design is trustworthy, so this is where it earns the fuller treatment. See `docs/design/mockups/03-item-detail.html`.

**Rejected alternative:** a vertical checklist of stages (like a to-do list). It's easier to build but reads as a generic task list, not as *time* — and time-to-act is the actual product. A horizontal timeline visually encodes the axis that matters (how much runway is left) in a way a checklist doesn't.

---

## 4. Mark-as-done and follow-through tone (routed question 4)

- **From the list:** a quick action on the card (tap a "Mark done" affordance, no swipe-only gesture — swipe-to-dismiss is easy to trigger accidentally on a screen full of stacked cards, and this data doesn't have cloud undo). For types that typically recur (insurance, vehicle, licence, and passport at a longer horizon), marking done opens a small bottom sheet: "Nice — when's the next one due?" with a one-tap smart default ("Same time next year" / "+10 years" for passport) plus a manual date picker. Warranty skips the recur prompt (nothing to renew); Custom asks a yes/no "does this repeat?" first, since we don't know its cadence.
- **From a notification:** the expanded notification carries two actions, **Mark done** and **Snooze 2 weeks**, so most resolutions never require opening the app. Tapping "Mark done" from a notification clears the current cycle and cancels remaining ladder stages immediately; the recurrence question ("when's the next one due?") is deferred to a small inline banner on the item's detail screen the next time the app is opened — **not** a follow-up push notification. Firing a second notification to ask about the first one is exactly the kind of self-inflicted fatigue the research warns about.
- **Tone:** overdue notifications never use blame language ("you forgot," "you failed to..."). Copy stays collaborative and matter-of-fact: *"Insurance renewal — still open"* / *"Still need to sort this?"* with **Mark done** / **Snooze** actions, not a bare dismiss. The visual treatment leans on the existing error/overdue color to carry urgency rather than stacking urgent copy on top of urgent color — see status language in §6.

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
| Custom | 14 days before |

This reframes the upgrade pitch from "we deliberately gave you a bad reminder" to "we'll remind you once — upgrade for the full countdown, plus we'll check that you actually did it." That's the honest difference (escalation + follow-through), and it's the one the positioning already claims is defensible.

**Where the difference is shown:** not a separate promotional screen the user has to seek out or dismiss as an ad. On a free-tier item's detail screen, the ladder track (§3) renders the unlocked reminder as normal and the *would-be* additional stages as greyed-out, locked markers in their correct time positions on the same timeline — the user can see exactly where the extra warnings would have fired, at the exact moment they're evaluating whether this item's cadence is trustworthy. A small "Unlock full ladder" affordance sits inline on that visual, not as a separate interstitial. This is the direct answer to "make the difference legible at the moment it matters" — the moment is item detail, not app launch or list view. See the free-tier variant in `docs/design/mockups/03-item-detail.html`.

The dedicated paywall screen still exists (accessible from settings and from that inline prompt) for the actual purchase transaction, but its job is completing a decision the user already made looking at the ladder track, not making the pitch from scratch — so it can afford to be short: what you get, price, one button. See `docs/design/mockups/04-paywall.html`.

---

## 6. Visual language: type icons and status language (routed question 6)

**Two separate encoding systems, deliberately not sharing a color space:**

- **Category tint** (which of the 6 types this is) — a tonal container color pair per type, used only on the type icon/badge.
- **Status color** (upcoming / due soon / overdue / done) — a semantic role, used on status chips and the ladder track.

If both systems drew from the same hue family, an amber vehicle icon next to an amber "due soon" chip would be genuinely ambiguous at a glance. Category tints deliberately avoid amber, red, and green — those three hues are reserved for status.

| Type | Icon motif | Category tint |
|---|---|---|
| Passport/Travel ID | booklet + wing/globe mark | Blue |
| Insurance | shield | Teal |
| Professional Licence | ribbon/certificate | Violet |
| Vehicle | car | Terracotta/clay (not amber) |
| Warranty | box + check | Slate blue-grey |
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

## 7. Proposed theme tokens (new — no prior theme exists for this app)

Material 3 Expressive baseline: tonal color roles, larger/varied corner radii, bolder type. Full CSS custom-property block is inlined in every mockup; summarized here for developer handoff.

**Two roles proposed as additions beyond stock Material 3**, since the base M3 spec only ships an `error` semantic role, not `warning`/`success`, and this app's status language needs both:
- `--md-warning` / `--md-warning-container` / `--md-on-warning-container` — used only for "due soon" status.
- `--md-success` / `--md-success-container` / `--md-on-success-container` — used only for "done" status.

Everything else (primary/secondary/surface containers/error/outline) follows stock M3 role naming so developer can map directly onto Android's `MaterialTheme` / `ColorScheme` (Compose) without renaming.

**Shape scale:** `--shape-xs 8px, --shape-sm 12px, --shape-md 16px, --shape-lg 20px, --shape-xl 28px, --shape-full 999px` — cards at `lg`, the FAB and stage markers at `xl`/`full`, chips at `full`. M3 Expressive leans into rounder, larger radii than M2; this scale reflects that.

**Spacing:** 4dp grid — `--sp-1` through `--sp-7` = 4/8/12/16/24/32/48px.

**Type:** system font stack (`'Google Sans', 'Roboto', system-ui, sans-serif`) — deliberately not bundling a custom font family. A solo developer shipping on Android gets Roboto/Google Sans for free from the platform; bundling a font is a dependency with zero payoff here.

Exact values are in the `:root` block at the top of each mockup file — identical across all of them for consistency.

---

## Rejected alternatives (summary)

- **Bottom nav / tabs** — rejected as unnecessary chrome for an app with one real hub.
- **Vertical checklist for the ladder** — rejected in favor of a horizontal timeline; a checklist reads as generic tasks, not as time-to-act, which is the actual product.
- **Sharing status and category color spaces** — rejected; kept structurally separate to stay scannable once multiple types share a list.
- **Escalating (tightening) overdue cadence, matching a more aggressive competitor pattern** — rejected on fatigue data; used a de-escalating cadence instead.
- **Exact-alarm permission as a mandatory onboarding step** — designed as optional and deferred instead, pending developer's feasibility check, specifically so it can be cut with zero rework if unneeded.
- **Free tier's single reminder at the ladder's closest-to-due stage** (a literal reading of the scope doc) — rejected for long-lead types; tuned per type instead so the free tier doesn't set users up to fail on items like passport.

---

## Open questions for product-manager / user

1. Does the free-tier reminder-timing table in §5 (deviating from a literal "single reminder ahead of due date" reading) match intent, or was a fixed single lead time (e.g., always 7 days, regardless of type) actually preferred for simplicity? I'd push back on that being simpler-but-worse for passport specifically.
2. Is the Custom type's fixed 30/7/1 ladder acceptable, or should it get a cheap escape hatch (see Suggested Enhancements — a single short/medium/long lead-time selector, not full per-stage editing) given it's the one type where the default is a guess?
3. Confirm the worst-case "all 5 items overdue at once" peak (~5 notifications in one week) is an acceptable edge case to accept rather than design further against.

---

## Suggested enhancements (beyond what was asked — for triage, not commitments)

| Idea | Why | Impact |
|---|---|---|
| Undo toast after "mark done" / delete | Local-only storage means no cloud undo; an accidental tap is unrecoverable without this. Cheap (a toast + a few seconds' grace), meaningfully reduces error-recovery anxiety. | **High**, low effort — worth reconsidering for v1 itself, not just backlog |
| Custom type: single short/medium/long lead-time selector (not full ladder editing) | Custom is the one type where a fixed default is a guess, not a grounded proposal; a single dropdown is far cheaper than the deferred full per-stage editing (P1 in scope doc) | Medium |
| Tap-to-explain on the ladder track ("Based on typical passport processing time") | Builds trust in the ladder's timing specifically where research couldn't fully validate the numbers — directly supports the paid pitch | Medium |
| Home-screen summary line for paid users ("5 items · full ladder active") | Cheap, ongoing reminder of what was purchased, without another notification | Low–Medium |
| Snooze duration picker (not fixed 2 weeks) | More flexible, but real added complexity for a P2-feeling need | Low |

---

## States coverage checklist (per working agreement)

| Screen | Loading | Empty | Error | Success |
|---|---|---|---|---|
| Home/List | ✓ skeleton | ✓ first-run type-picker | ✓ read-failure retry | ✓ grouped by status |
| Add/Edit | ✓ saving spinner | ✓ blank form | ✓ validation error | ✓ saved confirmation |
| Item detail | ✓ skeleton | n/a (always has data) | ✓ not found | ✓ free-tier + ✓ paid-tier |
| Paywall | ✓ billing check | n/a | ✓ purchase failed | ✓ purchased |
| Notification permission | n/a (instant) | n/a | ✓ denied-recovery | ✓ granted |
| Exact-alarm (conditional) | n/a | n/a | ✓ denied-recovery | ✓ granted |
| Settings/Privacy | ✓ | n/a (static) | ✓ load failure | ✓ populated |
