import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../shared/theme.dart';
import '../domain/exercise_media.dart';
import '../data/exercise_media_repository.dart';

/// Plays an exercise's Vital Animations clip — autoplay, muted, looping, no
/// controls. The clip renders at its own (original) aspect ratio on a white
/// field, never stretched or cropped.
///
/// Mount this **only on the exercise detail screen** — never in a list. The
/// controller is created on mount and disposed with the route.
///
/// Renders nothing when the exercise has no Vital clip, so callers can drop it
/// in unconditionally.
class ExerciseAnimationWidget extends StatefulWidget {
  final String exerciseName;

  /// Optional fixed frame width:height. When null the widget fills its parent
  /// and letterboxes the clip (in white) to keep its original aspect ratio.
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
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExerciseAnimationWidget old) {
    super.didUpdateWidget(old);
    if (old.exerciseName != widget.exerciseName) _load();
  }

  Future<void> _load() async {
    _disposeController();
    _error = null;
    final media = exerciseMediaFor(widget.exerciseName);
    _media = media;
    if (media == null || media.kind != ExerciseMediaKind.mp4) {
      if (mounted) setState(() {});
      return;
    }
    final c = media.isAsset
        ? VideoPlayerController.asset(media.source)
        : VideoPlayerController.networkUrl(Uri.parse(media.source));
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  void _retry() {
    setState(() => _attempt++);
    _load();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final media = _media;
    if (media == null) return const SizedBox.shrink();

    final inner = ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _content(media),
          if (media.attribution != null)
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

  // Both kinds render at their original aspect ratio, centred, white letterbox
  // where they don't fill — never stretched or cropped.
  Widget _content(ExerciseMedia media) {
    if (_error != null) return _AnimationError(onRetry: _retry);

    if (media.kind == ExerciseMediaKind.mp4) {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return const _AnimationLoading();
      return Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    }

    return Image.network(
      media.source,
      key: ValueKey('${media.source}#$_attempt'),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _AnimationLoading(),
      errorBuilder: (context, error, stack) => _AnimationError(onRetry: _retry),
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
