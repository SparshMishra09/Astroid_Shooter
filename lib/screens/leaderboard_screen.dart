import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_progress.dart';
import '../services/user_progress_service.dart';

/// Space-themed leaderboard screen showing top players ranked by the
/// selected metric. Uses a StreamBuilder so the list updates in real-time
/// when players finish games.
///
/// Sort categories:
/// - Best Score (total astrids from best single game)
/// - Highest Wave (highest wave reached in a single game)
/// - Total Destroyed (total asteroids destroyed across all games)
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  /// Which metric to rank by.
  String _orderBy = 'bestScore';

  String get _orderByLabel {
    switch (_orderBy) {
      case 'bestScore':
        return 'BEST SCORE';
      case 'highestWave':
        return 'HIGHEST WAVE';
      case 'totalAsteroidsDestroyed':
        return 'TOTAL DESTROYED';
      default:
        return 'BEST SCORE';
    }
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
          child: Column(
            children: [
              // === Header ===
              _buildHeader(),
              // === Sort tabs ===
              _buildSortTabs(),
              const SizedBox(height: 8),
              // === Leaderboard list ===
              Expanded(child: _buildLeaderboardList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Icon(Icons.leaderboard, color: Colors.amber.shade300, size: 28),
          const SizedBox(width: 10),
          const Text(
            'LEADERBOARD',
            style: TextStyle(
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

  Widget _buildSortTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildSortChip('bestScore', 'BEST SCORE'),
          const SizedBox(width: 8),
          _buildSortChip('highestWave', 'HIGHEST WAVE'),
          const SizedBox(width: 8),
          _buildSortChip('totalAsteroidsDestroyed', 'TOTAL DESTROYED'),
        ],
      ),
    );
  }

  Widget _buildSortChip(String field, String label) {
    final isActive = _orderBy == field;
    return GestureDetector(
      onTap: () => setState(() => _orderBy = field),
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
          label,
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

  Widget _buildLeaderboardList() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<UserProgress>>(
      stream: UserProgressService.instance.getLeaderboardStream(
        limit: 50,
        orderBy: _orderBy,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyan, strokeWidth: 3),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final players = snapshot.data ?? [];

        if (players.isEmpty) {
          return _buildEmptyState();
        }

        // Find current user's position (they might not be in the top 50)
        final myIndex = players.indexWhere((p) => p.uid == currentUid);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: players.length + (myIndex == -1 ? 1 : 0),
          itemBuilder: (context, index) {
            // If current user isn't in the top 50, show their card at the end
            if (myIndex == -1 && index == players.length) {
              return FutureBuilder<UserProgress?>(
                future: _loadMyProgress(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildDivider('YOUR RANK'),
                      const SizedBox(height: 8),
                      _buildPlayerRow(snap.data!, -1, isMe: true),
                    ],
                  );
                },
              );
            }

            final player = players[index];
            final isMe = player.uid == currentUid;
            return _buildPlayerRow(player, index + 1, isMe: isMe);
          },
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

  Widget _buildPlayerRow(UserProgress player, int rank, {required bool isMe}) {
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

    // The metric value to display based on current sort
    final String metricValue;
    switch (_orderBy) {
      case 'bestScore':
        metricValue = '${player.bestScore}';
        break;
      case 'highestWave':
        metricValue = 'Wave ${player.highestWave}';
        break;
      case 'totalAsteroidsDestroyed':
        metricValue = '${player.totalAsteroidsDestroyed}';
        break;
      default:
        metricValue = '${player.bestScore}';
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
                Row(
                  children: [
                    Icon(Icons.stars, size: 11, color: Colors.amber.withOpacity(0.6)),
                    const SizedBox(width: 3),
                    Text(
                      '${player.astrids}',
                      style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.waves, size: 11, color: Colors.orange.withOpacity(0.6)),
                    const SizedBox(width: 3),
                    Text(
                      'W${player.highestWave}',
                      style: TextStyle(color: Colors.orange.withOpacity(0.7), fontSize: 11),
                    ),
                  ],
                ),
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
    return Center(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
      ),
    );
  }
}
