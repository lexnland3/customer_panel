import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'plot_detail_screen.dart';

// ══════════════════════════════════════════════════════════════
//  Customer — My Visits (matches Figma mockup)
// ══════════════════════════════════════════════════════════════
class WishlistTab extends StatefulWidget {
  const WishlistTab({super.key});
  @override
  State<WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends State<WishlistTab> {
  List<dynamic> _visits     = [];
  bool   _loading    = true;
  String _timePeriod = 'Upcoming';
  String _status     = 'All';

  final _timePeriods = ['Today', 'Upcoming', 'Past'];
  final _statuses    = ['All', 'Pending', 'Confirmed', 'Rescheduled', 'Cancelled'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.getMyVisits();
      if (mounted) setState(() { _visits = res['visits'] as List? ?? []; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<dynamic> get _filtered {
    final now = DateTime.now();
    return _visits.where((v) {
      final vMap   = v as Map<String, dynamic>;
      final status = (vMap['status'] as String? ?? '').toLowerCase();
      DateTime? vDate;
      try { vDate = DateTime.parse(vMap['visitDate'] as String? ?? '').toLocal(); } catch (_) {}
      if (vDate != null) {
        final isToday    = vDate.year == now.year && vDate.month == now.month && vDate.day == now.day;
        final isUpcoming = vDate.isAfter(now) && !isToday;
        final isPast     = vDate.isBefore(now) && !isToday;
        if (_timePeriod == 'Today'    && !isToday)    return false;
        if (_timePeriod == 'Upcoming' && !isUpcoming)  return false;
        if (_timePeriod == 'Past'     && !isPast)      return false;
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
        backgroundColor: Colors.white, elevation: 0,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scheduled Visits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.textDark)),
        ]),
        actions: [
          IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: C.primary)),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(children: [
            // Time period tabs
            Row(children: _timePeriods.map((p) {
              final active = _timePeriod == p;
              return GestureDetector(
                onTap: () => setState(() => _timePeriod = p),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? C.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(p, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : C.textMuted,
                  )),
                ),
              );
            }).toList()),
            const SizedBox(height: 10),
            // Status chips
            SizedBox(
              height: 36,
              child: ListView(scrollDirection: Axis.horizontal, children: _statuses.map((s) {
                final active = _status == s;
                return GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? C.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? C.primary : C.border),
                    ),
                    child: Text(s, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
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
                          visit:     _filtered[i] as Map<String, dynamic>,
                          onCancel:  _load,
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
  final VoidCallback onCancel;
  const _CustomerVisitCard({required this.visit, required this.onCancel});
  @override
  State<_CustomerVisitCard> createState() => _CustomerVisitCardState();
}

class _CustomerVisitCardState extends State<_CustomerVisitCard> {
  bool _cancelling = false;

  Future<void> _editVisit() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CustomerEditVisitScreen(
        visit: widget.visit,
        onDone: () { widget.onCancel(); Navigator.pop(context); },
      ),
    ));
  }

  Future<void> _acceptVisit() async {
    try {
      await Api.acceptVisit(widget.visit['_id'] as String);
      widget.onCancel();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: C.error));
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
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: C.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: C.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await Api.cancelVisit(widget.visit['_id'] as String);
      widget.onCancel();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: C.error));
    } finally { if (mounted) setState(() => _cancelling = false); }
  }

  @override
  Widget build(BuildContext context) {
    final v      = widget.visit;
    final status      = v['status']      as String? ?? 'pending';
    final scheduledBy = v['scheduledBy'] as String? ?? 'customer';
    final prop        = v['property']    as Map<String, dynamic>? ?? {};
    final name   = v['visitorName']  as String? ?? '—';
    final req    = v['requirement']  as String? ?? '';
    final date      = _fmtDate(v['visitDate'] as String?);
    final time      = v['visitTime']    as String? ?? '';
    final ownerNote = v['ownerNote']    as String? ?? '';

    Color  sc; String sl;
    switch (status) {
      case 'confirmed':   sc = const Color(0xFF2E7D32); sl = 'Confirmed';   break;
      case 'rescheduled': sc = const Color(0xFF1565C0); sl = 'Rescheduled'; break;
      case 'cancelled':   sc = const Color(0xFFC62828); sl = 'Cancelled';   break;
      case 'completed':   sc = C.textLight;             sl = 'Completed';   break;
      default:            sc = const Color(0xFFE65100); sl = 'Pending';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark))),
            Text(sl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sc)),
          ]),
          const SizedBox(height: 3),
          Text('$date, $time',
              style: const TextStyle(fontSize: 12, color: C.textMuted)),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PlotDetailScreen(plotId: prop['_id'] as String? ?? ''))),
            child: Text(prop['propertyName'] ?? '—',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: C.primary, decoration: TextDecoration.underline)),
          ),
          if (req.isNotEmpty)
            Text(req, style: const TextStyle(fontSize: 12, color: C.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),

          // Rescheduled info
          if (status == 'rescheduled' && v['rescheduleDate'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.update_rounded, size: 13, color: Color(0xFF1565C0)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'New time: ${_fmtDate(v['rescheduleDate'] as String?)} ${v['rescheduleTime'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                )),
              ]),
            ),
          ],

          // Owner message — shown when owner sent a note requesting changes
          if (ownerNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.message_outlined, size: 14, color: Color(0xFF7B5800)),
                const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Message from owner',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: Color(0xFF7B5800))),
                  const SizedBox(height: 2),
                  Text(ownerNote,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037))),
                ])),
              ]),
            ),
          ],

          const SizedBox(height: 10),
          Row(children: [
            // View Details button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: C.primary, borderRadius: BorderRadius.circular(8)),
              child: const Text('View Details',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            // Action buttons — only on pending visits
            if (status == 'pending') ...[
              // Customer scheduled → they can Edit the time
              // Owner scheduled → customer must Accept
              if (scheduledBy == 'customer') ...[
                GestureDetector(
                  onTap: _editVisit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: C.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Edit Visit',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _acceptVisit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Accept',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _cancelling ? null : _cancel,
                child: _cancelling
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: C.error, strokeWidth: 2))
                    : const Icon(Icons.cancel_outlined, color: C.error, size: 22),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw).toLocal();
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${mo[d.month-1]}, ${d.year}';
    } catch (_) { return raw; }
  }
}


// ── Customer Reschedule Screen ─────────────────────────────────
class _CustomerEditVisitScreen extends StatefulWidget {
  final Map<String, dynamic> visit;
  final VoidCallback onDone;
  const _CustomerEditVisitScreen({required this.visit, required this.onDone});
  @override
  State<_CustomerEditVisitScreen> createState() => _CustomerEditVisitScreenState();
}

class _CustomerEditVisitScreenState extends State<_CustomerEditVisitScreen> {
  DateTime? _date;
  String?   _time;
  bool _saving = false;

  final _times = ['9:00 AM','10:00 AM','11:00 AM','12:00 PM',
    '1:00 PM','2:00 PM','3:00 PM','4:00 PM','5:00 PM'];

  @override
  void initState() {
    super.initState();
    // Pre-fill with current visit date/time
    try {
      _date = DateTime.parse(widget.visit['visitDate'] as String).toLocal();
    } catch (_) {}
    _time = widget.visit['visitTime'] as String?;
  }

  Future<void> _save() async {
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select date and time'), backgroundColor: C.error));
      return;
    }
    setState(() => _saving = true);
    try {
      await Api.editVisit(
        widget.visit['_id'] as String,
        visitDate: _date!.toIso8601String(),
        visitTime: _time!,
      );
      widget.onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: C.error));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final v    = widget.visit;
    final name = v['visitorName'] as String? ?? '—';
    final prop = (v['property'] as Map<String, dynamic>?)?['propertyName'] as String? ?? '—';

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: const BackButton(color: C.textDark),
        title: const Text('Edit Visit',
            style: TextStyle(fontWeight: FontWeight.w800, color: C.textDark)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.textDark)),
              Text(prop, style: const TextStyle(fontSize: 12, color: C.textMuted)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Select new date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.textDark)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
                firstDate:   DateTime.now(),
                lastDate:    DateTime.now().add(const Duration(days: 90)),
                builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(primary: C.primary)), child: child!),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _date != null ? C.primary : C.border,
                      width: _date != null ? 1.5 : 1)),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    color: _date != null ? C.primary : C.textLight, size: 18),
                const SizedBox(width: 10),
                Text(_date == null ? 'Select date'
                    : '${_date!.day}/${_date!.month}/${_date!.year}',
                    style: TextStyle(fontSize: 14,
                        color: _date != null ? C.textDark : C.textLight,
                        fontWeight: _date != null ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select new time',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.textDark)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _times.map((t) => GestureDetector(
            onTap: () => setState(() => _time = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _time == t ? C.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _time == t ? C.primary : C.border),
              ),
              child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _time == t ? Colors.white : C.textDark)),
            ),
          )).toList()),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.primaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Text(
              'The owner will be notified and must accept the new time. Discuss any details in the chat.',
              style: TextStyle(fontSize: 12, color: C.primary),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: C.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(foregroundColor: C.textMuted,
                side: const BorderSide(color: C.border),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}


class _EmptyVisits extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: C.primaryLight, shape: BoxShape.circle),
          child: const Icon(Icons.calendar_month_outlined, size: 38, color: C.primary)),
      const SizedBox(height: 16),
      const Text('No visits yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.textDark)),
      const SizedBox(height: 6),
      const Text('Book a site visit from any plot page',
          style: TextStyle(color: C.textMuted)),
    ]),
  );
}
