import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';

/// A plain nav row (icon, label, sub, trailing chevron) — pushes into a
/// Settings sub-page.
Widget settingsNavRow(BuildContext context, {required IconData icon, required String label, required String sub, required VoidCallback onTap}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      onTap: onTap,
      child: Row(children: [
        IconBubble(icon: Icon(icon, size: 16, color: T.muted), size: 32, background: T.surface2),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: T.text)),
              Text(sub, style: TextStyle(fontSize: 12, color: T.muted)),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: 18, color: T.faint),
      ]),
    ),
  );
}

/// A settings row with a trailing status pill instead of a plain chevron —
/// shows the current value (goal, split, macros...) right on the row.
Widget settingsBadgeRow(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required Color iconBg,
  required String label,
  required String sub,
  required String badge,
  required Color badgeBg,
  required Color badgeColor,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      onTap: onTap,
      child: Row(children: [
        IconBubble(icon: Icon(icon, size: 16, color: iconColor), size: 32, background: iconBg),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: T.text)),
              Text(sub, style: TextStyle(fontSize: 12, color: T.muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(T.pill)),
          child: Text(badge, style: mono(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor)),
        ),
      ]),
    ),
  );
}
