import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/atoms.dart';
import '../../shared/lib/muscle_map.dart';
import 'exercise_library.dart';

class LibraryScreen extends StatefulWidget {
  final ValueChanged<String> openExercise;
  const LibraryScreen({super.key, required this.openExercise});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String q = '';
  Map<String, bool> openG = {'Chest': true};

  @override
  Widget build(BuildContext context) {
    final names = lib.keys.toList();
    final ql = q.toLowerCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
            SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => q = v),
          style: TextStyle(color: T.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search exercises',
            hintStyle: TextStyle(color: T.faint),
            filled: true,
            fillColor: T.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(T.pill), borderSide: BorderSide(color: T.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.pill), borderSide: BorderSide(color: T.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.pill), borderSide: const BorderSide(color: T.accent)),
          ),
        ),
        const SizedBox(height: 16),
        ...groups.map((g) {
          final list = names.where((n) => lib[n]!.group == g && (q.isEmpty || n.toLowerCase().contains(ql))).toList();
          if (list.isEmpty) return const SizedBox.shrink();
          final isOpen = q.isNotEmpty ? true : (openG[g] ?? false);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => openG[g] = !(openG[g] ?? false)),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Text(g, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: T.text)),
                          Text(' · ${list.length}', style: mono(fontSize: 12, color: T.faint)),
                        ]),
                        AnimatedRotation(
                          turns: isOpen ? 0 : -0.25,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down, size: 18, color: T.faint),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                    children: list.map((n) {
                      final info = lib[n]!;
                      return AppCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () => widget.openExercise(n),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MuscleMap(view: info.view, primary: info.primary, secondary: info.secondary, size: 58),
                            const SizedBox(height: 8),
                            Text(n, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.25, color: T.text)),
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text(info.target.split(',').first, style: mono(fontSize: 10, color: T.muted))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
