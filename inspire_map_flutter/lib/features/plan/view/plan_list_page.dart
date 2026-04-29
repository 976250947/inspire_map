import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tap_scale.dart';
import '../viewmodel/plan_list_viewmodel.dart';
import '../data/plan_model.dart';
import 'package:intl/intl.dart';

class PlanListPage extends ConsumerWidget {
  const PlanListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planListProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(
          '我的行程',
          style: GoogleFonts.notoSerifSc(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.coral, size: 48),
              const SizedBox(height: 16),
              Text('加载失败', style: GoogleFonts.dmSans(fontSize: 16)),
              TextButton(
                onPressed: () => ref.read(planListProvider.notifier).refresh(),
                child: const Text('重试'),
              )
            ],
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_rounded, size: 64, color: AppColors.ink.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text(
                    '暂无行程规划',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 18,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '去首页让智能伴游帮你规划吧',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(planListProvider.notifier).refresh(),
            color: AppColors.teal,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return _buildPlanCard(context, plan);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, TravelPlan plan) {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return TapScale(
      onTap: () {
        context.push('/plans/${plan.planId}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.ink.withValues(alpha: 0.9), AppColors.ink],
                  ),
                ),
              ),
              // Map Icon Decoration
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.map_rounded,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${plan.city} • ${plan.days}天',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateFormat.format(plan.createdAt),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      plan.title,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timeline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          '${plan.itineraryData.expand((e) => e.stops).length} 个打卡点',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.check_box_outlined, size: 14, color: AppColors.tealWash),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.checklistData.where((e) => e.checked).length}/${plan.checklistData.length} 项准备',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.tealWash,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
