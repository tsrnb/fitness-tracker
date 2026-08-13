import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';
import 'switch_profile_screen.dart';

/// Profile list page — switch-on-tap with active-highlighting, an "Add
/// profile" action, and a per-row delete. Switching user, deleting the
/// active profile, or starting a new one all change what's mounted
/// underneath the whole Settings page, so those actions pop the entire
/// Settings page (root navigator) rather than just this sub-page. Deleting
/// an *inactive* profile is the one exception — nothing on screen depends
/// on that profile's data, so it just drops out of this page's own list.
class ProfilesPage extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const ProfilesPage({super.key, required this.app, required this.controller});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final List<SimpleUser> _users = [];

  @override
  void initState() {
    super.initState();
    _users.addAll(widget.app.users);
  }

  Future<void> _switchTo(int id, String name) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    // The switch animation runs on top of Settings (covering it), does the
    // actual reload itself, then pops itself once it's done — only then do
    // we pop Settings too, landing on the dashboard with the new profile
    // already loaded instead of snapping to it mid-fetch.
    await rootNav.push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => SwitchProfileScreen(toName: name, onSwitch: () => widget.controller.switchUser(id)),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
    if (mounted) rootNav.pop();
  }

  Future<bool> _confirmDelete(SimpleUser u, {required bool isLastProfile}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.surface,
        title: Text('Delete ${u.name}\'s profile?', style: TextStyle(color: T.text)),
        content: Text(
          isLastProfile
              ? "This is your only profile — deleting it erases all their workouts, diet log, and settings, and takes you back to setup. This can't be undone."
              : "This permanently erases ${u.name}'s workouts, diet log, and settings. This can't be undone.",
          style: TextStyle(color: T.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: TextStyle(color: T.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Delete', style: TextStyle(color: T.danger, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _delete(SimpleUser u) async {
    final isActive = u.id == widget.app.user!.id;
    if (!await _confirmDelete(u, isLastProfile: isActive && _users.length == 1)) return;
    if (!isActive) {
      // Someone else's data — safe to just delete in place and drop the row.
      await widget.controller.deleteUser(u.id);
      if (mounted) setState(() => _users.removeWhere((x) => x.id == u.id));
      return;
    }
    final remaining = _users.where((x) => x.id != u.id).toList();
    if (remaining.isEmpty) {
      // Deleting the only profile — no "switching to" target, just wipe and
      // let the root screen pick up AppView.onboarding once Settings closes.
      await widget.controller.deleteUser(u.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    // Deleting the active profile with others left — same reload-then-pop
    // shape as a normal switch, except AppController.deleteUser does both
    // the deletion and the reload to `remaining.first` in one call.
    final next = remaining.first;
    final rootNav = Navigator.of(context, rootNavigator: true);
    await rootNav.push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => SwitchProfileScreen(toName: next.name, onSwitch: () => widget.controller.deleteUser(u.id)),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
    if (mounted) rootNav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return pageScaffold(
      context: context,
      title: 'Profiles',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._users.map((u) {
            final active = u.id == widget.app.user!.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: active ? null : () => _switchTo(u.id, u.name),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: active ? T.accentDim : T.surface2,
                    border: Border.all(color: active ? T.hero : T.line),
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                  child: Row(children: [
                    IconBubble(icon: Icon(Icons.person, size: 16, color: active ? Colors.white : T.muted), size: 32, background: active ? T.hero : T.surface),
                    const SizedBox(width: 10),
                    Expanded(child: Text(u.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: T.text))),
                    if (active) Padding(padding: const EdgeInsets.only(right: 8), child: Text('active', style: mono(fontSize: 11, color: T.hero))),
                    if (!active) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.chevron_right, size: 16, color: T.faint)),
                    // Own GestureDetector so the tap doesn't fall through to
                    // the row's switch-profile tap behind it.
                    GestureDetector(
                      onTap: () => _delete(u),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.delete_outline, size: 18, color: T.faint),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              widget.controller.beginCreate();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.pill), border: Border.all(color: T.line)),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 16, color: T.hero),
                const SizedBox(width: 8),
                Text('Add profile', style: TextStyle(color: T.hero, fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
