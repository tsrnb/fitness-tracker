import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';
import '../../../../shared/widgets/pressable_scale.dart';

enum DataIllustrationKind { export, import }

/// A small illustrated tray-and-document motif for the export/import cards,
/// built entirely from layered shapes (no external image asset) so it stays
/// theme-aware in light/dark automatically, per T.* tokens.
class DataIllustration extends StatelessWidget {
  final DataIllustrationKind kind;
  const DataIllustration({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isExport = kind == DataIllustrationKind.export;
    final tone = isExport ? T.hero : T.lav;
    final badgeInk = isExport ? Colors.white : T.lavInk;
    return SizedBox(
      width: 72,
      height: 66,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 4,
            child: Container(
              width: 58,
              height: 30,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 38,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
              decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tone, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(3, (i) {
                  return Container(
                    margin: EdgeInsets.only(bottom: i < 2 ? 5 : 0),
                    height: 3,
                    width: i == 2 ? 14 : double.infinity,
                    decoration: BoxDecoration(color: tone.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                  );
                }),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle, border: Border.all(color: T.surface, width: 2.5)),
              child: Icon(isExport ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: badgeInk),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _dataActionButtonContent(IconData icon, String label, bool loading, Color color) {
  if (loading) {
    return SizedBox(height: 17, width: 17, child: CircularProgressIndicator(strokeWidth: 2, color: color));
  }
  return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
  ]);
}

/// One card in "Data & export" — an illustration, description, and a button
/// that swaps to a spinner while [loading].
Widget dataActionCard(
  BuildContext context, {
  required Widget illustration,
  required String title,
  required String description,
  required String buttonLabel,
  required IconData buttonIcon,
  required bool loading,
  required VoidCallback? onTap,
  bool filled = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          illustration,
          const SizedBox(height: 14),
          Text(title, style: Type.h3),
          const SizedBox(height: 6),
          Text(description, style: Type.caption),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: filled
                ? PrimaryButton(
                    onTap: onTap,
                    opacity: loading ? 0.6 : 1,
                    child: _dataActionButtonContent(buttonIcon, buttonLabel, loading, Colors.white),
                  )
                : PressableScale(
                    onTap: loading ? null : onTap,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(T.rM),
                        border: Border.all(color: T.line),
                      ),
                      alignment: Alignment.center,
                      child: _dataActionButtonContent(buttonIcon, buttonLabel, loading, T.text),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
