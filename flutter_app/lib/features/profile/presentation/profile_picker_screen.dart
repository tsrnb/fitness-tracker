import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../app/app_state.dart';

class ProfilePickerScreen extends StatelessWidget {
  final List<SimpleUser> users;
  final ValueChanged<int> onPick;
  final VoidCallback onCreate;
  const ProfilePickerScreen({super.key, required this.users, required this.onPick, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 40, 18, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBubble(icon: Icon(Icons.fitness_center, size: 22, color: Colors.white), size: 44, background: T.hero),
              const SizedBox(height: 18),
              Text("Who's training?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: T.text)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text('Pick a profile on this device, or add a new one.', style: TextStyle(color: T.muted, fontSize: 14)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ...users.map((u) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => onPick(u.id),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.rL)),
                              child: Row(
                                children: [
                                  const IconBubble(icon: Icon(Icons.person, size: 22, color: T.hero), size: 44, background: T.accentDim),
                                  const SizedBox(width: 14),
                                  Expanded(child: Text(u.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: T.text))),
                                  Icon(Icons.chevron_right, size: 20, color: T.faint),
                                ],
                              ),
                            ),
                          ),
                        )),
                    GestureDetector(
                      onTap: onCreate,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.rL), border: Border.all(color: T.line, style: BorderStyle.solid)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 18, color: T.hero),
                            SizedBox(width: 10),
                            Text('Add profile', style: TextStyle(color: T.hero, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
