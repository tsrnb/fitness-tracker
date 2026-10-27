import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/app_state.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import 'google_button.dart';
import 'landing_collage.dart';


Widget _eyebrow(String s) => Text(s, style: mono(fontSize: 11, color: T.muted).copyWith(letterSpacing: 1.4));

Widget _avatar(String name, {double size = 44, Color? color}) {
  final c = color ?? T.accent;
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: c.withValues(alpha: 0.16), shape: BoxShape.circle),
    child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(color: c, fontSize: size * 0.4, fontWeight: FontWeight.w800)),
  );
}

Widget _card({required Widget child, Color? border}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: T.surface, border: Border.all(color: border ?? T.line), borderRadius: BorderRadius.circular(T.rL)),
      child: child,
    );

Widget _page({required List<Widget> top, Widget? bottom}) => Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...top, if (bottom != null) bottom]),
            ),
          ),
        ),
      ),
    );

Widget _brand() => Row(children: [
      Container(width: 10, height: 10, decoration: const BoxDecoration(color: T.accent, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('CutTracker', style: Type.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
    ]);

Widget _emailChip(String email) => Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _avatar(email, size: 28),
        const SizedBox(width: 10),
        Text(email, style: Type.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );

/// Landing page (new user), "we found your data" gate (existing on-device
/// profiles) and "sign in again" gate (session ended) — one screen, three wordings.
/// The landing wording also has a tablet and a desktop layout; the other two
/// stay in the centered phone-width column everywhere.
class AuthGateScreen extends StatelessWidget {
  final AuthGateMode mode;
  final List<SimpleUser> localUsers;
  final String? email;
  final bool offline;
  final String? error;
  final void Function(String idToken) onToken;
  final void Function(String message) onError;
  final VoidCallback onRetry;

  const AuthGateScreen({
    super.key,
    required this.mode,
    required this.localUsers,
    required this.email,
    required this.offline,
    required this.error,
    required this.onToken,
    required this.onError,
    required this.onRetry,
  });

  (String, String, String) get _copy => switch (mode) {
        AuthGateMode.landing => ('WELCOME', 'Your cut, safe on every device.', 'Sign in to keep your logs in your account and pick up where you left off on any phone.'),
        AuthGateMode.found => ('ON THIS DEVICE', 'We found your data.', "Save it to your Google account so it's backed up and follows you to any device."),
        AuthGateMode.expired => ('SESSION ENDED', 'Sign in again.', 'Your data is safe in your account. Sign in to pick up where you left off.'),
      };

  String get _footnote => switch (mode) {
        AuthGateMode.found => 'Nothing is deleted from this device until it is safely in your account.',
        AuthGateMode.expired => 'Use ${email ?? 'the same Google account'} to get back to your data.',
        _ => 'By continuing you agree to the Terms and Privacy Policy.',
      };

  /// The offline / error card, when there is something to say.
  Widget? _notice() {
    if (!offline && error == null) return null;
    return _card(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline, size: 20, color: T.danger),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(offline ? "You're offline" : 'Something went wrong', style: Type.h3),
            const SizedBox(height: 2),
            Text(offline ? 'CutTracker needs an internet connection to sign you in and load your data.' : error!, style: Type.caption),
          ]),
        ),
      ]),
    );
  }

  /// The sign-in button (or "Try again" when offline) and the footnote under it.
  Widget _action() {
    return Column(children: [
      if (offline)
        PrimaryButton(onTap: onRetry, child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.refresh, size: 18), SizedBox(width: 10), Text('Try again')]))
      else
        GoogleSignInButton(onToken: onToken, onError: onError),
      const SizedBox(height: 16),
      Text(_footnote, textAlign: TextAlign.center, style: Type.caption),
    ]);
  }

  /// Eyebrow, headline, body, then the notice and action — shared by the wide layouts.
  Widget _block({required double titleSize, required double gap}) {
    final (eyebrow, title, body) = _copy;
    final notice = _notice();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow(eyebrow),
      const SizedBox(height: 12),
      Text(title, style: Type.display.copyWith(fontSize: titleSize)),
      const SizedBox(height: 12),
      Text(body, style: Type.body.copyWith(color: T.muted)),
      SizedBox(height: gap),
      if (notice != null) ...[notice, const SizedBox(height: 16)],
      _action(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (mode == AuthGateMode.landing) {
        final w = c.maxWidth, h = c.maxHeight;
        if (w >= 1100 || (w >= 900 && w / h > 1.25)) return _desktop(w);
        if (w >= 720) return _tablet();
      }
      return _phone();
    });
  }

  /// Desktop: brand panel with the product collage on the left, sign-in on the right.
  Widget _desktop(double width) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Row(children: [
        Container(
          width: (width * 0.56).clamp(560.0, 720.0),
          padding: const EdgeInsets.fromLTRB(40, 48, 40, 48),
          decoration: BoxDecoration(color: T.surface, border: Border(right: BorderSide(color: T.line))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 8), child: _brand()),
            const Expanded(child: Center(child: LandingCollage())),
          ]),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: _block(titleSize: 40, gap: 36)),
            ),
          ),
        ),
      ]),
    );
  }

  /// Tablet: one column, the collage above a rounded sign-in card.
  Widget _tablet() {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
              child: Column(children: [
                Align(alignment: Alignment.centerLeft, child: _brand()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 544), child: const LandingCollage())),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rXL)),
                    child: _block(titleSize: 34, gap: 28),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phone() {
    final landing = mode == AuthGateMode.landing;
    final (eyebrow, title, body) = _copy;
    final notice = _notice();
    return _page(
      top: [
        _brand(),
        if (landing) ...[
          const Expanded(child: Center(child: AnimatedRings())),
        ] else ...[
          const SizedBox(height: 40),
        ],
        _eyebrow(eyebrow),
        const SizedBox(height: 10),
        Text(title, style: Type.display),
        const SizedBox(height: 10),
        Text(body, style: Type.body.copyWith(color: T.muted)),
        if (mode == AuthGateMode.found) ...[
          const SizedBox(height: 28),
          for (final u in localUsers) ...[
            _card(child: Row(children: [_avatar(u.name), const SizedBox(width: 14), Text(u.name, style: Type.h3)])),
            const SizedBox(height: 10),
          ],
        ],
        if (mode == AuthGateMode.expired && email != null) ...[
          const SizedBox(height: 24),
          _emailChip(email!),
        ],
        if (!landing) const Spacer(),
        if (landing) const SizedBox(height: 28),
        if (notice != null) ...[notice, const SizedBox(height: 16)],
      ],
      bottom: _action(),
    );
  }
}

/// The landing page's three progress rings, drawn in one after another.
class AnimatedRings extends StatefulWidget {
  const AnimatedRings({super.key});

  @override
  State<AnimatedRings> createState() => _AnimatedRingsState();
}

class _AnimatedRingsState extends State<AnimatedRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2050));

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _stagger(double start) => Curves.easeOutCubic.transform(((_c.value * 2050 - start) / 1400).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: const Size(236, 236),
        painter: _RingsPainter([_stagger(150), _stagger(400), _stagger(650)]),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<double> t;
  _RingsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const radii = [100.0, 74.0, 48.0];
    const fills = [0.72, 0.71, 0.85];
    final colors = [T.accent, T.lav, const Color(0xFF7FCB86)];
    for (var i = 0; i < 3; i++) {
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = T.surface2;
      canvas.drawCircle(c, radii[i], track);
      final sweep = 2 * math.pi * fills[i] * t[i];
      if (sweep > 0.02) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: radii[i]),
          -math.pi / 2,
          sweep,
          false,
          track
            ..strokeCap = StrokeCap.round
            ..color = colors[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.t[0] != t[0] || old.t[1] != t[1] || old.t[2] != t[2];
}

/// Moves on-device profiles into the account (one-time).
class MigrationScreen extends StatelessWidget {
  final String? email;
  final List<SimpleUser> users;
  final Set<int> doneIds;
  final bool finished;
  final String? error;
  final VoidCallback onContinue;
  final VoidCallback onRetry;

  const MigrationScreen({super.key, required this.email, required this.users, required this.doneIds, required this.finished, required this.error, required this.onContinue, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final nextId = users.where((u) => !doneIds.contains(u.id)).map((u) => u.id).firstOrNull;
    return _page(
      top: [
        if (email != null) _emailChip(email!),
        const SizedBox(height: 40),
        _eyebrow(finished ? 'DONE' : 'SAVING'),
        const SizedBox(height: 10),
        Text(finished ? 'Saved to your account.' : 'Saving to your account.', style: Type.display),
        const SizedBox(height: 10),
        Text(finished ? 'Your profiles now follow you to any device.' : 'This is a one-time move. Keep the app open until it finishes.', style: Type.body.copyWith(color: T.muted)),
        const SizedBox(height: 32),
        for (final u in users) ...[
          _card(
            child: Row(children: [
              _avatar(u.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: Type.h3),
                  Text(
                    doneIds.contains(u.id) ? 'Saved' : (u.id == nextId && error == null ? 'Uploading…' : 'Waiting'),
                    style: Type.caption.copyWith(color: doneIds.contains(u.id) ? T.success : T.muted),
                  ),
                ]),
              ),
              if (doneIds.contains(u.id))
                Icon(Icons.check_circle, color: T.success, size: 24)
              else if (u.id == nextId && error == null)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: T.accent)),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: Type.caption.copyWith(color: T.danger))),
        const Spacer(),
      ],
      bottom: error != null
          ? PrimaryButton(onTap: onRetry, child: const Text('Try again'))
          : PrimaryButton(opacity: finished ? 1 : 0.4, onTap: finished ? onContinue : null, child: const Text('Continue')),
    );
  }
}

/// The account already has profiles and this device has some too.
class ConflictScreen extends StatefulWidget {
  final String? email;
  final int cloudCount;
  final List<SimpleUser> localUsers;
  final void Function(bool add) onChoose;
  const ConflictScreen({super.key, required this.email, required this.cloudCount, required this.localUsers, required this.onChoose});

  @override
  State<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<ConflictScreen> {
  bool _add = true;

  Widget _option(bool add, String title, String sub) {
    final on = _add == add;
    return GestureDetector(
      onTap: () => setState(() => _add = add),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: on ? T.accentDim : T.surface,
          border: Border.all(color: on ? T.accent : T.line),
          borderRadius: BorderRadius.circular(T.rL),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? T.accent : T.faint, width: 2)),
            child: on ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: T.accent, shape: BoxShape.circle)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Type.h3), const SizedBox(height: 4), Text(sub, style: Type.caption)])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.localUsers.map((u) => u.name).join(' and ');
    return _page(
      top: [
        if (widget.email != null) _emailChip(widget.email!),
        const SizedBox(height: 40),
        _eyebrow('HEADS UP'),
        const SizedBox(height: 10),
        Text('This account already has data.', style: Type.display),
        const SizedBox(height: 10),
        Text('Your account has ${widget.cloudCount} saved profile${widget.cloudCount == 1 ? '' : 's'}. This device has ${widget.localUsers.length}. Choose what to keep.', style: Type.body.copyWith(color: T.muted)),
        const SizedBox(height: 28),
        _option(true, "Add this device's profiles", 'Keeps everything. $names are saved next to the profiles already in your account.'),
        _option(false, "Use my account's data", "Replaces what's on this device with your saved profiles. $names are removed from this device."),
        const Spacer(),
      ],
      bottom: PrimaryButton(onTap: () => widget.onChoose(_add), child: Text(_add ? 'Save and continue' : 'Replace and continue')),
    );
  }
}

/// Shown for a moment after sign-in while the account's profiles load: four
/// steps tick through (the third with a progress bar), then the button
/// lights up as the app opens. The app holds this screen for [totalMs].
class RestoreScreen extends StatefulWidget {
  /// How long the checklist takes to run; the controller holds the screen at least this long.
  static const totalMs = 2300;

  final String? email;
  const RestoreScreen({super.key, required this.email});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: RestoreScreen.totalMs));

  // (title, start ms, end ms, shows a progress bar while active)
  static const _steps = [
    ('Profile and settings', 0, 500, false),
    ('Food library', 500, 1000, false),
    ('Logs and training history', 1000, 1800, true),
    ('Calibration and muscle data', 1800, 2200, false),
  ];

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _icon(int state) {
    // 0 pending, 1 active, 2 done
    return switch (state) {
      2 => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: T.success.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(Icons.check, size: 16, color: T.success),
        ),
      1 => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: T.accentDim, shape: BoxShape.circle),
          child: const Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2.2, color: T.accent)),
        ),
      _ => Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: T.line, width: 2))),
    };
  }

  Widget _row(int i, double ms) {
    final (title, start, end, bar) = _steps[i];
    final state = ms >= end ? 2 : (ms >= start ? 1 : 0);
    final pct = ((ms - start) / (end - start)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(children: [
        Row(children: [
          _icon(state),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: Type.h3.copyWith(color: state == 0 ? T.muted : T.text))),
          if (bar && state == 1) Text('${(pct * 100).round()}%', style: mono(fontSize: 12, color: T.accent)),
        ]),
        if (bar && state == 1) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(T.pill),
            child: SizedBox(
              height: 6,
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: T.surface2)),
                Positioned.fill(
                  child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: pct, child: const ColoredBox(color: T.accent)),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final ms = _c.value * RestoreScreen.totalMs;
        final ready = ms >= 2200;
        final checklist = Container(
          decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rL)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: T.line),
              _row(i, ms),
            ],
          ]),
        );
        final button = PrimaryButton(opacity: ready ? 1 : 0.4, onTap: null, child: const Text('Open CutTracker'));
        Widget heading(double titleSize) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _eyebrow('SIGNED IN'),
              const SizedBox(height: 10),
              Text('Welcome back.', style: Type.display.copyWith(fontSize: titleSize)),
              const SizedBox(height: 10),
              Text('Restoring your profiles from your account. Keep the app open.', style: Type.body.copyWith(color: T.muted)),
            ]);

        // Tablet and desktop: brand top-left, one centered card.
        if (MediaQuery.sizeOf(context).width >= 720) {
          return Scaffold(
            backgroundColor: T.bg,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
                child: Column(children: [
                  Align(alignment: Alignment.centerLeft, child: _brand()),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Container(
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rXL)),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (widget.email != null) ...[_emailChip(widget.email!), const SizedBox(height: 28)],
                              heading(34),
                              const SizedBox(height: 28),
                              checklist,
                              const SizedBox(height: 28),
                              button,
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }

        return _page(
          top: [
            if (widget.email != null) _emailChip(widget.email!),
            const SizedBox(height: 40),
            heading(Type.display.fontSize ?? 30),
            const SizedBox(height: 32),
            checklist,
            const Spacer(),
          ],
          bottom: button,
        );
      },
    );
  }
}

/// Settings > Account.
class AccountScreen extends StatelessWidget {
  final AppState app;
  final AppController controller;
  const AccountScreen({super.key, required this.app, required this.controller});

  Future<void> _delete(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXL))),
      builder: (_) => const _DeleteSheet(),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      await controller.deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = app.email ?? '';
    return pageScaffold(
      context: context,
      title: 'Account',
      onBack: () => Navigator.of(context).pop(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _card(
          child: Row(children: [
            _avatar(email, size: 52),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(email, style: Type.h3), Text('Google account', style: Type.caption)])),
          ]),
        ),
        const SizedBox(height: 14),
        _card(child: Row(children: [Expanded(child: Text('Profiles in this account', style: Type.h3)), Text('${app.users.length}', style: mono(fontSize: 12, color: T.muted))])),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
            await controller.signOut();
          },
          child: _card(child: Row(children: [Expanded(child: Text('Sign out', style: Type.h3)), Icon(Icons.logout, size: 18, color: T.muted)])),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(6, 10, 6, 0), child: Text('Your data stays in your account. Signing out only clears this device.', style: Type.caption)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => _delete(context),
          child: _card(child: Row(children: [Expanded(child: Text('Delete account', style: Type.h3.copyWith(color: T.danger))), Icon(Icons.chevron_right, size: 20, color: T.danger)])),
        ),
      ]),
    );
  }
}

class _DeleteSheet extends StatefulWidget {
  const _DeleteSheet();

  @override
  State<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends State<_DeleteSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _c.text.trim().toUpperCase() == 'DELETE';
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: T.danger.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(Icons.delete_outline, color: T.danger),
        ),
        const SizedBox(height: 16),
        Text('Delete your account?', style: Type.h1),
        const SizedBox(height: 8),
        Text("This permanently deletes all profiles, logs and photos saved to your account and signs you out. It can't be undone.", style: Type.body.copyWith(color: T.muted)),
        const SizedBox(height: 20),
        _eyebrow('TYPE DELETE TO CONFIRM'),
        const SizedBox(height: 8),
        TextField(
          controller: _c,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: T.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(T.pill), borderSide: BorderSide(color: T.line)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: ok ? () => Navigator.of(context).pop(true) : null,
          child: Opacity(
            opacity: ok ? 1 : 0.4,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: T.danger, borderRadius: BorderRadius.circular(T.pill)),
              child: const Text('Delete account', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: Type.h3)),
      ]),
    );
  }
}
