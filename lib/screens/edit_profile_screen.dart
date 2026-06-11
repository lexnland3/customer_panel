import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_city_picker.dart';
import '../utils/validators.dart';
import 'main_shell.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isOnboarding;
  const EditProfileScreen(
      {super.key, required this.user, this.isOnboarding = false});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _occupationCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _cityCtrl;
  String _gender = '';
  String _lookingFor = '';
  bool _saving = false;

  static const _genders = ['male', 'female', 'other'];
  static const _looking = ['plot', 'pg', 'guest'];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u['name'] ?? '');
    _phoneCtrl = TextEditingController(text: u['phone'] ?? '');
    final ageVal = u['age'];
    _ageCtrl =
        TextEditingController(text: ageVal == null ? '' : ageVal.toString());
    _occupationCtrl = TextEditingController(text: u['occupation'] ?? '');
    _stateCtrl = TextEditingController(text: u['state'] ?? '');
    _cityCtrl = TextEditingController(text: u['city'] ?? '');
    _gender = (u['gender'] ?? '') as String;
    _lookingFor = (u['lookingFor'] ?? '') as String;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _ageCtrl,
      _occupationCtrl,
      _stateCtrl,
      _cityCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final missing = <String>[];
    if (_nameCtrl.text.trim().isEmpty) missing.add('Name');
    if (_ageCtrl.text.trim().isEmpty) missing.add('Age');
    if (_gender.isEmpty) missing.add('Gender');
    if (_occupationCtrl.text.trim().isEmpty) missing.add('Occupation');
    if (_stateCtrl.text.trim().isEmpty) missing.add('State');
    if (_cityCtrl.text.trim().isEmpty) missing.add('City');
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill: ${missing.join(', ')}'),
        backgroundColor: C.error,
      ));
      return;
    }
    if (!isValidName(_nameCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter a valid name (letters only)'),
          backgroundColor: C.error));
      return;
    }

    setState(() => _saving = true);
    try {
      await Api.updateProfile({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _gender,
        'occupation': _occupationCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'lookingFor': _lookingFor,
      });
      if (mounted) {
        if (widget.isOnboarding) {
          // Profile complete → enter the app. (Payment step will slot in here later.)
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (_) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Profile updated'), backgroundColor: C.primary));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not save: $e'), backgroundColor: C.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(
            widget.isOnboarding ? 'Complete your profile' : 'Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: C.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field('Full Name', _nameCtrl),
            _field('Phone', _phoneCtrl, keyboard: TextInputType.phone),
            _field('Age', _ageCtrl, keyboard: TextInputType.number),
            const SizedBox(height: 4),
            const Text('Gender',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.textDark)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                children: _genders
                    .map((g) => ChoiceChip(
                          label: Text(g[0].toUpperCase() + g.substring(1)),
                          selected: _gender == g,
                          onSelected: (_) => setState(() => _gender = g),
                          selectedColor: C.primaryLight,
                          labelStyle: TextStyle(
                              color: _gender == g ? C.primary : C.textMuted,
                              fontWeight: FontWeight.w600),
                        ))
                    .toList()),
            const SizedBox(height: 16),
            _field('Occupation', _occupationCtrl),
            StateCityPicker(
              state: _stateCtrl.text,
              city: _cityCtrl.text,
              accent: C.primary,
              citySearch: Api.searchCities,
              onStateChanged: (s) => setState(() => _stateCtrl.text = s),
              onCityChanged: (c) => setState(() => _cityCtrl.text = c),
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 4),
            const Text('Looking for (optional)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.textDark)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                children: _looking
                    .map((l) => ChoiceChip(
                          label: Text(l == 'pg'
                              ? 'PG'
                              : l[0].toUpperCase() + l.substring(1)),
                          selected: _lookingFor == l,
                          onSelected: (_) => setState(
                              () => _lookingFor = _lookingFor == l ? '' : l),
                          selectedColor: C.primaryLight,
                          labelStyle: TextStyle(
                              color: _lookingFor == l ? C.primary : C.textMuted,
                              fontWeight: FontWeight.w600),
                        ))
                    .toList()),
            const SizedBox(height: 28),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Profile',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.primary)),
        ),
      ),
    );
  }
}
