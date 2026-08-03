import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../day_start_applied_screen.dart';

String formatDayStart(int minutes) {
  final h24 = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final period = h24 < 12 ? 'AM' : 'PM';
  var h12 = h24 % 12;
  if (h12 == 0) h12 = 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

/// The "day starts at" wheel-picker sheet — lets a tracking day roll over at
/// any time rather than only midnight. On confirm, calls [onApplied] then
/// pushes the full-screen [DayStartAppliedScreen] confirmation, since this
/// setting is read by every screen that groups logs by day and a toast
/// undersells that reach.
void showDayBoundarySheet(BuildContext context, {required int initialMinutes, required ValueChanged<int> onApplied}) {
  int minutes = initialMinutes;
  showModalBottomSheet(
    context: context,
    backgroundColor: T.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXL))),
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSheetState) {
        final h24 = (minutes ~/ 60) % 24;
        final m = minutes % 60;
        var h12 = h24 % 12;
        if (h12 == 0) h12 = 12;
        final isPm = h24 >= 12;

        void recompute({int? newH12, int? newM, bool? newIsPm}) {
          final hh12 = newH12 ?? h12;
          final mm = newM ?? m;
          final pm = newIsPm ?? isPm;
          var hh24 = hh12 % 12;
          if (pm) hh24 += 12;
          setSheetState(() => minutes = hh24 * 60 + mm);
        }

        final isMidnight = minutes == 0;

        // CupertinoPicker's own off-center dimming is a fixed, non-tunable
        // 44.7% opacity — against this app's dark surfaces that reads as
        // "still basically white," not a clear selected/unselected split.
        // Styling each row explicitly from known state guarantees the
        // selected row is unmistakably white/bold instead of leaving it to
        // an internal effect neither adjustable nor easy to verify.
        Widget wheelItem(String label, bool selected) => Center(
              child: Text(
                label,
                style: selected
                    ? mono(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)
                    : mono(fontSize: 16, fontWeight: FontWeight.w500, color: T.faint),
              ),
            );

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: T.line, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 16),
              Text('Day starts at', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.text)),
              const SizedBox(height: 3),
              Text('Scroll to any hour and minute — this is when your tracking day rolls over.', style: TextStyle(fontSize: 12, color: T.muted)),
              const SizedBox(height: 16),
              SizedBox(
                height: 190,
                child: Row(children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 46,
                      scrollController: FixedExtentScrollController(initialItem: h12 - 1),
                      onSelectedItemChanged: (i) => recompute(newH12: i + 1),
                      // CupertinoPicker always paints selectionOverlay ON TOP of the
                      // wheel — an opaque fill here hides the very number it's meant to
                      // highlight, which is what made the selected row look "greyed
                      // out" instead of crisp white/bold. Translucent fill + a full-
                      // opacity border reads as a highlight band without hiding the text.
                      selectionOverlay: Container(
                        decoration: BoxDecoration(
                          color: T.surface2.withValues(alpha: 0.55),
                          border: Border.all(color: T.line),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      children: List.generate(12, (i) => wheelItem('${i + 1}', i + 1 == h12)),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 46,
                      scrollController: FixedExtentScrollController(initialItem: m ~/ 5),
                      onSelectedItemChanged: (i) => recompute(newM: i * 5),
                      // CupertinoPicker always paints selectionOverlay ON TOP of the
                      // wheel — an opaque fill here hides the very number it's meant to
                      // highlight, which is what made the selected row look "greyed
                      // out" instead of crisp white/bold. Translucent fill + a full-
                      // opacity border reads as a highlight band without hiding the text.
                      selectionOverlay: Container(
                        decoration: BoxDecoration(
                          color: T.surface2.withValues(alpha: 0.55),
                          border: Border.all(color: T.line),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      children: List.generate(12, (i) => wheelItem((i * 5).toString().padLeft(2, '0'), i * 5 == m)),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 46,
                      scrollController: FixedExtentScrollController(initialItem: isPm ? 1 : 0),
                      onSelectedItemChanged: (i) => recompute(newIsPm: i == 1),
                      // CupertinoPicker always paints selectionOverlay ON TOP of the
                      // wheel — an opaque fill here hides the very number it's meant to
                      // highlight, which is what made the selected row look "greyed
                      // out" instead of crisp white/bold. Translucent fill + a full-
                      // opacity border reads as a highlight band without hiding the text.
                      selectionOverlay: Container(
                        decoration: BoxDecoration(
                          color: T.surface2.withValues(alpha: 0.55),
                          border: Border.all(color: T.line),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      children: [
                        wheelItem('AM', !isPm),
                        wheelItem('PM', isPm),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  isMidnight
                      ? 'Set to ${formatDayStart(minutes)} — a standard calendar day. Logs after midnight always belong to the new date.'
                      : 'Set to ${formatDayStart(minutes)} — logs before this time still count toward the previous day.',
                  style: TextStyle(fontSize: 12, color: T.muted, height: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                onTap: () {
                  final applied = minutes;
                  onApplied(applied);
                  Navigator.of(ctx).pop();
                  // A toast would undersell this — the day boundary is read by
                  // every screen that groups logs by day, so the confirmation
                  // is a full-screen moment that shows that reach directly
                  // instead of just saying "saved."
                  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
                    opaque: true,
                    transitionDuration: const Duration(milliseconds: 280),
                    reverseTransitionDuration: const Duration(milliseconds: 200),
                    pageBuilder: (_, __, ___) => DayStartAppliedScreen(timeLabel: formatDayStart(applied), isMidnight: applied == 0),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  ));
                },
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check, size: 17),
                  SizedBox(width: 8),
                  Text('Set day start & save'),
                ]),
              ),
            ],
          ),
        );
      });
    },
  );
}
