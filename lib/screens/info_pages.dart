import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Shared layout for static info pages.
class _InfoPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoPage({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ),
      );
}

Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: C.textDark)),
    );

Widget _p(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t,
          style:
              const TextStyle(fontSize: 14, color: C.textMuted, height: 1.55)),
    );

// ─────────────────────────────────────────────────────────────
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});
  @override
  Widget build(BuildContext context) => _InfoPage(title: 'About Us', children: [
        _p('LexNLand is a property platform that makes buying and selling plots simple, transparent and trustworthy. We connect verified plot owners with genuine buyers, so you can explore land listings, see real details, and talk directly to owners — all in one place.'),
        _h('Key Services'),
        _p('• Browse verified plots with photos, pricing and location.\n'
            '• Chat directly with plot owners, no middlemen.\n'
            '• Save your favourite plots for later.\n'
            '• Rate plots and share your experience.'),
        _h('Our Mission'),
        _p('To bring clarity and trust to land deals, giving every buyer and owner a safe, direct and easy way to do business.'),
        _h('Get in touch'),
        _p('Have a question or feedback? Use the Contact Us option in your profile and our team will be happy to help.'),
      ]);
}

// ─────────────────────────────────────────────────────────────
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _InfoPage(title: 'Terms & Conditions', children: [
        _p('By using the LexNLand app, you agree to the terms below. Please read them carefully.'),
        _h('1. Using the app'),
        _p('You agree to use LexNLand only for lawful purposes and to provide accurate information about yourself and any listings you interact with.'),
        _h('2. Listings'),
        _p('Plot listings are submitted by owners and reviewed before going live. While we verify listings to the best of our ability, you should independently confirm details before making any commitment or payment.'),
        _h('3. Communication'),
        _p('The app lets buyers and owners communicate directly. You are responsible for your own conversations and any agreements you reach.'),
        _h('4. Payments'),
        _p('Any payment made through the app is subject to the applicable terms shown at the time of payment. Registration and service fees, where charged, are non-refundable unless stated otherwise.'),
        _h('5. Changes'),
        _p('We may update these terms from time to time. Continued use of the app after changes means you accept the updated terms.'),
      ]);
}

// ─────────────────────────────────────────────────────────────
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _InfoPage(title: 'Privacy Policy', children: [
        _p('Your privacy matters to us. This policy explains what we collect and how we use it.'),
        _h('What we collect'),
        _p('We collect the details you provide — such as your name, email, phone number and location — and information about how you use the app, such as the plots you view or save.'),
        _h('How we use it'),
        _p('We use your information to run the app, show you relevant plots, let you chat with owners, respond to your support requests, and improve our service.'),
        _h('Sharing'),
        _p('We do not sell your personal data. Limited details may be shared with an owner when you choose to contact them about a plot, or with service providers who help us operate the app.'),
        _h('Your choices'),
        _p('You can update your profile details at any time, or contact us to request changes to your information.'),
        _h('Contact'),
        _p('For any privacy questions, reach us through the Contact Us option in your profile.'),
      ]);
}
