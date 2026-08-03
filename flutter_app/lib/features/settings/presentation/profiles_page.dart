import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';
import 'switch_profile_screen.dart';

/// Profile list page — switch-on-tap with active-highlighting, and an "Add
/// profile" action. Switching user or starting a new profile changes what's
/// mounted underneath the whole Settings page, so those two actions pop the
/// entire Settings page (root navigator) rather than just this sub-page.
class ProfilesPage extends StatelessWidget {
  final AppState app;
  final AppController controller;
  const ProfilesPage({super.key, required this.app, required this.controller});

  Future<void> _switchTo(BuildContext context, int id, String name) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    // The switch animation runs on top of Settings (covering it), does the
    // actual reload itself, then pops itself once it's done — only then do
    // we pop Settings too, landing on the dashboard with the new profile
    // already loaded instead of snapping to it mid-fetch.
    await rootNav.push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => SwitchProfileScreen(toName: name, onSwitch: () => controller.switchUser(id)),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
    if (context.mounted) rootNav.pop();
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
          ...app.users.map((u) {
            final active = u.id == app.user!.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: active ? null : () => _switchTo(context, u.id, u.name),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                  decoration: BoxDecoration(
                    color: active ? T.accentDim : T.surface2,
                    border: Border.all(color: active ? T.hero : T.line),
                    borderRadius: BorderRadius.circular(T.pill),
                  ),
                  child: Row(children: [
                    IconBubble(icon: Icon(Icons.person, size: 16, color: active ? Colors.white : T.muted), size: 32, background: active ? T.hero : T.surface),
                    const SizedBox(width: 10),
                    Expanded(child: Text(u.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: T.text))),
                    active ? Text('active', style: mono(fontSize: 11, color: T.hero)) : Icon(Icons.chevron_right, size: 16, color: T.faint),
                  ]),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              controller.beginCreate();
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
