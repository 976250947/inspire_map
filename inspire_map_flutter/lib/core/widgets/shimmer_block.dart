import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

class ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBlock({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.paperWarm,
      highlightColor: AppColors.paper,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.paperWarm,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerLines extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;

  const ShimmerLines({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
          child: ShimmerBlock(
            height: lineHeight,
            width: isLast ? 160 : double.infinity,
            borderRadius: 6,
          ),
        );
      }),
    );
  }
}
