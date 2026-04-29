import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 一个简单的组件，用于实现列表项进入时的交错（Staggered）动画效果。
/// 常用于 AI 摘要、搜索结果等列表。
class StaggeredListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final int delayMs;

  const StaggeredListItem({
    super.key,
    required this.child,
    this.index = 0,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return child.animate()
        .fadeIn(delay: (delayMs + (index * 100)).ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }
}
