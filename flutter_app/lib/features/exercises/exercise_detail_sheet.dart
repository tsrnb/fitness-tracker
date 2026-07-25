import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/muscle_map.dart';
import '../training/program.dart';
import 'exercise_library.dart';

class ExerciseDetailSheet extends StatelessWidget {
  final String name;
  const ExerciseDetailSheet({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final info = lib[name];
    if (info == null) return const SizedBox.shrink();
    ProgramItem? prescribed;
    for (final d in dayOrder) {
      final match = program[d]!.items.where((x) => x.name == name);
      if (match.isNotEmpty) {
        prescribed = match.first;
        break;
      }
    }
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
