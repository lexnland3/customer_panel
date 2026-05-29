import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class BookVisitScreen extends StatefulWidget {
  final String plotId, plotName;
  const BookVisitScreen({super.key, required this.plotId, required this.plotName});
  @override
  State<BookVisitScreen> createState() => _BookVisitScreenState();
}

class _BookVisitScreenState extends State<BookVisitScreen> {
  final _name        = TextEditingController();
  final _phone       = TextEditingController();
  final _requirement = TextEditingController();
  DateTime? _date;
  String?   _time;
  bool      _loading = false;
  bool      _done    = false;

  final _times = ['9:00 AM','10:00 AM','11:00 AM','12:00 PM',
    '1:00 PM','2:00 PM','3:00 PM','4:00 PM','5:00 PM'];

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      _snack('Please enter your name and phone'); return;
    }
    if (_date == null) { _snack('Please select a visit date'); return; }
    if (_time == null) { _snack('Please select a time slot'); return; }

    setState(() => _loading = true);
    try {
      await Api.bookVisit(
        plotId:       widget.plotId,
        visitorName:  _name.text.trim(),
        visitorPhone: _phone.text.trim(),
        visitDate:    _date!.toIso8601String(),
        visitTime:    _time!,
        requirement:  _requirement.text.trim(),
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: C.error));

  @override
  Widget build(BuildContext context) {
    if (_done) return _SuccessView(plotName: widget.plotName,
        onBack: () => Navigator.pop(context));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Visit: ${widget.plotName}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: const BackButton(color: C.textDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.primary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: C.primary, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text(
                'Schedule a free on-site visit. The owner will confirm your slot.',
                style: TextStyle(fontSize: 13, color: C.primary, height: 1.4),
              )),
            ]),
          ),

          _Label('Your Name'),
          TextField(controller: _name,
              decoration: const InputDecoration(
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_outline, color: C.primary))),
          const SizedBox(height: 14),

          _Label('Phone Number'),
          TextField(controller: _phone, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Enter your mobile number',
                prefixIcon: Icon(Icons.phone_outlined, color: C.primary))),
          const SizedBox(height: 20),

          _Label('Visit Date'),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate:   DateTime.now().add(const Duration(days: 1)),
                lastDate:    DateTime.now().add(const Duration(days: 60)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: C.primary)),
                  child: child!,
                ),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _date != null ? C.primary : C.border, width: _date != null ? 1.5 : 1),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    color: _date != null ? C.primary : C.textLight, size: 20),
                const SizedBox(width: 12),
                Text(
                  _date == null ? 'Select date' : '${_date!.day}/${_date!.month}/${_date!.year}',
                  style: TextStyle(fontSize: 14,
                      color: _date != null ? C.textDark : C.textLight,
                      fontWeight: _date != null ? FontWeight.w600 : FontWeight.w400),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          _Label('Preferred Time Slot'),
          Wrap(spacing: 8, runSpacing: 8, children: _times.map((t) => GestureDetector(
            onTap: () => setState(() => _time = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _time == t ? C.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _time == t ? C.primary : C.border),
              ),
              child: Text(t, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _time == t ? Colors.white : C.textDark,
              )),
            ),
          )).toList()),
          const SizedBox(height: 20),

          _Label('What are you looking for? (optional)'),
          TextField(
            controller: _requirement,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. Agricultural land for farming, residential plot for house construction…',
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(_loading ? 'Booking…' : 'Confirm Visit'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.textDark)),
  );
}

class _SuccessView extends StatelessWidget {
  final String plotName;
  final VoidCallback onBack;
  const _SuccessView({required this.plotName, required this.onBack});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(color: C.successBg, shape: BoxShape.circle,
                border: Border.all(color: C.success.withValues(alpha: 0.3), width: 2)),
            child: const Center(child: Text('✅', style: TextStyle(fontSize: 56))),
          ),
          const SizedBox(height: 28),
          const Text('Visit Booked!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: C.textDark)),
          const SizedBox(height: 12),
          Text('Your site visit for "$plotName" has been submitted. The owner will confirm your slot.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: C.textMuted, height: 1.5)),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: onBack, child: const Text('Back to Plot'))),
        ]),
      ),
    ),
  );
}
