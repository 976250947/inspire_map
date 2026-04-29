/// 收藏夹页 — Editorial Paper 风格
/// 展示用户收藏的 POI 地点列表
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          '收藏夹',
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
      body: _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 56,
            color: AppColors.inkFaint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '收藏夹是空的',
            style: GoogleFonts.notoSerifSc(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMid,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在地图上点击灵感地点，收藏想去的地方',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
