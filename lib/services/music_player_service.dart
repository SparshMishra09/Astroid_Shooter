import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

/// One track in the music library.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.assetPath,
    required this.coverPath,
    required this.color,
  });

  final String id;
  final String title;
  final String artist;
  final String assetPath;
  final String coverPath;

  /// Accent color for the playlist UI (matches the cover's mood).
  final Color color;
}

/// The game's soundtrack library — track order here is the default
/// playlist order (Afterburner Ascent leads by design).
const List<Track> musicLibrary = [
  Track(
    id: 'afterburner_ascent',
    title: 'Afterburner Ascent',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Afterburner_Ascent.m4a',
    coverPath: 'assets/audio/covers/Afterburner_Ascent.jpg',
    color: Color(0xFF22D3EE),
  ),
  Track(
    id: 'interceptor_burn',
    title: 'Interceptor Burn',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Interceptor_Burn.m4a',
    coverPath: 'assets/audio/covers/Interceptor_Burn.jpg',
    color: Color(0xFFF59E0B),
  ),
  Track(
    id: 'titan_approach',
    title: 'Titan Approach',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Titan_Approach.m4a',
    coverPath: 'assets/audio/covers/Titan_Approach.jpg',
    color: Color(0xFF8B5CF6),
  ),
  Track(
    id: 'terminal_velocity_shift',
    title: 'Terminal Velocity Shift',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Terminal_Velocity_Shift.m4a',
    coverPath: 'assets/audio/covers/Terminal_Velocity_Shift.jpg',
    color: Color(0xFFEF4444),
  ),
  Track(
    id: 'armor_piercing',
    title: 'Armor Piercing',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Armor_Piercing.m4a',
    coverPath: 'assets/audio/covers/Armor_Piercing.jpg',
    color: Color(0xFF10B981),
  ),
  Track(
    id: 'breach_point',
    title: 'Breach Point',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Breach_Point.m4a',
    coverPath: 'assets/audio/covers/Breach_Point.jpg',
    color: Color(0xFF3B82F6),
  ),
  Track(
    id: 'last_starship_standing',
    title: 'Last Starship Standing',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Last_Starship_Standing.m4a',
    coverPath: 'assets/audio/covers/Last_Starship_Standing.jpg',
    color: Color(0xFFF43F5E),
  ),
  Track(
    id: 'thirty_seconds_to_impact',
    title: 'Thirty Seconds To Impact',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Thirty_Seconds_To_Impact.m4a',
    coverPath: 'assets/audio/covers/Thirty_Seconds_To_Impact.jpg',
    color: Color(0xFFF97316),
  ),
  Track(
    id: 'titan_overdrive',
    title: 'Titan Overdrive',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Titan_Overdrive.m4a',
    coverPath: 'assets/audio/covers/Titan_Overdrive.jpg',
    color: Color(0xFFD946EF),
  ),
  Track(
    id: 'hull_breach_detected',
    title: 'Hull Breach Detected',
    artist: 'Space Wars OST',
    assetPath: 'assets/audio/Hull_Breach_Detected.m4a',
    coverPath: 'assets/audio/covers/Hull_Breach_Detected.jpg',
    color: Color(0xFF64748B),
  ),
];

/// Singleton music player: a persistent Spotify-style playlist for the
/// game's soundtrack.
///
/// Behavior:
/// - Auto-starts on first [initialize] call and keeps playing across
///   ALL screens (auth, home, gameplay) until the app closes.
/// - The playlist is an ordered queue of track ids; when the last song
///   ends it loops back to the first.
/// - Players can reorder (move a track up/down) and deselect tracks;
///   deselecting everything pauses the player. The playlist is
///   persisted to SharedPreferences and restored on launch.
/// - [onTrackChanged] listeners drive the now-playing UI.
class MusicPlayerService {
  MusicPlayerService._internal();
  static final MusicPlayerService instance = MusicPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _completedSub;

  /// Ordered queue of track ids (the playlist). Empty = all deselected.
  List<String> _queue = musicLibrary.map((t) => t.id).toList();

  /// Index into [_queue] of the currently playing track.
  int _currentIndex = 0;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Track? get currentTrack {
    if (_queue.isEmpty || _currentIndex >= _queue.length) return null;
    return musicLibrary.firstWhere((t) => t.id == _queue[_currentIndex]);
  }

  /// Notifies the now-playing UI on track/play-state changes.
  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  /// The user's playlist, in order — full [Track] objects.
  List<Track> get playlist =>
      _queue.map((id) => musicLibrary.firstWhere((t) => t.id == id)).toList();

  bool isQueued(String trackId) => _queue.contains(trackId);

  // -------------------------------------------------------------------------
  //  Lifecycle
  // -------------------------------------------------------------------------

  /// Load the persisted playlist and (re)start playback. Called once
  /// from the app root so music spans every screen.
  Future<void> initialize() async {
    if (_isPlaying) return; // already running

    await _loadPersistedQueue();
    _completedSub ??= _player.onPlayerComplete.listen((_) {
      _playNext(autoAdvance: true);
    });
    if (_queue.isNotEmpty) {
      await _playCurrent();
    }
  }

  Future<void> _loadPersistedQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('music_playlist');
      // Validate saved ids against the library (tracks may change).
      final valid = saved?.where((id) => musicLibrary.any((t) => t.id == id)).toList();
      if (valid != null && valid.isNotEmpty) {
        // Keep library tracks missing from the save appended at the end
        // so nothing silently disappears.
        final missing = musicLibrary
            .map((t) => t.id)
            .where((id) => !valid.contains(id))
            .toList();
        _queue = [...valid, ...missing];
      }
    } catch (e) {
      debugPrint('MusicPlayerService queue load error: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('music_playlist', _queue);
    } catch (e) {
      debugPrint('MusicPlayerService queue save error: $e');
    }
  }

  // -------------------------------------------------------------------------
  //  Playback
  // -------------------------------------------------------------------------

  Future<void> _playCurrent() async {
    final track = currentTrack;
    if (track == null) {
      await _player.stop();
      _isPlaying = false;
      _notify();
      return;
    }
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      // audioplayers' AssetSource resolves relative to its own 'assets/'
      // prefix — passing the full 'assets/audio/...' path would double
      // the prefix and fail to find the file, so strip it here.
      final relative = track.assetPath.replaceFirst('assets/', '');
      await _player.play(AssetSource(relative));
      _isPlaying = true;
    } catch (e) {
      debugPrint('MusicPlayerService play error: $e');
      _isPlaying = false;
    }
    _notify();
  }

  /// Advance to the next track; wraps to the start after the last one.
  /// When every track is deselected there is nothing to advance to.
  Future<void> _playNext({bool autoAdvance = false}) async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      _notify();
      return;
    }
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await _playCurrent();
  }

  Future<void> _playPrevious() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await _playCurrent();
  }

  Future<void> skipNext() => _playNext();
  Future<void> skipPrevious() => _playPrevious();

  Future<void> togglePause() async {
    if (_queue.isEmpty) return;
    if (_isPlaying) {
      await _player.pause();
      _isPlaying = false;
    } else {
      if (currentTrack == null) {
        _currentIndex = 0;
        await _playCurrent();
      } else {
        await _player.resume();
        _isPlaying = true;
      }
    }
    _notify();
  }

  /// Jump straight to a queued track.
  Future<void> playTrack(String trackId) async {
    final index = _queue.indexOf(trackId);
    if (index == -1) return;
    _currentIndex = index;
    await _playCurrent();
  }

  // -------------------------------------------------------------------------
  //  Playlist editing (auto-persists)
  // -------------------------------------------------------------------------

  /// Move a track one slot up (-1) or down (+1) in the queue.
  Future<void> moveTrack(String trackId, int delta) async {
    final i = _queue.indexOf(trackId);
    final j = i + delta;
    if (i == -1 || j < 0 || j >= _queue.length) return;
    final playingId = currentTrack?.id;

    final id = _queue.removeAt(i);
    _queue.insert(j, id);

    // Keep the currently-playing track selected if it moved.
    if (playingId != null) {
      _currentIndex = _queue.indexOf(playingId).clamp(0, _queue.length - 1);
    }
    await _persistQueue();
    _notify();
  }

  /// Toggle a track in/out of the queue. Re-adding appends it to the
  /// end. Removing the playing track advances to the next one.
  Future<void> toggleTrack(String trackId) async {
    final i = _queue.indexOf(trackId);
    if (i != -1) {
      final wasPlaying = i == _currentIndex;
      final playingId = currentTrack?.id;
      _queue.removeAt(i);
      if (wasPlaying) {
        // The playing track was removed — play what took its slot (or
        // stop if the queue is now empty).
        if (_currentIndex >= _queue.length) _currentIndex = 0;
        if (_queue.isEmpty) {
          await _player.stop();
          _isPlaying = false;
        } else {
          await _playCurrent();
        }
      } else {
        // Keep the currently-playing track selected.
        if (playingId != null) {
          _currentIndex = _queue.indexOf(playingId).clamp(0, _queue.length - 1);
        }
      }
    } else {
      _queue.add(trackId);
      // If nothing was playing (all were deselected), start the restored
      // track immediately.
      if (_queue.length == 1) {
        _currentIndex = 0;
        await _playCurrent();
      }
    }
    await _persistQueue();
    _notify();
  }

  /// Restore the default playlist order (all tracks, library order).
  Future<void> resetPlaylist() async {
    _queue = musicLibrary.map((t) => t.id).toList();
    _currentIndex = 0;
    await _persistQueue();
    await _playCurrent();
  }

  /// Duration / position streams for the seek bar.
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  Future<void> dispose() async {
    await _completedSub?.cancel();
    await _player.dispose();
  }
}
