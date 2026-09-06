import 'dart:js_interop';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web: a plain autoplay/muted/loop `<video>` element via HtmlElementView.
///
/// Deliberately NOT the video_player plugin — its web build forces
/// `crossOrigin="anonymous"` and resolves inconsistently under a non-root
/// base-href, which is why the clips showed "unavailable". A bare `<video>`
/// with a direct `src` just plays.
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
  void _bind(web.HTMLVideoElement v) {
    v
      ..src = widget.url
      ..autoplay = true
      ..muted = true
      ..defaultMuted = true
      ..loop = true
      ..controls = false;
    v.setAttribute('playsinline', '');
    v.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..backgroundColor = 'transparent';
    v.addEventListener(
      'canplay',
      (web.Event _) {
        if (mounted) widget.onReady();
      }.toJS,
    );
    v.addEventListener(
      'error',
      (web.Event _) {
        if (mounted) widget.onError();
      }.toJS,
    );
    v.play();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'video',
      onElementCreated: (Object el) => _bind(el as web.HTMLVideoElement),
    );
  }
}
