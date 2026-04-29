/// 个人中心页 — Editorial Paper 风格
/// Dark ink hero + 衬线昵称 + MBTI chip + 统计行 + 菜单
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/tap_scale.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/profile_viewmodel.dart';
import '../widgets/footprint_map_card.dart';
import 'follow_list_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 ViewModel 状态，自动触发重建
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context, ref, profileState)),
          SliverToBoxAdapter(child: _buildStats(context, profileState, profileState.userId)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: FootprintMapCard(),
            ),
          ),
          SliverToBoxAdapter(child: _buildMenuSection(context, ref)),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, WidgetRef ref, ProfileState profileState) {
    final topPadding = MediaQuery.of(context).padding.top;
    final persona = profileState.persona;
    final hasProfile = profileState.hasProfile;
    final nickname = profileState.nickname ?? '旅行者';

    return Container(
      padding: EdgeInsets.fromLTRB(24, topPadding + 20, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.ink,
      ),
      child: Column(
        children: [
          // Settings icon
          Align(
            alignment: Alignment.topRight,
            child: TapScale(
              onTap: () => _showSettingsSheet(context, ref),
              child: Icon(
                Icons.settings_outlined,
                color: Colors.white.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Avatar — teal gradient circle + initial
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.tealDeep, AppColors.teal],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '旅',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Nickname — serif
          Text(
            nickname,
            style: GoogleFonts.notoSerifSc(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // 旅行人格标签
          TapScale(
            onTap: () => context.push(AppRouter.onboarding),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_rounded,
                      size: 14, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    hasProfile
                        ? persona ?? '自由旅行者'
                        : '点击测试旅行人格',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Travel tags
          if (hasProfile) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: profileState.travelTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, ProfileState profileState, String? userId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.rule),
      ),
      child: Row(
        children: [
          _StatItem(value: '${profileState.footprintCount}', label: '足迹'),
          Container(width: 1, height: 28, color: AppColors.rule),
          _StatItem(value: '${profileState.postCount}', label: '动态'),
          Container(width: 1, height: 28, color: AppColors.rule),
          _StatItem(
            value: '${profileState.followerCount}',
            label: '粉丝',
            onTap: userId != null
                ? () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FollowListPage(
                      userId: userId, type: FollowListType.followers,
                    ),
                  ))
                : null,
          ),
          Container(width: 1, height: 28, color: AppColors.rule),
          _StatItem(
            value: '${profileState.followingCount}',
            label: '关注',
            onTap: userId != null
                ? () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FollowListPage(
                      userId: userId, type: FollowListType.following,
                    ),
                  ))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的旅程',
            style: GoogleFonts.notoSerifSc(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          _MenuItem(
            icon: Icons.map_rounded,
            title: '足迹地图',
            subtitle: '看看你都去过哪儿',
            onTap: () => context.push(AppRouter.footprints),
          ),
          _MenuItem(
            icon: Icons.article_rounded,
            title: '我的动态',
            subtitle: '分享的攻略与避坑经验',
            onTap: () => context.push(AppRouter.myPosts),
          ),
          _MenuItem(
            icon: Icons.event_note_rounded,
            title: '我的行程',
            subtitle: '查看、编辑攻略清单',
            onTap: () => context.push(AppRouter.plans),
          ),
          _MenuItem(
            icon: Icons.bookmark_rounded,
            title: '收藏夹',
            subtitle: '想去的地方都在这里',
            onTap: () => context.push(AppRouter.bookmarks),
          ),
          _MenuItem(
            icon: Icons.card_giftcard_rounded,
            title: '旅行成就',
            subtitle: '生成你的旅行海报',
            onTap: () => context.push(AppRouter.travelPoster),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetContext).padding.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.rule,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              _SettingsAction(
                icon: Icons.event_note_rounded,
                title: '我的行程',
                subtitle: '查看和编辑已经保存的攻略',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRouter.plans);
                },
              ),
              _SettingsAction(
                icon: Icons.explore_rounded,
                title: '重新测试旅行人格',
                subtitle: '更新 MBTI 画像与偏好标签',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(AppRouter.onboarding);
                },
              ),
              _SettingsAction(
                icon: Icons.logout_rounded,
                title: '退出登录',
                subtitle: '清除本地登录状态并返回登录页',
                isDanger: true,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go(AppRouter.login);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatItem({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.rule)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.tealWash,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: AppColors.teal, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.inkFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDanger ? const Color(0xFFB65C4D) : AppColors.ink;

    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDanger ? const Color(0xFFF9F1EE) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDanger ? const Color(0xFFE7CEC7) : AppColors.rule,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDanger ? const Color(0xFFF3E0DA) : AppColors.paperWarm,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.inkFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
