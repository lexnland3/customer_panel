import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPage(
      emoji: '🌿',
      title: 'Find Your\nPerfect Plot',
      subtitle: 'Browse verified agricultural,\nresidential and commercial plots\nacross the region.',
      bg: C.primaryDark,
    ),
    _OnboardPage(
      emoji: '✅',
      title: 'Legally Verified\nListings',
      subtitle: 'Every plot is reviewed by our admin\nteam before going live. Registry\ndocuments verified.',
      bg: C.primary,
    ),
    _OnboardPage(
      emoji: '📅',
      title: 'Schedule a\nSite Visit',
      subtitle: 'Book a free on-site visit with the\nowner directly from the app.\nNo middleman.',
      bg: C.primaryMid,
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _pages[i],
          ),
          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 44),
              child: Column(children: [
                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8, height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == _page ? 1 : 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
                const SizedBox(height: 28),
                Row(children: [
                  if (_page < _pages.length - 1)
                    Expanded(child: TextButton(
                      onPressed: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: Text('Skip',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15)),
                    )),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: C.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        _page == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.primary),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color bg;
  const _OnboardPage({required this.emoji, required this.title, required this.subtitle, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [bg, Color.lerp(bg, Colors.black, 0.25)!],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Illustration circle
            Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 80))),
            ),
            const SizedBox(height: 48),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                    color: Colors.white, height: 1.2)),
            const SizedBox(height: 20),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8),
                    height: 1.6)),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
