/// 足迹历史列表页 — Editorial Paper 风格
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../data/local/footprint_service.dart';
import '../../../data/models/footprint_model.dart';

class FootprintListPage extends ConsumerWidget {
  const FootprintListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final footprintService = ref.read(footprintServiceProvider);
    final footprints = footprintService.getFootprints();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '我的足迹',
          style: GoogleFonts.notoSerifSc(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.rule, height: 1),
        ),
      ),
      body: footprints.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: footprints.length,
              itemBuilder: (context, index) {
                return _buildFootprintCard(footprints[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_off_rounded,
            size: 56,
            color: AppColors.inkFaint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有足迹',
            style: GoogleFonts.notoSerifSc(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMid,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '去地图上探索灵感地点，打卡留下你的足迹吧',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFootprintCard(FootprintModel footprint) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(footprint.checkedAt);
    final categoryIcon = _getCategoryIcon(footprint.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.rule)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tealWash,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(categoryIcon, color: AppColors.teal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        footprint.poiName,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.tealWash,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        footprint.category,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (footprint.note != null && footprint.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      footprint.note!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.inkMid,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: AppColors.inkFaint),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      default: return Icons.place_rounded;
    }
  }
}
