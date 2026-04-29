/// 足迹地图卡片组件 — Editorial Paper 风格
/// Paper 背景 + rule 边框 + teal accent
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../core/widgets/tap_scale.dart';
import '../../../data/local/footprint_service.dart';
import '../../../data/local/user_prefs_service.dart';
import '../../../core/utils/geo_province_lookup.dart';
import 'china_map_widget.dart';

class FootprintMapCard extends ConsumerWidget {
  const FootprintMapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final footprintService = ref.read(footprintServiceProvider);
    final prefs = ref.read(userPrefsProvider);
    final mbti = prefs.getMBTI();

    final footprints = footprintService.getFootprints();
    final visitedProvinces = <String>{};
    for (final fp in footprints) {
      final province = GeoProvinceLookup.findProvince(fp.longitude, fp.latitude);
      if (province != null) visitedProvinces.add(province);
    }

    final totalProvinces = GeoProvinceLookup.allProvinces.length;
    final litCount = visitedProvinces.length;
    final accentColor = AppColors.mbtiAccent(mbti);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TapScale(
        onTap: () => context.push(AppRouter.footprints),
        scaleDown: 0.98,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.rule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.tealWash,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.public_rounded, color: AppColors.teal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '足迹地图',
                          style: GoogleFonts.notoSerifSc(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已点亮 $litCount / $totalProvinces 个省份',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.tealWash,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${(litCount / totalProvinces * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ChinaMapWidget(
                  litProvinces: visitedProvinces,
                  accentColor: accentColor,
                  showLabels: true,
                ),
              ),

              if (litCount == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.paperWarm,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.explore_rounded, size: 14, color: AppColors.inkSoft),
                        const SizedBox(width: 8),
                        Text(
                          '去探索地图，打卡点亮你的省份吧',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
