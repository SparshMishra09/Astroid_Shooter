import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/enums.dart';
import '../models/user_progress.dart';
import '../services/user_progress_service.dart';

/// Space-themed leaderboard: a global board plus one board per game mode.
///
/// Landing view:
/// - HIGHEST ASTRIDS — total astrids earned across ALL modes (currency).
/// - Cards for each game mode's leaderboard.
///
/// Classic Run board: best score / highest wave / asteroids destroyed
/// (classic games only).
///
/// Boss Rush board: best score / highest boss reached / bosses defeated
/// (boss rush games only).
///
/// All boards are StreamBuilders so they update in real-time when
/// players finish games.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

/// One sortable metric of a leaderboard board.
class _Metric {
  const _Metric(this.field, this.label, this.value);

  /// Firestore field to order by.
  final String field;

  /// Chip label shown to the player.
  final String label;

  /// Formats a player's value for the metric badge in their row.
  final String Function(UserProgress player) value;
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  /// null = landing view (global astrids + mode cards).
  GameMode? _selectedMode;
  String _orderBy = 'astrids';

  /// Cached so the "your rank" FutureBuilder doesn't refetch on every
  /// stream emission; reset when the view or metric changes.
  Future<UserProgress?>? _myProgressFuture;

  List<_Metric> get _metrics {
    if (_selectedMode == null) {
      return [
        _Metric('astrids', 'ASTRIDS', (p) => '${p.astrids}'),
      ];
    }
    switch (_selectedMode!) {
      case GameMode.classicRun:
        return [
          _Metric('classicBestScore', 'BEST SCORE', (p) => '${p.classicBestScore}'),
          _Metric('classicHighestWave', 'HIGHEST WAVE', (p) => 'Wave ${p.classicHighestWave}'),
          _Metric('classicAsteroidsDestroyed', 'ASTEROIDS DESTROYED', (p) => '${p.classicAsteroidsDestroyed}'),
        ];
      case GameMode.bossRush:
        return [
          _Metric('bossRushBestScore', 'BEST SCORE', (p) => '${p.bossRushBestScore}'),
          _Metric('bossRushHighestWave', 'HIGHEST BOSS', (p) => 'Boss ${p.bossRushHighestWave}'),
          _Metric('bossRushBossesDefeated', 'BOSSES DEFEATED', (p) => '${p.bossRushBossesDefeated}'),
        ];
    }
  }

  _Metric get _metric =>
      _metrics.firstWhere((m) => m.field == _orderBy, orElse: () => _metrics.first);

  void _openMode(GameMode mode) {
    setState(() {
      _selectedMode = mode;
      _orderBy = _metrics.first.field;
      _myProgressFuture = null;
    });
  }

  void _backToLanding() {
    setState(() {
      _selectedMode = null;
      _orderBy = 'astrids';
      _myProgressFuture = null;
    });
  }

  void _selectMetric(String field) {
    setState(() {
      _orderBy = field;
      _myProgressFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo.shade900.withOpacity(0.7), Colors.black],
          ),
        ),
        child: SafeArea(
          child: _selectedMode == null ? _buildLanding() : _buildModeView(),
        ),
      ),
    );
  }

  // =========================================================================
  //  LANDING VIEW — global astrids board + game-mode cards
  // =========================================================================

  Widget _buildLanding() {
    return Column(
      children: [
        _buildHeader(
          icon: Icons.leaderboard,
          iconColor: Colors.amber.shade300,
          title: 'LEADERBOARD',
          onBack: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildSectionTitle(
                icon: Icons.stars,
                color: Colors.amber,
                title: 'HIGHEST ASTRIDS',
                subtitle: 'Total astrids earned — every game mode counts',
              ),
              const SizedBox(height: 8),
              // The global board renders directly (no section chips).
              _buildBoard(limit: 10),
              const SizedBox(height: 20),
              _buildDivider('GAME MODES'),
              const SizedBox(height: 12),
              _buildModeCard(
                mode: GameMode.classicRun,
                icon: Icons.travel_explore,
                iconColor: Colors.cyan,
                gradient: const [Color(0xFF0E7490), Color(0xFF155E75)],
                title: 'CLASSIC RUN',
                subtitle: 'Best Score · Highest Wave · Asteroids Destroyed',
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                mode: GameMode.bossRush,
                icon: Icons.local_fire_department,
                iconColor: Colors.red,
                gradient: const [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                title: 'BOSS RUSH',
                subtitle: 'Best Score · Highest Boss · Bosses Defeated',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  //  MODE VIEW — section chips + ranked list
  // =========================================================================

  Widget _buildModeView() {
    final isClassic = _selectedMode == GameMode.classicRun;
    return Column(
      children: [
        _buildHeader(
          icon: isClassic ? Icons.travel_explore : Icons.local_fire_department,
          iconColor: isClassic ? Colors.cyan : Colors.red,
          title: isClassic ? 'CLASSIC RUN' : 'BOSS RUSH',
          onBack: _backToLanding,
        ),
        // === Section chips ===
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in _metrics) ...[
                  _buildSortChip(m),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSectionTitle(
            icon: Icons.emoji_events,
            color: isClassic ? Colors.cyan : Colors.red,
            title: _metric.label,
            subtitle: isClassic ? 'Classic Run games only' : 'Boss Rush games only',
          ),
        ),
        const SizedBox(height: 8),
        // === Ranked list ===
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [_buildBoard()],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  //  SHARED PIECES
  // =========================================================================

  Widget _buildHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required GameMode mode,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradient,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(color: iconColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: iconColor.withOpacity(0.25), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMode(mode),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: iconColor.withOpacity(0.6), width: 2),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: iconColor.withOpacity(0.8), size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(_Metric metric) {
    final isActive = _orderBy == metric.field;
    return GestureDetector(
      onTap: () => _selectMetric(metric.field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.amber.withOpacity(0.6) : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          metric.label,
          style: TextStyle(
            color: isActive ? Colors.amber : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// The ranked list for the current view/metric.
  Widget _buildBoard({int limit = 50}) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final metric = _metric;

    return StreamBuilder<List<UserProgress>>(
      stream: UserProgressService.instance.getLeaderboardStream(
        limit: limit,
        orderBy: metric.field,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: Colors.cyan, strokeWidth: 3),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final players = snapshot.data ?? [];

        if (players.isEmpty) {
          return _buildEmptyState();
        }

        // Find current user's position (they might not be in the top N)
        final myIndex = players.indexWhere((p) => p.uid == currentUid);

        return Column(
          children: [
            for (int i = 0; i < players.length; i++)
              _buildPlayerRow(
                players[i],
                i + 1,
                isMe: players[i].uid == currentUid,
                metricValue: metric.value(players[i]),
              ),
            if (myIndex == -1)
              FutureBuilder<UserProgress?>(
                future: _myProgressFuture ??= _loadMyProgress(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildDivider('YOUR RANK'),
                      const SizedBox(height: 8),
                      _buildPlayerRow(
                        snap.data!,
                        -1,
                        isMe: true,
                        metricValue: metric.value(snap.data!),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<UserProgress?> _loadMyProgress() async {
    try {
      return await UserProgressService.instance.getMyProgress();
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlayerRow(
    UserProgress player,
    int rank, {
    required bool isMe,
    required String metricValue,
  }) {
    final initial = player.displayName.isNotEmpty
        ? player.displayName[0].toUpperCase()
        : 'P';

    // Rank-based styling for top 3
    Color? rankColor;
    IconData? rankIcon;
    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade300;
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.orange.shade700;
      rankIcon = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.cyan.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.cyan.withOpacity(0.5) : Colors.white.withOpacity(0.08),
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: isMe
            ? [BoxShadow(color: Colors.cyan.withOpacity(0.1), blurRadius: 8)]
            : null,
      ),
      child: Row(
        children: [
          // Rank number / medal
          SizedBox(
            width: 36,
            child: rank == -1
                ? Text('—',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center)
                : rankIcon != null
                    ? Icon(rankIcon, color: rankColor, size: 24)
                    : Text(
                        '$rank',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isMe
                    ? [Colors.cyan, Colors.blue.shade700]
                    : [Colors.indigo, Colors.indigo.shade800],
              ),
              border: Border.all(
                color: isMe ? Colors.cyan.withOpacity(0.6) : Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + secondary stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${player.displayName} (You)' : player.displayName,
                  style: TextStyle(
                    color: isMe ? Colors.cyan : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _buildSecondaryStats(player),
              ],
            ),
          ),

          // Primary metric (what we're sorting by)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: rankColor?.withOpacity(0.1) ?? Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              metricValue,
              style: TextStyle(
                color: rankColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small flavor stats under each name — the metric badge already shows
  /// the ranked stat, so these show cross-mode context instead.
  Widget _buildSecondaryStats(UserProgress player) {
    final List<Widget> stats = [];

    // Astrids (unless it IS the ranked metric)
    if (_metric.field != 'astrids') {
      stats.addAll([
        Icon(Icons.stars, size: 11, color: Colors.amber.withOpacity(0.6)),
        const SizedBox(width: 3),
        Text(
          '${player.astrids}',
          style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 11),
        ),
        const SizedBox(width: 10),
      ]);
    }

    switch (_selectedMode) {
      case null:
        // Global view: one stat per mode.
        stats.addAll([
          Icon(Icons.waves, size: 11, color: Colors.orange.withOpacity(0.6)),
          const SizedBox(width: 3),
          Text(
            'W${player.classicHighestWave}',
            style: TextStyle(color: Colors.orange.withOpacity(0.7), fontSize: 11),
          ),
          const SizedBox(width: 10),
          Icon(Icons.local_fire_department, size: 11, color: Colors.red.withOpacity(0.6)),
          const SizedBox(width: 3),
          Text(
            'B${player.bossRushBossesDefeated}',
            style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 11),
          ),
        ]);
        break;
      case GameMode.classicRun:
        stats.addAll([
          Icon(Icons.waves, size: 11, color: Colors.orange.withOpacity(0.6)),
          const SizedBox(width: 3),
          Text(
            'W${player.classicHighestWave}',
            style: TextStyle(color: Colors.orange.withOpacity(0.7), fontSize: 11),
          ),
        ]);
        break;
      case GameMode.bossRush:
        stats.addAll([
          Icon(Icons.local_fire_department, size: 11, color: Colors.red.withOpacity(0.6)),
          const SizedBox(width: 3),
          Text(
            'B${player.bossRushBossesDefeated}',
            style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 11),
          ),
        ]);
        break;
    }

    return Row(children: stats);
  }

  Widget _buildDivider(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rocket_launch, size: 48, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            'No pilots yet!',
            style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to make the leaderboard.',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: Colors.red.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'Could not load leaderboard',
            style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your internet connection and try again.',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
