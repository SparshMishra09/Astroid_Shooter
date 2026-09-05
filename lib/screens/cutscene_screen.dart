import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../widgets/game_loading_screen.dart';

/// The intro cutscene, shown the first time a logged-in player hits
/// PLAY each session. Skippable at any time via a button or tap.
///
/// While the video initializes, the themed [GameLoadingScreen] plays
/// (no separate spinner/continue UI). SKIP — and the video's natural
/// end — both return to the home screen.
class CutsceneScreen extends StatefulWidget {
  const CutsceneScreen({super.key});

  /// Whether the intro has already played this app session.
  static bool playedThisSession = false;

  @override
  State<CutsceneScreen> createState() => _CutsceneScreenState();
}

class _CutsceneScreenState extends State<CutsceneScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _leaving = false;
  Timer? _hideControlsTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    CutsceneScreen.playedThisSession = true;
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller =
        VideoPlayerController.asset('assets/cutscenes/starting_scene_1.mp4');
    try {
      await controller.initialize();
      _controller = controller;
      await controller.setLooping(false);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _initialized = true);
      controller.addListener(() {
        if (!mounted) return;
        // When playback reaches the end, head back home.
        final pos = controller.value.position;
        final dur = controller.value.duration;
        if (dur > Duration.zero && pos >= dur) {
          _goHome();
        }
      });
      _scheduleHideControls();
    } catch (e) {
      debugPrint('Cutscene init error: $e');
      // Video failed — the themed loading screen keeps playing; give
      // it a short beat, then head home automatically. No CONTINUE
      // button needed: the player is never stuck.
      await controller.dispose();
      if (mounted) {
        setState(() => _error = true);
        Timer(const Duration(seconds: 3), _goHome);
      }
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _goHome() {
    if (_leaving) return;
    _leaving = true;
    _hideControlsTimer?.cancel();
    // Back to the game's home screen — the cutscene sits between the
    // home screen and itself (skipping returns where the player came
    // from, rather than pushing the mode selection on top).
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // While the video loads (or failed), the themed launch loading
      // screen plays — same one the game itself uses.
      body: (_error || !_initialized)
          ? const GameLoadingScreen(message: 'ENTERING THE GALAXY')
          : GestureDetector(
              onTap: _scheduleHideControls,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),

                  // Skip button (fades out with the controls)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    right: 20,
                    bottom: _controlsVisible ? 28 : -80,
                    child: _SkipButton(onPressed: _goHome),
                  ),

                  // Subtle vignette so the skip button always reads.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        color: Colors.black.withOpacity(0.45),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.skip_next_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'SKIP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
