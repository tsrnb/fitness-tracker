enum ExerciseMediaKind { mp4, gif }

/// An exercise's animation, served over the network. [source] is an absolute
/// URL — a bundled-then-published Vital MP4, or a fallback GIF.
class ExerciseMedia {
  final String source;
  final ExerciseMediaKind kind;

  /// Credit line shown over the clip when the source requires it.
  final String? attribution;

  const ExerciseMedia({
    required this.source,
    required this.kind,
    this.attribution,
  });
}
