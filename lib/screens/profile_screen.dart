import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'contact_us_screen.dart';
import 'info_pages.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Refresh from server so newly-saved profile fields show immediately.
    try {
      final res = await Api.getMe();
      final c = res['customer'] as Map<String, dynamic>?;
      if (c != null) {
        if (mounted) setState(() => _user = c);
        return;
      }
    } catch (_) {}
    final u = await Api.getUser();
    if (mounted) setState(() => _user = u);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _user == null
              ? _GuestView()
              : _UserView(
                  user: _user!,
                  onEdit: () async {
                    final changed = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EditProfileScreen(user: _user!)));
                    if (changed == true) _load();
                  },
                  onLogout: () async {
                    await Api.logout();
                    if (context.mounted)
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false);
                  }),
        ),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 40),
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
              color: C.primaryLight, shape: BoxShape.circle),
          child: Center(
              child: Image.asset('assets/images/logo_small.png',
                  width: 46, height: 46)),
        ),
        const SizedBox(height: 20),
        const Text('You\'re browsing as a guest',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: C.textDark)),
        const SizedBox(height: 8),
        const Text('Sign in to save plots and chat with owners',
            style: TextStyle(color: C.textMuted)),
        const SizedBox(height: 28),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Sign In / Register'),
            )),
      ]);
}

class _UserView extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final VoidCallback onEdit;
  const _UserView(
      {required this.user, required this.onLogout, required this.onEdit});

  bool get _incomplete =>
      user['age'] == null ||
      ((user['gender'] ?? '') as String).isEmpty ||
      ((user['occupation'] ?? '') as String).isEmpty ||
      ((user['state'] ?? '') as String).isEmpty ||
      ((user['city'] ?? '') as String).isEmpty;

  String _ageText() {
    final a = user['age'];
    return a == null ? '—' : a.toString();
  }

  String _cap(String s) =>
      s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [C.primary, C.primaryMid]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: Center(
                  child: Text(
                (user['name'] as String? ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              )),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(user['name'] ?? 'User',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(user['email'] ?? '',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8))),
                  if ((user['phone'] ?? '').isNotEmpty)
                    Text(user['phone'],
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7))),
                ])),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Edit profile',
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Incomplete profile prompt ──
        if (_incomplete)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFE65100), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text(
                  'Complete your profile to get plots near you and better recommendations.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w600),
                )),
                const Text('Update',
                    style: TextStyle(
                        color: Color(0xFFE65100), fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        if (_incomplete) const SizedBox(height: 16),

        _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user['email'] ?? '—'),
        _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value:
                (user['phone'] ?? '').toString().isEmpty ? '—' : user['phone']),
        _InfoTile(
            icon: Icons.location_city_rounded,
            label: 'City',
            value: _cap((user['city'] ?? '') as String)),
        _InfoTile(
            icon: Icons.map_outlined,
            label: 'State',
            value: _cap((user['state'] ?? '') as String)),
        _InfoTile(icon: Icons.cake_outlined, label: 'Age', value: _ageText()),
        _InfoTile(
            icon: Icons.person_outline,
            label: 'Gender',
            value: _cap((user['gender'] ?? '') as String)),
        _InfoTile(
            icon: Icons.work_outline,
            label: 'Occupation',
            value: _cap((user['occupation'] ?? '') as String)),
        const SizedBox(height: 16),
        _AppMenu(user: user),
        const SizedBox(height: 16),
        const _RateExperience(),
        const SizedBox(height: 24),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, color: C.error),
              label: const Text('Sign Out',
                  style:
                      TextStyle(color: C.error, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: C.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )),
      ]);
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.border)),
        child: Row(children: [
          Icon(icon, size: 18, color: C.primary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: C.textMuted)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: C.textDark)),
        ]),
      );
}

// ── App menu (Contact / About / Terms / Privacy) ─────────────
class _AppMenu extends StatelessWidget {
  final Map<String, dynamic> user;
  const _AppMenu({required this.user});

  Widget _tile(BuildContext context, IconData icon, String title,
          VoidCallback onTap, bool divider) =>
      Column(children: [
        ListTile(
          leading: Icon(icon, color: C.primary, size: 20),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: C.textDark)),
          trailing: const Icon(Icons.chevron_right_rounded, color: C.textLight),
          onTap: onTap,
        ),
        if (divider) const Divider(height: 1, color: C.border),
      ]);

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Column(children: [
        _tile(context, Icons.support_agent_rounded, 'Contact Us',
            () => go(ContactUsScreen(user: user)), true),
        _tile(context, Icons.info_outline_rounded, 'About Us',
            () => go(const AboutUsScreen()), true),
        _tile(context, Icons.description_outlined, 'Terms & Conditions',
            () => go(const TermsScreen()), true),
        _tile(context, Icons.privacy_tip_outlined, 'Privacy Policy',
            () => go(const PrivacyScreen()), false),
      ]),
    );
  }
}

// ── Rate your experience (app feedback -> support inbox) ─────
class _RateExperience extends StatefulWidget {
  const _RateExperience();
  @override
  State<_RateExperience> createState() => _RateExperienceState();
}

class _RateExperienceState extends State<_RateExperience> {
  int _rating = 0;
  bool _sending = false;
  bool _done = false;

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _sending = true);
    try {
      await Api.submitProblem(
          'App rating: $_rating/5 stars (Rate your experience)');
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: C.error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Rate Your Experience',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark)),
        const SizedBox(height: 4),
        const Text('How is your experience with the app so far?',
            style: TextStyle(fontSize: 12, color: C.textMuted)),
        const SizedBox(height: 10),
        if (_done)
          Row(children: const [
            Icon(Icons.check_circle_rounded, color: C.success, size: 20),
            SizedBox(width: 8),
            Text('Thanks for your feedback!',
                style:
                    TextStyle(color: C.success, fontWeight: FontWeight.w700)),
          ])
        else ...[
          Row(
              children: List.generate(5, (i) {
            final filled = i < _rating;
            return GestureDetector(
              onTap: _sending ? null : () => setState(() => _rating = i + 1),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFA726),
                    size: 34),
              ),
            );
          })),
          if (_rating > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Sending…' : 'Send feedback'),
              ),
            ),
          ],
        ],
      ]),
    );
  }
}
