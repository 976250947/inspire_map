import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/plan_model.dart';
import '../../../../core/widgets/tap_scale.dart';

class ChecklistCard extends StatelessWidget {
  final List<ChecklistItem> checklist;
  final Function(int) onToggle;

  const ChecklistCard({
    super.key,
    required this.checklist,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (checklist.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tealWash,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_box_outlined, color: AppColors.teal, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '行前准备',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                '${checklist.where((e) => e.checked).length} / ${checklist.length}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(checklist.length, (index) {
            final item = checklist[index];
            return TapScale(
              onTap: () => onToggle(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: item.checked ? AppColors.teal : Colors.transparent,
                        border: Border.all(
                          color: item.checked ? AppColors.teal : AppColors.divider,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: item.checked
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: item.checked ? AppColors.inkSoft : AppColors.ink,
                          decoration: item.checked ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.inkSoft,
                        ),
                        child: Text(item.item),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
