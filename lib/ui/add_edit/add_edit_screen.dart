import 'package:flutter/material.dart';

import '../../data/repository/renewal_repository.dart';
import '../../data/repository/settings_repository.dart';
import '../../domain/format/relative_date.dart';
import '../../domain/models/custom_tier.dart';
import '../../domain/models/renewal.dart';
import '../../domain/models/renewal_type.dart';
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
    this.initialType,
    this.existingItem,
  });

  final RenewalRepository repository;
  final SettingsRepository settingsRepository;
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
      if (!mounted) return;
      setState(() {
        _saving = false;
        _justSaved = true;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
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
