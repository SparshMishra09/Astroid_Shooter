import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/game_config.dart';
import '../models/enums.dart';
import '../models/asteroids.dart';
import '../models/enemy_ship.dart';
import '../models/swarm_unit.dart';
import '../services/score_service.dart';
import '../services/user_progress_service.dart';
import '../services/audio_service.dart';
import '../widgets/space_background.dart';
import '../widgets/entity_widgets.dart';
import '../widgets/game_overlays.dart';
import '../widgets/playlist_widgets.dart';
import '../game/game_controller.dart';

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final DifficultyLevel difficulty;

  const GameScreen({
    Key? key,
    this.gameMode = GameMode.classicRun,
    this.difficulty = DifficultyLevel.cadet,
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameController _controller;
  late AudioService _audioService;

  // Animation controllers for visual effects that need TickerProvider
  late AnimationController _shakeController;
  late AnimationController _comboFlashController;

  // Engine trail points (screen-local, since they depend on player position)
  final List<Offset> _engineTrailPoints = [];

  // Screen dimensions
  double _screenWidth = GameConfig.defaultScreenWidth;
  double _screenHeight = GameConfig.defaultScreenHeight;

  // Game timer (nullable — null until _initializeGame starts it)
  Timer? _gameTimer;

  // Guard so we only submit game results to Firestore once per run
  bool _resultsSubmitted = false;
  // True while results are being saved to Firestore (shows indicator)
  bool _isSavingResults = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _comboFlashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _audioService = AudioService();

    // Build the controller with callbacks that drive audio + UI reactions.
    // initialize() is called synchronously here so gameState/player are
    // valid before the first build() — otherwise LateInitializationError
    // causes a grey screen in release mode.
    _controller = GameController(
      mode: widget.gameMode,
      callbacks: _ScreenCallbacks(this),
    );
    _controller.initialize();

    // Sound effects only — the music playlist (MusicPlayerService) owns
    // background music and keeps playing across screens.
    _audioService.initialize();

    _loadHighScoreAndStart();
  }

  Future<void> _loadHighScoreAndStart() async {
    // Load the user's best score from Firestore (per-account).
    // Falls back to local storage if Firestore is unavailable.
    int highScore = 0;
    try {
      final progress = await UserProgressService.instance.getMyProgress();
      highScore = progress.bestScore;
    } catch (_) {
      highScore = await ScoreService.getHighScore();
    }
    if (!mounted) return;
    // Store on the already-initialized gameState, then re-init with real
    // screen dimensions (preserving the loaded high score).
    _controller.gameState.highScore = highScore;
    _resultsSubmitted = false;
    _isSavingResults = false;
    _initializeGame();
  }

  void _initializeGame() {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    _controller.setScreenSize(_screenWidth, _screenHeight);
    _controller.initialize(preserveHighScore: true);
    _engineTrailPoints.clear();

    _gameTimer?.cancel();
    // Difficulty = game speed: the tick duration scales the whole
    // simulation (entities, bullets, spawns, animations) together.
    _gameTimer = Timer.periodic(
      GameConfig.tickDurationFor(widget.difficulty),
      (_) => _gameLoop(),
    );
    setState(() {});
  }

  void _gameLoop() {
    if (_controller.gameState.isPaused || _controller.gameState.isGameOver) return;

    // Update engine trail (sample player's engine position)
    _engineTrailPoints.add(Offset(
      _controller.player.x + _controller.player.width / 2,
      _controller.player.y + _controller.player.height - 4,
    ));
    if (_engineTrailPoints.length > 8) _engineTrailPoints.removeAt(0);

    // Safety net: any exception during tick() must NOT prevent setState()
    // from being called — otherwise the UI freezes permanently. In release
    // mode there is no red error screen, so an uncaught exception here
    // would manifest as a grey/frozen game.
    try {
      _controller.tick();
    } catch (e) {
      // Log to console (visible in logcat / flutter logs) but keep running.
      debugPrint('Game loop error (recovered): $e');
    }

    // When the game just ended, submit the results to Firestore once.
    // This runs on the SAME frame that gameOver() was called (the early
    // return at the top hasn't triggered yet because isGameOver was
    // false when this frame started).
    if (_controller.gameState.isGameOver && !_resultsSubmitted) {
      _resultsSubmitted = true;
      _submitGameResults();
    }

    setState(() {});
  }

  void _restartGame() {
    _gameTimer?.cancel();
    _gameTimer = null;
    _loadHighScoreAndStart();
  }

  void _goToMainMenu() {
    _gameTimer?.cancel();
    _gameTimer = null;
    Navigator.of(context).pop();
  }

  /// Show a confirmation dialog when quitting from the pause menu.
  /// Warns the user that their current run's progress will be lost.
  void _confirmQuitToMainMenu() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Quit Game?', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: const Text(
          'Your current progress for this run will be lost and will NOT be counted.\n\n'
          'Astrids and stats are only saved when you die (Game Over).',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.15),
            ),
            child: const Text('Quit Anyway', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _goToMainMenu();
      }
    });
  }

  /// Submit the completed game's results to Firestore (per-user progress).
  /// Sets [_isSavingResults] while the write is in flight so the game-over
  /// overlay can show a saving indicator. Calls [setState] when done so
  /// the UI updates.
  ///
  /// CRITICAL: This captures the game state values synchronously at the
  /// start (before any await), so they're correct even if the controller
  /// is later reset by _restartGame.
  void _submitGameResults() async {
    // Capture values synchronously — they won't change after this point
    // even if the controller is reset.
    final score = _controller.gameState.score;
    final waveReached = _controller.gameState.currentWave;
    final asteroidsDestroyed = _controller.asteroidsDestroyed;
    final bossesDefeated = _controller.bossesDefeated;

    _controller.commitHighScore();
    ScoreService.saveHighScore(_controller.gameState.highScore);

    // Show saving indicator
    if (mounted) {
      setState(() => _isSavingResults = true);
    }

    try {
      await UserProgressService.instance.submitGameResult(
        scoreEarned: score,
        waveReached: waveReached,
        asteroidsDestroyed: asteroidsDestroyed,
        gameMode: widget.gameMode,
        bossesDefeated: bossesDefeated,
      );
    } catch (e) {
      debugPrint('Submit game results error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingResults = false);
      }
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _shakeController.dispose();
    _comboFlashController.dispose();
    // The music playlist keeps playing after leaving the game screen.

    // Persist high score locally as a fallback (the primary save goes to
    // Firestore in _submitGameResults when the game ends).
    _controller.commitHighScore();
    ScoreService.saveHighScore(_controller.gameState.highScore);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // --- Gesture handlers ---
  void _handlePanUpdate(DragUpdateDetails details) {
    _controller.movePlayerTo(details.globalPosition.dx);
  }

  void _handlePanStart(DragStartDetails details) {
    _controller.movePlayerTo(details.globalPosition.dx);
  }

  void _togglePause() {
    setState(() => _controller.togglePause());
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _controller.setScreenSize(_screenWidth, _screenHeight);

    final c = _controller;
    final blinkVisible = !c.player.isInvulnerable || (c.frameCount % GameConfig.blinkFrames < GameConfig.blinkFrames ~/ 2);
    final isComboFlashing = c.comboFlashTimer > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final offset = _shakeController.value * 10;
            final dx = sin(_shakeController.value * 10) * offset;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Stack(
            children: [
              // Play field + gesture detector
              GestureDetector(
                onPanUpdate: _handlePanUpdate,
                onPanStart: _handlePanStart,
                child: Container(
                  width: _screenWidth,
                  height: _screenHeight,
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      SpaceBackground(
                        scrollOffset: c.backgroundScrollOffset,
                        width: _screenWidth,
                        height: _screenHeight,
                      ),

                      // Effects layer (drawn under entities so explosions appear behind)
                      EffectsLayer(
                        explosions: c.explosionEffects,
                        hitEffects: c.hitEffects,
                        muzzleFlashes: c.muzzleFlashes,
                        engineTrailPoints: List.of(_engineTrailPoints),
                        playerX: c.player.x,
                        playerY: c.player.y,
                        playerWidth: c.player.width,
                        width: _screenWidth,
                        height: _screenHeight,
                      ),

                      // Player
                      PlayerWidget(
                        player: c.player,
                        hasShield: c.hasShield,
                        shieldHitsRemaining: c.shieldHitsRemaining,
                        blinkVisible: blinkVisible,
                        frameCount: c.frameCount,
                        trailPoints: const [],
                      ),

                      // Wing drones (flank the player, rapid fire)
                      for (final pos in c.wingDronePositions)
                        WingDroneWidget(
                          x: pos.dx,
                          y: pos.dy,
                          size: GameConfig.droneSize,
                          frameCount: c.frameCount,
                        ),

                      // Asteroids
                      for (var a in c.asteroids) AsteroidWidget(asteroid: a),

                      // Bullets
                      for (var b in c.bullets) BulletWidget(bullet: b),

                      // Power-ups (classic run only)
                      if (c.config.powerUpsEnabled)
                        for (var p in c.powerUps) PowerUpWidget(powerUp: p, frameCount: c.frameCount),

                      // Laser beams
                      if (c.config.powerUpsEnabled)
                        for (var l in c.laserBeams)
                          LaserBeamWidget(laser: l, frameCount: c.frameCount),

                      // Floating text
                      if (c.config.powerUpsEnabled)
                        for (var t in c.floatingTexts) FloatingTextWidget(text: t),

                      // Enemies
                      for (var e in c.enemies)
                        if (e.isVisible)
                          if (e is SmallFastAsteroid)
                            SmallAsteroidWidget(asteroid: e, frameCount: c.frameCount)
                          else if (e is HugeSlowAsteroid)
                            HugeAsteroidWidget(asteroid: e)
                          else if (e is SwarmUnit)
                            SwarmUnitWidget(unit: e, frameCount: c.frameCount)
                          else if (e is EnemyShip)
                            EnemyShipWidget(ship: e, frameCount: c.frameCount),

                      // Enemy bullets
                      for (var b in c.enemyBullets) EnemyBulletWidget(bullet: b, frameCount: c.frameCount),

                      // Bomb barrels (Demolition Titan)
                      for (var b in c.bombBarrels)
                        BombBarrelWidget(barrel: b, frameCount: c.frameCount),

                      // Bosses (normally one; Boss Rush twins the tri-beam)
                      for (var boss in c.activeBosses)
                        BossWidget(boss: boss, frameCount: c.frameCount),

                      // Void Lancers' laser beams (charge telegraph +
                      // lethal beam under each firing boss)
                      for (var boss in c.activeBosses)
                        BossLaserBeamWidget(
                          boss: boss,
                          screenHeight: _screenHeight,
                          frameCount: c.frameCount,
                          beamWidth: GameConfig.bossLaserWidth,
                        ),
                    ],
                  ),
                ),
              ),

              // HUD
              GameHUD(
                gameState: c.gameState,
                player: c.player,
                mode: c.config,
                activePowerUps: c.activePowerUps,
                difficulty: widget.difficulty,
              ),

              // Combo
              if (c.player.hasCombo)
                AnimatedBuilder(
                  animation: _comboFlashController,
                  builder: (context, _) => ComboDisplay(
                    player: c.player,
                    isFlashing: isComboFlashing,
                    flashValue: _comboFlashController.value,
                  ),
                ),

              // Pause button
              PauseButton(isPaused: c.gameState.isPaused, onPressed: _togglePause),

              // Music dock (top-left, clear of the HUD's left column
              // which starts ~75px down). The soundtrack continues
              // through gameplay; the playlist editor opens from here.
              MusicDock(
                onOpenPlaylist: () => showPlaylistSheet(context),
              ),

              // Wave notifications (wave-based modes only; Boss Rush's
              // stage banner comes from the boss spawn announcement)
              if (c.config.wavesEnabled && c.gameState.showWaveStart)
                WaveStartNotification(gameState: c.gameState, mode: c.config),
              if (c.config.wavesEnabled && c.gameState.showWaveComplete)
                WaveCompleteNotification(gameState: c.gameState),

              // Overlays
              if (c.gameState.isGameOver)
                GameOverOverlay(
                  gameState: c.gameState,
                  asteroidsDestroyed: c.asteroidsDestroyed,
                  isSaving: _isSavingResults,
                  onRestart: _restartGame,
                  onMainMenu: _goToMainMenu,
                  waveLabel: c.config.waveLabel,
                ),
              if (c.gameState.isPaused)
                PauseOverlay(
                  onResume: _togglePause,
                  onRestart: _restartGame,
                  onQuitToMenu: _confirmQuitToMainMenu,
                  onOpenPlaylist: () => showPlaylistSheet(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bridges [GameCallbacks] to this screen's audio + animation controllers.
class _ScreenCallbacks implements GameCallbacks {
  _ScreenCallbacks(this._state);
  final _GameScreenState _state;

  @override
  void onShoot() => _state._audioService.playShoot();

  @override
  void onExplosion() => _state._audioService.playExplosion();

  @override
  void onPowerUp() => _state._audioService.playPowerUp();

  @override
  void onHit() => _state._audioService.playHit();

  @override
  void onGameOver() => _state._audioService.playGameOver();

  @override
  void onWaveComplete() => _state._audioService.playWaveComplete();

  @override
  void onBossIncoming() => _state._audioService.playHit();

  @override
  void onBossDefeated() => _state._audioService.playExplosion();

  @override
  void onShieldBreak() {}

  @override
  void onShake(double intensity) {
    _state._shakeController.forward(from: 0);
  }

  @override
  void onComboFlash() {
    _state._comboFlashController.forward(from: 0);
  }

  @override
  void onLaserActivated() {
    // Heavy impact — the laser is the game's flashiest power-up.
    HapticFeedback.heavyImpact();
  }

  @override
  void onBossDefeatedHaptic() {
    // A triumphant double-tick for a boss kill.
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.lightImpact();
    });
  }
}
