import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/helpers.dart';
import '../../app/app_state.dart';

/// Prominent, always-visible Health sync status — deliberately placed at the
/// very top of the home screen (not tucked into the activity card) since
/// "did my watch data actually come in" is the first thing worth confirming
/// each time the app opens. Distinct visual treatment per state (tinted
/// border + icon + copy), with the icon itself spinning while a sync is
/// actually in flight, and a tap target that works from every state.
class HealthSyncBanner extends StatefulWidget {
  final AppState app;
  final AppController controller;
  const HealthSyncBanner({super.key, required this.app, required this.controller});

  @override
  State<HealthSyncBanner> createState() => _HealthSyncBannerState();
}

class _HealthSyncBannerState extends State<HealthSyncBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.app.healthSyncStatus;
    final lastSynced = widget.app.healthLastSyncedAt;
    final today = todayStr();
    final act = Map<String, dynamic>.from(widget.app.data.activity[today] ?? {});
    final syncing = status == HealthSyncStatus.syncing;

    late final Color accent;
    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final String action;
    switch (status) {
      case HealthSyncStatus.syncing:
        accent = T.blue;
        icon = Icons.sync;
        title = 'Syncing with Health…';
        subtitle = 'Pulling steps & calories burned';
        action = '';
        break;
      case HealthSyncStatus.success:
        accent = T.success;
        icon = Icons.check_circle;
        title = 'Health synced';
        subtitle = '${lastSynced != null ? _relativeTime(lastSynced) : 'Just now'} · '
            '${act['steps'] ?? 0} steps · ${act['kcal'] ?? 0} kcal';
        action = 'Sync now';
        break;
      case HealthSyncStatus.failed:
        accent = T.danger;
        icon = Icons.error_outline;
        title = 'Health sync failed';
        subtitle = 'Tap to retry';
        action = 'Retry';
        break;
      case HealthSyncStatus.idle:
        accent = T.hero;
        icon = Icons.watch;
        title = 'Sync with Health';
        subtitle = 'Get steps & calories from your watch automatically';
        action = 'Sync';
        break;
    }

    return Surface(
      background: accent.withValues(alpha: 0.10),
      borderColor: accent.withValues(alpha: 0.35),
      radius: T.rL,
      padding: const EdgeInsets.all(14),
      onTap: syncing ? null : () => widget.controller.syncHealth(),
      child: Row(
        children: [
          RotationTransition(
            turns: syncing ? _spin : const AlwaysStoppedAnimation(0),
            child: IconBubble(icon: Icon(icon, size: 18, color: Colors.white), size: 40, background: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Type.h3),
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: Type.caption)),
              ],
            ),
          ),
          if (!syncing) ...[
            const SizedBox(width: 8),
            Text(action, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
          ],
        ],
      ),
    );
  }
}
