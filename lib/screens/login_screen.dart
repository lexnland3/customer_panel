import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _gLoading = false;
  bool _obscure = true;
  String? _error;

  // Login is Google-only for now. Flip this to true to bring back the
  // email/password + register UI (the code below is kept intact).
  bool _showEmailLogin = false;

  // ── Email / Password login ────────────────────────────────────
  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Api.login(
          email: _email.text.trim(), password: _password.text.trim());
      _goHome();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() {
      _gLoading = true;
      _error = null;
    });
    try {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');

      // signInWithPopup is web-only; on Android/iOS use signInWithProvider
      // (opens the OAuth flow in a Custom Tab / browser).
      final UserCredential cred = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      final User? firebaseUser = cred.user;
      if (firebaseUser == null)
        throw Exception('Google sign-in failed. Try again.');

      final String? idToken = await firebaseUser.getIdToken();
      if (idToken == null)
        throw Exception('Could not get authentication token.');

      // Send to backend — backend checks if this email is an Owner
      await Api.googleSignIn(idToken);
      _goHome();
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          msg = 'Sign-in was cancelled.';
          break;
        case 'network-request-failed':
          msg = 'Network error. Check your connection.';
          break;
        default:
          msg = e.message ?? 'Google sign-in failed.';
      }
      setState(() => _error = msg);
      // Sign out from Firebase so there's no dangling session
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      final raw = e.toString().replaceAll('Exception: ', '');

      // ── Owner account detected ────────────────────────────────
      if (raw.contains('registered as a property owner') ||
          raw.contains('isOwner')) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _showOwnerDialog();
        return;
      }

      setState(() => _error = raw);
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) setState(() => _gLoading = false);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
  }

  // ── Owner-account dialog ──────────────────────────────────────
  void _showOwnerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.3),
                    width: 2),
              ),
              child: const Center(
                  child: Text('🏠', style: TextStyle(fontSize: 34))),
            ),
            const SizedBox(height: 18),
            const Text('Owner Account Detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 12),
            const Text(
              'This Google account is registered as a property owner in the Owner Panel app.\n\n'
              'The Customer app is for buyers looking for plots. Please use the Owner Panel app to manage your listings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF6B6B6B), height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Got it — Use Different Account',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Allow guest browsing
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (_) => false);
              },
              child: const Text('Browse as Guest',
                  style: TextStyle(
                      color: C.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(children: [
                  // ── Purple gradient header ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [C.primaryDark, C.primary, C.primaryMid],
                      ),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(36)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo
                          Row(children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: Image.asset(
                                          'assets/images/logo_small_white.png',
                                          fit: BoxFit.contain))),
                            ),
                            const SizedBox(width: 10),
                            const Text('Lex n Land',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ]),
                          const SizedBox(height: 28),
                          const Text('Welcome Back!',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1)),
                          const SizedBox(height: 6),
                          Text('Sign in to explore verified plots',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.82))),
                        ]),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Error banner
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: C.errorBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: C.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.error_outline,
                                      color: C.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_error!,
                                          style: const TextStyle(
                                              color: C.error, fontSize: 13))),
                                ]),
                              ),
                            ],

                            // ── Google Button ──────────────────────────────
                            _GoogleButton(
                                loading: _gLoading, onTap: _signInWithGoogle),
                            const SizedBox(height: 20),

                            // ── Email / password + Register (DISABLED: Google-only) ──
                            if (_showEmailLogin) ...[
                              // Divider
                              Row(children: [
                                const Expanded(child: Divider(color: C.border)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text('or sign in with email',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: C.textLight
                                              .withValues(alpha: 0.9))),
                                ),
                                const Expanded(child: Divider(color: C.border)),
                              ]),
                              const SizedBox(height: 20),

                              // Email
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email address',
                                  prefixIcon: Icon(Icons.email_outlined,
                                      color: C.primary),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Password
                              TextField(
                                controller: _password,
                                obscureText: _obscure,
                                onSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: C.primary),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: C.textLight),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : const Text('Sign In'),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Register link
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Don't have an account? ",
                                        style: TextStyle(
                                            color: C.textMuted, fontSize: 14)),
                                    GestureDetector(
                                      onTap: () => Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterScreen())),
                                      child: const Text('Register',
                                          style: TextStyle(
                                              color: C.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                    ),
                                  ]),
                              const SizedBox(height: 10),
                            ], // end if (_showEmailLogin)
                          ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Google Button ──────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: C.primary, strokeWidth: 2.5)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Google G logo
                _GoogleG(),
                const SizedBox(width: 12),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: C.textDark),
                ),
              ]),
      ),
    );
  }
}

// ── Google G icon (no external package needed) ─────────────────
class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Clip to circle
    canvas.clipPath(Path()..addOval(rect));

    // White background
    canvas.drawCircle(center, r, Paint()..color = Colors.white);

    // Draw colored arcs (simplified Google G)
    final strokeW = size.width * 0.13;
    final arcRect = Rect.fromCircle(center: center, radius: r - strokeW / 2);

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
          arcRect,
          start,
          sweep,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.butt);
    }

    // Blue (right)
    arc(-0.18, 1.06, const Color(0xFF4285F4));
    // Red (top-left)
    arc(0.88, 1.06, const Color(0xFFEA4335));
    // Yellow (bottom-left)
    arc(1.94, 1.06, const Color(0xFFFBBC05));
    // Green (left)
    arc(3.0, 1.06, const Color(0xFF34A853));

    // White cutout bar (right side of G)
    final barPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeW * 0.85
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(center.dx + r * 0.08, center.dy - strokeW * 0.1),
      Offset(center.dx + r * 0.95, center.dy - strokeW * 0.1),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
