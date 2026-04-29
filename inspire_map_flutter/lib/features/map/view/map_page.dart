import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer_block.dart';
import '../../../data/local/user_prefs_service.dart';
import '../../../data/models/poi_model.dart';
import '../viewmodel/map_viewmodel.dart';
import '../widgets/ai_summary_sheet.dart';
import '../widgets/maplibre_core_view.dart';
import '../widgets/search_overlay.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  static const List<_MapCategory> _categories = <_MapCategory>[
    _MapCategory('全部', null),
    _MapCategory('景点', '景点'),
    _MapCategory('美食', '美食'),
    _MapCategory('文化', '文化'),
    _MapCategory('自然', '自然'),
    _MapCategory('购物', '购物'),
    _MapCategory('夜生活', '夜生活'),
  ];

  final GlobalKey<MaplibreCoreViewState> _mapKey = GlobalKey<MaplibreCoreViewState>();

  void _onCategoryChanged(String? category) {
    HapticFeedback.selectionClick();
    ref.read(mapProvider.notifier).setCategory(category);
  }

  void _onMarkerTap(POIModel poi) {
    HapticFeedback.selectionClick();
    ref.read(mapProvider.notifier).selectPoi(poi);
    _mapKey.currentState?.animateTo(
      poi.latitude,
      poi.longitude,
      zoom: _mapKey.currentState?.currentZoom ?? 14,
    );
  }

  void _onClusterTap(POIClusterModel cluster) {
    HapticFeedback.selectionClick();
    ref.read(mapProvider.notifier).onClusterTap(cluster);
  }

  void _openSearch() {
    final currentPois = ref.read(mapProvider).pois;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SearchOverlay(
          pois: currentPois,
          onSelect: (poi) {
            _onMarkerTap(poi);
            _mapKey.currentState?.animateTo(poi.latitude, poi.longitude);
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.2, 0.9, 0.2, 1.0),
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: mapState.loading
                ? const ShimmerBlock(width: double.infinity, height: double.infinity)
                : MaplibreCoreView(
                    key: _mapKey,
                    pois: mapState.isRouteMode ? const [] : mapState.pois,
                    clusters: mapState.isRouteMode ? const [] : mapState.clusters,
                    routeLineCoords: mapState.visibleRouteCoords,
                    routePoints: mapState.visibleRoutePoints,
                    onMarkerTap: _onMarkerTap,
                    onClusterTap: _onClusterTap,
                    onBoundsChanged: ref.read(mapProvider.notifier).onBoundsChanged,
                    mbtiType: ref.read(userPrefsProvider).getMBTI(),
                  ),
          ),
          if (!mapState.isRouteMode)
            Positioned(
              top: topInset + 8,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapSearchBar(onTap: _openSearch),
                  const SizedBox(height: 10),
                  _MapCategoryBar(
                    categories: _categories,
                    selectedValue: mapState.selectedCategory,
                    onChanged: _onCategoryChanged,
                  ),
                ],
              ),
            ),
          if (mapState.isRouteMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 12,
              right: 12,
              child: _RouteModeBar(
                days: mapState.routeDays,
                selectedDay: mapState.routeVisibleDay,
                onDayChanged: (day) {
                  HapticFeedback.selectionClick();
                  ref.read(mapProvider.notifier).setRouteVisibleDay(day);
                },
                onExit: () {
                  HapticFeedback.mediumImpact();
                  ref.read(mapProvider.notifier).clearRouteLine();
                },
              ),
            ),
          if (!mapState.isRouteMode && mapState.hasData)
            Positioned(
              left: 12,
              bottom: bottomInset + 92,
              child: _MapStatChip(
                title: mapState.selectedProvince == null
                    ? '发现 ${mapState.totalCount} 处灵感'
                    : '${mapState.selectedProvince} ${mapState.totalCount} 处灵感',
                onClear: mapState.selectedProvince == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        ref.read(mapProvider.notifier).clearProvinceFocus();
                        _mapKey.currentState?.animateToCenter();
                      },
              ),
            ),
          if (!mapState.isRouteMode)
            Positioned(
              right: 12,
              bottom: bottomInset + 86,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundToolButton(
                    size: 34,
                    backgroundColor: Colors.white,
                    iconColor: AppColors.inkSoft,
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _mapKey.currentState?.animateToCenter();
                    },
                  ),
                  const SizedBox(height: 10),
                  _RoundToolButton(
                    size: 40,
                    backgroundColor: AppColors.ochre,
                    iconColor: Colors.white,
                    icon: Icons.alt_route_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push(AppRouter.routePlan);
                    },
                  ),
                  const SizedBox(height: 10),
                  _RoundToolButton(
                    size: 44,
                    backgroundColor: AppColors.teal,
                    iconColor: Colors.white,
                    icon: Icons.auto_awesome_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.go(AppRouter.aiChat);
                    },
                  ),
                ],
              ),
            ),
          if (mapState.selectedPoi != null)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                if (notification.extent <= 0.1) {
                  ref.read(mapProvider.notifier).selectPoi(null);
                }
                return true;
              },
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(mapProvider.notifier).selectPoi(null),
                      child: Container(color: Colors.black.withValues(alpha: 0.16)),
                    ),
                  ),
                ],
              ),
            ),
          if (mapState.selectedPoi != null)
            DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.05,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const <double>[0.45, 0.92],
              builder: (context, scrollController) {
                return AiSummarySheet(
                  poi: mapState.selectedPoi!,
                  scrollController: scrollController,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MapCategory {
  final String label;
  final String? value;

  const _MapCategory(this.label, this.value);
}

class _MapSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _MapSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 16, color: AppColors.inkFaint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '想去哪儿看看？',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.inkFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.tealWash,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.tune_rounded, size: 14, color: AppColors.teal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCategoryBar extends StatelessWidget {
  final List<_MapCategory> categories;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _MapCategoryBar({
    required this.categories,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = categories[index];
          final selected =
              item.value == selectedValue || (item.value == null && selectedValue == null);
          return GestureDetector(
            onTap: () => onChanged(item.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF4A155) : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected
                    ? const <BoxShadow>[]
                    : const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: Text(
                item.label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.inkSoft,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapStatChip extends StatelessWidget {
  final String title;
  final VoidCallback? onClear;

  const _MapStatChip({
    required this.title,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5FD),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.place_rounded, size: 12, color: AppColors.teal),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMid,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 14, color: AppColors.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onTap;

  const _RoundToolButton({
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: size * 0.44, color: iconColor),
        ),
      ),
    );
  }
}

class _RouteModeBar extends StatelessWidget {
  final List<int> days;
  final int? selectedDay;
  final ValueChanged<int?> onDayChanged;
  final VoidCallback onExit;

  const _RouteModeBar({
    required this.days,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkSoft),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RouteDayChip(
                  label: '全部',
                  selected: selectedDay == null,
                  onTap: () => onDayChanged(null),
                ),
                for (final day in days)
                  _RouteDayChip(
                    label: 'D$day',
                    selected: selectedDay == day,
                    onTap: () => onDayChanged(day),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RouteDayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ochre : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
