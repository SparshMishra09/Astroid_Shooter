import 'dart:async';
import 'package:flutter/material.dart';
import '../services/music_player_service.dart';

// ============================================================
//  MUSIC DOCK (top-left, expands horizontally)
// ============================================================

/// A compact music dock pinned to the TOP-LEFT of the screen.
///
/// Collapsed: a small circular button (spinning cover art while music
/// plays) that sits beside the screen's other top-left UI without
/// overlapping it — pass [leftOffset] to shift it clear of existing
/// elements (e.g. the game's back/pause buttons).
///
/// Expanded: animates horizontally into a pill with prev/play-pause/
/// next and a playlist button. Auto-collapses after 6s of inactivity.
class MusicDock extends StatefulWidget {
  const MusicDock({
    super.key,
    this.leftOffset = 0,
    this.onOpenPlaylist,
  });

  /// Horizontal offset from the left edge, so the dock doesn't overlap
  /// other top-left UI (back buttons etc.) when collapsed.
  final double leftOffset;

  /// Opens the full playlist editor sheet.
  final VoidCallback? onOpenPlaylist;

  @override
  State<MusicDock> createState() => _MusicDockState();
}

class _MusicDockState extends State<MusicDock>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    MusicPlayerService.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    MusicPlayerService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _expand() {
    setState(() => _expanded = true);
    _scheduleCollapse();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final music = MusicPlayerService.instance;
    final track = music.currentTrack;

    // Nothing queued — show nothing at all.
    if (track == null) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      left: 12 + widget.leftOffset,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.black.withOpacity(_expanded ? 0.88 : 0.62),
            border: Border.all(
              color: track.color.withOpacity(_expanded ? 0.55 : 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: track.color.withOpacity(_expanded ? 0.35 : 0.25),
                blurRadius: _expanded ? 16 : 10,
              ),
            ],
          ),
          child: _expanded ? _buildExpanded(track) : _buildCollapsed(track),
        ),
      ),
    );
  }

  /// Collapsed: spinning cover button.
  Widget _buildCollapsed(Track track) {
    return GestureDetector(
      onTap: _expand,
      child: _SpinningCover(
        coverPath: track.coverPath,
        accent: track.color,
        isPlaying: MusicPlayerService.instance.isPlaying,
        size: 40,
      ),
    );
  }

  /// Expanded: cover + transport controls + playlist button.
  Widget _buildExpanded(Track track) {
    final music = MusicPlayerService.instance;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cover (tap to collapse)
        GestureDetector(
          onTap: () => setState(() => _expanded = false),
          child: _SpinningCover(
            coverPath: track.coverPath,
            accent: track.color,
            isPlaying: music.isPlaying,
            size: 40,
          ),
        ),

        // Title
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  music.isPlaying ? 'NOW PLAYING' : 'PAUSED',
                  style: TextStyle(
                    color: track.color.withOpacity(0.85),
                    fontSize: 8,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Transport controls
        _DockIcon(
          icon: Icons.skip_previous_rounded,
          onTap: () {
            music.skipPrevious();
            _scheduleCollapse();
          },
        ),
        _PlayPauseButton(
          isPlaying: music.isPlaying,
          accent: track.color,
          size: 30,
          onPressed: () {
            music.togglePause();
            _scheduleCollapse();
          },
        ),
        _DockIcon(
          icon: Icons.skip_next_rounded,
          onTap: () {
            music.skipNext();
            _scheduleCollapse();
          },
        ),
        _DockIcon(
          icon: Icons.queue_music_rounded,
          onTap: () {
            setState(() => _expanded = false);
            widget.onOpenPlaylist?.call();
          },
        ),
      ],
    );
  }
}

/// Small icon button used inside the expanded dock.
class _DockIcon extends StatelessWidget {
  const _DockIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(icon, color: Colors.white.withOpacity(0.85)),
        onPressed: onTap,
      ),
    );
  }
}

/// Cover art that slowly rotates like a vinyl while music plays.
class _SpinningCover extends StatefulWidget {
  const _SpinningCover({
    required this.coverPath,
    required this.accent,
    required this.isPlaying,
    this.size = 44,
  });

  final String coverPath;
  final Color accent;
  final bool isPlaying;
  final double size;

  @override
  State<_SpinningCover> createState() => _SpinningCoverState();
}

class _SpinningCoverState extends State<_SpinningCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.isPlaying) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpinningCover old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.isPlaying && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: RotationTransition(
        turns: _spin,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage(widget.coverPath),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(color: widget.accent.withOpacity(0.4), blurRadius: 8),
            ],
          ),
          // Vinyl center dot
          child: Center(
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.75),
                border: Border.all(color: widget.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.accent,
    required this.onPressed,
    this.size = 40,
  });

  final bool isPlaying;
  final Color accent;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [accent, accent.withOpacity(0.6)]),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 10)],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: child,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            color: Colors.white,
            size: size * 0.65,
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

// ============================================================
//  PLAYLIST EDITOR SHEET
// ============================================================

/// Full-screen playlist editor: reorder (move up/down), deselect
/// tracks (checkboxes), jump to a track, reset to default order.
/// Opens as a bottom sheet with a slide-up transition.
Future<void> showPlaylistSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context) as TickerProvider,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
    ),
    builder: (context) => const PlaylistSheet(),
  );
}

class PlaylistSheet extends StatefulWidget {
  const PlaylistSheet({super.key});

  @override
  State<PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<PlaylistSheet> {
  @override
  void initState() {
    super.initState();
    MusicPlayerService.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    MusicPlayerService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final music = MusicPlayerService.instance;
    final queued = music.playlist;
    final current = music.currentTrack;
    final screenHeight = MediaQuery.of(context).size.height;

    // Deselected tracks sit below the queue so they can be re-added.
    final queuedIds = queued.map((t) => t.id).toSet();
    final deselected =
        musicLibrary.where((t) => !queuedIds.contains(t.id)).toList();

    return Container(
      height: screenHeight * 0.82,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E).withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: current?.color.withOpacity(0.4) ?? Colors.white24, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Grab handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.queue_music_rounded,
                    color: current?.color ?? Colors.cyan, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PLAYLIST · ${queued.length} TRACKS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => music.resetPlaylist(),
                  icon: const Icon(Icons.restart_alt_rounded,
                      size: 16, color: Colors.white54),
                  label: const Text(
                    'RESET',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.white.withOpacity(0.08)),

          // Track list: the queue (in order), then a divider, then the
          // deselected tracks available to re-add.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: queued.length + (deselected.isEmpty ? 0 : deselected.length + 1),
              itemBuilder: (context, index) {
                if (index < queued.length) {
                  final track = queued[index];
                  final isCurrent = current?.id == track.id;
                  return _PlaylistRow(
                    track: track,
                    isCurrent: isCurrent,
                    isSelected: true,
                    canMoveUp: index > 0,
                    canMoveDown: index < queued.length - 1,
                    onPlay: () => music.playTrack(track.id),
                    onMoveUp: () => music.moveTrack(track.id, -1),
                    onMoveDown: () => music.moveTrack(track.id, 1),
                    onDeselect: () => music.toggleTrack(track.id),
                  );
                }

                // Deselected section divider
                final di = index - queued.length;
                if (di == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                              height: 1, color: Colors.white.withOpacity(0.08)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'NOT IN PLAYLIST — TAP + TO ADD',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                              height: 1, color: Colors.white.withOpacity(0.08)),
                        ),
                      ],
                    ),
                  );
                }

                final track = deselected[di - 1];
                return _PlaylistRow(
                  track: track,
                  isCurrent: false,
                  isSelected: false,
                  canMoveUp: false,
                  canMoveDown: false,
                  onPlay: () => music.toggleTrack(track.id),
                  onMoveUp: () {},
                  onMoveDown: () {},
                  onDeselect: () => music.toggleTrack(track.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the playlist editor: cover, title, playing indicator,
/// reorder arrows, and a select/deselect toggle. Deselected rows are
/// dimmed with a "+" affordance.
class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.track,
    required this.isCurrent,
    required this.isSelected,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onPlay,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDeselect,
  });

  final Track track;
  final bool isCurrent;
  final bool isSelected;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onPlay;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDeselect;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? track.color.withOpacity(0.12)
            : Colors.white.withOpacity(isSelected ? 0.03 : 0.015),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? track.color.withOpacity(0.5)
              : Colors.white.withOpacity(isSelected ? 0.06 : 0.03),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Opacity(
        opacity: isSelected ? 1.0 : 0.45,
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 10, right: 4),
          leading: GestureDetector(
            onTap: onPlay,
            child: _RowCover(
              coverPath: track.coverPath,
              accent: track.color,
              isCurrent: isCurrent,
            ),
          ),
          title: GestureDetector(
            onTap: onPlay,
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? track.color : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          subtitle: Text(
            isCurrent
                ? 'PLAYING NOW'
                : isSelected
                    ? track.artist
                    : 'not in playlist',
            style: TextStyle(
              color: isCurrent
                  ? track.color.withOpacity(0.8)
                  : Colors.white.withOpacity(0.35),
              fontSize: 11,
              letterSpacing: isCurrent ? 1.2 : 0,
            ),
          ),
          // Reorder arrows (queued rows only) + select/deselect toggle
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ArrowButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      enabled: canMoveUp,
                      onTap: onMoveUp,
                    ),
                    _ArrowButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      enabled: canMoveDown,
                      onTap: onMoveDown,
                    ),
                  ],
                ),
              // Toggle: check (remove) for queued rows, + (add) for the rest.
              IconButton(
                icon: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: isSelected ? track.color : Colors.white54,
                  size: 22,
                ),
                onPressed: onDeselect,
                tooltip: isSelected ? 'Remove from playlist' : 'Add to playlist',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small cover in a playlist row with an equalizer overlay when playing.
class _RowCover extends StatelessWidget {
  const _RowCover({
    required this.coverPath,
    required this.accent,
    required this.isCurrent,
  });

  final String coverPath;
  final Color accent;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: AssetImage(coverPath), fit: BoxFit.cover),
        border: Border.all(
          color: isCurrent ? accent : Colors.white.withOpacity(0.15),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: isCurrent
          ? Center(
              child: Icon(Icons.graphic_eq_rounded,
                  color: accent, size: 18),
            )
          : null,
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(
          icon,
          color: enabled ? Colors.white54 : Colors.white.withOpacity(0.12),
        ),
        onPressed: enabled ? onTap : null,
      ),
    );
  }
}
