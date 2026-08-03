import 'package:flutter/material.dart';
import '../../../shared/theme.dart';
import '../data/speech_recognition_service.dart';
import 'widgets/ai_gradient.dart';

/// Full-screen voice capture, pushed from the mic button beside Ask AI's
/// send button. Starts listening the instant it's shown — recording begins
/// before any entrance animation finishes, so there's no lag between the
/// tap and the mic actually being live. Pops with the final transcript
/// (or `null` if cancelled/nothing was said) for the chat screen to feed
/// straight into the same `_send()` pipeline a typed message uses.
class VoiceListenScreen extends StatefulWidget {
  const VoiceListenScreen({super.key});

  static Future<String?> push(BuildContext context) {
    return Navigator.of(context).push<String>(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const VoiceListenScreen(),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
      ),
    ));
  }

  @override
  State<VoiceListenScreen> createState() => _VoiceListenScreenState();
}

class _VoiceListenScreenState extends State<VoiceListenScreen> {
  final _speech = SpeechRecognitionService();
  String _transcript = '';
  bool _listening = false;
  bool _stopping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _transcript = '';
      _listening = true;
    });
    try {
      await _speech.startListening(
        onResult: (text, {required isFinal}) {
          if (!mounted) return;
          setState(() => _transcript = text);
        },
        onDone: () {
          if (!mounted || _stopping) return;
          // The plugin stopped on its own (silence timeout) — settle the UI
          // the same way a manual tap would, rather than leaving the mic
          // looking "live" when it no longer is.
          setState(() => _listening = false);
        },
      );
    } on SpeechUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _error = "Couldn't start listening — try again.";
      });
    }
  }

  Future<void> _stopAndSubmit() async {
    _stopping = true;
    await _speech.stop();
    if (!mounted) return;
    final text = _transcript.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  Future<void> _cancel() async {
    _stopping = true;
    await _speech.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopping = true;
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Stack(children: [
        Positioned.fill(child: AiGradientWash(base: T.bg, alpha: 0.18, child: const SizedBox.expand())),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: _cancel,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(Icons.close, size: 16, color: T.muted),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: _error != null ? _errorContent() : _listeningContent(),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 36 + MediaQuery.of(context).padding.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _WaveBars(active: _listening),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _error != null ? _start : _stopAndSubmit,
                  child: AiGradient(
                    builder: (context, gradient) => Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradient,
                        boxShadow: [BoxShadow(color: aiColor1.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 2)],
                      ),
                      alignment: Alignment.center,
                      child: Icon(_error != null ? Icons.refresh_rounded : Icons.stop_rounded, size: 28, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _error != null ? 'Tap to try again' : (_listening ? 'Tap to stop and log it' : 'Tap to log what you said'),
                  style: TextStyle(fontSize: 11.5, color: T.faint),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _errorContent() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.mic_off_rounded, size: 32, color: T.danger),
      const SizedBox(height: 14),
      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: T.muted, fontSize: 13, height: 1.5)),
    ]);
  }

  Widget _listeningContent() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.fiber_manual_record, size: 10, color: _listening ? T.danger : T.faint),
        const SizedBox(width: 6),
        Text(
          _listening ? 'LISTENING' : 'READY TO LOG',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: _listening ? T.danger : T.faint),
        ),
      ]),
      const SizedBox(height: 22),
      Text(
        _transcript.isEmpty ? 'Say what you ate…' : _transcript,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _transcript.isEmpty ? 15 : 21,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: _transcript.isEmpty ? T.muted : T.text,
        ),
      ),
    ]);
  }
}

/// A tiny animated equalizer standing in for a live waveform — bars settle
/// flat when nothing is being captured (error state, or after auto-stop).
class _WaveBars extends StatefulWidget {
  final bool active;
  const _WaveBars({required this.active});

  @override
  State<_WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<_WaveBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _heights = [8.0, 18.0, 26.0, 14.0, 22.0, 10.0];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_heights.length, (i) {
              final t = widget.active ? ((_c.value - i * 0.12) % 1.0 + 1.0) % 1.0 : 0.0;
              final bump = widget.active ? (0.5 + 0.5 * (1 - (t - 0.5).abs() * 2)) : 0.22;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 4,
                  height: _heights[i] * bump.clamp(0.22, 1.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [aiColor2, aiColor3]),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
