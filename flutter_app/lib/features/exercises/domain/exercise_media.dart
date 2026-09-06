enum ExerciseMediaKind { mp4, gif }

/// An exercise's animation. [source] is a Flutter asset key
/// (`assets/exercises/<slug>.mp4`, [isAsset] true) for a bundled Vital clip, or
/// an absolute URL for a remote fallback GIF.
class ExerciseMedia {
  final String source;
  final ExerciseMediaKind kind;
  final bool isAsset;

  /// Credit line shown over the clip when the source requires it.
  final String? attribution;

  const ExerciseMedia({
    required this.source,
    required this.kind,
    this.isAsset = false,
    this.attribution,
  });
}
