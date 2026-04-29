/// 浮动搜索框 — Editorial Paper 风格
/// 纸质半透明 + 毛玻璃 + 圆形筛选按钮
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../core/widgets/tap_scale.dart';

class FloatingSearchBar extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;

  const FloatingSearchBar({super.key, this.onTap, this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.inkSoft,
                  size: 16,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '想去哪儿看看？',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                // Filter button
                GestureDetector(
                  onTap: onFilterTap,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.tealWash,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.teal,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.15, curve: Curves.easeOutBack);
  }
}
