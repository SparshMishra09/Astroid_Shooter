import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user_progress.dart';
import '../services/user_progress_service.dart';
import '../auth/auth_service.dart';
import '../widgets/loading_screen.dart';
import '../widgets/playlist_widgets.dart';
import 'cutscene_screen.dart';
import 'mode_selection_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  UserProgress? _progress;
  bool _isLoading = true;
  String _displayName = 'Pilot';
  String _email = '';

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadUserInfo();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Load the user's persistent progress from Firestore.
  Future<void> _loadProgress() async {
    try {
      final progress = await UserProgressService.instance.getMyProgress();
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      final name = await AuthService.instance.getDisplayName();
      if (!mounted) return;
      setState(() {
        _displayName = name;
        _email = user.email ?? '';
      });
    }
  }

  void _openModeSelection() {
    // The intro cutscene plays once per app session — the first PLAY
    // of the session watches it (skippable), later PLAYs go straight
    // to mode selection.
    final destination = CutsceneScreen.playedThisSession
        ? const ModeSelectionScreen()
        : const CutsceneScreen();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => destination))
        .then((_) => _loadProgress()); // Refresh stats after returning from game
  }

  void _openLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text('You\'ll need to log in again to play.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.signOut();
      // AuthGate will auto-route back to AuthScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    // While the user's progress is being fetched from Firestore, show the
    // themed loading screen rather than empty/placeholder stats.
    if (_isLoading) {
      return const LoadingScreen(message: 'LOADING PROFILE…');
    }

    final astrids = _progress?.astrids ?? 0;
    final highestWave = _progress?.highestWave ?? 0;
    final totalDestroyed = _progress?.totalAsteroidsDestroyed ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo.shade900],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content (scrollable)
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Game title
                      const Text(
                        'SPACE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'WARS',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Player greeting
                      _buildPlayerGreeting(),
                      const SizedBox(height: 24),

                      // Animated spaceship
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: SvgPicture.asset('assets/images/spaceship.svg',
                                width: 90, height: 90),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Stats cards (astrids, highest wave, total destroyed)
                      _buildStatsRow(astrids, highestWave, totalDestroyed),
                      const SizedBox(height: 30),

                      // Play Game Button
                      _buildPlayButton(),
                      const SizedBox(height: 12),

                      // Leaderboard Button
                      _buildLeaderboardButton(),
                      const SizedBox(height: 20),

                      // Instructions
                      _buildInstructions(),
                    ],
                  ),
                ),
              ),

              // Logout button (top-right corner)
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  tooltip: 'Sign Out',
                  onPressed: _handleLogout,
                ),
              ),

              // Now-playing bar (bottom) — the soundtrack keeps playing
              // everywhere; tapping the chevron opens the playlist editor.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NowPlayingBar(
                  onOpenPlaylist: () => showPlaylistSheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerGreeting() {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'P';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Colors.cyan, Colors.indigo]),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $_displayName',
              style: const TextStyle(
                  color: Colors.cyan, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_email.isNotEmpty)
              Text(
                _email,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }

  /// Three stat cards: Astrids (currency), Highest Wave, Total Destroyed.
  Widget _buildStatsRow(int astrids, int highestWave, int totalDestroyed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.stars,
            iconColor: Colors.amber,
            label: 'ASTRIDS',
            value: '$astrids',
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            icon: Icons.waves,
            iconColor: Colors.orange,
            label: 'HIGHEST WAVE',
            value: '$highestWave',
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            icon: Icons.whatshot,
            iconColor: Colors.red,
            label: 'DESTROYED',
            value: '$totalDestroyed',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _openModeSelection,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
            child: const Text(
              'PLAY',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.cyan.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _openLeaderboard,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.leaderboard, color: Colors.cyan.shade300, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'LEADERBOARD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
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

  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: const Column(
        children: [
          Text(
            'HOW TO PLAY',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            '• Drag to move — your ship fires automatically\n'
            '• Destroy asteroids & enemies for astrids, chain hits\n'
            '  for combo multipliers\n'
            '• Six power-ups: Shield, Rapid Fire, Triple Shot,\n'
            '  Laser, Penta Shot ("^" barrage) & Wing Drones\n'
            '• Power-ups stack — Rapid Fire speeds up Penta Shot!\n'
            '• CLASSIC RUN: survive waves; a boss arrives every 150 kills\n'
            '• BOSS RUSH: nine boss variants back-to-back — break\n'
            '  shields, dodge lasers & bombs, scatter the Swarm Lords\n\n'
            'Every astrid you earn is saved to your account and ranked\n'
            'on the global + per-mode leaderboards!',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
