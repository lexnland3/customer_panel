import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'plot_detail_screen.dart';

class FavouritesTab extends StatefulWidget {
  const FavouritesTab({super.key});
  @override
  State<FavouritesTab> createState() => _FavouritesTabState();
}

class _FavouritesTabState extends State<FavouritesTab> {
  List<dynamic> _plots   = [];
  bool          _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.getFavourites();
      if (mounted) setState(() {
        _plots   = res['properties'] as List? ?? [];
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _remove(String plotId) async {
    setState(() => _plots.removeWhere((p) => (p as Map)['_id'] == plotId));
    await Api.removeFavourite(plotId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Favourites', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.textDark)),
          Text(_loading ? '' : '${_plots.length} saved plot${_plots.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: C.textMuted)),
        ]),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: C.primary)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : _plots.isEmpty
              ? _EmptyFav()
              : RefreshIndicator(
                  color: C.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final p   = _plots[i] as Map<String, dynamic>;
                      final id  = p['_id'] as String? ?? '';
                      final d   = p['plotDetails'] as Map<String, dynamic>? ?? {};
                      final photos = p['photos'] as List? ?? [];
                      final price  = d['totalPrice'] as num? ?? 0;
                      final size   = d['plotSize']   as num? ?? 0;
                      final type   = d['plotType']   as String? ?? '';
                      final facing = d['facing']     as String? ?? '';
                      final isVerified = p['isVerified'] as bool? ?? false;

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PlotDetailScreen(plotId: id)));
                          _load();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Photo
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                              child: SizedBox(
                                width: 110, height: 110,
                                child: photos.isNotEmpty
                                    ? Image.network(_fullUrl(photos.first as String), fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: C.primaryLight,
                                          child: const Icon(Icons.landscape_rounded, color: C.primary, size: 32)))
                                    : Container(color: C.primaryLight,
                                        child: const Icon(Icons.landscape_rounded, color: C.primary, size: 32)),
                              ),
                            ),
                            // Info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(p['propertyName'] ?? 'Plot',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.textDark),
                                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    if (isVerified)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: C.successBg, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('✓', style: TextStyle(fontSize: 11, color: C.success, fontWeight: FontWeight.w800)),
                                      ),
                                  ]),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: C.textMuted),
                                    const SizedBox(width: 2),
                                    Expanded(child: Text(p['location'] ?? '',
                                        style: const TextStyle(fontSize: 12, color: C.textMuted),
                                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 5, runSpacing: 4, children: [
                                    if (size > 0)     _SmallChip('${size.toInt()} sq ft'),
                                    if (type.isNotEmpty)   _SmallChip(type),
                                    if (facing.isNotEmpty) _SmallChip(facing),
                                  ]),
                                  if (price > 0) ...[
                                    const SizedBox(height: 8),
                                    Text('₹${_fmt(price.toInt())}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.primary)),
                                  ],
                                ]),
                              ),
                            ),
                            // Remove heart
                            GestureDetector(
                              onTap: () => _remove(id),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: const Icon(Icons.favorite_rounded, color: Color(0xFFE53935), size: 22),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  const _SmallChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: C.textMuted)),
  );
}

class _EmptyFav extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), shape: BoxShape.circle),
        child: const Icon(Icons.favorite_border_rounded, size: 44, color: Color(0xFFE53935)),
      ),
      const SizedBox(height: 20),
      const Text('No favourites yet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.textDark)),
      const SizedBox(height: 8),
      const Text('Tap the ❤️ on any plot to save it here',
          style: TextStyle(color: C.textMuted, fontSize: 14)),
    ]),
  );
}

String _fullUrl(String url) => url.startsWith('http') ? url : '${Api.mediaBase}$url';
String _fmt(int n) {
  if (n >= 10000000) return '${(n/10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000)   return '${(n/100000).toStringAsFixed(1)}L';
  return n.toString();
}
