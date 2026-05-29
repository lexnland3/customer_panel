import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _phone    = TextEditingController();
  final _password = TextEditingController();
  bool _loading  = false;
  bool _gLoading = false;
  bool _obscure  = true;
  bool _agree    = false;
  String? _error;

  Future<void> _register() async {
    if (!_agree) { setState(() => _error = 'Please agree to the terms and conditions'); return; }
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      setState(() => _error = 'Please fill all required fields'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Api.register(
        name: _name.text.trim(), email: _email.text.trim(),
        phone: _phone.text.trim(), password: _password.text.trim(),
      );
      _goHome();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _gLoading = true; _error = null; });
    try {
      final provider = GoogleAuthProvider()..addScope('email')..addScope('profile');
      final cred = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = cred.user;
      if (user == null) throw Exception('Google sign-in failed.');
      final idToken = await user.getIdToken();
      if (idToken == null) throw Exception('Could not get authentication token.');
      await Api.googleSignIn(idToken);
      _goHome();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'popup-closed-by-user' && e.code != 'cancelled-popup-request') {
        setState(() => _error = e.message ?? 'Google sign-in failed.');
      }
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      final raw = e.toString().replaceAll('Exception: ', '');
      if (raw.contains('registered as a property owner') || raw.contains('isOwner')) {
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
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0), shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.3), width: 2)),
              child: const Center(child: Text('🏠', style: TextStyle(fontSize: 34))),
            ),
            const SizedBox(height: 18),
            const Text('Owner Account Detected', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 12),
            const Text(
              'This Google account is already registered as a property owner.\n\n'
              'Please use the Owner Panel app to manage your listings, or register with a different account here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B), height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: C.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('Use Different Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            )),
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
        child: SingleChildScrollView(
          child: Column(children: [
            // Purple header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [C.primaryDark, C.primary, C.primaryMid],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Center(child: Text('🌿', style: TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 10),
                  const Text('Lex n Land',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
                const SizedBox(height: 28),
                const Text('Get Started', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 6),
                Text("Let's create your account",
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.82))),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: C.errorBg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: C.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: C.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: C.error, fontSize: 13))),
                    ]),
                  ),
                ],

                // Google
                _GoogleButton(loading: _gLoading, onTap: _signInWithGoogle),
                const SizedBox(height: 20),

                Row(children: [
                  const Expanded(child: Divider(color: C.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or register with email',
                        style: TextStyle(fontSize: 12, color: C.textLight.withValues(alpha: 0.9))),
                  ),
                  const Expanded(child: Divider(color: C.border)),
                ]),
                const SizedBox(height: 20),

                TextField(controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, color: C.primary))),
                const SizedBox(height: 14),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, color: C.primary))),
                const SizedBox(height: 14),
                TextField(controller: _phone, keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number (optional)', prefixIcon: Icon(Icons.phone_outlined, color: C.primary))),
                const SizedBox(height: 14),
                TextField(controller: _password, obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Create Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: C.primary),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: C.textLight),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    )),
                const SizedBox(height: 10),

                Row(children: [
                  Checkbox(value: _agree, activeColor: C.primary,
                      onChanged: (v) => setState(() => _agree = v ?? false)),
                  Expanded(child: RichText(
                    text: const TextSpan(
                      text: 'I agree to the ', style: TextStyle(color: C.textMuted, fontSize: 13),
                      children: [
                        TextSpan(text: 'Terms & Conditions',
                            style: TextStyle(color: C.primary, fontWeight: FontWeight.w600)),
                        TextSpan(text: ' and '),
                        TextSpan(text: 'Privacy Policy',
                            style: TextStyle(color: C.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
                ]),
                const SizedBox(height: 22),

                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Account'),
                )),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Already have an account? ', style: TextStyle(color: C.textMuted, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Sign In',
                        style: TextStyle(color: C.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Shared Google button (same as login_screen) ────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: loading ? null : onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: loading
          ? const Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: C.primary, strokeWidth: 2.5)))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _GoogleIcon(),
              const SizedBox(width: 12),
              const Text('Continue with Google',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.textDark)),
            ]),
    ),
  );
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Text('G',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4)));
}
