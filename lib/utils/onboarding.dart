import 'package:flutter/material.dart';
import '../screens/main_shell.dart';
import '../screens/edit_profile_screen.dart';

/// A customer profile counts as complete once the core details are filled.
bool isProfileComplete(Map<String, dynamic>? u) {
  if (u == null) return false;
  String s(String k) => (u[k] ?? '').toString().trim();
  final ageStr = (u['age'] ?? '').toString().trim();
  final ageOk = u['age'] != null && ageStr.isNotEmpty && ageStr != '0';
  return ageOk &&
      s('gender').isNotEmpty &&
      s('occupation').isNotEmpty &&
      s('state').isNotEmpty &&
      s('city').isNotEmpty;
}

/// After sign-in / app launch: complete profiles enter the app; new or
/// incomplete ones are sent to the onboarding profile form first.
/// (A payment step will be inserted between onboarding and the app later.)
void routeAfterAuth(BuildContext context, Map<String, dynamic>? user) {
  final Widget next = isProfileComplete(user)
      ? const MainShell()
      : EditProfileScreen(
          user: user ?? <String, dynamic>{}, isOnboarding: true);
  Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => next), (_) => false);
}
