import 'dart:async';
import 'package:flutter/material.dart';
import '../data/india_locations.dart';

/// State dropdown + type-to-search City field.
/// Pick a state, then start typing the city — suggestions come from the
/// backend (which proxies a cities API). If suggestions are unavailable
/// (e.g. API key not set), the typed text is still accepted as the city.
class StateCityPicker extends StatefulWidget {
  final String state;
  final String city;
  final ValueChanged<String> onStateChanged;
  final ValueChanged<String> onCityChanged;

  /// Returns city suggestions for (state, query). Optional — if null, the city
  /// field works as plain free-text with no suggestions.
  final Future<List<String>> Function(String state, String query)? citySearch;
  final Color accent;

  const StateCityPicker({
    super.key,
    required this.state,
    required this.city,
    required this.onStateChanged,
    required this.onCityChanged,
    this.citySearch,
    this.accent = const Color(0xFF5C35A0),
  });

  @override
  State<StateCityPicker> createState() => _StateCityPickerState();
}

class _StateCityPickerState extends State<StateCityPicker> {
  late final TextEditingController _cityCtrl;
  final FocusNode _cityFocus = FocusNode();
  Timer? _debounce;
  List<String> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController(text: widget.city);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cityCtrl.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  void _onCityTyped(String v) {
    widget.onCityChanged(v); // free-text value is always live
    _debounce?.cancel();
    final search = widget.citySearch;
    if (search == null || widget.state.isEmpty || v.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      final results = await search(widget.state, v.trim());
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  void _pickSuggestion(String city) {
    _cityCtrl.text = city;
    _cityCtrl.selection = TextSelection.collapsed(offset: city.length);
    widget.onCityChanged(city);
    setState(() => _suggestions = []);
    _cityFocus.unfocus();
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c));

  InputDecoration _dec(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _border(const Color(0xFFE0E0E0)),
        enabledBorder: _border(const Color(0xFFE0E0E0)),
        focusedBorder: _border(widget.accent),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: widget.state.isEmpty
              ? null
              : (kIndiaStates.contains(widget.state) ? widget.state : null),
          isExpanded: true,
          decoration: _dec('State'),
          hint: const Text('Select state'),
          items: kIndiaStates
              .map((s) => DropdownMenuItem(
                  value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (s) {
            if (s == null) return;
            widget.onStateChanged(s);
            widget.onCityChanged('');
            _cityCtrl.clear();
            setState(() => _suggestions = []);
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _cityCtrl,
          focusNode: _cityFocus,
          enabled: widget.state.isNotEmpty,
          onChanged: _onCityTyped,
          decoration: _dec(
            'City',
            hint: widget.state.isEmpty
                ? 'Select a state first'
                : 'Type to search…',
            suffix: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (_cityCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _cityCtrl.clear();
                          widget.onCityChanged('');
                          setState(() => _suggestions = []);
                        },
                      )
                    : null),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: _suggestions
                  .take(8)
                  .map((c) => InkWell(
                        onTap: () => _pickSuggestion(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(children: [
                            Icon(Icons.location_city_rounded,
                                size: 16, color: widget.accent),
                            const SizedBox(width: 10),
                            Expanded(
                                child:
                                    Text(c, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
