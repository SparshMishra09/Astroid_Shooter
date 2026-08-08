import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Audio players
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  
  // Settings
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _sfxVolume = 0.7;
  double _musicVolume = 0.3;

  // Initialize audio service
  Future<void> initialize() async {
    // Set up music player for looping
    await _musicPlayer.setPlayerMode(PlayerMode.mediaPlayer);
  }

  // Sound effects
  Future<void> playShoot() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/shoot.wav'),
        volume: _sfxVolume * 0.3, // Lower volume for frequent sound
      );
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  Future<void> playExplosion() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/explosion.wav'),
        volume: _sfxVolume,
      );
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  Future<void> playPowerUp() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/powerup.wav'),
        volume: _sfxVolume,
      );
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  Future<void> playHit() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/hit.wav'),
        volume: _sfxVolume,
      );
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  Future<void> playGameOver() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/gameover.wav'),
        volume: _sfxVolume,
      );
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  Future<void> playWaveComplete() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/wave_complete.wav'),
        volume: _sfxVolume,
      );
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  Future<void> playMenuClick() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/menu_click.wav'),
        volume: _sfxVolume * 0.8,
      );
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  // Background music
  Future<void> playBackgroundMusic() async {
    if (!_musicEnabled) return;
    try {
      await _musicPlayer.play(
        AssetSource('audio/background_music.mp3'),
        volume: _musicVolume,
      );
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      // Silently handle missing audio files
    }
  }

  Future<void> stopBackgroundMusic() async {
    await _musicPlayer.stop();
  }

  Future<void> pauseBackgroundMusic() async {
    await _musicPlayer.pause();
  }

  Future<void> resumeBackgroundMusic() async {
    await _musicPlayer.resume();
  }

  // Settings
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  double get sfxVolume => _sfxVolume;
  double get musicVolume => _musicVolume;

  set soundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  set musicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      stopBackgroundMusic();
    } else {
      playBackgroundMusic();
    }
  }

  set sfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
  }

  set musicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    _musicPlayer.setVolume(_musicVolume);
  }

  // Cleanup
  Future<void> dispose() async {
    await _sfxPlayer.dispose();
    await _musicPlayer.dispose();
  }
}
