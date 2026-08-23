import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repository/renewal_repository.dart';
import '../../data/repository/settings_repository.dart';
import '../../domain/format/relative_date.dart';
import '../../domain/models/custom_tier.dart';
import '../../domain/models/renewal.dart';
import '../../domain/models/renewal_type.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/reconciliation_service.dart';
import '../../theme/app_dimens.dart';
import 'widgets/custom_tier_selector.dart';
import 'widgets/health_check_fields.dart';
import 'widgets/ladder_preview_card.dart';
import 'widgets/type_selector.dart';

/// Add/Edit item — REQ-2. Creation is reachable from the home screen's FAB
/// and empty-state tiles this slice; [existingItem] is supported for edit
/// so the screen is ready for item detail's "Edit" button in a later
/// slice, but nothing in *this* slice's UI navigates here with an
/// existing item — flagged explicitly in the developer handoff.
class AddEditScreen extends StatefulWidget {
  const AddEditScreen({
    super.key,
    required this.repository,
    required this.settingsRepository,
    required this.notificationService,
    required this.reconciliationService,
    this.initialType,
    this.existingItem,
  });

  final RenewalRepository repository;
  final SettingsRepository settingsRepository;

  /// Task brief items 1/6: after a successful save, this screen (a)
  /// re-runs reconciliation so the new/edited item's schedule is armed
  /// promptly, and (b) — creation only, and only when this was the very
  /// first item ever added — primes the Android 13+ notification
  /// permission, per REQ-11.1 and the task brief's explicit "after the
  /// first item is added, not on first launch."
  final NotificationService notificationService;
  final ReconciliationService reconciliationService;
  final RenewalType? initialType;
  final Renewal? existingItem;

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _notesController;

  RenewalType? _type;
  DateTime? _dueDate;
  CustomTier _customTier = CustomTier.defaultTier;
  int _healthMonths = 12;

  bool _healthNoteDismissed = false;
  bool _saving = false;
  bool _justSaved = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    _labelController = TextEditingController(text: existing?.label ?? '')..addListener(_onFieldChanged);
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _type = existing?.type ?? widget.initialType;
    _dueDate = existing?.dueDate;
    _customTier = existing?.customTier ?? CustomTier.defaultTier;
    _healthMonths = existing?.healthRecurrenceMonths ?? 12;

    if (!_isEditing) {
      widget.settingsRepository.isHealthCheckNoteDismissed().then((dismissed) {
        if (mounted) setState(() => _healthNoteDismissed = dismissed);
      });
    } else {
      // Edit flow never shows the one-time note (REQ-1.2) — pre-mark it
      // dismissed for this form instance regardless of the real flag.
      _healthNoteDismissed = true;
    }
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _labelController.removeListener(_onFieldChanged);
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _typeMissing => _type == null;
  bool get _labelMissing => _labelController.text.trim().isEmpty;
  bool get _dueDateMissing => _dueDate == null;
  bool get _canSave => !_typeMissing && !_labelMissing && !_dueDateMissing;

  /// Only the Due date error is actually mocked (`02-add-edit-item.html`
  /// panel p3); Label's is a BA default extending the same pattern
  /// (REQ-2.2). Both are shown proactively once the *other* two required
  /// fields are filled, so the error is legible without needing a tap on
  /// a button that (per REQ-2.2's disablement rule) can't be tapped while
  /// anything required is still missing.
  bool get _showDueDateError => !_typeMissing && !_labelMissing && _dueDateMissing;
  bool get _showLabelError => !_typeMissing && !_dueDateMissing && _labelMissing;

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    // Past due dates are explicitly allowed at creation (REQ-17.1 — a user
    // logging something already lapsed) and with no stated bound on how
    // far back. `firstDate` has to stay behind whatever's already
    // selected, or reopening the picker on an old date would throw
    // (`initialDate` outside `[firstDate, lastDate]`) instead of just
    // showing it.
    final firstDate = initial.isBefore(now) ? DateTime(initial.year - 1) : DateTime(now.year - 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final label = _labelController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final customTier = _type == RenewalType.custom ? _customTier : null;
    final healthMonths = _type == RenewalType.healthCheck ? _healthMonths : null;

    try {
      // Task brief item 6: "requested after the user adds their first
      // item, not on first launch." Counted *before* the write below, so
      // this genuinely reads "was the portfolio empty going into this
      // save" rather than being thrown off by the row this save itself is
      // about to add.
      final isFirstItemEver = !_isEditing && await widget.repository.countAll() == 0;

      if (_isEditing) {
        final existing = widget.existingItem!;
        await widget.repository.updateItem(
          id: existing.id,
          type: _type!,
          label: label,
          dueDate: _dueDate!,
          notes: notes,
          customTier: customTier,
          healthRecurrenceMonths: healthMonths,
          isDone: existing.isDone,
          lastCompletedAt: existing.lastCompletedAt,
          createdAt: existing.createdAt,
        );
      } else {
        await widget.repository.createItem(
          type: _type!,
          label: label,
          dueDate: _dueDate!,
          notes: notes,
          customTier: customTier,
          healthRecurrenceMonths: healthMonths,
        );
      }

      // REQ-16.1 / docs/technical/04-scheduling-and-stack.md §2: a
      // create/edit is exactly the kind of change reconciliation exists to
      // react to (new item's ladder, or a due-date/type edit's full
      // recompute). Not awaited before showing the saved confirmation —
      // scheduling is a background concern from the user's point of view,
      // and blocking the "Saved" state on it would make every save feel
      // slower for no visible benefit.
      unawaited(widget.reconciliationService.reconcile());

      if (!mounted) return;
      setState(() {
        _saving = false;
        _justSaved = true;
      });

      // Bug fix (developer task brief, "fix that race condition" — see
      // business-analyst's §0.8/REQ-11.1 revision): this used to be an
      // `unawaited()` call racing against the fixed 900ms delay below,
      // with *this screen* showing the denial SnackBar directly — so a
      // slow or hesitant tap on the OS dialog could resolve after this
      // screen had already popped, leaving the SnackBar nowhere to render
      // and the message silently lost. Now awaited before the delay/pop,
      // and it returns a plain outcome instead of showing anything itself;
      // `HomeScreen._openAddEdit` shows the message once this screen has
      // actually finished popping, from a screen that's guaranteed to
      // still be mounted at that moment. See that method's own doc
      // comment for the full before/after.
      var notificationPermissionDenied = false;
      if (isFirstItemEver) {
        try {
          notificationPermissionDenied = await _primeNotificationPermission();
        } catch (_) {
          // The item is already saved at this point — a failure asking
          // for the permission (plugin error, etc.) must not be reported
          // to the user as a failed *save*, and must not block the normal
          // pop below. Nothing to recover: no permission-denied message
          // is owed for an ask that never actually completed.
          notificationPermissionDenied = false;
        }
      }

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(notificationPermissionDenied);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save — check local storage and try again.')),
      );
    }
  }

  Future<void> _dismissHealthNote() async {
    setState(() => _healthNoteDismissed = true);
    await widget.settingsRepository.dismissHealthCheckNote();
  }

  /// Task brief item 6. A stripped-down version of REQ-11.1's full
  /// three-panel priming flow (`05-permissions.html` p1–p3): this fires the
  /// real OS permission dialog directly (via
  /// `flutter_local_notifications`' Android 13+ API) rather than showing
  /// this app's own priming screen first. REQ-11.1's own priming-screen
  /// visuals are an accepted omission for v1 (§0.8) — not built.
  ///
  /// Awaited by [_handleSave] before this screen pops (see that method's
  /// updated doc comment for why — this used to be `unawaited()`, racing
  /// against the auto-navigate-back delay, which is the race condition
  /// fixed as part of this slice). Returns `true` only when the user
  /// actually denied the permission and a recovery message should be
  /// shown once control is back on a screen that's guaranteed to still be
  /// mounted — this screen deliberately no longer shows that message
  /// itself; see `HomeScreen._openAddEdit`/`_showNotificationDeniedMessage`.
  Future<bool> _primeNotificationPermission() async {
    final granted = await widget.notificationService.requestPermission();
    // `null` means no runtime prompt exists on this Android version at all
    // (below API 33) — nothing to recover from, notifications already work.
    if (granted == null || granted == true) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canInteract = !_saving && !_justSaved;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit renewal' : 'New renewal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            color: _canSave && canInteract ? scheme.onPrimaryContainer : scheme.outline,
            style: IconButton.styleFrom(
              backgroundColor: _canSave && canInteract ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            ),
            onPressed: _canSave && canInteract ? _handleSave : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Opacity(
              opacity: _saving ? .6 : 1,
              child: IgnorePointer(
                ignoring: !canInteract,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp2, AppSpacing.sp4, 120),
                  children: [
                    const _FieldLabel('Type'),
                    TypeSelector(selected: _type, onChanged: (t) => setState(() => _type = t)),

                    // REQ-2.4's stated order: type-select → one-time note
                    // (if applicable) → Label/Due date → recurrence
                    // stepper → Notes → ladder preview. The note sits here
                    // — right after type selection, before Label — not
                    // bundled with the stepper further down.
                    if (_type == RenewalType.healthCheck && !_healthNoteDismissed)
                      HealthCheckOneTimeNote(onDismiss: _dismissHealthNote),

                    const _FieldLabel('Label'),
                    TextField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Passport" or "Honda Civic MOT"',
                      ),
                    ),
                    if (_showLabelError) const _ErrorHelper("Label is required — give it a name you'll recognize."),

                    const _FieldLabel('Due date'),
                    _DueDateField(
                      date: _dueDate,
                      hasError: _showDueDateError,
                      onTap: _pickDueDate,
                    ),
                    if (_showDueDateError)
                      const _ErrorHelper('Due date is required — we need it to build your reminder schedule.'),

                    if (_type == RenewalType.healthCheck) ...[
                      const _FieldLabel('Remind me every'),
                      HealthRecurrenceStepper(
                        months: _healthMonths,
                        onChanged: (v) => setState(() => _healthMonths = v),
                      ),
                    ],

                    if (_type == RenewalType.custom) ...[
                      const _FieldLabel('How much lead time do you need?'),
                      CustomTierSelector(
                        selected: _customTier,
                        onChanged: (t) => setState(() => _customTier = t),
                      ),
                    ],

                    const _FieldLabel('Notes (optional)'),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Anything you want to remember — policy number, provider, etc.',
                      ),
                    ),

                    if (_type != null && _dueDate != null)
                      LadderPreviewCard(type: _type!, customTier: _type == RenewalType.custom ? _customTier : null),
                  ],
                ),
              ),
            ),
            if (_justSaved)
              Positioned(
                left: AppSpacing.sp4,
                right: AppSpacing.sp4,
                bottom: AppSpacing.sp4,
                child: Material(
                  // Same toast-visibility fix as undo_toast.dart (design
                  // doc §7a, bug #2) — inverseSurface/onInverseSurface
                  // instead of a literal that vanishes in dark.
                  color: scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(AppShapes.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: scheme.onInverseSurface, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Saved — reminders scheduled',
                          style: TextStyle(color: scheme.onInverseSurface, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _justSaved
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, 8, AppSpacing.sp4, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSave && canInteract ? _handleSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSave ? scheme.primary : scheme.surfaceContainerHigh,
                      foregroundColor: _canSave ? scheme.onPrimary : scheme.outline,
                    ),
                    child: _saving
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 10),
                              Text('Saving…'),
                            ],
                          )
                        : const Text('Save renewal'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Deliberately NOT calling `.toUpperCase()` here: the mockups'
    // `.field-label` uses CSS `text-transform: uppercase`, which only
    // changes *rendering*, not the underlying text — but there's no
    // Flutter equivalent that does the same without mutating the actual
    // string, and REQ-1.1 specifies this field's label copy verbatim as
    // "Remind me every" (mixed case). Mutating it to "REMIND ME EVERY"
    // would silently drift from the specified copy and from what a
    // screen reader announces. Small caps + letter-spacing gets close to
    // the mockup's visual weight without that tradeoff.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sp4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .3, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _ErrorHelper extends StatelessWidget {
  const _ErrorHelper(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.error)),
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({required this.date, required this.hasError, required this.onTap});

  final DateTime? date;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasError ? scheme.errorContainer : scheme.surfaceContainerLow,
          border: Border.all(color: hasError ? scheme.error : scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppShapes.sm),
        ),
        child: Text(
          date != null ? RelativeDateFormatter.longDate(date!) : 'Select a date',
          style: TextStyle(
            fontSize: 14.5,
            color: date != null ? (hasError ? scheme.onErrorContainer : scheme.onSurface) : scheme.outline,
          ),
        ),
      ),
    );
  }
}
