/// POI 搜索覆盖层 — Editorial Paper 风格
/// 全屏 paper 背景 + 自动聚焦搜索框 + 后端实时搜索
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../core/network/api_service.dart';
import '../../../data/models/poi_model.dart';

class SearchOverlay extends StatefulWidget {
  final List<POIModel> pois;
  final ValueChanged<POIModel> onSelect;

  const SearchOverlay({
    super.key,
    required this.pois,
    required this.onSelect,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _controller = TextEditingController();
  List<POIModel> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _debounce?.cancel();
      setState(() { _results = []; _isSearching = false; });
      return;
    }

    // 本地已有 POI 先做即时过滤（无延迟）
    final localResults = widget.pois.where((poi) {
      final q = query.toLowerCase();
      return poi.name.toLowerCase().contains(q) ||
          poi.category.toLowerCase().contains(q) ||
          (poi.subCategory?.toLowerCase().contains(q) ?? false) ||
          (poi.address?.toLowerCase().contains(q) ?? false);
    }).toList();
    setState(() => _results = localResults);

    // 防抖 400ms 后调用后端搜索
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final remote = await ApiService().searchPOIs(query);
      if (!mounted || _controller.text.trim() != query) return;

      // 合并本地 + 远程结果，去重
      final seen = <String>{};
      final merged = <POIModel>[];
      for (final p in [...localResults, ...remote]) {
        if (seen.add(p.poiId)) merged.add(p);
      }
      setState(() { _results = merged; _isSearching = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          // Search header
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(bottom: BorderSide(color: AppColors.rule)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back_rounded, color: AppColors.ink, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.paperWarm,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.rule),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 16, color: AppColors.inkSoft),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              hintText: '搜索地点、分类...',
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.inkFaint,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => _controller.clear(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded, size: 16, color: AppColors.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _controller.text.isEmpty
                ? _buildHintState()
                : _isSearching && _results.isEmpty
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal))
                    : _results.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              return _buildResultItem(_results[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 48, color: AppColors.inkFaint.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            '输入关键词搜索地图上的地点',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.inkFaint.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            '没有找到匹配的地点',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(POIModel poi) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        widget.onSelect(poi);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.rule)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.tealWash,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(_getCategoryIcon(poi.category), color: AppColors.teal, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tealWash,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          poi.category,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tealDeep,
                          ),
                        ),
                      ),
                      if (poi.address != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            poi.address!,
                            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.inkSoft),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint, size: 18),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '美食': return Icons.restaurant_rounded;
      case '景点': return Icons.photo_camera_rounded;
      case '文化': return Icons.museum_rounded;
      case '购物': return Icons.shopping_bag_rounded;
      case '咖啡': return Icons.local_cafe_rounded;
      case '自然': return Icons.park_rounded;
      case '夜生活': return Icons.nightlife_rounded;
      default: return Icons.place_rounded;
    }
  }
}
