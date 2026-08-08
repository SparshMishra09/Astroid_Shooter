import 'dart:math';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../config/palette.dart';

/// Space-themed authentication screen with login + signup tabs and a
/// Google Sign-In button.
///
/// Visual identity: deep-space gradient, animated parallax starfield,
/// glowing neon accents (cyan + amber), and a custom animated tab bar
/// with a sliding glow indicator. Matches the game's identity.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Animations
  late AnimationController _starController;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _errorMessage = null;
        });
      }
    });

    // Slow continuous star drift
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Pulsing glow for title + accents
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _starController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isLogin = _tabController.index == 0;
      if (isLogin) {
        await AuthService.instance.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await AuthService.instance.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
      }
      // AuthGate will automatically route to HomeScreen on success
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signInWithGoogle();
      // AuthGate will automatically route to HomeScreen on success
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign-in failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // === Animated starfield background ===
          _StarfieldBackground(animation: _starController),

          // === Foreground content ===
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),

                      // === Title ===
                      _buildTitle(),
                      const SizedBox(height: 6),

                      // Subtitle
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          return Text(
                            _tabController.index == 0
                                ? 'Sign in to continue your mission'
                                : 'Create an account to begin',
                            style: TextStyle(
                              color: Colors.cyan.withOpacity(0.65),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // === Glowing Tab Bar ===
                      _buildGlowTabBar(),
                      const SizedBox(height: 24),

                      // === Form Fields ===
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          return Column(
                            children: [
                              if (_tabController.index == 1) ...[
                                _buildTextField(
                                  controller: _nameController,
                                  hint: 'Pilot Callsign',
                                  icon: Icons.person_outline,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Enter a callsign'
                                      : null,
                                ),
                                const SizedBox(height: 14),
                              ],
                              _buildTextField(
                                controller: _emailController,
                                hint: 'Email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: _passwordController,
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                obscure: _obscurePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                validator: _validatePassword,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // === Error Message ===
                      if (_errorMessage != null) _buildErrorMessage(),

                      const SizedBox(height: 12),

                      // === Submit Button ===
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) => _buildSubmitButton(),
                      ),
                      const SizedBox(height: 22),

                      // === Divider ===
                      _buildDivider(),
                      const SizedBox(height: 22),

                      // === Google Sign-In ===
                      _buildGoogleButton(),

                      const SizedBox(height: 28),

                      // === Footer ===
                      Text(
                        'SPACE WARS v2.2',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === Widget Builders ===

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        return Column(
          children: [
            // Glowing rocket icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.amber.withOpacity(0.4 * _glowAnim.value),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.2 * _glowAnim.value),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.rocket_launch,
                color: Colors.amber,
                size: 40,
                shadows: [
                  Shadow(
                    color: Colors.amber.withOpacity(_glowAnim.value),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // SPACE
            Text(
              'SPACE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                shadows: [
                  Shadow(
                    color: Colors.cyan.withOpacity(0.8 * _glowAnim.value),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: Colors.cyan.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // WARS
            Text(
              'WARS',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                shadows: [
                  Shadow(
                    color: Colors.orange.withOpacity(0.8 * _glowAnim.value),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Custom glowing tab bar with an animated sliding indicator.
  /// The active tab gets a neon glow; the indicator slides smoothly.
  Widget _buildGlowTabBar() {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;
              final slideAnim = _tabController.animation!;
              final offset = slideAnim.value * tabWidth;

              return Stack(
                children: [
                  // Sliding glow indicator
                  Positioned(
                    left: offset,
                    top: 4,
                    bottom: 4,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          colors: [
                            Palette.waveNotifyStart.withOpacity(0.35),
                            Palette.waveNotifyEnd.withOpacity(0.45),
                          ],
                        ),
                        border: Border.all(
                          color: Palette.waveNotifyStart.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.waveNotifyStart.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tab labels
                  Row(
                    children: [
                      _buildTabLabel('LOGIN', 0),
                      _buildTabLabel('SIGN UP', 1),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTabLabel(String label, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (context, _) {
              // Compute "activeness" for this tab (0..1)
              final double activeness;
              if (index == 0) {
                activeness = 1.0 - _tabController.animation!.value;
              } else {
                activeness = _tabController.animation!.value;
              }
              return Text(
                label,
                style: TextStyle(
                  color: Color.lerp(
                    Colors.white38,
                    Colors.white,
                    activeness,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: activeness > 0.5
                      ? [
                          Shadow(
                            color: Colors.cyan.withOpacity(activeness * 0.8),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.cyan,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: Colors.cyan.withOpacity(0.6), size: 22),
          suffixIcon: suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isLogin = _tabController.index == 0;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: isLogin
                ? [Colors.amber, Colors.orange.shade700]
                : [Colors.cyan, Colors.blue.shade700],
          ),
          boxShadow: [
            BoxShadow(
              color: (isLogin ? Colors.amber : Colors.cyan).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isLoading ? null : _handleEmailAuth,
            child: Center(
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.black.withOpacity(0.7),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      isLogin ? 'LAUNCH MISSION' : 'CREATE ACCOUNT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: isLogin
                            ? Colors.black.withOpacity(0.85)
                            : Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.15),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isLoading ? null : _handleGoogleSignIn,
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google "G" logo — official multi-color
                        _GoogleLogo(size: 22),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // === Validators ===

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email';
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Animated starfield background — lightweight CustomPaint with a
// parallax star field, nebula glow, and slow drift. No per-frame
// widget allocation.
// ═══════════════════════════════════════════════════════════════════

class _StarfieldBackground extends StatelessWidget {
  final Animation<double> animation;
  const _StarfieldBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return CustomPaint(
            painter: _AuthStarfieldPainter(animation.value),
            child: Container(),
          );
        },
      ),
    );
  }
}

class _AuthStarfieldPainter extends CustomPainter {
  final double t; // 0..1 animation progress
  _AuthStarfieldPainter(this.t);

  // Seeded star positions — stable across repaints
  static List<_Star>? _stars1;
  static List<_Star>? _stars2;
  static List<_Star>? _stars3;

  void _ensureStars(Size size) {
    if (_stars1 != null) return;
    final r1 = Random(42);
    final r2 = Random(99);
    final r3 = Random(137);
    _stars1 = List.generate(25, (_) => _Star(
          r1.nextDouble() * 400, // x (will scale)
          r1.nextDouble(),
          1.5 + r1.nextDouble() * 1.5,
        ));
    _stars2 = List.generate(40, (_) => _Star(
          r2.nextDouble() * 400,
          r2.nextDouble(),
          1.0 + r2.nextDouble() * 1.0,
        ));
    _stars3 = List.generate(70, (_) => _Star(
          r3.nextDouble() * 400,
          r3.nextDouble(),
          0.5 + r3.nextDouble() * 0.8,
        ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ensureStars(size);

    // Deep space gradient background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.3),
        radius: 1.5,
        colors: [
          const Color(0xFF1A1A3E),
          const Color(0xFF0A0A1A),
          Colors.black,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Nebula glow blobs
    final nebulaPaint = Paint()
      ..color = Colors.indigo.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.15),
      100,
      nebulaPaint,
    );

    final nebulaPaint2 = Paint()
      ..color = Colors.cyan.withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.8),
      120,
      nebulaPaint2,
    );

    // Draw star layers with parallax drift
    _drawLayer(canvas, size, _stars1!, 0.3, 0.7);
    _drawLayer(canvas, size, _stars2!, 0.5, 0.5);
    _drawLayer(canvas, size, _stars3!, 0.8, 0.3);
  }

  void _drawLayer(Canvas canvas, Size size, List<_Star> stars,
      double speed, double opacity) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity);
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final s in stars) {
      final x = (s.x / 400) * size.width;
      final y = ((s.baseY + t * speed) % 1.0) * size.height;
      canvas.drawCircle(Offset(x, y), s.size + 1.5, glowPaint);
      canvas.drawCircle(Offset(x, y), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthStarfieldPainter old) => true;
}

class _Star {
  final double x;
  final double baseY;
  final double size;
  _Star(this.x, this.baseY, this.size);
}

// ═══════════════════════════════════════════════════════════════════
// Official-style multi-color Google "G" logo drawn with CustomPaint
// (no asset needed).
// ═══════════════════════════════════════════════════════════════════

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeW = radius * 0.34;

    // The Google "G" is a ring split into 4 colored arcs, with a gap
    // on the right where the horizontal bar extends.

    final rect = Rect.fromCircle(center: center, radius: radius - strokeW / 2);

    // Red (top) — from ~ -50° to 10°
    _drawArc(canvas, rect, -50, 60, strokeW, const Color(0xFFEA4335));
    // Amber (top-right) — 10° to 100°
    _drawArc(canvas, rect, 10, 90, strokeW, const Color(0xFFFBBC05));
    // Green (bottom-right) — 100° to 200°
    _drawArc(canvas, rect, 100, 100, strokeW, const Color(0xFF34A853));
    // Blue (left/bottom) — 200° to 310°
    _drawArc(canvas, rect, 200, 110, strokeW, const Color(0xFF4285F4));

    // Horizontal bar (blue) — extends from center to the right edge gap
    final barPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + radius * 0.72, center.dy)
      ..lineTo(center.dx + radius * 0.72, center.dy - strokeW)
      ..lineTo(center.dx, center.dy - strokeW)
      ..close();
    canvas.drawPath(
        barPath, Paint()..color = const Color(0xFF4285F4));
  }

  void _drawArc(Canvas canvas, Rect rect, double startAngle, double sweepAngle,
      double strokeWidth, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Convert degrees to radians; 0° = 3 o'clock in Flutter
    canvas.drawArc(
      rect,
      startAngle * pi / 180,
      sweepAngle * pi / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
