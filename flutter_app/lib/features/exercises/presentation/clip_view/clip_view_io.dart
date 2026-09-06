import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Mobile/desktop: plays [url] with the video_player plugin. Reports readiness
/// and failure so the parent can show the shared spinner / retry chrome.
class ClipView extends StatefulWidget {
  final String url;
  final VoidCallback onReady;
  final VoidCallback onError;

  const ClipView({
    super.key,
    required this.url,
    required this.onReady,
    required this.onError,
  });

  @override
  State<ClipView> createState() => _ClipViewState();
}

class _ClipViewState extends State<ClipView> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) return;
      setState(() {});
      widget.onReady();
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }
}
