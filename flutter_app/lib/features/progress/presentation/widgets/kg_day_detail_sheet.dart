import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/lib/helpers.dart';
import '../../domain/kg_progress.dart';

/// What tapping a bar in the Next Kg screen's day-strip opens — that day's
/// eaten/maintenance/burned/deficit, in the same plain-language terms as the
/// rest of the screen (no "banked", no bare "deficit").
class KgDayDetailSheet extends StatelessWidget {
  final KgDayDetail detail;
  final int milestoneNumber; // which kg this day counted toward
  const KgDayDetailSheet({super.key, required this.detail, required this.milestoneNumber});

  @override
  Widget build(BuildContext context) {
    final isDeficit = detail.deficit >= 0;
    // A whole kg is 7,700 kcal — express one day's contribution as a rough
    // share of that, the same "how much did today actually matter" framing
    // the design settled on rather than a bare kcal number.
    final pctOfKg = (detail.deficit.abs() / kcalPerKg * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fmtFull2(detail.date), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.text)),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 16),
          child: Text('Counted toward kg $milestoneNumber', style: TextStyle(fontSize: 12.5, color: T.muted)),
        ),
        _row(context, 'You ate', '${detail.eaten} kcal'),
        _row(context, 'Your maintenance', '${detail.tdee.round()} kcal'),
        _row(context, 'Burned from activity', '+${detail.burned.round()} kcal', last: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isDeficit ? 'Under your goal by' : 'Over your goal by', style: TextStyle(fontSize: 13, color: T.text, fontWeight: FontWeight.w700)),
              Text('${detail.deficit.abs().round()} kcal', style: mono(fontSize: 14, fontWeight: FontWeight.w800, color: isDeficit ? T.success : T.danger)),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDeficit ? T.success.withValues(alpha: 0.12) : T.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(isDeficit ? Icons.check_circle : Icons.info_outline, size: 16, color: isDeficit ? T.success : T.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isDeficit
                    ? (pctOfKg >= 5 ? 'A strong day — about $pctOfKg% of a whole kg on its own.' : 'A day in the right direction.')
                    : "A day over goal — it happens, and it's just this one day, not the whole picture.",
                style: TextStyle(fontSize: 12, color: T.text, height: 1.4),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: T.line))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: T.muted)),
          Text(value, style: mono(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.text)),
        ],
      ),
    );
  }
}

/// "Tuesday, Aug 12" for an arbitrary iso date — [fmtFull] in helpers.dart
/// only ever formats *today*, so a distinct name here instead of overloading it.
String fmtFull2(String iso) {
  final d = DateTime.parse('${iso}T00:00:00');
  final weekday = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d.weekday - 1];
  final month = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];
  return '$weekday, $month ${d.day}';
}
