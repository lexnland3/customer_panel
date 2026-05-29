import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'book_visit_screen.dart';
import 'chat_screen.dart';

class PlotDetailScreen extends StatefulWidget {
  final String plotId;
  const PlotDetailScreen({super.key, required this.plotId});
  @override
  State<PlotDetailScreen> createState() => _PlotDetailScreenState();
}

class _PlotDetailScreenState extends State<PlotDetailScreen> {
  Map<String, dynamic>? _plot;
  bool _loading  = true;
  bool _isFav    = false;
  int  _activePhoto = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await Api.getPlotById(widget.plotId);
      if (mounted) setState(() { _plot = res['property'] as Map<String, dynamic>?; _loading = false; });
      _checkFav();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkFav() async {
    try {
      final ids = await Api.getFavouriteIds();
      final list = ids['ids'] as List? ?? [];
      if (mounted) setState(() => _isFav = list.contains(widget.plotId));
    } catch (_) {}
  }

  Future<void> _toggleFav() async {
    final was = _isFav;
    setState(() => _isFav = !was);
    try {
      await Api.toggleFavourite(widget.plotId, was);
    } catch (_) {
      if (mounted) setState(() => _isFav = was);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: C.primary)));
    if (_plot == null) return const Scaffold(body: Center(child: Text('Plot not found')));

    final d       = _plot!['plotDetails'] as Map<String, dynamic>? ?? {};
    final photos  = _plot!['photos'] as List? ?? [];
    final owner   = _plot!['owner']  as Map<String, dynamic>? ?? {};
    final price   = d['totalPrice']  as num? ?? 0;
    final size    = d['plotSize']    as num? ?? 0;
    final ppSqft  = d['pricePerSqft'] as num? ?? 0;
    final isVerified = _plot!['isVerified'] as bool? ?? false;

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        slivers: [
          // ── Photo header ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: C.primary,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const BackButton(color: Colors.white),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleFav,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFav ? const Color(0xFFEF5350) : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isEmpty
                  ? Container(
                      color: C.primaryLight,
                      child: const Center(child: Text('🌿', style: TextStyle(fontSize: 80))))
                  : Stack(fit: StackFit.expand, children: [
                      PageView.builder(
                        itemCount: photos.length,
                        onPageChanged: (i) => setState(() => _activePhoto = i),
                        itemBuilder: (_, i) => Image.network(
                          _fullUrl(photos[i] as String), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: C.primaryLight,
                              child: const Center(child: Text('🌿', style: TextStyle(fontSize: 60)))),
                        ),
                      ),
                      // Photo counter
                      if (photos.length > 1)
                        Positioned(bottom: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${_activePhoto + 1} / ${photos.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          )),
                    ]),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Title row
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_plot!['propertyName'] ?? 'Plot',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.textDark)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: C.textMuted),
                      const SizedBox(width: 4),
                      Expanded(child: Text(_plot!['location'] ?? '',
                          style: const TextStyle(fontSize: 13, color: C.textMuted))),
                    ]),
                  ])),
                  if (isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: C.successBg, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.success.withValues(alpha: 0.4)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_rounded, size: 14, color: C.success),
                        SizedBox(width: 4),
                        Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.success)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 20),

                // Price card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.primary, C.primaryMid]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total Price', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(price > 0 ? '₹${_fmt(price.toInt())}' : 'Contact for Price',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      if (ppSqft > 0)
                        Text('₹${ppSqft.toInt()} per sq ft',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (size > 0) ...[
                        const Text('Plot Size', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${size.toInt()} sq ft',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        if ((d['plotDimensions']?['length'] ?? 0) > 0)
                          Text(
                            '${d['plotDimensions']?['length']}×${d['plotDimensions']?['width']} ft',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                          ),
                      ],
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),

                // Details grid
                _SectionTitle('Plot Details'),
                const SizedBox(height: 10),
                _DetailGrid(items: [
                  if ((d['plotType'] ?? '').isNotEmpty)   _DetailItem('Type',          d['plotType']!),
                  if ((d['facing']   ?? '').isNotEmpty)   _DetailItem('Facing',        d['facing']!),
                  if ((d['ownershipType'] ?? '').isNotEmpty) _DetailItem('Ownership', d['ownershipType']!),
                  if ((d['plotId']   ?? '').isNotEmpty)   _DetailItem('Plot ID',       d['plotId']!),
                ]),
                const SizedBox(height: 16),

                // Facilities
                if ((d['facilities'] as List? ?? []).isNotEmpty) ...[
                  _SectionTitle('Facilities & Amenities'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8,
                      children: (d['facilities'] as List).map((f) => _FacilityChip(f.toString())).toList()),
                  const SizedBox(height: 16),
                ],

                // Description
                if ((d['description'] ?? '').isNotEmpty) ...[
                  _SectionTitle('Description'),
                  const SizedBox(height: 8),
                  Text(d['description'], style: const TextStyle(fontSize: 14, color: C.textMuted, height: 1.6)),
                  const SizedBox(height: 16),
                ],

                // Owner info
                _SectionTitle('Listed By'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.card, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: C.primaryLight, shape: BoxShape.circle),
                      child: Center(child: Text(
                        (owner['name'] as String? ?? 'O')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.primary),
                      )),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(owner['name'] ?? 'Property Owner',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.textDark)),
                      const SizedBox(height: 3),
                      Row(children: [
                        if (owner['isAadhaarVerified'] == true)
                          const _OwnerBadge(label: '✓ ID Verified', color: C.success, bg: C.successBg),
                        if (owner['accountStatus'] == 'active')
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: _OwnerBadge(label: 'Active', color: C.success, bg: C.successBg),
                          ),
                      ]),
                    ])),
                  ]),
                ),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),

      // ── CTAs ──
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: C.border)),
          ),
          child: Row(children: [
            // Chat with Owner
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final ownerId = (_plot!['owner'] as Map?)?['_id'] as String?;
                if (ownerId == null) return;
                try {
                  final res = await Api.getOrCreateChat(
                    plotId: widget.plotId, ownerId: ownerId);
                  final chat = res['chat'] as Map<String, dynamic>;
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId:    chat['_id'] as String,
                        ownerName: (chat['owner'] as Map?)?['name'] as String? ?? 'Owner',
                        ownerId:   (chat['owner'] as Map?)?['_id']  as String? ?? '',
                        plotName:  _plot!['propertyName'] ?? 'Plot',
                      ),
                    ));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: C.error));
                }
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.primary,
                side: const BorderSide(color: C.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            )),
            const SizedBox(width: 10),
            // Book Visit
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BookVisitScreen(
                  plotId:   widget.plotId,
                  plotName: _plot!['propertyName'] ?? 'Plot',
                ),
              )),
              icon: const Icon(Icons.calendar_today_rounded, size: 17),
              label: const Text('Book Visit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            )),
          ]),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.textDark));
}

class _DetailGrid extends StatelessWidget {
  final List<_DetailItem> items;
  const _DetailGrid({required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border)),
      child: Column(children: List.generate(items.length, (i) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            Expanded(flex: 2, child: Text(items[i].label,
                style: const TextStyle(fontSize: 13, color: C.textMuted))),
            Expanded(flex: 3, child: Text(items[i].value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textDark))),
          ]),
        ),
        if (i < items.length - 1) const Divider(height: 1, color: C.border),
      ]))),
    );
  }
}

class _DetailItem { final String label, value; const _DetailItem(this.label, this.value); }

class _FacilityChip extends StatelessWidget {
  final String label;
  const _FacilityChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: C.primaryLight, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.primary.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.primary)),
  );
}

class _OwnerBadge extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _OwnerBadge({required this.label, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

String _fullUrl(String url) => url.startsWith('http') ? url : 'http://localhost:5000$url';
String _fmt(int n) {
  if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)} Cr';
  if (n >= 100000)   return '${(n / 100000).toStringAsFixed(1)} L';
  return n.toString();
}
