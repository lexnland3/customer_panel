import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'plot_detail_screen.dart';

// ══════════════════════════════════════════════════════════════
//  Customer — My Visits (with back-and-forth scheduling)
// ══════════════════════════════════════════════════════════════
class WishlistTab extends StatefulWidget {
  const WishlistTab({super.key});
  @override
  State<WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends State<WishlistTab> {
  List<dynamic> _visits = [];
  bool _loading = true;
  String _timePeriod = 'Today';
  String _status = 'All';

  final _timePeriods = ['Today', 'Upcoming', 'Past'];
  final _statuses = ['All', 'Pending', 'Confirmed', 'Rescheduled', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.getMyVisits();
      if (mounted) {
        setState(() {
          _visits = res['visits'] as List? ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    final now = DateTime.now();
    return _visits.where((v) {
      final vMap = v as Map<String, dynamic>;
      final status = (vMap['status'] as String? ?? '').toLowerCase();
      DateTime? vDate;
      try {
        vDate = DateTime.parse(vMap['visitDate'] as String? ?? '').toLocal();
      } catch (_) {}
      if (vDate != null) {
        final isToday = vDate.year == now.year &&
            vDate.month == now.month &&
            vDate.day == now.day;
        final isUpcoming = vDate.isAfter(now) && !isToday;
        final isPast = vDate.isBefore(now) && !isToday;
        if (_timePeriod == 'Today' && !isToday) return false;
        if (_timePeriod == 'Upcoming' && !isUpcoming) return false;
        if (_timePeriod == 'Past' && !isPast) return false;
      }
      if (_status != 'All' && status != _status.toLowerCase()) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scheduled Visits',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: C.textDark)),
            ]),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: C.primary)),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(children: [
            Row(
                children: _timePeriods.map((p) {
              final active = _timePeriod == p;
              return GestureDetector(
                onTap: () => setState(() => _timePeriod = p),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? C.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(p,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : C.textMuted,
                      )),
                ),
              );
            }).toList()),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _statuses.map((s) {
                    final active = _status == s;
                    return GestureDetector(
                      onTap: () => setState(() => _status = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? C.primary : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: active ? C.primary : C.border),
                        ),
                        child: Text(s,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : C.textDark,
                            )),
                      ),
                    );
                  }).toList()),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.primary))
              : _filtered.isEmpty
                  ? _EmptyVisits()
                  : RefreshIndicator(
                      color: C.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CustomerVisitCard(
                          visit: _filtered[i] as Map<String, dynamic>,
                          onChanged: _load,
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _CustomerVisitCard extends StatefulWidget {
  final Map<String, dynamic> visit;
  final VoidCallback onChanged;
  const _CustomerVisitCard({required this.visit, required this.onChanged});
  @override
  State<_CustomerVisitCard> createState() => _CustomerVisitCardState();
}

class _CustomerVisitCardState extends State<_CustomerVisitCard> {
  bool _busy = false;

  void _snack(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(e.toString().replaceAll('Exception: ', '')),
      backgroundColor: C.error));

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await Api.acceptVisit(widget.visit['_id'] as String);
      widget.onChanged();
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Visit?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('Are you sure you want to cancel this visit?',
            style: TextStyle(color: C.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: C.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Cancel',
                  style:
                      TextStyle(color: C.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.cancelVisit(widget.visit['_id'] as String);
      widget.onChanged();
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _counter() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CounterProposeSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.proposeVisit(
        widget.visit['_id'] as String,
        newDate: result['date']!,
        newTime: result['time']!,
        note: result['note'] ?? '',
      );
      widget.onChanged();
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final status = v['status'] as String? ?? 'pending';
    final awaiting = (v['awaitingFrom'] as String?) ??
        (status == 'rescheduled'
            ? 'customer'
            : status == 'pending'
                ? 'owner'
                : null);
    final proposedBy = v['proposedBy'] as String? ?? 'customer';
    final proposals = (v['proposals'] as List?) ?? [];
    final prop = v['property'] as Map<String, dynamic>? ?? {};
    final name = v['visitorName'] as String? ?? '—';
    final req = v['requirement'] as String? ?? '';
    final date = _fmtDate(v['visitDate'] as String?);
    final time = v['visitTime'] as String? ?? '';

    final settled =
        status == 'cancelled' || status == 'completed' || status == 'confirmed';
    final myTurn = !settled && awaiting == 'customer';
    final theirTurn = !settled && awaiting == 'owner';

    // Status pill
    Color sc;
    String sl;
    if (status == 'confirmed') {
      sc = const Color(0xFF2E7D32);
      sl = 'Confirmed';
    } else if (status == 'cancelled') {
      sc = const Color(0xFFC62828);
      sl = 'Cancelled';
    } else if (status == 'completed') {
      sc = C.textLight;
      sl = 'Completed';
    } else if (myTurn) {
      sc = const Color(0xFF1565C0);
      sl = 'Your response needed';
    } else {
      sc = const Color(0xFFE65100);
      sl = 'Awaiting owner';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: C.textDark))),
            Text(sl,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: sc)),
          ]),
          const SizedBox(height: 3),
          Text('$date, $time',
              style: const TextStyle(fontSize: 12, color: C.textMuted)),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PlotDetailScreen(
                        plotId: prop['_id'] as String? ?? ''))),
            child: Text(prop['propertyName'] ?? '—',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: C.primary,
                    decoration: TextDecoration.underline)),
          ),
          if (req.isNotEmpty)
            Text(req,
                style: const TextStyle(fontSize: 12, color: C.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),

          // ── Negotiation banner ──
          if (myTurn) ...[
            const SizedBox(height: 8),
            _banner(
              const Color(0xFFE3F2FD),
              const Color(0xFF1565C0),
              Icons.swap_horiz_rounded,
              'The owner proposed $date at $time. Accept it or suggest another time.',
            ),
          ] else if (theirTurn) ...[
            const SizedBox(height: 8),
            _banner(
              const Color(0xFFFFF3E0),
              const Color(0xFFE65100),
              Icons.hourglass_top_rounded,
              proposedBy == 'customer'
                  ? 'Your proposed time was sent. Waiting for the owner to respond.'
                  : 'Waiting for the owner to respond.',
            ),
          ],

          // ── History thread (when more than one proposal) ──
          if (proposals.length > 1) ...[
            const SizedBox(height: 8),
            _History(proposals: proposals, fmtDate: _fmtDate),
          ],

          const SizedBox(height: 10),

          // ── Actions ──
          if (myTurn)
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _accept,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Accept',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _counter,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: C.primary,
                      side: const BorderSide(color: C.primary),
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: const Text('Suggest time',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _busy ? null : _cancel,
                child:
                    const Icon(Icons.cancel_outlined, color: C.error, size: 22),
              ),
            ])
          else
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: C.primary, borderRadius: BorderRadius.circular(8)),
                child: const Text('View Details',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (status == 'pending' ||
                  status == 'confirmed' ||
                  status == 'rescheduled')
                GestureDetector(
                  onTap: _busy ? null : _cancel,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: C.error, strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined,
                          color: C.error, size: 22),
                ),
            ]),
        ]),
      ),
    );
  }

  Widget _banner(Color bg, Color fg, IconData icon, String text) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: fg.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 11, color: fg, fontWeight: FontWeight.w600))),
        ]),
      );

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      const mo = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${mo[d.month - 1]}, ${d.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Proposal history thread ────────────────────────────────────
class _History extends StatelessWidget {
  final List<dynamic> proposals;
  final String Function(String?) fmtDate;
  const _History({required this.proposals, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('History',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: C.textMuted)),
          const SizedBox(height: 4),
          ...proposals.map((p) {
            final m = p as Map<String, dynamic>;
            final by = (m['by'] as String? ?? '') == 'owner' ? 'Owner' : 'You';
            final d = fmtDate(m['date'] as String?);
            final t = m['time'] as String? ?? '';
            final note = m['note'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '$by proposed $d at $t${note.isNotEmpty ? ' — $note' : ''}',
                style: const TextStyle(fontSize: 11, color: C.textDark),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Counter-propose bottom sheet ───────────────────────────────
class _CounterProposeSheet extends StatefulWidget {
  const _CounterProposeSheet();
  @override
  State<_CounterProposeSheet> createState() => _CounterProposeSheetState();
}

class _CounterProposeSheetState extends State<_CounterProposeSheet> {
  DateTime? _date;
  String? _time;
  final _note = TextEditingController();

  final _times = [
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM'
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick a date and time'), backgroundColor: C.error));
      return;
    }
    Navigator.pop(context, {
      'date': _date!.toIso8601String(),
      'time': _time!,
      'note': _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: C.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Suggest another time',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: C.textDark))),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 60)),
              builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(primary: C.primary)),
                  child: child!),
            );
            if (d != null) setState(() => _date = d);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _date != null ? C.primary : C.border,
                  width: _date != null ? 1.5 : 1),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 18, color: _date != null ? C.primary : C.textLight),
              const SizedBox(width: 10),
              Text(
                  _date == null
                      ? 'Select date'
                      : '${_date!.day}/${_date!.month}/${_date!.year}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _date != null ? C.textDark : C.textLight)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _times
                .map((t) => GestureDetector(
                      onTap: () => setState(() => _time = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: _time == t ? C.primary : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _time == t ? C.primary : C.border),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _time == t ? Colors.white : C.textDark)),
                      ),
                    ))
                .toList()),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Note (optional)',
            hintStyle: const TextStyle(color: C.textLight),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: C.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: C.border)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: C.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Send proposal',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _EmptyVisits extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(color: C.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.calendar_month_outlined,
                  size: 38, color: C.primary)),
          const SizedBox(height: 16),
          const Text('No visits yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: C.textDark)),
          const SizedBox(height: 6),
          const Text('Book a site visit from any plot page',
              style: TextStyle(color: C.textMuted)),
        ]),
      );
}
