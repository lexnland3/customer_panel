import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'favourites_screen.dart';
import 'chat_list_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;
  bool _authed   = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await Api.getToken();
    if (mounted) setState(() { _authed = token != null; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator(color: C.primary)));
    if (!_authed)  return const _AuthGate();

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeTab(),
          FavouritesTab(),
          ChatListTab(),
          WishlistTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: C.border)),
          boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -3))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              _NavItem(icon: Icons.home_outlined,            activeIcon: Icons.home_rounded,              label: 'Home',      idx: 0, cur: _index, onTap: () => setState(() => _index = 0)),
              _NavItem(icon: Icons.favorite_border_rounded,  activeIcon: Icons.favorite_rounded,          label: 'Favourite', idx: 1, cur: _index, onTap: () => setState(() => _index = 1)),
              _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded,    label: 'Chats',     idx: 2, cur: _index, onTap: () => setState(() => _index = 2)),
              _NavItem(icon: Icons.calendar_today_outlined,  activeIcon: Icons.calendar_today_rounded,    label: 'My Booking',idx: 3, cur: _index, onTap: () => setState(() => _index = 3)),
              _NavItem(icon: Icons.person_outline_rounded,   activeIcon: Icons.person_rounded,            label: 'Profile',   idx: 4, cur: _index, onTap: () => setState(() => _index = 4)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int idx, cur;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label,
      required this.idx, required this.cur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = idx == cur;
    final color  = active ? C.primary : C.textLight;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? C.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(active ? activeIcon : icon, size: 22, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Auth Gate ──────────────────────────────────────────────────
class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [C.primaryDark, C.primaryMid],
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.3),
                    blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: const Center(child: Text('🌿', style: TextStyle(fontSize: 60))),
            ),
            const SizedBox(height: 32),
            const Text('Welcome to\nLex n Land',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: C.textDark, height: 1.2)),
            const SizedBox(height: 12),
            const Text('Sign in with Google to explore verified plots,\nchat with owners and book site visits.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: C.textMuted, height: 1.5)),
            const SizedBox(height: 40),
            _GoogleSignInButton(),
            const SizedBox(height: 20),
            const _FeatureRow(icon: Icons.verified_rounded,          text: 'Browse legally verified plots'),
            const _FeatureRow(icon: Icons.favorite_rounded,          text: 'Save your favourite plots'),
            const _FeatureRow(icon: Icons.chat_bubble_outline_rounded,text: 'Chat directly with owners'),
            const _FeatureRow(icon: Icons.calendar_today_rounded,    text: 'Schedule on-site visits'),
          ]),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _loading ? null : () async {
      final result = await Navigator.push<bool>(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (result == true && context.mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
      }
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border, width: 1.5),
        boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: _loading
          ? const Center(child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: C.primary, strokeWidth: 2.5)))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
              SizedBox(width: 14),
              Text('Sign in with Google', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.textDark)),
            ]),
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(children: [
      Container(width: 34, height: 34,
          decoration: BoxDecoration(color: C.primaryLight, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: C.primary)),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: C.textMuted, fontWeight: FontWeight.w500))),
    ]),
  );
}
