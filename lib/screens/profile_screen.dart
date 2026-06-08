import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

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
          child:
              const Center(child: Text('🌿', style: TextStyle(fontSize: 44))),
        ),
        const SizedBox(height: 20),
        const Text('You\'re browsing as a guest',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: C.textDark)),
        const SizedBox(height: 8),
        const Text('Sign in to book visits and save plots',
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
  const _UserView({required this.user, required this.onLogout});

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
          ]),
        ),
        const SizedBox(height: 24),
        _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user['email'] ?? '—'),
        _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user['phone'] ?? '—'),
        const SizedBox(height: 16),
        const _SupportSection(),
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

// ── Ask a Problem / Contact Us ───────────────────────────────
class _SupportSection extends StatefulWidget {
  const _SupportSection();
  @override
  State<_SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<_SupportSection> {
  final TextEditingController _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      await Api.submitProblem(msg);
      _ctrl.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Sent! Our team will reply to your email.'),
            backgroundColor: C.success));
      }
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.support_agent_rounded, size: 18, color: C.primary),
          SizedBox(width: 8),
          Text('Ask a Problem',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: C.textDark)),
        ]),
        const SizedBox(height: 6),
        const Text(
            'Describe your issue and our team will get back to you on your email.',
            style: TextStyle(fontSize: 12, color: C.textMuted)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'Type your problem here…',
            hintStyle: const TextStyle(color: C.textLight, fontSize: 14),
            filled: true,
            fillColor: C.bg,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: C.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: C.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}
