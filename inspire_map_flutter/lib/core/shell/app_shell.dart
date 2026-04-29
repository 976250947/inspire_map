import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/mbti_theme_extension.dart';
import '../widgets/tap_scale.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRouter.profile)) return 3;
    if (location.startsWith(AppRouter.community)) return 2;
    if (location.startsWith(AppRouter.aiChat)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = math.max(280.0, math.min(screenWidth - 68, 318.0));
    final bottomOffset = MediaQuery.of(context).padding.bottom + 10;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomOffset,
            child: Center(
              child: Container(
                width: barWidth,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / 4;
                    return SizedBox(
                      height: 38,
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 380),
                            curve: const Cubic(0.2, 0.95, 0.2, 1.0),
                            left: itemWidth * index,
                            top: 0,
                            bottom: 0,
                            width: itemWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.paper,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _NavPill(
                                  label: '探索',
                                  icon: Icons.explore_rounded,
                                  isActive: index == 0,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    context.go(AppRouter.map);
                                  },
                                ),
                              ),
                              Expanded(
                                child: _NavPill(
                                  label: '伴游',
                                  icon: Icons.auto_awesome_rounded,
                                  isActive: index == 1,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    context.go(AppRouter.aiChat);
                                  },
                                ),
                              ),
                              Expanded(
                                child: _NavPill(
                                  label: '社区',
                                  icon: Icons.groups_rounded,
                                  isActive: index == 2,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    context.go(AppRouter.community);
                                  },
                                ),
                              ),
                              Expanded(
                                child: _NavPill(
                                  label: '我的',
                                  icon: Icons.person_rounded,
                                  isActive: index == 3,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    context.go(AppRouter.profile);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
    );
  }
}

class _NavPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scaleDown: 0.92,
      pressedOpacity: 0.9,
      child: SizedBox(
        height: 38,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.ink : Colors.white.withValues(alpha: 0.64),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.ink : Colors.white.withValues(alpha: 0.64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
