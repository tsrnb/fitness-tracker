import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../domain/exercise_media.dart';
import '../data/exercise_media_repository.dart';
import 'clip_view/clip_view.dart';

/// Plays an exercise's animation — a Vital MP4, or a fallback GIF — autoplay,
/// muted, looping, no controls. It renders at its original aspect ratio on a
/// white field, never stretched or cropped. Spinner while it loads; a
/// non-blocking "Animation unavailable · Retry" on failure.
///
/// Mount this **only on the exercise detail screen** — never in a list.
///
/// Renders nothing when the exercise has no animation, so callers can drop it
/// in unconditionally.
class ExerciseAnimationWidget extends StatefulWidget {
  final String exerciseName;

  /// Optional fixed frame width:height. When null the widget fills its parent.
  final double? aspectRatio;

  const ExerciseAnimationWidget({
    super.key,
    required this.exerciseName,
    this.aspectRatio,
  });

  @override
  State<ExerciseAnimationWidget> createState() =>
      _ExerciseAnimationWidgetState();
}

class _ExerciseAnimationWidgetState extends State<ExerciseAnimationWidget> {
  ExerciseMedia? _media;
  bool _ready = false;
  bool _failed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _media = exerciseMediaFor(widget.exerciseName);
  }

  @override
  void didUpdateWidget(covariant ExerciseAnimationWidget old) {
    super.didUpdateWidget(old);
    if (old.exerciseName != widget.exerciseName) {
      _media = exerciseMediaFor(widget.exerciseName);
      _ready = false;
      _failed = false;
      _attempt = 0;
    }
  }

  void _retry() => setState(() {
    _ready = false;
    _failed = false;
    _attempt++;
  });

  @override
  Widget build(BuildContext context) {
    final media = _media;
    if (media == null) return const SizedBox.shrink();

    final inner = ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _mediaWidget(media),
          if (!_ready && !_failed) const _AnimationLoading(),
          if (_failed) _AnimationError(onRetry: _retry),
          if (media.attribution != null && _ready)
            Positioned(
              right: 8,
              bottom: 6,
              child: Text(
                media.attribution!,
                style: TextStyle(fontSize: 8, color: T.faint),
              ),
            ),
        ],
      ),
    );

    if (widget.aspectRatio == null) return inner;
    return AspectRatio(
      aspectRatio: widget.aspectRatio!,
      child: ClipRRect(borderRadius: BorderRadius.circular(T.rL), child: inner),
    );
  }

  Widget _mediaWidget(ExerciseMedia media) {
    final key = ValueKey('${media.source}#$_attempt');
    if (media.kind == ExerciseMediaKind.mp4) {
      return ClipView(
        key: key,
        url: media.source,
        onReady: () {
          if (mounted && !_ready) setState(() => _ready = true);
        },
        onError: () {
          if (mounted && !_failed) setState(() => _failed = true);
        },
      );
    }
    return Image.network(
      media.source,
      key: key,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSync) {
        if (frame != null && !_ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_ready) setState(() => _ready = true);
          });
        }
        return child;
      },
      errorBuilder: (context, error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_failed) setState(() => _failed = true);
        });
        return const SizedBox.shrink();
      },
    );
  }
}

class _AnimationLoading extends StatelessWidget {
  const _AnimationLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: T.accent),
      ),
    );
  }
}

class _AnimationError extends StatelessWidget {
  final VoidCallback onRetry;
  const _AnimationError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_outlined, size: 20, color: T.faint),
          const SizedBox(height: 6),
          Text(
            'Animation unavailable',
            style: TextStyle(fontSize: 12, color: T.muted),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: T.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
