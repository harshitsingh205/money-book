import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';

/// ---------------------------------------------------------------------------
/// LoginScreen
/// ---------------------------------------------------------------------------
/// Shown to users who have not yet signed in.  Provides a Google Sign-In
/// button plus an option to continue without signing in (offline-only mode).
/// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    // Stagger the entrance animations.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fadeCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Sign-in handlers ───────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final expenseProvider = context.read<ExpenseProvider>();

    final success = await authProvider.signInWithGoogle();
    if (!success || !mounted) return;

    // Pre-load user data; _AppRouter handles navigation automatically.
    await expenseProvider.loadData();
    await userProvider.reload();
  }

  void _handleOfflineMode() {
    context.read<AuthProvider>().continueAsGuest();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE), Color(0xFFEEF2FF)],
                ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── App Icon ─────────────────────────────────────────
                      _AppIcon(),
                      const SizedBox(height: 28),

                      // ── App Name ─────────────────────────────────────────
                      Text(
                        'Money Book',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your personal finance manager',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white60 : Colors.black45,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ── Feature pills ─────────────────────────────────────
                      _FeaturePills(isDark: isDark),
                      const SizedBox(height: 48),

                      // ── Error message ─────────────────────────────────────
                      if (authProvider.errorMessage != null) ...[
                        _ErrorBanner(message: authProvider.errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      // ── Google Sign-In Button ─────────────────────────────
                      _GoogleSignInButton(
                        isLoading: authProvider.isLoading,
                        onTap: authProvider.isLoading ? null : _handleGoogleSignIn,
                      ),
                      const SizedBox(height: 16),

                      // ── Divider ───────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Offline / Skip Button ─────────────────────────────
                      OutlinedButton(
                        onPressed: authProvider.isLoading ? null : _handleOfflineMode,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Continue without signing in',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Privacy note ──────────────────────────────────────
                      Text(
                        'Your data is stored on your device.\nCloud backup requires sign-in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withAlpha(70),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Image.asset(
          'assets/icon/app_icon.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePills extends StatelessWidget {
  final bool isDark;
  const _FeaturePills({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.offline_bolt_rounded, 'Works offline'),
      (Icons.cloud_done_rounded, 'Auto cloud backup'),
      (Icons.lock_rounded, 'Secure & private'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: features.map((f) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(15)
                : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.blue.withAlpha(40),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.blue.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(f.$1, size: 16, color: AppTheme.primaryBlue),
              const SizedBox(width: 6),
              Text(
                f.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF4285F4),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo rendered with coloured arcs
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Renders the classic Google "G" logo using coloured text segments.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final colors = [
      (const Color(0xFF4285F4), -90.0, 120.0),  // Blue  (top → right)
      (const Color(0xFF34A853), 30.0, 90.0),     // Green (right → bottom)
      (const Color(0xFFFBBC05), 120.0, 60.0),    // Yellow
      (const Color(0xFFEA4335), 180.0, 90.0),    // Red
    ];

    for (final c in colors) {
      final paint = Paint()
        ..color = c.$1
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 2),
        _deg(c.$2),
        _deg(c.$3),
        false,
        paint,
      );
    }
  }

  double _deg(double d) => d * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
