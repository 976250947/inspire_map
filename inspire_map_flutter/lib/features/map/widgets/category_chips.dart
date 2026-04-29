/// 分类筛选标签栏 — Editorial Paper 风格
/// 纸质半透明 frosted 小药丸
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';

class CategoryChips extends StatefulWidget {
  final ValueChanged<String?> onCategoryChanged;

  const CategoryChips({super.key, required this.onCategoryChanged});

  @override
  State<CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  int _selected = 0;

  static const _categories = [
    _ChipData('全部', null),
    _ChipData('景点', '景点'),
    _ChipData('美食', '美食'),
    _ChipData('文化', '文化'),
    _ChipData('自然', '自然'),
    _ChipData('购物', '购物'),
    _ChipData('夜生活', '夜生活'),
  ];

  @override
  Widget build(BuildContext context) {
    final mbtiExt = Theme.of(context).extension<MbtiThemeExtension>();
    final accentColor = mbtiExt?.mbtiPrimary ?? AppColors.teal;

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isActive = index == _selected;

          return GestureDetector(
            onTap: () {
              if (_selected != index) {
                HapticFeedback.selectionClick();
                setState(() => _selected = index);
                widget.onCategoryChanged(cat.value);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? accentColor : AppColors.paper.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isActive ? accentColor : Colors.white.withValues(alpha: 0.85),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : AppColors.inkMid,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChipData {
  final String label;
  final String? value;
  const _ChipData(this.label, this.value);
}
