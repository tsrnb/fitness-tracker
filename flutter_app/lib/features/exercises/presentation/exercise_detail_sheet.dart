import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/atoms.dart';
import '../../../shared/lib/muscle_map.dart';
import '../../training/data/training_splits_data.dart';
import '../data/exercise_library_data.dart';

class ExerciseDetailSheet extends StatelessWidget {
  final String name;

  /// Set when this sheet is opened as a swap preview (long-press on a
  /// same-muscle-group alternative) rather than from the Library or a
  /// "tutorial" link — adds a second, primary action beneath "Watch
  /// tutorial" so the user can commit to the swap without leaving the sheet.
  final VoidCallback? onUseInstead;

  const ExerciseDetailSheet({super.key, required this.name, this.onUseInstead});

  @override
  Widget build(BuildContext context) {
    final info = lib[name];
    if (info == null) return const SizedBox.shrink();
    final prescribed = findAnyPrescription(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(name, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: T.text))),
            IconBubble(icon: Icon(Icons.close, size: 18, color: T.muted), size: 36, background: T.surface2, onTap: () => Navigator.of(context).pop()),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconBubble(
                icon: MuscleMap(view: info.view, primary: info.primary, secondary: info.secondary, size: 92),
                size: 112,
                background: T.surface2,
                border: Border.all(color: T.line),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Targets'),
                    Padding(padding: EdgeInsets.only(bottom: 10), child: Text(info.target, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: T.text))),
                    if (prescribed != null) ...[
                      const Eyebrow('Prescribed'),
                      Text('${prescribed.sets} × ${prescribed.reps}', style: mono(fontSize: 18, fontWeight: FontWeight.w600, color: T.hero)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(padding: EdgeInsets.only(bottom: 16), child: Text(info.desc, style: TextStyle(fontSize: 14, color: T.muted, height: 1.6))),
        const Eyebrow('Form cues'),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(info.cues.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((i + 1).toString().padLeft(2, '0'), style: mono(fontSize: 13, color: T.accent)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(info.cues[i], style: TextStyle(fontSize: 14, height: 1.4, color: T.text))),
                  ],
                ),
              );
            }),
          ),
        ),
        if (onUseInstead != null) ...[
          PrimaryButton(
            onTap: onUseInstead,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.swap_horiz, size: 18),
              const SizedBox(width: 8),
              Text('Use $name instead'),
            ]),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: () => launchUrl(ytUri(name), mode: LaunchMode.externalApplication),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.play_arrow, size: 14, color: T.accent),
                const SizedBox(width: 4),
                Text('Watch tutorial', style: TextStyle(fontSize: 13, color: T.accent, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ] else
          PrimaryButton(
            onTap: () => launchUrl(ytUri(name), mode: LaunchMode.externalApplication),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow, size: 18),
              SizedBox(width: 8),
              Text('Watch tutorial'),
            ]),
          ),
      ],
    );
  }
}
