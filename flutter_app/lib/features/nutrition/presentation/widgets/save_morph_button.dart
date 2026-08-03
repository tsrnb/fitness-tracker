import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';

/// A submit button that morphs into a green "Saved" pill on tap, holds
/// briefly, then closes the given sheet route — the shared confirmation
/// pattern used across the Log Food sub-sheets instead of a toast.
class SaveMorphButton extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final FutureOr<void> Function()? onTap;
  const SaveMorphButton({super.key, required this.child, required this.onTap, this.padding = const EdgeInsets.all(16), this.opacity = 1});

  @override
  State<SaveMorphButton> createState() => _SaveMorphButtonState();
}

class _SaveMorphButtonState extends State<SaveMorphButton> {
  bool _saved = false;
  bool _busy = false;

  void _handleTap() async {
    if (_busy || _saved || widget.onTap == null) return;
    setState(() => _busy = true);
    await widget.onTap!();
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: _saved
          ? Container(
              key: const ValueKey('saved'),
              width: double.infinity,
              padding: widget.padding,
              decoration: BoxDecoration(color: T.success, borderRadius: BorderRadius.circular(T.rM)),
              alignment: Alignment.center,
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Saved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            )
          : PrimaryButton(
              key: const ValueKey('submit'),
              padding: widget.padding,
              opacity: _busy ? 0.7 : widget.opacity,
              onTap: widget.onTap == null ? null : _handleTap,
              child: widget.child,
            ),
    );
  }
}
