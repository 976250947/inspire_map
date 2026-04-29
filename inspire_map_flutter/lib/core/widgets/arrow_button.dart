import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/mbti_theme_extension.dart';
import 'tap_scale.dart';

class ArrowButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isOutline;

  const ArrowButton({
    super.key,
    required this.text,
    this.onTap,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutline) {
      return TapScale(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.rule),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.inkMid,
            ),
          ),
        ),
      );
    }

    return TapScale(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap?.call();
      },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.only(left: 24, right: 6, top: 6, bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paper,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.paper,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.ink,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
