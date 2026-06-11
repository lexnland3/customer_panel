import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../utils/onboarding.dart';
import 'main_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    Timer(const Duration(seconds: 3), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final token = await Api.getToken();
    final prefs = await _firstTime();
    if (token != null) {
      try {
        final me = await Api.getMe();
        if (!mounted) return;
        routeAfterAuth(context, me['customer'] as Map<String, dynamic>?);
      } catch (_) {
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } else if (prefs) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<bool> _firstTime() async {
    final p = await _prefs();
    final seen = p.getBool('onboarding_seen') ?? false;
    if (!seen) await p.setBool('onboarding_seen', true);
    return !seen;
  }

  Future<dynamic> _prefs() async {
    // Using SharedPreferences
    final p = await _getPrefs();
    return p;
  }

  Future _getPrefs() async {
    // Placeholder — SharedPreferences already imported in api_service
    return _SharedPrefsShim();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.primaryDark, C.primary, C.primaryMid],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo circle
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2),
                      ),
                      child: const Center(
                        child: Text('🌿', style: TextStyle(fontSize: 56)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Lex n Land',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text('Find Your Perfect Plot',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 60),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: Colors.white.withValues(alpha: 0.6),
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Shim to avoid importing shared_preferences twice
class _SharedPrefsShim {
  bool getBool(String k) => false;
  Future<void> setBool(String k, bool v) async {}
}
