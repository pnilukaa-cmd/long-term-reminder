# V1 QA Report — renewal-reminder

Prepared by: qa-tester
Date: 2026-08-23
Scope: first QA pass, v1 feature-complete, ahead of the 12-tester closed-testing install.

**HONESTY STATEMENT — READ FIRST:** No Flutter SDK, Android device, or emulator exists in this
environment. **Nothing in this report was executed.** No `flutter test`, `flutter analyze`, or
`flutter run` was run, and no test result below should be read as "passed" or "failed" by
execution — I did not run the suite. Everything here is a static read: acceptance criteria
(`docs/requirements/03-v1-acceptance-criteria.md`) and the design/scope/technical docs, held up
against the actual code in `lib/` and the actual test files in `test/`, reasoned through by hand
(including tracing specific input values through the logic, e.g. the sign of a `Duration`). Where
I describe a bug, I am describing what the code provably does given specific inputs, not a
suspicion — but "provably does" is still a claim from reading, not from a debugger or a passing/
failing assertion. Sections 3 and parts of 4 name things that categorically cannot be closed by
reading code at all and need a real device.

---

## 1. The single most serious defect

**`NotificationDiffEngine` mislabels far more than the one reported case, and the mislabel is not
purely bookkeeping — it corrupts the one diagnostic ledger the team will actually rely on during
the 14-day window.** Full analysis in §2.1. Short version: any pending, future-dated notification
stage that drops out of the desired set for a reason *other than* its date naturally passing
(entitlement gain/loss, a due-date edit that reshapes the ladder, a type change) gets recorded as
`fired` when it should be `cancel`. The underlying OS alarm is correctly cancelled either way (I
verified both code paths call `NotificationService.cancel()`), so **this does not cause a missed
or duplicate notification** — the notification-volume budget and actual delivery are not at risk
from this bug. But it does mean the `scheduled_notifications` table — the single source of truth
`ScheduledStateDebugScreen` and any future support/insights investigation will use to answer "did
this notification actually fire?" — will confidently report `fired` for notifications that were
never shown to the user. That is a worse failure mode for a debugging tool than an obviously
broken one: it looks trustworthy and isn't.

---

## 2. Defects found by reading

### 2.1 `NotificationDiffEngine` — the flagged issue is real, broader than reported, and not "bookkeeping-only"

**File:** `lib/domain/notifications/notification_diff.dart`, lines 151–169 (the loop over rows
that dropped out of the desired set).

```dart
final gapDays = today.difference(row.fireOn).inDays;
final kind = gapDays <= 2 ? DiffActionKind.markFired : DiffActionKind.markSkipped;
```

This line is only reached for a `pending` row belonging to a still-active renewal whose
`stageKey` is **not** in the freshly computed desired set. The two labels it's choosing between
(`markFired` vs `markSkipped`) are both *only valid when `row.fireOn` is in the past* — the whole
point of the branch is "this stage's window closed with the passage of time; was that recent
delivery slippage (`fired`) or a big clock jump (`skipped`)?"

The bug: **the code never checks whether `row.fireOn` is actually in the past.** If `row.fireOn`
is still in the future, `today.difference(row.fireOn)` is negative, and a negative `Duration`'s
`.inDays` is always `<= 2`. So **every** dropped, future-dated, still-pending row gets
`markFired` — regardless of how far in the future it is (a stage six months out gets the same
label as one six days out).

**When does a pending row's key legitimately drop out while `fireOn` is still in the future?**
Never as a natural consequence of time passing (that case always has `fireOn` in the past by
construction). It happens whenever `ReconciliationPlanner`'s output for that item changes shape
between two reconciliation passes for a reason *other than* the clock:

- **Entitlement transition** (the case the developer flagged) — paid → free replaces
  `ladder:0..N` with `free:0`; free → paid does the reverse. Any not-yet-fired paid stage or the
  free stage that's superseded gets mislabeled.
- **A due-date edit that reshapes the ladder** (REQ-16.1) — e.g. editing a due date much closer
  in, so a stage that used to be `ladder:2` under the old due date no longer appears at all under
  the new one. I traced a concrete example: Vehicle due 2028‑01‑01, edited to 2027‑06‑05, with
  "today" = 2027‑06‑01. The old `ladder:0` row (fireOn 2027‑12‑02, still six months in the
  future) drops out of the new desired set entirely and gets `markFired`.
- **A type change on edit** (REQ-16.1 explicitly names this as always permitted) — e.g. Custom
  (3 stages) → Warranty (2 stages) drops a future-dated stage the same way.
- **Custom's lead-time selector changed on edit** (REQ-2.5) — Long → Short drops the earlier,
  more-future stages the same way.

So the mislabel is **not scoped to entitlement transitions** — it fires on the single most common
category of edit this app supports (REQ-16.1 edits that shrink or reshape the ladder), which is
very plausibly a more frequent trigger during a 14-day tester window than a purchase/restore
event.

**Is it "bookkeeping-only," as developer claimed?** Partially right, partially wrong:
- **Right:** it does not cause a live notification to be missed, duplicated, or delayed.
  `ReconciliationService._apply` (`lib/services/notifications/reconciliation_service.dart`,
  lines 140–150) calls `_notificationService.cancel(id)` for `markFired`, `markSkipped`, **and**
  `cancel` alike — the actual OS-level alarm cancellation is identical regardless of which label
  is chosen. I also checked stage revival (a `stageKey` coming back into the desired set later,
  e.g. re-purchasing after a downgrade, or editing the due date back): `NotificationDiffEngine`
  treats any non-`pending` status identically (`existing.status != 'pending'` →
  `rescheduleAndArm`), so a wrongly-`fired` row revives exactly as correctly as a `cancelled` one
  would. **No double-scheduling and no orphaned live notification results from this bug.**
- **Wrong:** `status` is not write-only bookkeeping nobody reads. `NotificationActionHandler`
  (`lib/services/notifications/notification_action_handler.dart`, line 65) filters on
  `row.status != 'pending'` to decide what to cancel on a notification-triggered mark-done — a
  correctness-sensitive read, even if not one this specific bug happens to break today. More
  directly: `lib/ui/debug/scheduled_state_debug_screen.dart` renders `status` as its entire
  reason for existing — it's the tool the team built *specifically* to let a human ("developer or
  QA," per that screen's own doc comment) distinguish "the app's belief" from what actually
  happened, and it's the tool named as the way to investigate REQ-17.3 (entitlement loss) on a
  real device (§6 of the debug screen's doc comment). A tester or developer looking at that
  screen after an edit or a purchase/restore during the 14-day window will see `fired` rows for
  notifications that were, in fact, silently cancelled and never shown — indistinguishable from a
  genuinely delivered notification. If a tester reports "I never got reminded about X," this is
  exactly the tool someone will reach for to check, and it will give a false answer for any stage
  that was cancelled by an edit or entitlement change rather than genuinely fired.

**Fix (for developer, not mine to implement):** the branch needs to check
`row.fireOn.isAfter(today)` (or equivalently, only classify as `markFired`/`markSkipped` when
`gapDays >= 0`) and route anything still in the future straight to `cancel`, the same way an
inactive-renewal row already is. This is additive to the existing `cancel` path, not a new
concept.

**Test-coverage gap that let this ship:** `test/domain/notification_diff_test.dart`'s two "dropped
out of the desired set" cases (`a still-active item whose stage passed within 2 days`, `...more
than 2 days ago`) both use a `row.fireOn` that is already in the past relative to `today`. There is
no case with a future `fireOn` for a still-active item — exactly the condition that exposes the
bug. `test/domain/reconciliation_planner_test.dart` has a test confirming free/paid stage-key sets
are disjoint (`REQ-14.2/17.3: the same item transitions cleanly between free and paid stage keys`,
lines 257–275) but it only tests `ReconciliationPlanner.planFor` (the *pure desired-set*
computation) — it never feeds that transition through `NotificationDiffEngine.diff` against a
previously-persisted row, which is the only way this bug is reachable. `test/services/billing/
purchase_manager_test.dart`'s `REQ-14.2` test only exercises free → paid (a *grant*), and only
asserts the count of `pending` rows afterward — it never asserts anything about the status of the
free-tier row that was superseded. **No test in the suite exercises paid → free (entitlement
loss) end-to-end through the actual `ReconciliationService`, and none exercises a due-date/type
edit that shrinks a ladder end-to-end either.** Both are the exact shapes needed to catch this.

**Severity: Medium.** Not a crash, not a missed/duplicate notification, not a budget violation.
Real harm is to debuggability during exactly the window (14-day closed test) where the team most
needs to trust its own diagnostics. Cheap, low-risk, additive fix.

### 2.2 Notification-volume budget — honoured at the code level, in both tiers, not device-verified

Checked `ReconciliationPlanner._planForItem` (`lib/domain/notifications/reconciliation_planner.dart`)
against design doc §2/§6 and REQ-3.1–3.3 line by line:

- Free tier: exactly one stage (`_freeStage`), and **overdue returns nothing at all**
  (`if (!isEntitled) return const [];` inside the `overdue` branch) — matches REQ-3.3's explicit
  "no overdue nag fires at all" rule for free items. Confirmed.
- Paid tier: full ladder pre-due (`_ladderStages`), full overdue sequence post-due
  (`_overdueStages`), with REQ-17.1's Day-0-clamped-forward asymmetry correctly implemented (only
  offset `0` clamps to "today" if stale; every other offset is silently skipped, not burst-fired).
  Confirmed against `test/domain/reconciliation_planner_test.dart`'s dedicated tests for this.
- `LadderTables` (`lib/domain/ladder/ladder_tables.dart`) — every paid ladder, free offset, and
  overdue-nag day-list I checked matches design doc §2/§2a/§2b and REQ-3.1/3.2/3.3's tables
  exactly (Passport 6mo/3mo/1mo/1wk paid, 3mo free; Insurance 21/7/1 paid, 7d free; Licence
  90/30/7 paid, 30d free; Vehicle 30/14/3 paid, 14d free; Warranty 30/7 paid, 30d free; Health
  check 30/14/3 paid, 30d free, overdue `[0, 30]`; Custom's three tiers with free-tier "middle
  stage" behavior per REQ-2.5). No mismatches found.
- Grouping (`groupDateKey`, `_reconcileGroupSummaries`) is keyed off the same `desired` list the
  budget math assumes, and correctly posts/cancels the summary as membership crosses the 2-item
  threshold.

**What this section cannot confirm:** whether real delivery timing on a real device holds to the
budget's implicit "one notification, one moment" assumption — that's the device-verification
checklist in `docs/technical/04-scheduling-and-stack.md` §6, not something I can exercise here.
**Entitlement transitions do not double-schedule or leave live orphans** (see §2.1 — both
mislabeled and correctly-labeled dropped rows result in an actual `cancel()` call), but as noted
above the *audit trail* of a transition is not reliable, which matters if anyone needs to verify
post-hoc that a transition behaved correctly rather than just trusting it did.

### 2.3 Entitlement gating — correct everywhere I checked; one real gap is the same one named in §2.1

Traced the entitlement flag from source to every consumer:
- `EntitlementRepository` (`lib/data/repository/entitlement_repository.dart`) — single
  local boolean, `false` by default, no network dependency to read it. Confirmed by
  `test/data/entitlement_repository_test.dart`.
- `ReconciliationPlanner.planFor` takes `isEntitled` and is the single point that decides paid vs.
  free scheduling (§2.2) — no other code path independently decides this.
- `ItemDetailScreen._LadderCard`, `LadderPreviewCard` (Add/Edit's live preview), and Settings all
  read `entitlementRepository.watchEntitled()` live, so a purchase/restore/downgrade updates
  every screen immediately, not just on next launch. Confirmed by reading
  `lib/ui/detail/item_detail_screen.dart` lines 176–194 and the corresponding Add/Edit wiring.
- `PurchaseManager` (`lib/services/billing/purchase_manager.dart`) only ever *grants*
  (`setEntitled(true)`) — there is genuinely no code path in this codebase that ever calls
  `setEntitled(false)` outside the `kDebugMode`-gated Settings toggle
  (`lib/ui/settings/settings_screen.dart` line 139). This matches REQ-17.3's own framing ("not
  expected to happen under normal operation") and is not a defect — real Play Billing entitlement
  loss is a rare, hard-to-simulate edge case, and the debug toggle exists specifically because the
  spec authors already knew this. I'm naming it so the team is clear the *only* way to exercise
  REQ-17.3 pre-release is that debug toggle, on a debug build.
- I did not find a case where a paid feature renders/schedules for a free user, or vice versa —
  no "pay and get nothing" or "don't pay and get everything" path in the code as read.

**The one real entitlement-adjacent gap** is §2.1's bug, which is *triggered* by entitlement
transitions among other things — restated here because the task brief asked specifically whether
entitlement transitions ever double-schedule or leave orphans, and the precise, evidence-backed
answer is: **no double-scheduling, no live orphans, but a corrupted status record of what
happened**, every time.

### 2.4 Reconciliation state machine — mostly solid; two narrow, low-severity gaps

Traced every listed trigger (edit, delete, mark-done, undo, undo-last-completion,
notification-mark-done, entitlement change, reboot, clock change) through to a `reconcile()` call
or an equivalent architectural guarantee:

- Edit (`AddEditScreen._handleSave`) → `unawaited(reconciliationService.reconcile())`. Confirmed.
- Delete/mark-done via the undo toast (`UndoController._commitPending` →
  `onCommitted?.call()`, wired to `reconciliationService.reconcile` in both `HomeScreen` and
  `ItemDetailScreen`). Confirmed.
- `Undo last completion` (`ItemDetailScreen._handleUndoLastCompletion`) → explicit
  `reconcile()` immediately after the DB revert. Confirmed.
- Notification-triggered mark-done (`NotificationActionHandler.handleMarkDone`) → cancels
  affected rows directly, then calls `reconciliationService.reconcile()` at the end. Confirmed.
- Entitlement change (`PurchaseManager._handleUpdates`, Settings' debug toggle) → both call
  `reconcile()` after writing the flag. Confirmed.
- Reboot/periodic drift → `workmanager`'s persisted `PeriodicWorkRequest` plus reconcile-on-launch,
  per the ADR — this is architecture I can read but not execute; see §3.
- Clock jump forward → handled *inside* the diff engine's gap-day heuristic (§2.1's same branch,
  when working correctly) — `markSkipped` for gaps > 2 days. This is correctly triggered for the
  *intended* case (stage genuinely fired in the past, clock jumped past it) but is the same code
  path with the sign bug for the *unintended* case (§2.1).
- `RenewalDao.markDone`/`undoLastCompletion` — read closely, and separately verified against a
  real in-memory database in `test/data/undo_last_completion_test.dart` (10 tests, genuinely
  exercising the state machine, not mocked) and `test/data/renewal_dao_markdone_test.dart`. The
  single-level-undo invariant (snapshot overwritten by any subsequent mark-done/edit/delete/prior
  undo) is implemented exactly as REQ-9.7 describes and is well-tested.

**Gap 1 (narrow race, Low severity):** `ItemDetailScreen`'s overflow-menu enablement for
`Undo last completion` is driven by `rawItem.hasUndoableCompletion` — the *last-committed* DB
value — not by whether a **new** mark-done is currently sitting, uncommitted, in its own 6-second
undo-toast window (`UndoController._pending`). Concretely: if item X has an old, still-undoable
completion (`hasUndoableCompletion == true` in the DB), and the user then taps "Mark done" again
(starting a fresh 6-second toast, nothing written yet), the overflow menu still shows
`Undo last completion` as enabled during those 6 seconds, referring to the *old* completion. If
the user taps it during that window, `RenewalRepository.undoLastCompletion` reverts the DB to the
pre-*old*-completion state — and then, ~6 seconds later, the still-pending new mark-done commits
on top of that, taking its "before" snapshot from whatever `undoLastCompletion` just wrote rather
than the state that actually preceded the new mark-done tap. This produces a confusing but
recoverable end state (not data loss — everything is still one more `Undo last completion` away
from being fixed by hand), and requires a user to deliberately open the overflow menu and tap a
second, different action while a toast is visibly counting down. Reproducible by reading the code;
not something the existing tests would catch (no test in `undo_last_completion_test.dart` or
`undo_controller_test.dart` combines a pending toast with a concurrent overflow-menu action).

**Gap 2 (unenforced spec line, Low severity, hard to trigger):** REQ-16.2 states "during the undo
window, the item's notifications should not fire." As implemented, this holds *only* because
delete is a deferred write (nothing changes in the DB, so nothing changes for reconciliation, so
nothing gets cancelled prematurely) — there is no active suppression of an already-armed OS alarm
that happens to be scheduled to fire inside that specific 6-second window. In the near-impossible
case where a real device's alarm fires in the same few seconds a user is also tapping delete on
that same item, the notification would still show. Given how narrow the window is against how
coarse this app's scheduling is (day-granularity, `fireHourLocal = 9`), this is not worth
engineering against for v1, but the spec line isn't actually enforced by any code — it's true by
coincidence of timing, not by design.

### 2.5 Notification-permission race (§0.8's required fix) — implemented correctly, as read, but has zero automated test coverage

This was the one specific defect BA required fixed before REQ-11.1 counts as met. Reading
`lib/ui/add_edit/add_edit_screen.dart` (`_handleSave`, `_primeNotificationPermission`) and
`lib/ui/home/home_screen.dart` (`_openAddEdit`, `_showNotificationDeniedMessage`): the fix is
structurally correct. `AddEditScreen` now `await`s the permission-priming result *before* popping
(previously `unawaited`, racing the fixed 900ms delay), and returns the outcome as the pushed
route's result rather than showing the SnackBar itself; `HomeScreen`, which is guaranteed to still
be mounted the instant that `await` on the `Navigator.push` resolves, shows the message from
there. This removes the race by construction rather than narrowing the timing window, which is
the right fix.

**However:** `test/ui/add_edit_screen_test.dart` constructs its `NotificationService` and never
calls `.init()`, and its own comment says explicitly: *"none of the cases in this file tap Save,
so `_handleSave`'s calls into these two never actually fire... A test that does exercise Save
would need a real (fake/mocked) plugin, which this slice doesn't set up — flagged in the developer
handoff as untested territory."* So the one defect BA specifically called out as a required fix,
with an explicit instruction that "QA should specifically test the denial path with a deliberately
delayed tap on the OS dialog to try to reproduce the race," currently has **no automated
regression test at all** — only my read of the code, which cannot exercise a real
`flutter_local_notifications` permission dialog's timing. This needs both an automated widget test
(inject a fake notification service with a controllable-delay `requestPermission()`, and assert
the SnackBar renders after `HomeScreen` has taken over) and the real-device check named in §3.

---

## 3. Test-coverage assessment

**Overall shape:** the domain layer (`lib/domain/`, mostly pure functions) is genuinely and
thoroughly tested — 19 tests in `reconciliation_planner_test.dart`, 14 in
`ladder_calculator_test.dart`, 9 in `date_math_test.dart`/`notification_diff_test.dart`/
`ladder_track_test.dart`, 7 in `recurrence_calculator_test.dart`, 6 in `status_calculator_test.dart`.
These read like real edge-case testing, not padding — e.g. `status_calculator_test.dart`'s
documented bug fix for the due-today boundary, `ladder_calculator_test.dart`'s past-due-stage
skipping, `undo_last_completion_test.dart`'s 10 tests running against a real in-memory drift
database (not a mock) and actually exercising invalidation-by-edit/delete/second-mark-done. This
is real coverage.

**Where coverage is thin or absent, named specifically:**

1. **`NotificationDiffEngine` + a real entitlement/edit transition, end-to-end.** Named in §2.1.
   A test would need to: seed a `ReconciliationService` with an in-memory DB, run `reconcile()`
   once paid (arming future-dated ladder rows), flip entitlement to free (or edit the due date to
   reshape the ladder), run `reconcile()` again, and assert on the **status** of the rows that
   dropped out (`cancelled`, not `fired`) — not just the count of `pending` rows afterward (which
   is all `purchase_manager_test.dart`'s existing REQ-14.2 test checks). This is the single test
   that would have caught the flagship defect and doesn't exist.

2. **UI/widget layer is present but shallow on the exact paths that matter most.**
   `test/ui/add_edit_screen_test.dart` (3 `testWidgets`) explicitly never exercises Save with a
   working notification service — the permission-race fix (§2.5) is unverified by any automated
   test. I did not deeply audit every other UI test file's assertions line-by-line given the scope
   of this pass, but `home_screen_test.dart`'s own doc comment confirms it deliberately doesn't
   assert on `SettingsScreen`'s real content once pushed, delegating that to
   `settings_screen_test.dart` — a reasonable scoping choice, but worth naming so nobody assumes
   full-screen coverage where there's a deliberate seam.

3. **`NotificationService`, `NotificationActionHandler`'s background-isolate path,
   `workmanager_dispatcher.dart`, and the reconciliation-on-reboot/periodic-task wiring are
   entirely unverified by any test in this suite** — and the code says so itself
   (`NotificationService`'s own class doc: *"Unverified: nothing in this file has been run — no
   Flutter SDK, no device, no emulator exist in this environment."*). This is honest labeling, not
   a hidden gap, but it means the actual `flutter_local_notifications` API surface used
   (`zonedSchedule`, `AndroidScheduleMode.inexactAllowWhileIdle`, `groupKey`/`setAsGroupSummary`,
   the two notification-response callbacks) has never been resolved against a real installed
   package version, let alone run. This is the single largest coverage gap in the project and it
   is categorically not closable without a device — see §4.

4. **No test simulates a genuine paid → free (entitlement loss) transition through the full
   `ReconciliationService` pipeline.** `reconciliation_planner_test.dart`'s disjoint-stage-key test
   only checks the *planner's* output for both tiers in isolation; nothing feeds that transition
   through the diff engine against previously-persisted rows (same gap as #1, restated because
   it's also a coverage gap in its own right for REQ-17.3, independent of the bug it happens to
   expose).

5. **Colorblind verification of the Health check tint vs. Overdue red** — design doc §7a did a
   rigorous *simulated* CVD check (Machado et al. 2009 matrices, ΔE 56) and explicitly asked
   qa-tester to re-verify "with a proper device-level CVD-simulation tool... against the actual
   rendered app, not just the token hex values." I cannot do this without a device or emulator —
   named here as a real, currently-open item, not silently skipped.

**Mutation-testing note:** I did not modify and re-run any code (no toolchain to run it with), so
I cannot claim to have proven the passing tests would catch a regression by deliberately breaking
something and watching red. What I did instead, consistent with "prove your tests actually test
something" without an executable harness: for the flagship defect, I traced the exact input
(`row.fireOn` in the future, dropped `stageKey`, active renewal) through the actual `diff()`
function by hand and confirmed the output (`markFired`) contradicts what the code's own semantics
say `markFired` should mean, and separately confirmed no existing test's inputs ever produce that
combination. That's as close to "mutation testing by hand" as static reading allows — the
statement above about the fix (`row.fireOn.isAfter(today)`) is falsifiable and should be the first
thing added to `notification_diff_test.dart` alongside the fix.

---

## 4. Device test plan

Ordered by risk. Items 1–6 mirror and extend the checklist already in
`docs/technical/04-scheduling-and-stack.md` §6 — do not treat this as a replacement for that
checklist, run both together. Each item states what a human should do, and what result means
**failure** (i.e., what should stop or delay a wider rollout, versus what's just a note).

1. **Basic + forced Doze inexact delivery** (ADR §6 tests 1–2). Schedule a short-horizon stage,
   force Doze via `adb shell dumpsys deviceidle force-idle`, confirm delivery within the next
   reported maintenance window. **Failure:** doesn't arrive at all within a few hours on stock,
   non-OEM-restricted Android. This is the single largest unverified assumption underneath every
   acceptance criterion that says "the reminder fires on [date]."

2. **Force-stop → reopen self-heal** (ADR §6 test 5). Force-stop the app, confirm
   `dumpsys alarm` is empty for the package, reopen manually, confirm the full expected schedule
   is restored. **Failure:** reopening does not fully restore the schedule — this is the one
   architecturally-accepted gap (force-stop cancels everything by Android's own design), and the
   *repair* on reopen is the only thing standing between that and a silently missed reminder; it
   must actually work.

3. **Reboot survival** (ADR §6 test 4). Schedule several future stages, `adb reboot`, confirm
   `dumpsys alarm` repopulates via the `workmanager` periodic task without the user opening the
   app. **Failure:** stays empty after reboot with no app open.

4. **OEM battery management, per actual tester device** (ADR §6 test 7). This cannot be verified
   once in a sandbox — it needs to be checked **per OEM represented among the 12 testers**
   (Samsung/Xiaomi/OnePlus/etc. each have different aggressive battery-killer defaults). Since
   this is explicitly named as the one category "architecture genuinely cannot fully solve," it's
   worth a short pre-flight ask to the 12 testers about device make/model so this can be spot-
   checked on at least one of the more aggressive OEMs (Samsung or Xiaomi/MIUI) before wide
   install, not discovered mid-window from a tester's silent, unexplained missed reminder.

5. **App update survival** (ADR §6 test 6). Install, schedule items, `adb install -r` an updated
   build over it without uninstalling, check `dumpsys alarm` before/after. This is a named,
   currently-unresolved documented-fact gap, not an assumption either way — worth settling early
   since the 14-day window will almost certainly include at least one build update pushed to
   testers.

6. **Clock-jump-forward burst prevention** (ADR §6 test 8b, directly tests §2.1's *correctly*
   working branch). Create a 6-month-out item, disable auto date/time, jump the clock forward in
   large steps. **Failure:** multiple stale notifications fire in a burst instead of being marked
   skipped silently.

7. **Real Play Billing round-trip, including a downgrade if achievable.** Purchase, restore, and
   — if there's any way to simulate it (a second test account without the purchase, or Play's own
   license-testing tools) — an entitlement loss. After any transition, open the debug screen
   (`Settings → Scheduled state`, debug builds only) and check whether any row for a still-active
   item shows `fired` for a date that's clearly still in the future — that's §2.1's bug, directly
   observable on-device once the fix isn't in yet, and a good regression check once it is.

8. **Notification-permission denial with a deliberately delayed tap on the OS dialog**, exactly as
   BA's REQ-11.1 revision instructs. Save a first item, and when the OS permission dialog appears,
   wait several seconds before tapping "Deny" (long enough that the Add/Edit screen would already
   have auto-navigated back under the old, buggy timing). **Failure:** the "notifications are
   off... Open settings" message never appears. This is structurally fixed per §2.5's code read,
   but has zero automated coverage and needs this exact real-device check to actually close it.

9. **Grouped/summary notification rendering**, light and dark, on the actual device's notification
   shade style. Schedule two items to land the same day, confirm the collapsed summary and its
   expanded per-line view match `07-notifications.html` panels p3/p4 — this is OS chrome the app
   doesn't control and was explicitly flagged by ux-designer as not covered by their own pass.

10. **Colorblind check of the Health check category tint against the Overdue status dot**, with a
    real CVD-simulation tool (Android Accessibility Scanner, or a browser/OS-level simulator)
    against the actually-rendered app — ux-designer's own suggested independent confirmation of
    their simulated-matrix result (§7a of the design doc), still open.

---

## 5. Release-readiness call

**None of what I found is a crash or a broken core-loop path** — add/edit/list/delete/mark-done/
undo/undo-last-completion, the ladder math, the free/paid gating, and the permission-race fix all
read as correctly implemented against their acceptance criteria. Given the project's own stated
dominant risk is never shipping, I would not gate the 12-tester install on anything in this
report.

**Fix before the 12 testers install (cheap, and specifically protects the team's own ability to
debug the 14-day window):**
- §2.1's `NotificationDiffEngine` sign bug. It's a small, additive, low-risk fix (route
  future-`fireOn` dropped rows to the existing `cancel` path instead of the fired/skipped
  heuristic) that directly improves the trustworthiness of the one tool the team will lean on to
  interpret tester reports like "I didn't get reminded" for the rest of the window. Add the
  missing test case from §2.2/§3.1 alongside the fix.

**Fix during the 14-day window, not before install:**
- Add the missing automated widget test for the permission-denial race (§2.5) — the code fix
  looks right by reading, but it's the literal condition BA set for REQ-11.1 to count as met, and
  it currently has no regression protection at all.
- Run the device-verification checklist (§4, items 1–3 and 8 especially) as early in the window as
  possible — ideally on day 1, in parallel with recruiting/onboarding the 12 testers, since
  REQ-11.2's "no exact alarms needed" call is explicitly provisional on this checklist per the
  ADR's own framing, and it's cheap to run on the developer's own device before testers are
  depending on the answer.
- Item 4 (OEM battery management) and item 5 (app update survival) should be scheduled within the
  window, not treated as launch blockers — they're real risks but ones the architecture already
  names and partially mitigates (self-heal-on-launch, the force-stop warning copy in REQ-1.4).

**Can wait / low priority:**
- The narrow "Undo last completion vs. a pending toast" race (§2.4, Gap 1) — needs a deliberate,
  unlikely sequence of taps within a 6-second window, and is recoverable, not data-destroying.
- REQ-16.2's unenforced-but-currently-harmless notification-during-undo-window edge case (§2.4,
  Gap 2).
- The device-level colorblind re-check (§4, item 10) — design doc's simulated verification was
  rigorous; this is confirmation, not a known problem.
- The per-type unlock-banner and notification-copy completion items already explicitly deferred by
  business-analyst in acceptance-criteria §15.

---

## 6. How to run this yourself

**This section is a placeholder for the actual toolchain run, which nobody has performed yet in
this repository.** I could not execute any of it — no Flutter SDK, Android device, or emulator
exists in this sandbox. A human (or an agent with access to a real toolchain) needs to run the
following and paste the real output back before this feature can be marked verified end-to-end,
per this team's own working agreement that a feature isn't done until it actually runs:

1. **Prerequisites:** Flutter SDK installed and on `PATH` (`flutter doctor` should show no
   blocking issues), and either a physical Android device with USB debugging enabled (strongly
   preferred, given how much of this report is about OS-scheduling behavior no emulator fully
   reproduces) or an Android emulator as a fallback for everything except §4's device-specific
   items (Doze/App Standby/OEM battery/reboot/force-stop behavior needs a real device or, at
   minimum, `adb`-driven emulator commands per the ADR's §6 table).

2. **Steps to launch:**
   ```bash
   cd /home/user/renewal-reminder
   flutter pub get
   flutter analyze          # must report zero issues
   flutter test              # must report all tests passing, with the pass/fail count
   flutter run                # onto a connected device/emulator
   ```

3. **What to try (core flow, ~5 minutes):**
   - From the empty first-run screen, tap a type tile (e.g. "Vehicle") to open Add/Edit
     pre-filled with that type.
   - Fill in a label and a due date a few weeks out, save. Confirm the "Saved — reminders
     scheduled" toast appears and the item shows up on the list under the correct status section.
   - Open the item, look at the ladder track — confirm the stage dots and due-date marker render
     without crashing.
   - Long-press the card on the list — confirm the delete action reveals, and tapping elsewhere
     dismisses it without deleting.
   - Tap the quick-done checkmark on a recurring type (e.g. Insurance) — confirm the "when's the
     next one due?" bottom sheet appears, pick the smart default, confirm the undo toast appears
     and the item's status updates correctly once the 6 seconds pass.
   - Open the overflow (⋮) menu on that item's detail screen — confirm "Undo last completion" is
     present and works, restoring the prior due date.
   - Open Settings, confirm the disclaimer text renders in full and reads in under ~20 seconds.

4. **What "working" looks like vs. a problem:** `flutter analyze` should print "No issues found!"
   and `flutter test` should end with a line like "All tests passed!" and a count (if either
   reports failures, that is the priority to fix first, ahead of anything in this report). On
   device, the app should never show a blank white screen (any load failure should show the
   "Try again" error state instead), and the app should never crash outright when tapping through
   the flow above. If notifications don't arrive within the same day for a short-horizon test
   item with the screen off, that's the signal to escalate straight to the device-verification
   checklist in §4 of this report and §6 of the technical ADR before assuming anything else is
   wrong.
