import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'plot_detail_screen.dart';

class HomeTab extends StatefulWidget {
  final void Function(int) onSwitchTab;
  const HomeTab({super.key, required this.onSwitchTab});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _searchCtrl = TextEditingController();
  String _facing = 'Any';
  String _plotType = 'Any';
  int? _minPrice;
  int? _maxPrice;
  List<dynamic> _plots = [];
  Set<String> _favIds = {};
  bool _loading = true;
  bool _more = false;
  int _page = 1;

  final _facings = [
    'Any',
    'North',
    'South',
    'East',
    'West',
    'North-East',
    'North-West',
    'South-East',
    'South-West'
  ];
  final _plotTypes = [
    'Any',
    'Agricultural',
    'Residential',
    'Commercial',
    'Industrial'
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _loadFavIds();
  }

  Future<void> _loadFavIds() async {
    try {
      final res = await Api.getFavouriteIds();
      if (mounted)
        setState(() => _favIds = Set<String>.from(res['ids'] as List? ?? []));
    } catch (_) {}
  }

  Future<void> _load({bool reset = true}) async {
    if (reset)
      setState(() {
        _loading = true;
        _page = 1;
      });
    try {
      final res = await Api.getPlots(
        search:
            _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        facing: _facing,
        plotType: _plotType,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        page: reset ? 1 : _page,
      );
      final list = res['properties'] as List? ?? [];
      if (mounted)
        setState(() {
          _plots = reset ? list : [..._plots, ...list];
          _more = (res['page'] ?? 1) < (res['pages'] ?? 1);
          _page = (res['page'] ?? 1) + 1;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFav(String plotId) async {
    final wasFav = _favIds.contains(plotId);
    setState(() {
      wasFav ? _favIds.remove(plotId) : _favIds.add(plotId);
    });
    try {
      await Api.toggleFavourite(plotId, wasFav);
    } catch (_) {
      if (mounted)
        setState(() {
          wasFav ? _favIds.add(plotId) : _favIds.remove(plotId);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: RefreshIndicator(
        color: C.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Top bar: location + icons ─────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        color: C.primary, size: 18),
                    const SizedBox(width: 4),
                    const Expanded(
                        child: Text('Amritsar, Punjab',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: C.textDark))),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: C.textDark, size: 22),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: C.textDark, size: 22),
                      onPressed: () => widget.onSwitchTab(2),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Search bar
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                          hintText: 'Search plots…',
                          hintStyle:
                              const TextStyle(color: C.textLight, fontSize: 14),
                          prefixIcon: const Icon(Icons.search,
                              color: C.textMuted, size: 20),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: C.primary, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Filter button
                    GestureDetector(
                      onTap: () => _showFilters(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: C.primary,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),

            // ── Hero banner ───────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                height: 160,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6A1B9A), C.primary, C.primaryMid],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(children: [
                  // Background decoration
                  Positioned(
                      right: 16,
                      bottom: 0,
                      child: Opacity(
                          opacity: 0.18,
                          child: Icon(Icons.landscape_rounded,
                              size: 140, color: Colors.white))),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Find your',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                          const Text('perfect plot',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1)),
                          const SizedBox(height: 6),
                          const Text('Verified plots, great locations.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Explore Now',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: C.primary)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded,
                                        size: 14, color: C.primary),
                                  ]),
                            ),
                          ),
                        ]),
                  ),
                ]),
              ),
            ),

            // ── Active filters ────────────────────────────────
            if (_facing != 'Any' ||
                _plotType != 'Any' ||
                _minPrice != null ||
                _maxPrice != null)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    children: [
                      if (_facing != 'Any')
                        _FilterPill('Facing: $_facing', () {
                          setState(() => _facing = 'Any');
                          _load();
                        }),
                      if (_plotType != 'Any')
                        _FilterPill('Type: $_plotType', () {
                          setState(() => _plotType = 'Any');
                          _load();
                        }),
                      if (_minPrice != null || _maxPrice != null)
                        _FilterPill(_priceLabel(), () {
                          setState(() {
                            _minPrice = null;
                            _maxPrice = null;
                          });
                          _load();
                        }),
                    ],
                  ),
                ),
              ),

            // ── Section header ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(children: [
                  const Expanded(
                      child: Text('Near By Your location',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: C.textDark))),
                  if (!_loading)
                    Text('${_plots.length} plots',
                        style:
                            const TextStyle(fontSize: 12, color: C.textMuted)),
                ]),
              ),
            ),

            // ── Plot list ─────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(color: C.primary)))
            else if (_plots.isEmpty)
              SliverFillRemaining(child: _Empty(onReset: () {
                _searchCtrl.clear();
                setState(() {
                  _facing = 'Any';
                  _plotType = 'Any';
                  _minPrice = null;
                  _maxPrice = null;
                });
                _load();
              }))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final p = _plots[i] as Map<String, dynamic>;
                    final id = p['_id'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _PlotCard(
                        plot: p,
                        isFav: _favIds.contains(id),
                        onFavTap: () => _toggleFav(id),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlotDetailScreen(plotId: id),
                              ));
                          _loadFavIds();
                        },
                      ),
                    );
                  },
                  childCount: _plots.length,
                ),
              ),

            if (_more && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: OutlinedButton(
                    onPressed: () => _load(reset: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.primary,
                      side: const BorderSide(color: C.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Load More',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  String _priceLabel() {
    final mn = _minPrice, mx = _maxPrice;
    if (mn != null && mx != null) return 'Rs ${_fmt(mn)} - ${_fmt(mx)}';
    if (mn != null) return 'Min Rs ${_fmt(mn)}';
    if (mx != null) return 'Max Rs ${_fmt(mx)}';
    return 'Price';
  }

  void _showFilters(BuildContext context) {
    String tf = _facing, tp = _plotType;
    final tMinCtrl = TextEditingController(text: _minPrice?.toString() ?? '');
    final tMaxCtrl = TextEditingController(text: _maxPrice?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
          builder: (ctx, ss) => Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Filter Plots',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: C.textDark)),
                            TextButton(
                                onPressed: () {
                                  ss(() {
                                    tf = 'Any';
                                    tp = 'Any';
                                  });
                                  tMinCtrl.clear();
                                  tMaxCtrl.clear();
                                },
                                child: const Text('Reset',
                                    style: TextStyle(color: C.primary))),
                          ]),
                      const SizedBox(height: 16),
                      const Text('Plot Type',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: C.textDark)),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _plotTypes
                              .map((t) => ChoiceChip(
                                    label: Text(t),
                                    selected: tp == t,
                                    onSelected: (_) => ss(() => tp = t),
                                    selectedColor: C.primaryLight,
                                    labelStyle: TextStyle(
                                        color:
                                            tp == t ? C.primary : C.textMuted,
                                        fontWeight: FontWeight.w600),
                                  ))
                              .toList()),
                      const SizedBox(height: 16),
                      const Text('Price Range (Rs)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: C.textDark)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextField(
                          controller: tMinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Min',
                            prefixText: 'Rs ',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: C.border)),
                          ),
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                          controller: tMaxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Max',
                            prefixText: 'Rs ',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: C.border)),
                          ),
                        )),
                      ]),
                      const SizedBox(height: 16),
                      const Text('Facing',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: C.textDark)),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _facings
                              .map((f) => ChoiceChip(
                                    label: Text(f),
                                    selected: tf == f,
                                    onSelected: (_) => ss(() => tf = f),
                                    selectedColor: C.primaryLight,
                                    labelStyle: TextStyle(
                                        color:
                                            tf == f ? C.primary : C.textMuted,
                                        fontWeight: FontWeight.w600),
                                  ))
                              .toList()),
                      const SizedBox(height: 20),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final mn = int.tryParse(tMinCtrl.text.trim());
                              final mx = int.tryParse(tMaxCtrl.text.trim());
                              setState(() {
                                _facing = tf;
                                _plotType = tp;
                                _minPrice = mn;
                                _maxPrice = mx;
                              });
                              Navigator.pop(ctx);
                              _load();
                            },
                            child: const Text('Apply Filters'),
                          )),
                      const SizedBox(height: 8),
                    ]),
              )),
    ).whenComplete(() {
      tMinCtrl.dispose();
      tMaxCtrl.dispose();
    });
  }
}

// ── Plot card — matches the mockup design ─────────────────────
class _PlotCard extends StatelessWidget {
  final Map<String, dynamic> plot;
  final bool isFav;
  final VoidCallback onFavTap;
  final VoidCallback onTap;
  const _PlotCard(
      {required this.plot,
      required this.isFav,
      required this.onFavTap,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = plot['plotDetails'] as Map<String, dynamic>? ?? {};
    final photos = plot['photos'] as List? ?? [];
    final price = d['totalPrice'] as num? ?? 0;
    final size = d['plotSize'] as num? ?? 0;
    final facing = d['facing'] as String? ?? '';
    final type = d['plotType'] as String? ?? '';
    final isVerified = plot['isVerified'] as bool? ?? false;
    final location = plot['location'] as String? ?? '';
    final name = plot['propertyName'] as String? ?? 'Plot';
    final facilities = d['facilities'] as List? ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo with price badge + heart
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: photos.isNotEmpty
                    ? Image.network(_fullUrl(photos.first as String),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PhotoPlaceholder())
                    : _PhotoPlaceholder(),
              ),
              // Price badge top-right
              if (price > 0)
                Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: C.primary,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Rs ${_fmt(price.toInt())}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    )),
              // Heart button bottom-right
              Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onFavTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? const Color(0xFFE53935) : C.textLight,
                        size: 18,
                      ),
                    ),
                  )),
            ]),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: C.textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                if (isVerified)
                  Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.star_rounded,
                        color: Color(0xFFFFA726), size: 14),
                    SizedBox(width: 2),
                    Text('4.9',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFA726))),
                  ]),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: C.textMuted),
                const SizedBox(width: 3),
                Expanded(
                    child: Text(location,
                        style:
                            const TextStyle(fontSize: 12, color: C.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 10),
              // Facility chips + size
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (size > 0) _Chip('${size.toInt()} sq ft'),
                if (facing.isNotEmpty) _Chip('$facing Facing'),
                if (type.isNotEmpty) _Chip(type),
                ...facilities.take(2).map((f) => _Chip(f.toString())),
                if (facilities.length > 2)
                  _Chip('+${facilities.length - 2} more', isMore: true),
              ]),
              const SizedBox(height: 12),
              // View Details button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: C.primaryLight,
        child: const Center(
            child: Icon(Icons.landscape_rounded, size: 60, color: C.primary)),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isMore;
  const _Chip(this.label, {this.isMore = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isMore ? C.primaryLight : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
          border: isMore
              ? Border.all(color: C.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMore ? C.primary : C.textMuted)),
      );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterPill(this.label, this.onRemove);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onRemove,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: C.primaryLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.primary.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: C.primary)),
            const SizedBox(width: 4),
            const Icon(Icons.close, size: 13, color: C.primary),
          ]),
        ),
      );
}

class _Empty extends StatelessWidget {
  final VoidCallback onReset;
  const _Empty({required this.onReset});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🌿', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 14),
          const Text('No plots found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: C.textDark)),
          const SizedBox(height: 6),
          const Text('Try different filters',
              style: TextStyle(color: C.textMuted)),
          const SizedBox(height: 16),
          TextButton(
              onPressed: onReset,
              child: const Text('Clear Filters',
                  style: TextStyle(
                      color: C.primary, fontWeight: FontWeight.w700))),
        ]),
      );
}

String _fullUrl(String url) =>
    url.startsWith('http') ? url : 'http://localhost:5000$url';
String _fmt(int n) {
  if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
  return n.toString();
}
