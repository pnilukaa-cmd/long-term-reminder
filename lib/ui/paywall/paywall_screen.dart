import 'package:flutter/material.dart';

import '../../data/repository/entitlement_repository.dart';
import '../../services/billing/billing_gateway.dart';
import '../../services/billing/paywall_controller.dart';
import '../../services/notifications/reconciliation_service.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_semantic_colors.dart';

/// REQ-14 — the paywall/one-time-unlock screen, matching
/// `docs/design/mockups/04-paywall.html`'s four mocked states (default,
/// loading, error, success) plus the three more real billing states the
/// developer task brief calls out explicitly (unavailable, pending,
/// cancelled) so a purchase attempt never silently does nothing. All
/// state logic lives in [PaywallController] — this widget is a pure
/// render of [PaywallController.status].
///
/// Reachable from: item detail's inline unlock banner (REQ-3.2, the
/// primary route — design doc §5's "the pitch already happened on the
/// ladder track"), and Settings' "Unlock full ladder" tile when not yet
/// entitled.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.billingGateway,
    required this.entitlementRepository,
    required this.reconciliationService,
  });

  final BillingGateway billingGateway;
  final EntitlementRepository entitlementRepository;
  final ReconciliationService reconciliationService;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final PaywallController _controller = PaywallController(
    billingGateway: widget.billingGateway,
    entitlementRepository: widget.entitlementRepository,
    reconciliationService: widget.reconciliationService,
  )..addListener(_onControllerChanged);

  @override
  void initState() {
    super.initState();
    // billingGateway.init() is idempotent (see NotificationService.init's
    // same pattern) — safe even though app.dart already calls it once at
    // startup; cheap insurance against this screen ever being reachable
    // before that has happened.
    widget.billingGateway.init().then((_) => _controller.load());
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: switch (_controller.status) {
          PaywallStatus.loading => const _LoadingView(),
          PaywallStatus.unavailable => _MessageView(
              icon: Icons.cloud_off_outlined,
              message: _controller.message ?? "In-app purchases aren't available right now.",
              primaryLabel: 'Try again',
              onPrimary: _controller.load,
            ),
          PaywallStatus.ready || PaywallStatus.busy || PaywallStatus.cancelled => _DefaultView(
              controller: _controller,
              busy: _controller.status == PaywallStatus.busy,
              cancelledMessage: _controller.status == PaywallStatus.cancelled ? _controller.message : null,
              onUnlock: _controller.buy,
              onRestore: _controller.restore,
            ),
          PaywallStatus.pending => _MessageView(
              icon: Icons.hourglass_top_outlined,
              message: _controller.message ?? 'Purchase pending — this can take a little while to clear.',
              primaryLabel: 'Back to your renewals',
              onPrimary: () => Navigator.of(context).pop(),
            ),
          PaywallStatus.error => _ErrorView(
              message: _controller.message ?? "Purchase didn't go through — you haven't been charged.",
              onTryAgain: _controller.buy,
              onRestore: _controller.restore,
            ),
          PaywallStatus.success => _SuccessView(alreadyOwned: _controller.alreadyOwned),
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sp5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _skeleton(context, height: 64, width: 64, radius: AppShapes.xl, center: true),
          const SizedBox(height: AppSpacing.sp4),
          _skeleton(context, height: 24, width: 180, radius: AppShapes.sm, center: true),
          const SizedBox(height: AppSpacing.sp4),
          _skeleton(context, height: 150, radius: AppShapes.lg),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.outline)),
              const SizedBox(width: 10),
              Text('Checking billing…', style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.sp4),
        ],
      ),
    );
  }

  Widget _skeleton(BuildContext context, {double? width, required double height, required double radius, bool center = false}) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(radius)),
    );
    return center ? Center(child: box) : box;
  }
}

/// REQ-14.1's default panel (p1) — the comparison list, price, primary
/// unlock button, and Restore purchase. Also covers [PaywallStatus.busy]
/// (button swaps to a spinner, everything else stays put — same "dim +
/// disable, don't replace the whole screen" pattern `AddEditScreen`
/// already uses for its own Saving state) and [PaywallStatus.cancelled]
/// (a light, non-alarming inline note — deliberately *not* the loud
/// error-container treatment, since a deliberate cancel isn't a failure;
/// see `PaywallController`'s class doc).
class _DefaultView extends StatelessWidget {
  const _DefaultView({
    required this.controller,
    required this.busy,
    required this.cancelledMessage,
    required this.onUnlock,
    required this.onRestore,
  });

  final PaywallController controller;
  final bool busy;
  final String? cancelledMessage;
  final VoidCallback onUnlock;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final price = controller.product?.formattedPrice ?? '\$3.99';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sp5, 0, AppSpacing.sp5, AppSpacing.sp5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(AppShapes.xl)),
              child: Icon(Icons.lock_open_outlined, color: scheme.onPrimaryContainer, size: 30),
            ),
          ),
          Text('Unlock the full ladder', textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'One payment. Every item, every type, forever.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sp5),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sp4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppShapes.lg),
            ),
            child: Column(
              children: const [
                _CompareRow(have: true, title: 'Unlimited items, all 7 types', subtitle: 'Already yours — free, no change'),
                _CompareRow(have: false, title: 'Full multi-stage ladder', subtitle: 'Type-aware, up to 4 reminders instead of 1'),
                _CompareRow(have: false, title: 'Overdue follow-through', subtitle: 'We check in if a renewal passes unmarked'),
                _CompareRow(
                  have: false,
                  title: "Full ladder for every Custom lead-time choice",
                  subtitle: 'Short/Medium/Long — free plan still gets one reminder either way',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sp5),
          if (cancelledMessage != null) ...[
            _InlineNote(message: cancelledMessage!),
            const SizedBox(height: AppSpacing.sp3),
          ],
          Text(price, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Not a subscription — pay once, keep it. Restorable if you change devices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sp4),
          FilledButton(
            onPressed: busy ? null : onUnlock,
            child: busy
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Processing…'),
                    ],
                  )
                : Text('Unlock for $price'),
          ),
          TextButton(onPressed: busy ? null : onRestore, child: const Text('Restore purchase')),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.have, required this.title, required this.subtitle});

  final bool have;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(have ? Icons.check_circle : Icons.lock_outline, size: 18, color: have ? semantic.success : scheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppShapes.md)),
      child: Text(message, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
    );
  }
}

/// REQ-14.1's error panel (p3) — purchase failed. Distinct from
/// [_MessageView]'s `unavailable` treatment: this one explicitly
/// reassures "you haven't been charged" (per the mockup's exact copy) and
/// keeps both recovery actions (Try again / Restore purchase) available,
/// since an error here means an actual attempt was made.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onTryAgain, required this.onRestore});

  final String message;
  final VoidCallback onTryAgain;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sp5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(AppShapes.md)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer, fontSize: 12.5))),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sp5),
          FilledButton(onPressed: onTryAgain, child: const Text('Try again')),
          TextButton(onPressed: onRestore, child: const Text('Restore purchase')),
        ],
      ),
    );
  }
}

/// Shared shape for the two non-mocked-but-required states: `unavailable`
/// and `pending`. Neither is the loud red error-container treatment
/// (billing being unavailable, or a purchase still clearing, isn't the
/// same failure as a rejected charge) — a neutral card instead.
class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.message, required this.primaryLabel, required this.onPrimary});

  final IconData icon;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sp5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sp4),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: AppSpacing.sp5),
          FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
        ],
      ),
    );
  }
}

/// REQ-14.1's success panel (p4).
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.alreadyOwned});

  final bool alreadyOwned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sp5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: semantic.successContainer, shape: BoxShape.circle),
            child: Icon(Icons.check, color: semantic.onSuccessContainer, size: 34),
          ),
          const SizedBox(height: AppSpacing.sp4),
          Text(alreadyOwned ? "You're already unlocked" : "You're set", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            alreadyOwned
                ? 'Full ladder unlocked for every item on this device.'
                : 'Full ladder unlocked for every item — the extra stages on your existing renewals are '
                    'scheduling now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sp5),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to your renewals'),
          ),
        ],
      ),
    );
  }
}
