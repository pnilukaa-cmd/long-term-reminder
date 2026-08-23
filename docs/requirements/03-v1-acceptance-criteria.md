# V1 Acceptance Criteria — renewal-reminder

Prepared by: business-analyst
Date: 2026-08-21 (amended 2026-08-23 — see revision note below)
Inputs: `CLAUDE.md`, `docs/product/01-v1-scope.md` (amended), `docs/design/02-v1-design.md` (amended), `docs/design/mockups/*.html`
Routed to: developer (build), qa-tester (test criteria), product-manager (confirm flagged conflicts/defaults)

Numbering starts at REQ-1 — first requirements doc for this project. Each requirement cites the mockup file/tab it's written against where one exists. Where a requirement resolves a gap the mockups/scope leave open, it's marked **[BA DEFAULT]** with the assumption stated — treat these as fast-confirmation items, not blockers, unless flagged otherwise in §0.

---

## Revision note (2026-08-23)

Closes out the items routed to business-analyst in scope doc §8 that were still open, plus one implementation review requested directly. Five changes, all below:

1. **§0.1 / REQ-11.3 (Snooze):** closed as resolved-cut, not open. REQ-11.3 is locked to a single `Mark done` notification action — the "contingent on §0.1" branch is removed, since there's only one branch now. The corresponding line in §15 and risk item 4 in §16 are updated to match (both were written when Snooze's fate was still undecided).
2. **§0.2 / REQ-5.4 (long-press delete):** re-framed as a confirmed product decision, not a tentative BA default — ux-designer has since drawn both previously-missing states (`01-home-list.html`'s long-press-reveal panel, `03-item-detail.html`'s expanded-overflow-menu panel). Criteria substance is unchanged, per product-manager's 2026-08-21 note that this wouldn't need to change, only its framing.
3. **REQ-4.2 (`Done` status):** the single `Done` bullet is rewritten into two, distinguishing terminal items (Warranty; "no repeat" Custom) — where `Done` is a real, persistent status — from recurring items, where `Done` is never a status the item sits in past the moment its next cycle's due date is set, per product-manager's 2026-08-21 recurrence-lifecycle decision (scope doc §3d).
4. **New: REQ-9.7, `Undo last completion`** — acceptance criteria for the new item-detail action from scope doc §3d, including its single-level-undo boundary. Not yet mocked (flagged inline, same convention as REQ-9.2/9.4).
5. **REQ-1.4 (Settings disclaimer):** a new paragraph naming the force-stop notification gap plainly, per the technical ADR's (`04-scheduling-and-stack.md` §2) finding that this is a real, unfixable-in-code limitation that belongs in user-facing copy, not just an engineering note.

Also reviewed and resolved: developer's flagged stripped-down notification-permission implementation (§0.8, REQ-11.1) — the reduced UI shape is **accepted**, but a specific defect in the implementation is **not accepted as shipped** and must be fixed. See §0.8 and the revised REQ-11.1 for the full reasoning and the exact criteria this resolves to.

---

## 0. Conflicts, gaps, and things two developers would build differently

Read this section first. These are not silently resolved elsewhere in this document without a flag.

### 0.1 [RESOLVED 2026-08-21 by product-manager] Snooze is cut from v1

Originally flagged here as an unresolved conflict: `docs/design/02-v1-design.md` §4 and both panels of `docs/design/mockups/07-notifications.html` drew a "Snooze 2 weeks" action on every notification, despite Snooze never appearing in scope doc §1's P0 list, §8's routing, or §6's notification-volume math (≈1.12/month, which never counted a Snooze re-post). product-manager resolved this in the 2026-08-21 revision of `01-v1-scope.md`: **Snooze is cut from v1 entirely**, not accounted for.

Reasoning (full detail in that doc's Decision 1): the existing ladder/overdue cadence already re-touches an unactioned notification later, on schedule, without needing a second scheduling mechanism — dismissing a notification doesn't lose the item, it stays visible at its correct status and gets reminded again by the mechanism that's already budgeted. Snooze would have added real, unbudgeted state-machine complexity (interacting with grouping and cancellation bookkeeping) for a convenience feature, not a gap in the core loop. ux-designer removed the action from both mockup panels and design doc §4's text. This document's REQ-11.3 is updated accordingly (below) — only `Mark done` ships as a notification action in v1.

**This is closed, not deferred.** Snooze remains a real P1 candidate for a future release, contingent on actual usage evidence (not assumption) and an honest re-count of the volume math if it's ever revisited — see scope doc §7 — but there is nothing left to resolve here for v1.

### 0.2 [CONFIRMED 2026-08-21] Delete affordance: long-press (list) / overflow menu (detail)

Originally flagged here as a gap: scope doc §3c named "list quick-action" as a covered undo-toast trigger for delete, but no mockup showed a list-level delete affordance, and item-detail's overflow (⋮) menu was never expanded in any panel. business-analyst's default (long-press-to-reveal on the list, overflow-menu on detail) was adopted by product-manager as a confirmed decision on 2026-08-21 — see that revision note's "Decision 2" in `01-v1-scope.md` — for the standard Android reasons: avoids a permanent per-row icon, consistent with the same accidental-trigger reasoning already used to reject swipe-to-delete, and keeps delete reachable in one screen rather than forcing a detour through item detail.

**Both states are now drawn**, closing the visual gap this section originally flagged: `docs/design/mockups/01-home-list.html`'s tab labeled "Long-press — delete revealed (new)", and `docs/design/mockups/03-item-detail.html`'s tab labeled "Overflow menu — Delete (new)". REQ-5.4 below is updated to cite these directly and drop its `[BA DEFAULT]` framing — the interaction pattern and its visuals are both locked now, not a placeholder.

### 0.3 Timing of the 6-second undo window against the mark-done recurrence bottom sheet is not specified, and the naive reading breaks it

Scope doc §3c says the undo window is "6 seconds" and, on revert, "any recurrence bottom-sheet choice made during the window" is undone — implying the bottom sheet interaction happens *inside* the 6-second window. But the bottom sheet (`03-item-detail.html`, panel p6) offers a "Pick a different date" option that opens a full date picker — a flow that routinely takes longer than 6 seconds to complete. If the countdown starts the instant "Mark done" is tapped, a user who chooses the manual date-picker path will frequently find Undo already expired by the time they've finished, for reasons that have nothing to do with hesitation.

**[BA DEFAULT]:** the 6-second countdown starts when the mark-done interaction **fully resolves**, not when it starts — i.e., immediately after tap for non-recurring types (Warranty, and any type where the user declines Custom's "does this repeat?" prompt), and immediately after the bottom sheet is dismissed (whether via the one-tap smart default or the manual date picker) for recurring types. See REQ-10.2.

### 0.4 Only the Health check variant of the mark-done recurrence bottom sheet is actually mocked

Design doc §4 describes three variants in prose — the generic recurring-type sheet (insurance/vehicle/licence/passport, smart default "Same time next year" / "+10 years"), the Health check variant (shown, `03-item-detail.html` panel p6), and Custom's yes/no "does this repeat?" prompt — but only the Health check one exists as an actual mockup panel. Acceptance criteria for the other two (REQ-9.2, REQ-9.3) are written against the design doc's text description, not a drawn state. This is a lower-severity gap than 0.2 (behavior is described, just not drawn) — flagging so it isn't mistaken for a verified mockup when QA writes test cases. The new REQ-9.7 (`Undo last completion`, added 2026-08-23) is in the same position — described in scope doc §3d, not yet drawn anywhere.

### 0.5 Recurrence smart-default is computed from the due date, not the completion date — stated once, applied everywhere for consistency

The Health check bottom sheet mockup computes "Same as your setting — In 12 months" as **14 May 2028**, which is the item's due date (14 May 2027) plus 12 months — not "today plus 12 months." Nothing in either doc says this explicitly for the other recurring types, but I'm applying the same rule uniformly (REQ-9.1) rather than leaving each type to infer its own basis, since a user marking an item done early (before its due date) would otherwise get a different next-cycle date depending on which developer wrote which type's logic. **[BA DEFAULT, inferred from the one mocked example, not independently confirmed]** — flagging because it's exactly the kind of thing that's obvious once you see it and easy to get inconsistently right without a stated rule. product-manager confirmed this as an owned product decision on 2026-08-21 (see `01-v1-scope.md`'s "Five business-analyst defaults reviewed and confirmed" section).

### 0.6 Entitlement loss, timezone/clock changes, and past-dated items at creation are not addressed in either source document

Covered as new rules in §14 (edge cases) — these are genuinely absent from scope and design, not contradictions between them. Resolved with stated defaults; product-manager confirmed all three as owned product decisions on 2026-08-21 (see `01-v1-scope.md`'s "Five business-analyst defaults reviewed and confirmed" section).

### 0.7 The exact-alarm question is resolved — inexact scheduling is sufficient

Originally flagged here as the single largest unresolved technical dependency underneath this document: every acceptance criterion below that references "the reminder fires on [date]" is written assuming same-day delivery is the actual contract, not minute- or hour-precision delivery, per the design doc's own framing. developer's technical ADR (`docs/technical/04-scheduling-and-stack.md`, 2026-08-21) has since concluded — from Android's own documentation, not yet from device testing — that inexact `AlarmManager` scheduling plus a self-healing reconciliation pass is sufficient for this app's day-granularity cadence, and that the exact-alarm permission flow (`05-permissions.html` panels p4–p6) should be cut from the build. **REQ-11.2 below resolves to "cut it"** on that basis. This is still provisional until the ADR's own device-verification checklist (§6 of that document) is actually run on a real device — treat REQ-11.2 as settled for build purposes, not as empirically closed.

### 0.8 [NEW 2026-08-23] Notification-permission ask shipped smaller than REQ-11.1 specifies — reviewed, partly accepted, partly a required fix

developer's implementation handoff flagged that the shipped Android 13+ notification-permission flow is a stripped-down version of REQ-11.1's original three-panel priming design (`05-permissions.html` p1–p3): the real OS dialog fires directly, with no in-app rationale screen first; the ask is triggered on first item save rather than first app launch; and denial surfaces a SnackBar with an "Open settings" action rather than a dedicated recovery screen. This was flagged explicitly in the developer handoff, not silently shipped.

**Reviewed and decided, not left open:**

- **The reduced UI shape is accepted for v1.** The three dedicated priming/granted/denied screens do not need to be built. The app remains fully functional without the permission either way (REQ-11.1's core promise), the ask still happens at a contextual, motivated moment (right after the user's first save, when the value of a reminder is freshest in mind), and a SnackBar-with-action is an already-established pattern in this app for comparable moments (the undo toast, the save-failure message). This is a reasonable, cheap MVP substitution, not a corner cut on the app's actual function.
- **The implementation as built has a real defect that is not accepted as-is.** The denial SnackBar is fired from the Add/Edit screen, which auto-navigates back to the list roughly 900ms after save completes. If the OS dialog's result arrives after that navigation — a real race, not a hypothetical one, since the OS dialog can easily take longer than 900ms to resolve if the user hesitates even briefly — the SnackBar has nowhere to render and the message is silently lost. In that path, a user who denies notifications gets **no explanation and no path back to settings at all**, which is worse than what REQ-11.1 promises, not merely a smaller version of it. This must be fixed before REQ-11.1 counts as met.
- **Worth naming for product-manager's awareness, not a build blocker on its own:** losing the dedicated rationale screen is a real, if soft, cost to the notification permission grant rate — and this is the one permission the entire ladder/follow-through value proposition depends on. Not reason enough to require rebuilding three screens, but reason enough that this shouldn't be treated as a purely cosmetic simplification either.

See the revised REQ-11.1 for the exact acceptance criteria this resolves to.

---

## 1. Copy — Health check field, one-time note, and the copy rule for future work

Per scope doc §3, routed to business-analyst. Both mockups currently carry placeholder text explicitly marked for replacement (`02-add-edit-item.html` panel p5's `.plain-note`, `06-settings-privacy.html` panel p3's `.disclaimer`) — ux-designer still needs to paste the final copy below into those mockup files; this document is the copy's source of truth in the meantime.

### REQ-1.1 — Health check recurrence field: label and helper text

**Field label** (form section heading, above the stepper row): `Remind me every`
**Stepper unit label** (beside the +/− control): `months`
**Helper text** (persistent, plain-grey weight, same as every other field's helper text — never the tinted `ladder-preview` treatment): `Your call — change this any time. Not a recommendation, just your own setting.`

- Given a user selects Health check as the item type on Add/Edit, When the form renders, Then the recurrence field appears as a plain stepper (`− [value] +`) in the same neutral container style as the Label and Due date fields above it — not the tinted `primary-container` card used for the ladder preview.
- Given the recurrence field, When no value has been set yet, Then it defaults to `12` (editable immediately, no confirmation step to change it).
- Given the recurrence field at any value, When the user taps `−` at a value of `1`, Then the control does not go below `1` (a 0-month interval is meaningless). No stated upper bound is required for v1; developer may cap at a sane maximum (e.g., 120) to prevent a UI overflow, since neither source doc specifies one.

### REQ-1.2 — One-time inline note at Health check type-selection

Shown once, the first time a user selects Health check as the type on Add/Edit (per-install, not per-item — see acceptance criteria below for what "once" means). Plain banner style (`.plain-note`), not the tinted callout — per design doc §2a's explicit rejection of that treatment.

**Note title:** `Not medical advice`
**Note body:** `Screening and check-up intervals vary by person, so this app doesn't set one for you. Pick whatever interval works for you below — you can change it anytime, the same way you would any other reminder here.`
**Dismiss control:** `Got it`

- Given a user has never selected Health check as a type before (fresh install, or has selected it before but never dismissed the note), When they select Health check on Add/Edit, Then the note renders above the recurrence field, per `02-add-edit-item.html` panel p5's placement (between the type row and the rest of the form).
- Given the note is visible, When the user taps `Got it`, Then the note is dismissed for this session and does not reappear on subsequent Health check selections, on this device, ever again — this is a persisted per-install flag, not a per-item or per-session one. **[BA DEFAULT — "once" is read as once-per-install for the life of the app, matching the design doc's own framing ("shown once, first time you pick this type"); re-showing it after every reinstall is acceptable and not worth special-casing.]**
- Given the note is dismissed without an explicit "Got it" tap (e.g., user backs out of Add/Edit entirely), When they return to Health check type-selection later, Then the note still shows (only an explicit dismiss suppresses it — abandoning the form doesn't count as having read it).
- Given the note has already been dismissed, When the user opens Add/Edit for an *existing* Health check item (edit flow, not creation), Then the note does not reappear — it is scoped to first-time type-selection, not every subsequent view of a Health check item's form.

### REQ-1.3 — Copy governance rule for future Health check (and any future health-adjacent) copy

This rule is the actual deliverable, not just the two strings above — someone will add copy to this screen later without this context.

**Rule:** No copy anywhere in the app may state or imply that a specific number, date, or interval associated with a Health check item is medically correct, standard, recommended, or sourced from any professional or institutional authority. Every reference to the recurrence value must describe it as something the *user* set, chose, or entered — never something the app determined, suggested, or scheduled *for* them on clinical grounds. ("Reminders scheduled" is fine as generic ladder-mechanics language, used identically across all seven types — it's describing notification delivery, not asserting the underlying interval is medically sound.)

**Explicitly banned constructions** (from scope doc §3, restated here as the enforceable list): "recommended interval," "doctors suggest/recommend," "standard guideline," "you should get/do [X]," "due for your [checkup]" or any phrasing that pairs a specific interval with an implication of clinical correctness (e.g., "the right interval is…").

**Allowed:** the existing generic status vocabulary (upcoming/due soon/overdue/done) — these describe the user's own set date, not a clinical judgment, and are explicitly carved out in scope doc §3.

**Test for new copy before it ships:** would this sentence read differently — in a way that implies clinical authority — if the item's type were Custom instead of Health check? If yes, it needs to be rewritten before merge. This test is cheap enough for a solo developer to actually run on every new string touching this field.

---

## 2. Copy — unified legal + medical disclaimer

Per scope doc §3, this replaces the placeholder text in `06-settings-privacy.html` panel p3.

### REQ-1.4 — Settings/Privacy disclaimer (full version)

Placed at the bottom of the Settings/Privacy screen, below the "About" section, per the existing mockup layout. Plain paragraphs, not a single dense block — short statements rather than one wall of legalese, per the instruction that a disclaimer nobody reads protects nobody:

> **Not legal, financial, or medical advice**
>
> This app reminds you about dates and intervals you set yourself. It doesn't verify official requirements and it isn't medical guidance — it's a personal reminder tool.
>
> For anything with legal or financial consequences — insurance, vehicle registration, professional licensing, and similar — check the actual requirements with the relevant authority or provider. Rules change and this app doesn't track them.
>
> For Health check reminders, the interval is entirely yours (or your healthcare provider's) to set. This app just repeats whatever number you chose.
>
> If you force-stop this app — or your phone's battery manager does it for you — Android cancels every reminder that was waiting to fire, and none of them come back until you open the app again. That's Android's own design for a force-stopped app, not a bug we can fix from here. Ordinary battery-saving settings can also delay a reminder without cancelling it, even without a force-stop.
>
> Whether or not a reminder arrives, you're still responsible for the renewal. Treat this as a memory aid, not a compliance system.

- Given the Settings/Privacy screen success state, When it renders, Then this text appears in full, replacing the placeholder currently in `06-settings-privacy.html`.
- Given this text, When product-manager or user reviews it, Then it should read in under 20 seconds — this is the concrete bar for "plain and readable," not a subjective judgment call left to whoever ships it.
- **[NEW 2026-08-23]** Given the force-stop paragraph specifically, When it's reviewed against `docs/technical/04-scheduling-and-stack.md` §2's finding, Then it must name the actual mechanism plainly (force-stop cancels *all* pending reminders, not just the next one; nothing brings them back except reopening the app) rather than the vaguer "notifications can be delayed or blocked" language this paragraph replaces — this is a deliberate strengthening, not a wording preference, per the instruction that an app promising you won't forget has an obligation to say so plainly.

### REQ-1.5 — Inline note (shorter version)

This is the same artifact as REQ-1.2 above, not a third piece of copy — scope doc §3 names exactly two placements for the unified disclaimer requirement (Settings, in full, and the Health-check-specific inline note, shorter, at the moment of type-selection). No additional inline disclaimer is required elsewhere (the design doc explicitly reasons that MOT/insurance-style legal risk is adequately covered by the Settings placement alone — §2a). If a future reviewer goes looking for a third disclaimer surface, there isn't meant to be one; this is a deliberate scope boundary, not an oversight.

---

## 3. Add / Edit item

Written against `docs/design/mockups/02-add-edit-item.html`, all six tabs.

### REQ-2.1 — Type selection

- Given the Add/Edit screen (empty state, panel p1), When it renders, Then all 7 type chips are visible and horizontally scrollable, none pre-selected, matching the type row order in the mockup (Passport, Insurance, Licence, Vehicle, Warranty, Health check, Custom).
- Given no type is selected, When the user attempts to save, Then Save is disabled (matches `.btn-filled.disabled` in panel p1) — type is a required field, same as Label and Due date.
- Given a type is selected, When the user taps a different type chip, Then the selection moves and any type-specific fields (Health check's stepper/note, Custom's segmented control) show/hide accordingly, and the live ladder preview recomputes for the newly selected type.

### REQ-2.2 — Required fields and validation

- Given the form, When Label, Due date, or Type is empty, Then Save remains disabled.
- Given the form, When the user taps Save with Due date empty specifically, Then the error state shown in `02-add-edit-item.html` panel p3 renders: the Due date input gets the error style and the helper text reads `Due date is required — we need it to build your reminder schedule.`
- Given the form, When Label is empty but Due date and Type are set, Then Save is disabled, but no specific error copy is drawn in the mockups for this case — developer should reuse the same error-input/helper-text pattern shown for Due date, with equivalent copy (e.g., "Label is required — give it a name you'll recognize."). **[BA DEFAULT — mockup only demonstrates the due-date validation error; the same visual pattern is assumed to extend to Label.]**
- Given a valid form, When the user taps Save, Then the loading state renders (panel p2: dimmed content, disabled inputs, `Saving…` with spinner) followed by the success state (panel p4: saved confirmation toast `Saved — reminders scheduled`, ladder preview visible).
- Notes field is optional in all cases — its absence never blocks Save.

### REQ-2.3 — Live ladder preview

- Given any type is selected with a valid due date, When the form is in a valid, unsaved state, Then a ladder preview card renders below the form fields showing the correct stage count and day-offsets for that type/tier, per the table in design doc §2 (e.g., Vehicle shows 30/14/3 days before for paid; free tier shows only its single tuned reminder — see REQ-4).
- Given Custom is selected, When the user changes the Short/Medium/Long segmented control, Then the ladder preview updates live, without requiring Save — per `02-add-edit-item.html` panel p6 ("Updates live as you change the selector above").

### REQ-2.4 — Health check specific fields

Covered in detail in REQ-1.1–REQ-1.3 (copy) and REQ-2.5 below (ladder numbers). Structurally: type-select → one-time note (if applicable) → Label/Due date → recurrence stepper + helper → Notes → ladder preview, in that order, per panel p5.

### REQ-2.5 — Custom lead-time selector as a first-class form field

Per scope doc §3a, routed explicitly for acceptance criteria including its gating interaction.

- Given Custom is the selected type, When the form renders, Then a 3-way segmented control (`Short / Medium / Long`) appears directly below Due date, above the ladder preview, with `Medium` pre-selected by default — per `02-add-edit-item.html` panel p6.
- Given the user has not touched the selector, When the item is saved, Then it is stored with `Medium` (30/7/1 days paid; 7 days free) — this must be indistinguishable from today's existing fixed default, i.e., nothing regresses for a user who never interacts with the new control.
- Given `Short` is selected, When saved, Then the paid ladder is 7/3/1 days before, and the free-tier single reminder is 3 days before.
- Given `Long` is selected, When saved, Then the paid ladder is 90/30/7 days before, and the free-tier single reminder is 30 days before.
- Given a free-tier user, When they select any of the three profiles, Then the ladder preview and the item's actual scheduled reminder both reflect that profile's *middle* stage as the single free reminder — not a fixed 14-day default regardless of selection. This is the specific behavior scope doc §3a calls out as the reason the selector is worth building at all for free users too.
- Given an existing Custom item, When the user edits it and changes the selector (e.g., Medium → Long), Then on save, the full ladder is recomputed and rescheduled from the new profile (see REQ-16 for the general edit-reschedule rule) — the previously scheduled Medium-profile notifications are cancelled, not left to also fire.

---

## 4. Reminder ladder — type defaults and free/paid gating

### REQ-3.1 — Paid ladder per type

Given an item of a given type is saved by a paid-tier user, the scheduled paid ladder must match design doc §2's table exactly:

| Type | Paid ladder (days/months before due date) |
|---|---|
| Passport / Travel ID | 6 months, 3 months, 1 month, 1 week |
| Insurance | 21, 7, 1 days |
| Professional Licence | 90, 30, 7 days |
| Vehicle | 30, 14, 3 days |
| Warranty | 30, 7 days |
| Health check | 30, 14, 3 days |
| Custom | per selected profile — see REQ-2.5 |

- Given any of the above types, When the item is saved with a due date far enough in the future that all stages fall after today, Then all stages are scheduled.
- Given a due date close enough that one or more early stages would fall in the past relative to today (e.g., a Vehicle item due in 10 days), When the item is saved, Then only the stages that still fall in the future are scheduled — earlier stages are silently skipped, not fired retroactively. (See also REQ-17.1 for the fully-past-due case.)

### REQ-3.2 — Free tier single reminder per type

Given an item of a given type is saved by a free-tier user, the single scheduled reminder must match design doc §5's table:

| Type | Free single reminder |
|---|---|
| Passport | 3 months before |
| Insurance | 7 days before |
| Professional Licence | 30 days before |
| Vehicle | 14 days before |
| Warranty | 30 days before |
| Health check | 30 days before |
| Custom | 3 / 7 / 30 days before, matching Short/Medium/Long |

- Given a free-tier item, When viewed on item detail, Then the unlocked stage renders in its correct chronological position on the same timeline used for paid items, with the remaining would-be stages rendered as locked/greyed markers in their correct positions — not omitted entirely. Per `03-item-detail.html` panel p3.
- Given a free-tier item's detail screen, When it renders, Then an "Unlock" affordance (`.unlock-banner`) sits inline on the ladder track itself, not as a separate interstitial — matching panel p3's placement and copy pattern (`"[N] more warnings live here, unclaimed"` + price + unlock button). Copy should be type-specific in the sense that it explains *why* the missing stages matter for that type, per the mockup's passport-specific example — developer/BA should adapt the explanatory line per type using the "why this spacing" reasoning already written in design doc §2's table, rather than a single generic sentence for all seven types. **[BA DEFAULT — mockup only shows the passport version; the same explanatory-line pattern should be authored per type before ship, reusing design doc §2's existing rationale column so this isn't a second copy-writing pass from scratch.]**

### REQ-3.3 — Overdue follow-through cadence per type (paid only)

| Type | Overdue nags after due date |
|---|---|
| Passport | Day 0, +10d, +30d (3 total, then status-only) |
| Insurance | Day 0, +3d, +10d, +30d (4 total) |
| Professional Licence | Day 0, +7d, +21d (3 total) |
| Vehicle | Day 0, +3d, +10d, +30d (4 total) |
| Warranty | Day 0 only, then stops |
| Health check | Day 0, +30d (2 total, then status-only) |
| Custom | Day 0, +7d, +21d (3 total), all profiles |

- Given a free-tier item passes its due date without being marked done, When it becomes overdue, Then no overdue nag fires at all — overdue follow-through is entirely a paid-tier feature (scope doc §2). The item's list status still correctly shows "Overdue" (status computation is not gated; only the *notification* is).
- Given a paid-tier item reaches the end of its type's overdue nag sequence (e.g., Warranty at Day 0, or Passport after +30d) without being marked done, When further time passes, Then no further notifications fire — the item simply remains visible as "Overdue" on the list indefinitely until the user marks it done, edits the due date, or deletes it. This should be stated explicitly rather than left implicit, since "then stops" in the design doc's table could otherwise be read as the item disappearing or resetting, which it does not.

---

## 5. List / Home screen

Written against `docs/design/mockups/01-home-list.html`.

### REQ-4.1 — Four states

- **Loading:** skeleton cards render (panel p1) on cold load / any local-read-in-progress state.
- **Empty (first run):** panel p2's type-picker-as-empty-state renders — all 7 type tiles, tapping any tile opens Add/Edit pre-populated with that type selected. This state only shows when there are zero items total, ever (not zero items matching some filter — v1 has no filter, per scope doc's explicit P2 deferral of search/filter/sort).
- **Error:** panel p3's local-read-failure state renders on a data-layer read error, with a `Try again` action. Never render a blank white screen on read failure — this is stated as a hard requirement in the design doc and repeated here because it's easy to accidentally regress by letting an unhandled exception fall through to nothing.
- **Success:** panel p4/p5 — items grouped into Overdue / Due soon / Upcoming / Done sections, in that order, Done collapsed/reduced-opacity per REQ-4.2.

### REQ-4.2 — Status grouping and computation

- Given an item's due date has passed and it is not marked done, its status is `Overdue`.
- Given an item's next ladder/reminder stage has fired (i.e., it's inside its "due soon" window) but the due date has not passed, its status is `Due soon`. **[BA DEFAULT — neither doc defines the exact boundary for "due soon" vs. "upcoming" as a status category, only as a chip label tied to "next stage." Reasonable default: an item is "Due soon" once its final pre-due ladder stage has fired (i.e., it's within the last/closest stage's window), and "Upcoming" before that. Flagging since this is a threshold a developer would otherwise have to guess.]**
- Given an item's due date is in the future and no ladder stage within its final window has fired yet, its status is `Upcoming`.
- **[REWRITTEN 2026-08-23, per product-manager's 2026-08-21 recurrence-lifecycle decision, scope doc §3d]** `Done` is not one uniform rule — it depends on whether the item is terminal or recurring:
  - **Terminal items** (Warranty always, per REQ-9.3; Custom items answered "No" to "does this repeat?", per REQ-9.4): once marked done, the item's status is `Done`, rendered at reduced opacity (`.card.done`, `opacity:.55`) and grouped in a collapsed section below the active ones, per design doc §6. This is a real, persistent, terminal status — it stays exactly as-is until the user deletes the item or uses `Undo last completion` (REQ-9.7). Nothing else changes it.
  - **Recurring items** (any type where mark-done produces a next due date — REQ-9.1/9.2): `Done` is never a status the item sits in past the moment its next cycle's due date is set. The instant the recurrence bottom sheet resolves (or the 6-second undo window lapses, if no sheet was shown), the item's status recomputes from that new due date using the exact same Overdue/Due soon/Upcoming rule above, with no special case — no dormant "done-but-secretly-has-a-future-date" state, and no separate trigger needed to "bring it back." A freshly-cycled item due 10 years out is `Upcoming`, indistinguishable from a brand-new item entered with that due date, and renders with the item's normal (non-`.card.done`) card treatment in whichever section its new status places it — not the collapsed Done section.
- Given a section (e.g., Overdue) has zero items, When the list renders, Then that section label and its divider do not render — sections only appear when they have at least one item, matching the fact that panel p4/p5 shows section headers only where cards exist beneath them.

### REQ-4.3 — Quick-done action

- Given any card in Overdue, Due soon, or Upcoming, When the user taps the `.quick-done` checkmark, Then the same mark-done flow described in REQ-9 triggers (including the recurrence bottom sheet for recurring types, and the undo toast per REQ-10) — this is the same logical action as "Mark as done" on item detail, just reached from a different entry point, per scope doc §3c's explicit statement that both entry points are covered.

---

## 6. Item detail

Written against `docs/design/mockups/03-item-detail.html`.

### REQ-5.1 — Four states

- **Loading:** skeleton (panel p1).
- **Error:** "item not found" (panel p2) — must be reachable (e.g., item deleted in another flow, then a stale deep-link/back-stack reference is opened) and must not crash; offers `Back to your renewals`.
- **Empty:** not applicable — an item detail screen, by construction, always has data once it loads successfully (per design doc's own states table, "n/a (always has data)").
- **Success:** free-tier (p3), paid-tier (p4), Health check (p5) variants, all covered above under REQ-3.

### REQ-5.2 — Free vs. paid ladder track rendering

Covered under REQ-3.2. Additionally:

- Given a paid-tier item's detail screen, When it renders, Then an `active-note` confirms "Full ladder active — plus overdue follow-through if this passes unmarked" (or the type-appropriate equivalent, e.g. Health check's lighter-cadence phrasing in panel p5), so the paid state is legible without requiring the user to compare against what free tier would have shown.

### REQ-5.3 — Notes field

- Given an item has no notes, When viewed, Then the Notes card shows `No notes added.` (panel p3) rather than an empty/missing card — the card itself always renders, only its content changes.

### REQ-5.4 — Delete (confirmed 2026-08-21 — see §0.2)

- Given an item's detail screen, When the user opens the overflow menu (⋮) and selects Delete, Then the item is immediately removed from the list, no separate confirmation dialog appears (the undo toast is the safety net, per scope doc §3c's rationale — a confirmation dialog on top of an undo toast is redundant friction), and the undo toast renders per REQ-10. Matches `03-item-detail.html`'s overflow-menu-expanded panel (labeled "Overflow menu — Delete (new)").
- Given a card on the list, When the user long-presses it, Then a delete action (`.quick-delete`) is revealed on the card, per `01-home-list.html`'s long-press panel (labeled "Long-press — delete revealed (new)"); tapping it triggers the same immediate-delete-plus-undo-toast flow as detail-screen delete. This is a confirmed interaction pattern, not a tentative default — ux-designer has drawn both states referenced above, and product-manager locked the pattern itself on 2026-08-21.
- Given a card is in the long-press-revealed state, When the user taps elsewhere on the screen without tapping the delete action, Then the reveal state clears and no delete occurs — the standard dismiss behavior for a long-press reveal, stated explicitly since the mockup shows the revealed state as a snapshot, not its dismissal path. **[BA DEFAULT — reasonable interaction convention, not itself drawn as a distinct mockup state.]**

---

## 7. Mark-as-done and recurrence

### REQ-9.1 — Recurrence smart default is computed from the due date

Per §0.5: for every recurring type, the one-tap smart default in the mark-done bottom sheet computes the next due date as **(original due date) + (the type's standard recurrence interval)** — not from today's date or the completion date. This applies whether the item is marked done early, on time, or late (overdue).

- Given a Passport item due 12 Dec 2026 is marked done on 1 Dec 2026 (early), When the bottom sheet's smart default is shown, Then it reads a date 10 years after the *original due date* (12 Dec 2036), not 10 years from the completion date.
- Given a Health check item with a stored interval of `12` months and a due date of 14 May 2027, When marked done (at any point relative to that due date), Then the smart default reads `Same as your setting — In 12 months` and computes 14 May 2028, exactly matching `03-item-detail.html` panel p6.

### REQ-9.2 — Generic recurring-type bottom sheet (not directly mocked — see §0.4)

- Given Insurance, Vehicle, Professional Licence, or Passport is marked done, When the sheet opens, Then it offers a one-tap smart default (`"Same time next year"` for annual types, `"+10 years"` for Passport) plus a manual date-picker option, per design doc §4's text description. Visual structure should mirror the mocked Health check sheet (primary highlighted option + secondary manual option), per `03-item-detail.html` panel p6, since no separate mockup exists for this variant.
- Given the user picks the manual date option, When they confirm a date, Then that date is used exactly as entered — no validation against the type's "typical" cycle length is required for v1 (a user might legitimately want an unusual next date).

### REQ-9.3 — Warranty: no recurrence prompt

- Given a Warranty item is marked done, When the action completes, Then no bottom sheet appears at all — the item simply moves to `Done` status with no next due date, per design doc §4 ("Warranty skips the recur prompt — nothing to renew"). **[BA DEFAULT — neither doc states whether a done Warranty item without a next cycle should remain permanently visible in the collapsed Done section or be eligible for deletion by the user manually; treating it as: it stays, exactly like any other Done item, until the user deletes it themselves, or uses `Undo last completion` (REQ-9.7). No automatic cleanup.]**

### REQ-9.4 — Custom: "does this repeat?" prompt (not mocked — see §0.4)

- Given a Custom item is marked done, When the action completes, Then a yes/no prompt ("Does this repeat?") appears before any date-based recurrence UI, per design doc §4's text description. If "No," the item moves straight to `Done` with no next cycle (same as Warranty). If "Yes," a manual date picker appears (no smart default exists for Custom, since the app has no basis to guess its cadence). **[BA DEFAULT — visual treatment unspecified in mockups; should reuse the existing bottom-sheet component shell.]**

### REQ-9.5 — Mark-done from a notification

- Given a user taps `Mark done` on an expanded notification (ladder-stage or overdue), When the action fires, Then the current cycle is cleared and all remaining scheduled stages for that item are cancelled immediately — matching the in-app behavior — but the recurrence question is **not** asked via a second notification. Per design doc §4, it is deferred to an inline banner on the item's detail screen, shown the next time the app is opened. **[Not mocked — no mockup panel shows this banner; developer/BA should treat design doc §4's text as the spec until a mockup exists. Low risk since the behavior is unambiguous even without a drawn state.]**
- Given a notification-triggered mark-done, When it completes, Then no undo toast appears (scope doc §3c, explicit) — but the item's status can always be manually reverted from item detail regardless, since mark-done never destroys data, only changes status (extended by REQ-9.7's `Undo last completion` action for the post-window case).

### REQ-9.6 — Mark-done on an already-overdue item

- Given an item's status is `Overdue`, When the user marks it done (from list or detail), Then the same flow applies as for a non-overdue item — no special-cased behavior. This is stated explicitly because it's a natural point of hesitation for a developer to wonder about, not because either source doc treats it differently.

### REQ-9.7 — `Undo last completion` (item detail, new — scope doc §3d)

**Location:** item-detail overflow (⋮) menu, alongside `Delete`. **Not on the list** — deliberately low-frequency, low-visibility, consistent with how delete itself is tucked behind long-press/overflow rather than a permanent icon. **Not yet mocked** — `03-item-detail.html`'s expanded overflow-menu panel currently shows only `Delete`; product-manager routed adding this entry to ux-designer on 2026-08-21, not yet drawn. Criteria below are written against scope doc §3d's text description, following the same precedent as REQ-9.2/9.4's unmocked variants.

**What it's for:** a correction path for a mistake noticed *after* the 6-second undo toast (REQ-10.2) has already lapsed — not a step in the recurrence flow itself, and not a way to reach back further than the most recent completion.

- Given an item whose most recent state-changing action was a mark-done event (triggered in-app from list or detail, or from a notification per REQ-9.5) and nothing else has touched the item since, When the user opens item detail's overflow menu, Then an `Undo last completion` entry is visible and enabled.
- Given an item that has never been marked done, or whose most recent mark-done event has already been superseded (see the scope boundary below), When the overflow menu opens, Then `Undo last completion` does not appear (or appears visibly disabled) — it is never offered as a dead-end action a user can tap and have nothing happen.
- Given `Undo last completion` is tapped, When the action fires, Then it performs the exact same revert operation already required for the undo toast in REQ-10.2: the item's due date reverts to its prior value (undoing any recurrence advance), the prior ladder/overdue schedule is restored and rescheduled, and the item's status recomputes from the restored due date. No confirmation dialog is required — same reasoning as Delete (REQ-5.4): this is a correction path, not a novel destructive action, and it's itself reversible by simply marking the item done again.
- Given the action completes, When it finishes, Then no new undo toast appears for it — this action has no "undo the undo" mechanism in v1.
- **Single-level-undo scope boundary:** Given `Undo last completion` has just been used on an item, When the user opens the overflow menu again with no other action in between, Then the entry is no longer available. It becomes unavailable the moment *anything else* changes the item's state: an edit save, another mark-done, a delete, or a prior use of this same action. This applies regardless of how long ago the original mark-done event happened — per scope doc §3d, a years-old, never-touched-since completion is still a well-defined, harmless single most-recent event to revert; no time cutoff is needed or specified.
- Given a Warranty or "no-repeat" Custom item (terminal `Done`, no next cycle — REQ-9.3/9.4) is marked done, When the user later opens its overflow menu, Then `Undo last completion` is available on these items too, using the same rule — reverting a terminal `Done` back to its pre-done state is a well-defined use of the same action, whether or not the underlying event also advanced a due date. **[BA DEFAULT — neither source doc explicitly excludes terminal items from this action; scope doc §3d's "any subsequent action invalidates it" framing applies uniformly, so there's no reason to special-case terminal types out of an otherwise-general action.]**
- Not in scope for v1 (stated explicitly per scope doc §3d, so it isn't silently expected): re-doing a previously-undone completion, undoing anything older than the single most recent mark-done event, or any list-level affordance for this action.

---

## 8. Undo toast

Per scope doc §3c and design doc §4a, written against `01-home-list.html` panel p5 and `03-item-detail.html` panel p7.

### REQ-10.1 — Covered and not-covered actions

- **Covered:** delete (list or detail), mark-done (list or detail).
- **Not covered:** edit (reversible by editing again — no toast), mark-done triggered from a notification action (no foreground UI surface at that moment — see REQ-9.5; the post-window correction path for this case is REQ-9.7).
- Given either covered action fires, When it completes, Then a dark snackbar-style toast renders at the bottom of the content area, with the FAB (list screen) or bottom action bar (detail screen) elevating to sit above it, never overlapped — per design doc §4a.
- Copy is specific per action, not generic: `Deleted — [item label]` / `Marked done — [item label]`, each with a right-aligned `UNDO` action, matching `01-home-list.html` panel p5 and `03-item-detail.html` panel p7 exactly.

### REQ-10.2 — Window timing (resolves §0.3)

- Given a covered action with no recurrence prompt (delete; mark-done on a non-recurring type or a "No" answer to Custom's repeat prompt), When the action is triggered, Then the 6-second countdown starts immediately.
- Given a covered action that opens the recurrence bottom sheet (mark-done on a recurring type), When the sheet is dismissed — via smart default tap or manual date-picker confirmation — Then the 6-second countdown starts at that point, not at the initial "Mark done" tap. While the sheet is open, no countdown is running and Undo is not yet available (there is nothing to undo yet — the action hasn't completed).
- Given the countdown is running, When the user taps `UNDO`, Then the entire action reverts — for delete, the item and its exact prior ladder/history state are restored; for mark-done, the current cycle re-activates, remaining ladder stages are restored, and any recurrence choice made in the sheet is discarded.
- Given the countdown lapses without an undo tap, When it expires, Then the action becomes final — for delete, the underlying data is actually removed at this point (not before — see developer's routed confirmation in scope doc §8 that the deferred-write approach needs no persistent trash table); for mark-done, remaining ladder stages are actually cancelled at this point. This is also the exact revert operation reused by REQ-9.7's `Undo last completion` for the post-window case.
- **[BA DEFAULT — overlapping actions]** Given a toast is currently showing for action A, When the user triggers a second covered action B before A's window lapses, Then action A commits immediately (its window ends early, Undo for A is no longer available) and a new toast begins its own fresh 6-second window for action B. This keeps the mechanism simple for a solo developer to build and avoids stacking or merging toasts, at the cost of a user losing the ability to undo action A if they immediately follow it with action B — an acceptable tradeoff for v1, not raised in either source doc.

---

## 9. Local notifications

Written against `docs/design/mockups/05-permissions.html` and `07-notifications.html`.

### REQ-11.1 — Notification permission ask [REVISED 2026-08-23 — see §0.8]

**This revision replaces the original REQ-11.1 in full.** developer shipped a stripped-down version of the originally-specified three-panel priming flow (`05-permissions.html` p1–p3). Per §0.8's review: the reduced UI shape is **accepted** for v1; a specific implementation defect is **not accepted as shipped** and must be fixed before this requirement counts as met.

- Given a user saves their first item (not first app launch — the ask is triggered on first save, not on opening the app), When the save completes, Then the real Android notification-permission dialog fires directly — no in-app rationale screen precedes it. This is the accepted, shipped shape; `05-permissions.html` panels p1 (priming) and p2 (granted confirmation) are **not** required to be built.
- Given the OS dialog is granted, When it resolves, Then no further UI is required for this outcome — the app proceeds normally.
- Given the OS dialog is denied, When it resolves, Then the user reliably sees a message stating that notifications are off, that tracking still works without them, and offering an `Open settings` action that deep-links to the app's OS notification settings. **"Reliably" is the operative word and the specific fix required**: this message must render regardless of how quickly the Add/Edit screen has already auto-navigated back to the list after save. As currently built, a slow or hesitant response to the OS dialog can cause this message to never render at all — that is the defect this criterion exists to close. QA should specifically test the denial path with a deliberately delayed tap on the OS dialog to try to reproduce the race.
- Given permission was denied and the user takes no further action, When they continue using the app, Then all tracking/list/status functionality remains fully available — only notification delivery is affected. No feature should be blocked or degraded beyond "no notifications fire" as a result of a permission denial.
- Given permission was previously denied, When the user later grants it via system settings (outside the app's own flow), Then any items already tracked have their ladders/overdue nags scheduled from that point forward — developer should treat "permission newly granted" as a trigger to (re)schedule all currently-eligible future notifications for existing items, not just new ones created after the grant. **[BA DEFAULT — unchanged from the original REQ-11.1; neither doc addresses this transition explicitly, and without this rule a user who initially denies and later enables notifications from system settings would get no reminders for items they already added, defeating the point of enabling it.]**

**Not required for v1, and not a defect that this revision leaves open:** the dedicated `05-permissions.html` panel p1 (priming rationale) and panel p3 (dedicated denial-recovery screen, as opposed to the SnackBar). These are accepted omissions per §0.8, not gaps.

### REQ-11.2 — Exact-alarm permission (resolved — see §0.7)

- Per developer's technical ADR (`docs/technical/04-scheduling-and-stack.md`), inexact delivery is sufficient for this app's day-granularity cadence. **Panels p4–p6 of `05-permissions.html` are cut entirely** from the build, with no other rework required, per the design doc's own "zero rework if unneeded" framing. No acceptance criterion in this document depends on exact-alarm behavior.
- This is provisional on the ADR's own device-verification checklist actually being run before ship (ADR §6) — if that testing surfaces routine same-day-delivery slippage on stock Android (not an OEM-overlay issue), this section needs revisiting. Not expected, per the ADR's own reasoning, but named here so it isn't forgotten as a pre-ship check.

### REQ-11.3 — Single notification content and actions (locked 2026-08-21 — `Mark done` only, see §0.1)

- Given a ladder-stage notification fires, When it renders, Then it shows the item's category icon/tint, a title in the form `[Label] · due in [N] days` (or type-appropriate phrasing), body copy that is plain and matter-of-fact (not urgency-stacked), and a single action: `Mark done`. **No Snooze action ships in v1** — Snooze was cut from scope entirely (§0.1, resolved 2026-08-21); there is no contingent branch left to resolve.
- Given an overdue-nag notification fires, When it renders, Then title/body use the collaborative, non-blame tone specified in design doc §4 (e.g., `"[Label] — still open"` / `"Was due [N] days ago. Still need to sort this?"`), matching `07-notifications.html` panel p2 exactly, with the same single `Mark done` action.

---

## 10. Notification grouping (P0)

Written against `07-notifications.html` panels p3–p4 and scope doc §6.

### REQ-12.1 — Grouping trigger and collapsed state

- Given two or more of a user's items have a notification (any type — ladder stage or overdue nag, any tier) scheduled to land on the same calendar day, When those notifications would otherwise post separately, Then they collapse into a single Android grouped/summary notification instead, using `NotificationCompat`'s standard group-summary mechanism.
- Given a collapsed group notification, When it renders, Then the title reads `"[N] renewals need attention"` (count-driven) and the body lists item labels, truncated with `"+N more"` past two, e.g., `"Car insurance, MOT — Honda Civic +1 more"` — matching panel p3 exactly, not a generic "you have new notifications."

### REQ-12.2 — Expanded state

- Given the user expands a collapsed group notification, When it expands, Then each underlying notification renders as its own line (item label + specific stage/status, e.g., `"MOT — Honda Civic · 3 days before"`, `"Car insurance · overdue"`), each independently tappable to that item's detail screen — matching panel p4.
- Given a group contains a mix of upcoming ladder-stage and overdue-nag notifications on the same day, When expanded, Then no additional visual separation beyond each line's own status text is applied — this is a deliberate simplification (design doc §6a), not a missed requirement.
- Given the expanded group, When rendered, Then no per-line `Mark done`/`Snooze` quick actions are present (only tap-to-open) — matching panel p4, which shows no action buttons on individual grouped lines. This is a real, testable constraint: a developer defaulting to "give every notification its full action set" would over-build this state.

### REQ-12.3 — What grouping does not fix (stated so it isn't silently expected to)

- Given a user's overdue items go overdue on different calendar days within the same week (not the same day), grouping does **not** cap total weekly notification volume — each day's single notification posts individually, uncollapsed, per design doc §2's own explicit caveat. QA should not treat "no more than N notifications in a week" as a testable pass/fail criterion for this feature; only same-day collapsing is in scope.

---

## 11. Paywall / one-time unlock

Written against `04-paywall.html`.

### REQ-14.1 — Four states

- **Default (p1):** comparison list (already-free items marked with a check, locked items with a lock icon), price `$3.99 one-time`, `Unlock for $3.99` primary action, `Restore purchase` secondary action.
- **Loading (p2):** billing check in progress, primary button disabled/replaced with `Checking billing…` + spinner.
- **Error (p3):** purchase failed — explicit reassurance copy that the user has not been charged, `Try again` and `Restore purchase` actions remain available.
- **Success (p4):** confirmation (`You're set`), states that extra ladder stages for existing items begin scheduling now, single `Back to your renewals` action.

### REQ-14.2 — Unlock effect on existing items

- Given a user completes purchase, When the unlock succeeds, Then every existing item's ladder is immediately recomputed to its full paid-tier schedule (per REQ-3.1) and the newly-unlocked stages are scheduled from that point forward — not retroactively fired for stages whose date has already passed relative to today.
- Given the unlock, When it completes, Then overdue follow-through (REQ-3.3) becomes active for any currently-overdue items going forward, starting from whichever stage in that type's overdue sequence is next chronologically appropriate — not restarting the sequence from Day 0 if the item has already been overdue longer than the type's first overdue interval. **[BA DEFAULT — neither doc specifies this; the alternative (restarting from Day 0 regardless of how overdue the item already is) would mean a user unlocking six months after something lapsed gets a fresh "Day 0" nag for something six months stale, which reads oddly. Flagging as a reasonable default, not a locked decision.]**

### REQ-14.3 — Restore purchase

- Given a user taps `Restore purchase` (from paywall or Settings), When the restore check succeeds, Then the same unlock effects in REQ-14.2 apply.
- Given the restore check fails (nothing to restore, or a billing error), When it fails, Then the user sees a clear, non-alarming message — exact copy not specified in mockups, **[BA DEFAULT — developer/BA to draft a short failure string along the lines of "Nothing to restore — you haven't unlocked this on this Google account yet" before ship, since no mockup state covers this]**.

---

## 12. Local-only storage / Settings-Privacy

Written against `06-settings-privacy.html`.

### REQ-15.1 — Three states

- **Loading (p1):** skeleton.
- **Error (p2):** load failure — reassures the user that renewal data isn't held on this screen and isn't at risk.
- **Success (p3):** Reminders group (notification settings deep-link, exact-alarm settings deep-link if REQ-11.2 keeps that screen — it doesn't, per §0.7/REQ-11.2), Purchase group (full-ladder status, restore purchase), a green privacy card stating local-only storage plainly, About/version, and the disclaimer from REQ-1.4.

### REQ-15.2 — Local-only storage guarantee

- Given the app at any point, no network call is made that transmits item data, notes, or usage off-device — this is a structural/architectural requirement more than a UI one, and developer should treat it as a hard constraint verified at code-review and QA-test time, not just documented here. Play's Data Safety disclosure (per `CLAUDE.md`'s known constraints) depends on this actually being true, not just claimed.
- Given the privacy card on Settings, its copy ("Everything stays on this device — No account, no cloud, no sync. Your renewal dates and notes never leave your phone.") must remain accurate; since the paywall (P0, §11 above) uses direct Play Billing (`docs/technical/04-scheduling-and-stack.md` §5, confirmed over the prior RevenueCat default), purchase/entitlement verification does call out to Google's servers. This card's copy needs a scoped exception rather than a bare "never leave your phone" claim — e.g., "...never leave your phone — the one exception is a purchase check with Google Play if you buy the unlock, which doesn't include any of your renewal data." **[BA DEFAULT — exact final wording is a small copy task for whoever ships this screen; the privacy policy (`docs/legal/privacy-policy.md`) already states this distinction in full and can be used as the source for the shorter in-app phrasing.]** This closes the flag developer raised against this requirement in the technical ADR.

---

## 13. Edit / delete side-effects on scheduling

Resolves the "what happens to scheduled notifications when a due date is edited or an item deleted" edge case named in the task brief.

### REQ-16.1 — Editing a due date

- Given an item with an active ladder (some stages already fired, some pending), When the user edits its due date and saves, Then all pending (not-yet-fired) scheduled notifications for that item are cancelled and the full ladder is recomputed and rescheduled against the new due date, per REQ-3.1's rules (stages that would now fall in the past are skipped, not fired retroactively).
- Given an item's status (e.g., `Overdue`) changes as a result of the date edit (e.g., editing a due date from the past to the future un-overdues it), When the edit saves, Then the item's list status and any active overdue-nag schedule update accordingly — an item edited out of overdue status stops receiving overdue nags and resumes the normal pre-due ladder.
- Given editing any other field (Label, Notes, type — see below) without changing the due date, When saved, Then the existing schedule is left untouched (no unnecessary cancel/reschedule churn).
- Given the user changes an item's **type** during edit (e.g., Custom → Vehicle), When saved, Then the ladder is recomputed entirely from the new type's rules — this is functionally the same operation as a due-date change, just triggered by a different field. **[BA DEFAULT — neither doc explicitly discusses changing type on an existing item; treating it as always permitted and always triggering a full ladder recompute, same as a due-date edit, rather than special-casing or blocking it.]**

### REQ-16.2 — Deleting an item

- Given an item is deleted (see REQ-5.4/REQ-10 for the undo-toast-gated flow), When the 6-second undo window lapses without an undo tap, Then all pending scheduled notifications for that item are cancelled at that point (not before — during the undo window, the item's notifications should not fire even though the underlying data hasn't been destroyed yet, since firing a notification for an item the user just told the app to delete would be a confusing, contradictory experience). **[BA DEFAULT — the "no notification during the undo window" half of this isn't explicitly stated in either doc; flagging because the alternative (a notification firing mid-undo-window for an item about to be deleted) is clearly wrong but nobody wrote down that it's wrong.]**

---

## 14. Edge cases resolved with stated defaults

Per the task brief's explicit list of examples. Each is a **[BA DEFAULT]** unless noted otherwise, since neither source doc addresses these. All three below were confirmed by product-manager as owned product decisions on 2026-08-21 (see `01-v1-scope.md`).

### REQ-17.1 — Due date in the past at creation time

- Given a user creates a new item with a due date that is already in the past (e.g., logging an insurance policy that's already lapsed), When saved, Then the item is accepted (not blocked by validation) and immediately shows status `Overdue`.
- Given such an item on a paid tier, When saved, Then no pre-due ladder stages are scheduled (they're all in the past), and the Day-0 overdue nag fires immediately (within normal notification delivery latency) rather than being skipped or deferred to some later check-in. Subsequent overdue nags follow the type's normal +N-day cadence from the actual due date, per REQ-3.3.
- Given several such backdated items are added in the same session (a plausible first-run scenario — a user logging several already-expired things at once), grouping (REQ-12.1) applies normally if their Day-0 nags land on the same moment/day, which mitigates but does not eliminate a burst of notifications on first use — this is an accepted, self-selecting edge case per the reasoning already given in scope doc §6, not something this document proposes further engineering against.

### REQ-17.2 — Timezone and device-clock changes

- Given an item was created while the device was in timezone A, When the device's timezone later changes to timezone B (travel, or manual change) before the item's due date, Then the reminder still fires on the correct calendar day relative to the due date, evaluated in the device's *current* timezone at delivery time — not frozen to the timezone at creation time. **This is a product requirement; the specific Android alarm-scheduling mechanism that satisfies it (e.g., using wall-clock/RTC-based scheduling and re-evaluating on timezone-change broadcasts, rather than elapsed-realtime scheduling) is a developer implementation decision, flagged here as a real technical dependency, not resolved by this document.**
- Given a device's clock is set backward (accidentally or deliberately) past a point where a notification already fired, When the clock changes, Then already-fired notifications are not re-fired — status/history should reflect what has already been delivered, not recompute as if it hadn't happened.
- Given a device's clock is set forward, skipping past one or more scheduled stages, When the app is next opened, Then any stage whose scheduled time has passed without firing (e.g., because the device was off, or Doze deferred it and the clock jump caused it to be considered stale) is treated as fired/skipped rather than queued to fire immediately on next opportunity — avoiding a burst of stale notifications arriving all at once after a clock correction. This is a defensive default against a genuinely rare scenario, included because "several stale notifications suddenly firing" is exactly the kind of bug that erodes trust in an app whose entire pitch is a well-calibrated cadence.

### REQ-17.3 — Loss of paid entitlement

- Given a device that previously had the paid unlock somehow reports itself as no longer entitled (e.g., a failed re-verification, an unusual billing-library edge case — not expected to happen under normal operation, but must degrade safely if it does), When entitlement is lost, Then the app does not delete any item data, notes, or history. Ladders visually and functionally degrade to the free-tier single-reminder view (REQ-3.2/REQ-5.2) for all items, with the same locked-stage-markers presentation used for any other free-tier item, and a clear path back via `Restore purchase`.
- Given this degraded state, When the user successfully restores or re-purchases, Then full paid behavior resumes exactly as described in REQ-14.2/14.3 — no data was ever lost in the interim, only notification scheduling was reduced.

---

## 15. Not covered by this document — needs separate specification later

Named explicitly so it isn't silently built or silently skipped:

- **Exact wording for every notification title/body across all 7 types × 2 notification kinds (ladder-stage, overdue nag) × grouped variants.** REQ-11.3/REQ-12.1 specify the pattern and give worked examples for the types shown in mockups; the remaining combinations (e.g., Professional Licence's overdue nag copy, Warranty's single Day-0 nag copy) follow the same pattern but haven't each been individually drafted here — that's a copy-completion pass, not a design decision, and can reasonably be done alongside implementation rather than blocking it.
- **The free-tier "why these stages matter" explanatory line for each type's unlock banner** (REQ-3.2) — pattern given, six of seven types' specific wording not yet drafted.
- **Restore-purchase failure copy** (REQ-14.3) — not mocked, default drafting deferred to implementation.
- **Colorblind/accessibility verification of the Health check category tint** against the error-container red — design doc §2a/§6 flags this as its own open question for a "second look," explicitly not something resolved by acceptance criteria; recommend qa-tester include a colorblind-simulation pass on this one tint specifically before ship.
- **Any acceptance criteria contingent on the exact-alarm decision** — resolved, not open; see §0.7/REQ-11.2 (inexact scheduling confirmed sufficient, exact-alarm screens cut).
- ~~**Snooze behavior in full**~~ — **Resolved, not deferred.** Snooze was cut from v1 entirely on 2026-08-21 (§0.1); there is no snooze behavior to specify. No notification action other than `Mark done` ships in v1 (REQ-11.3).
- **Widgets, dark theme, search/filter/sort, OCR, live vehicle data, calendar import, multi-profile, attachments, localization** — all explicitly out of v1 per scope doc §1's table; not addressed here at all, consistent with that table, not by omission.
- **Play Store listing content, closed-testing tester communications, Data Safety form answers** — outside this document's scope; noted because REQ-15.2's local-only guarantee is the thing that Data Safety form will need to reflect accurately, and that's a growth/product-manager-owned artifact, not a BA one. The privacy policy itself (`docs/legal/privacy-policy.md` / `.html`) has been drafted and is a BA deliverable, per direct task routing — see that document.

---

## 16. Requirements flagged as technically risky or unusually complex

For product-manager and developer to weigh in on before treating as settled, per this role's standing instruction not to make technical feasibility calls unilaterally:

1. **REQ-11.2 / §0.7 — the exact-alarm/Doze question.** Nearly every scheduling-related requirement in this document assumes same-day inexact delivery survives Doze reliably over horizons as long as 6 months (Passport's first stage). developer's technical ADR concludes this should hold, from documentation alone — the device-verification checklist in that ADR (§6) is what actually closes this out, and hasn't been run yet as far as this document knows. Still the single biggest residual risk here.
2. **REQ-12.1/12.2 — notification grouping via `NotificationCompat` group summaries**, combined with per-item cancel/reschedule logic (REQ-16.1) and the deferred-write undo mechanism (REQ-10.2) all touching the same underlying notification IDs. Getting the bookkeeping right (which notification IDs belong to which item, which are pending vs. fired vs. cancelled-during-undo-window) is more state-machine complexity than its individual pieces look like in isolation. developer's ADR (`04-scheduling-and-stack.md` §2) addresses this with a single `scheduled_notifications` source-of-truth table, which directly de-risks this item — still worth a design review before/alongside implementation, not just a read-through of these criteria.
3. **REQ-17.2 — timezone/clock-change handling.** Correctly implementing "reminders still land on the right calendar day after a timezone change" without either double-firing or silently dropping notifications is a known-hard class of bug on Android. Flagging as higher-risk than its one paragraph here suggests.
4. ~~**§0.1 — Snooze**, if confirmed in scope, adds a second independent scheduling mechanism...~~ — **No longer applicable.** Snooze was cut from v1 on 2026-08-21 (§0.1); the state-machine complexity this item warned about doesn't arise, because there is no second scheduling mechanism being built. Left here, struck through, only so the numbering and history stay traceable — not an open risk.
