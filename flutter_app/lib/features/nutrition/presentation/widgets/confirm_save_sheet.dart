import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';

/// The "save to library?" step shown after Manual entry — used to live as
/// its own page-level step before Manual entry became one self-contained
/// sheet flow.
class ConfirmSaveSheet extends StatefulWidget {
  final Map<String, dynamic> pending;
  final Future<void> Function(bool saveForFuture) onConfirm;
  const ConfirmSaveSheet({super.key, required this.pending, required this.onConfirm});

  @override
  State<ConfirmSaveSheet> createState() => _ConfirmSaveSheetState();
}

class _ConfirmSaveSheetState extends State<ConfirmSaveSheet> {
  bool _busy = false;
  bool _saved = false;

  void _handle(bool saveForFuture) async {
    if (_busy || _saved) return;
    setState(() => _busy = true);
    await widget.onConfirm(saveForFuture);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = true;
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (context.mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Save for next time?', style: Type.h2),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text.rich(TextSpan(style: TextStyle(color: T.muted, fontSize: 14), children: [
            const TextSpan(text: 'Add '),
            TextSpan(text: '${widget.pending['name']}', style: TextStyle(color: T.text, fontWeight: FontWeight.bold)),
            TextSpan(text: ' (${widget.pending['kcal']} kcal · ${widget.pending['protein']}g) to your food library so it\'s one tap in future?'),
          ])),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: _saved
              ? Container(
                  key: const ValueKey('saved'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: T.success, borderRadius: BorderRadius.circular(T.rM)),
                  alignment: Alignment.center,
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Saved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                )
              : Column(
                  key: const ValueKey('actions'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PrimaryButton(
                        opacity: _busy ? 0.7 : 1,
                        onTap: () => _handle(true),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.save, size: 17),
                          SizedBox(width: 8),
                          Text('Save & add to today'),
                        ]),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _handle(false),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(border: Border.all(color: T.line), borderRadius: BorderRadius.circular(T.pill)),
                        alignment: Alignment.center,
                        child: Text('Just add for today', style: TextStyle(color: T.text, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
