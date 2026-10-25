import 'package:flutter/material.dart';
import 'theme.dart';

/// Width classes for the web build. Phones keep the original layout; wider
/// windows center and cap the content, and desktop swaps the floating pill nav
/// for a sidebar.
enum ScreenClass { phone, tablet, desktop }

class Responsive {
  static const tabletMin = 640.0;
  static const desktopMin = 1024.0;

  /// Content width from which tab bodies switch to two columns.
  static const wideContent = 720.0;

  static ScreenClass of(double width) {
    if (width >= desktopMin) return ScreenClass.desktop;
    if (width >= tabletMin) return ScreenClass.tablet;
    return ScreenClass.phone;
  }
}

/// Centers [child] and caps it at [maxWidth]. Under the cap it is a no-op, so
/// phone layouts are untouched.
class ContentColumn extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const ContentColumn({super.key, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

/// Page route for every pushed screen (Settings, Plan, Calibration, chats…).
/// On tablet and desktop windows the screen slides in as a right-hand panel
/// over a dimmed backdrop; on a phone it is the normal full-screen page.
class AppRoute<R> extends PageRoute<R> {
  AppRoute({required this.builder, super.settings, super.fullscreenDialog}) : _panel = _windowIsWide();

  final WidgetBuilder builder;
  final bool _panel;

  static const panelWidth = 520.0;

  static bool _windowIsWide() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize.width / view.devicePixelRatio >= Responsive.tabletMin;
  }

  // A panel leaves the page underneath visible; a phone page covers it.
  @override
  bool get opaque => !_panel;
  @override
  bool get barrierDismissible => false;
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    if (!_panel) return builder(context);
    final mq = MediaQuery.of(context);
    final w = panelWidth.clamp(0.0, mq.size.width).toDouble();
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: T.bg,
        clipBehavior: Clip.antiAlias,
        elevation: 12,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(T.rXL))),
        // Descendants that size themselves from MediaQuery see the panel, not the window.
        child: MediaQuery(
          data: mq.copyWith(size: Size(w, mq.size.height)),
          child: SizedBox(width: w, height: double.infinity, child: builder(context)),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (!_panel) return Theme.of(context).pageTransitionsTheme.buildTransitions<R>(this, context, animation, secondaryAnimation, child);
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return Stack(
      children: [
        FadeTransition(
          opacity: curved,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.5), child: const SizedBox.expand()),
          ),
        ),
        SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved), child: child),
      ],
    );
  }
}

/// Two side-by-side columns for tab bodies once there is room (see
/// [Responsive.wideContent]); callers fall back to a single stack otherwise.
class TwoPane extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;
  final double gap;
  const TwoPane({super.key, required this.left, required this.right, this.gap = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
        SizedBox(width: gap),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
      ],
    );
  }
}

/// Lays [cards] out in two equal columns when [wide]; otherwise returns them
/// unchanged. [width] is the width available to the cards.
List<Widget> splitColumns(bool wide, double width, List<Widget> cards, {double gap = 12}) {
  if (!wide) return cards;
  return [
    Wrap(
      spacing: gap,
      children: [for (final c in cards) SizedBox(width: (width - gap) / 2, child: c)],
    ),
  ];
}

/// Tablet and desktop windows get sheets and chat screens as a right-hand
/// panel instead of a bottom sheet or a full page.
bool useSidePanel(BuildContext context) => MediaQuery.sizeOf(context).width >= Responsive.tabletMin;

/// Slides [builder]'s content in from the right over a dimmed backdrop. Tapping
/// the backdrop or popping the route closes it.
Future<R?> showSidePanel<R>(BuildContext context, {required WidgetBuilder builder, double width = 460}) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, __) {
      final w = width.clamp(0.0, MediaQuery.sizeOf(ctx).width).toDouble();
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: T.surface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(T.rXL))),
          elevation: 12,
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(size: Size(w, MediaQuery.sizeOf(ctx).height)),
            child: SizedBox(width: w, height: double.infinity, child: builder(ctx)),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
      child: child,
    ),
  );
}

/// Pushes [builder]'s screen; [AppRoute] shows it as a right-hand panel on wide windows.
Future<R?> pushPanelOrPage<R>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push<R>(AppRoute<R>(builder: builder));
