import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../data/database/notification_dao.dart';
import '../../data/repository/entitlement_repository.dart';
import '../../services/billing/billing_gateway.dart';
import '../../services/billing/paywall_controller.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/notifications/reconciliation_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_semantic_colors.dart';
import '../debug/scheduled_state_debug_screen.dart';
import '../paywall/paywall_screen.dart';
import 'privacy_policy_constants.dart';
import 'widgets/settings_disclaimer.dart';
import 'widgets/settings_error_view.dart';
import 'widgets/settings_loading_view.dart';

/// Settings/Privacy — the last v1 screen before the paywall. Matches
/// `docs/design/mockups/06-settings-privacy.html`'s three states
/// (REQ-15.1: loading / error / success — there's no meaningful empty
/// state here, this screen's content is static plus one live permission
/// check, same "n/a — always has data" reasoning item detail uses).
///
/// Reachable from the home screen's app-bar gear icon. Carries two
/// required-before-ship legal surfaces — [SettingsDisclaimer] (REQ-1.4)
/// and the privacy summary card below — plus the notification-permission
/// recovery route (REQ-11.1), the Purchase group (this slice — REQ-15.1's
/// previously-omitted group, built honestly now that an entitlement model
/// exists), and the `kDebugMode`-gated scheduled-state debug entry point,
/// moved here from the home app bar per the developer task brief item 6
/// ("the home app bar should not carry developer affordances").
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.notificationDao,
    required this.notificationService,
    required this.reconciliationService,
    required this.entitlementRepository,
    required this.billingGateway,
    this.checkNotificationPermission,
  });

  /// Only used to reach the debug-only scheduled-state screen (task item
  /// 7's original home) — this screen itself never queries the plugin or
  /// DAO directly beyond that.
  final NotificationDao notificationDao;
  final NotificationService notificationService;

  /// Re-run on resume (see [_SettingsScreenState.didChangeAppLifecycleState])
  /// — a plausible moment the user has just come back from the system
  /// notification-settings screen this screen deep-links to, which is
  /// exactly the "permission granted later, outside the app's own flow"
  /// transition REQ-11.1's last bullet requires existing items to be
  /// (re)scheduled from. Settings is the one screen that owns permission
  /// recovery, so it's the cheapest, most contained place to close that
  /// gap — not built as a general app-wide foreground-resume hook.
  final ReconciliationService reconciliationService;

  /// Drives the Purchase group's live status, and its `Undo`-equivalent —
  /// the `kDebugMode`-gated "reset entitlement" toggle that lets a human
  /// exercise REQ-17.3's loss-of-entitlement path without a real purchase
  /// (see the debug screen).
  final EntitlementRepository entitlementRepository;
  final BillingGateway billingGateway;

  /// Overridable for widget tests: `permission_handler`'s
  /// `Permission.notification.status` talks to a real platform channel
  /// that doesn't exist in the widget-test harness (no Flutter SDK/device
  /// in this environment to verify against either) — injecting a fake here
  /// keeps the success/error states genuinely testable without depending
  /// on unverified plugin-channel mocking. Defaults to the real check.
  final Future<ph.PermissionStatus> Function()? checkNotificationPermission;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late Future<ph.PermissionStatus> _permissionStatus = _loadPermissionStatus();

  Future<ph.PermissionStatus> _loadPermissionStatus() {
    final checker = widget.checkNotificationPermission ?? () => ph.Permission.notification.status;
    return checker();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    setState(() => _permissionStatus = _loadPermissionStatus());
    // Cheap and idempotent (see ReconciliationService.reconcile's own doc
    // comment) — fired on every resume/retry rather than only when the
    // status actually changed, since there's no cheaper way to know that
    // without already having done the check.
    unawaited(widget.reconciliationService.reconcile());
  }

  Future<void> _openSystemNotificationSettings() => ph.openAppSettings();

  void _openDebugScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduledStateDebugScreen(
          notificationDao: widget.notificationDao,
          notificationService: widget.notificationService,
        ),
      ),
    );
  }

  /// `kDebugMode`-only — REQ-17.3 ("loss of paid entitlement") is
  /// otherwise genuinely unverifiable in this project without a real Play
  /// Console purchase that then somehow un-verifies itself. This lets a
  /// human (developer or QA) flip the local entitlement flag straight to
  /// `false` and watch the app degrade gracefully — item detail's ladder
  /// track drops to locked markers, Add/Edit's preview drops to one
  /// reminder, the next reconciliation pass cancels the now-ungated
  /// notifications — with **no item data touched**, exactly as REQ-17.3
  /// requires. Never reachable in a release build.
  Future<void> _handleDebugResetEntitlement() async {
    await widget.entitlementRepository.setEntitled(false);
    await widget.reconciliationService.reconcile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entitlement reset — app now renders as free tier (debug only).')),
    );
  }

  void _handlePrivacyPolicyTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("The full privacy policy isn't hosted online yet — this will link out once it is."),
      ),
    );
  }

  void _openPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          billingGateway: widget.billingGateway,
          entitlementRepository: widget.entitlementRepository,
          reconciliationService: widget.reconciliationService,
        ),
      ),
    );
  }

  /// REQ-14.3 — "restore purchase... from paywall **or Settings**." This
  /// deliberately doesn't navigate anywhere: it builds a short-lived
  /// [PaywallController] purely to reuse its restore-with-timeout logic
  /// (see that class's doc comment on why that logic lives there once,
  /// not duplicated here), awaits a settled result, reports it via a
  /// SnackBar, and throws the controller away — Settings has no dedicated
  /// success-state screen mocked for this (only the paywall does), so a
  /// SnackBar is the honest, minimal surface for this entry point.
  Future<void> _handleRestoreFromSettings() async {
    final controller = PaywallController(
      billingGateway: widget.billingGateway,
      entitlementRepository: widget.entitlementRepository,
      reconciliationService: widget.reconciliationService,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for a previous purchase…'), duration: Duration(seconds: 30)),
    );
    final result = await controller.restoreAndAwaitResult();
    controller.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final message = switch (result) {
      PaywallStatus.success => 'Restored — full ladder unlocked.',
      PaywallStatus.error => controller.message ?? "Nothing to restore — you haven't unlocked this on this "
          'Google account yet.',
      PaywallStatus.pending => controller.message ?? 'Purchase pending — check back shortly.',
      _ => "Couldn't check for a previous purchase — try again in a moment.",
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: FutureBuilder<ph.PermissionStatus>(
          future: _permissionStatus,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SettingsErrorView(onRetry: _refresh);
            }
            if (!snapshot.hasData) {
              return const SettingsLoadingView();
            }
            return _SettingsSuccessView(
              permissionStatus: snapshot.data!,
              entitlementRepository: widget.entitlementRepository,
              onOpenNotificationSettings: _openSystemNotificationSettings,
              onOpenDebug: _openDebugScreen,
              onPrivacyPolicyTap: _handlePrivacyPolicyTap,
              onOpenPaywall: _openPaywall,
              onRestorePurchase: _handleRestoreFromSettings,
              onDebugResetEntitlement: _handleDebugResetEntitlement,
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSuccessView extends StatelessWidget {
  const _SettingsSuccessView({
    required this.permissionStatus,
    required this.entitlementRepository,
    required this.onOpenNotificationSettings,
    required this.onOpenDebug,
    required this.onPrivacyPolicyTap,
    required this.onOpenPaywall,
    required this.onRestorePurchase,
    required this.onDebugResetEntitlement,
  });

  final ph.PermissionStatus permissionStatus;
  final EntitlementRepository entitlementRepository;
  final VoidCallback onOpenNotificationSettings;
  final VoidCallback onOpenDebug;
  final VoidCallback onPrivacyPolicyTap;
  final VoidCallback onOpenPaywall;
  final VoidCallback onRestorePurchase;
  final VoidCallback onDebugResetEntitlement;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp4, AppSpacing.sp2, AppSpacing.sp4, AppSpacing.sp7),
      children: [
        const _GroupLabel('Reminders'),
        _SettingsList(
          children: [
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: _notificationStatusLabel(permissionStatus),
              onTap: onOpenNotificationSettings,
            ),
          ],
        ),

        const _GroupLabel('Purchase'),
        StreamBuilder<bool>(
          stream: entitlementRepository.watchEntitled(),
          initialData: false,
          builder: (context, snapshot) {
            final isEntitled = snapshot.data ?? false;
            return _SettingsList(
              children: [
                isEntitled
                    ? const _SettingsTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Full ladder',
                        subtitle: 'Active — every reminder stage, plus overdue follow-through',
                      )
                    : _SettingsTile(
                        icon: Icons.lock_open_outlined,
                        title: 'Unlock full ladder',
                        subtitle: 'One-time purchase — escalating reminders plus overdue follow-through',
                        onTap: onOpenPaywall,
                      ),
                _SettingsTile(
                  icon: Icons.restore_outlined,
                  title: 'Restore purchase',
                  subtitle: 'Already bought this on another device? Restore it here',
                  onTap: onRestorePurchase,
                ),
              ],
            );
          },
        ),

        const _GroupLabel('About'),
        _SettingsList(
          children: [
            const _SettingsTile(icon: Icons.info_outline, title: 'Version', subtitle: kAppVersionLabel),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy policy',
              subtitle: 'Full policy — opens once hosted',
              onTap: onPrivacyPolicyTap,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sp3),
        const _PrivacyCard(),

        const SizedBox(height: AppSpacing.sp5),
        const SettingsDisclaimer(),

        // Task brief item 6: moved from the home app bar's `kDebugMode`
        // bug icon. Still debug-gated — never reachable in a release
        // build.
        if (kDebugMode) ...[
          const _GroupLabel('Debug'),
          _SettingsList(
            children: [
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                title: 'Scheduled state (debug)',
                subtitle: "Diff this app's belief against the OS and the plugin",
                onTap: onOpenDebug,
              ),
              _SettingsTile(
                icon: Icons.money_off_outlined,
                title: 'Reset entitlement (debug)',
                subtitle: 'Exercise REQ-17.3 (loss of entitlement) without a real purchase',
                onTap: onDebugResetEntitlement,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// `PermissionStatus.provisional`/`limited` are iOS-only concepts in
  /// practice, but `permission_handler`'s enum is cross-platform — handled
  /// here rather than assumed unreachable, so this `switch` stays
  /// exhaustive without a `default` swallowing a real future case.
  static String _notificationStatusLabel(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
      case ph.PermissionStatus.provisional:
        return 'On — manage in system settings';
      case ph.PermissionStatus.denied:
      case ph.PermissionStatus.permanentlyDenied:
        return 'Off — tap to turn it back on';
      case ph.PermissionStatus.restricted:
        return 'Restricted by your device';
      case ph.PermissionStatus.limited:
        return 'Limited — manage in system settings';
    }
  }
}

/// Hardcoded to match `pubspec.yaml`'s `version:` field rather than reading
/// it dynamically — this project has no `package_info_plus` (or
/// equivalent) dependency yet. A future slice should replace this with a
/// real runtime read so it can't drift from the actual shipped build;
/// flagged explicitly in the developer handoff rather than silently
/// treated as done.
const String kAppVersionLabel = '1.0.0';

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sp5, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .4, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShapes.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// REQ-15.2 — local-only storage guarantee, with the scoped exception for
/// Play Billing's purchase-verification call the technical ADR (§5) and
/// BA's revision both require: a bare "never leaves your phone" claim
/// would no longer be literally true once the paywall ships, so this card
/// states the one exception explicitly rather than silently staying wrong
/// once billing lands. Wording follows `docs/legal/privacy-policy.md`'s
/// own short-version framing, per REQ-15.2's stated source. Uses the
/// `success` semantic role (design doc §7) — matches
/// `06-settings-privacy.html`'s `.privacy-card` (`--md-success-container`),
/// not a bespoke color.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: semantic.successContainer,
        borderRadius: BorderRadius.circular(AppShapes.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: semantic.onSuccessContainer, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything stays on this device',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: semantic.onSuccessContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  'No account, no cloud, no sync. Your renewal dates and notes never leave your phone — the one '
                  "exception is a purchase check with Google Play if you buy the unlock, which doesn't include any "
                  'of your renewal data.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: semantic.onSuccessContainer),
                ),
                const SizedBox(height: 6),
                Text(
                  'Full policy: $kPrivacyPolicyUrl (not yet hosted)',
                  style: TextStyle(fontSize: 11, color: semantic.onSuccessContainer.withValues(alpha: .8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
