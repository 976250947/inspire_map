import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../viewmodel/community_viewmodel.dart';
import 'comment_sheet.dart';

class CommunityPage extends ConsumerWidget {
  final String? initialPostId;

  const CommunityPage({super.key, this.initialPostId});

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dateTime.month}/${dateTime.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          backgroundColor: AppColors.ink,
          onPressed: () {
            HapticFeedback.selectionClick();
            context.push(AppRouter.publishPost);
          },
          child: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: () => ref.read(communityProvider.notifier).loadPosts(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 20,
            20,
            120,
          ),
          children: [
            Text(
              '社区灵感',
              style: GoogleFonts.notoSerifSc(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '旅行者的经验、避坑和路线灵感都在这里。',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 20),
            if (state.isLoading && state.posts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              )
            else if (state.posts.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.rule),
                ),
                child: Text(
                  '还没有社区内容，去发布第一条动态吧。',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.inkSoft,
                  ),
                ),
              )
            else
              ...state.posts.map(
                (post) => Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.rule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.teal,
                            child: Text(
                              (post.authorNickname ?? '旅')[0],
                              style: GoogleFonts.notoSerifSc(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.authorNickname ?? '匿名旅行者',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  _formatTime(post.createdAt),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((post.authorMbti ?? '').isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.tealWash,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                post.authorMbti!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.tealDeep,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((post.poiName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          post.poiName!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ochre,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        post.content,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.inkMid,
                        ),
                      ),
                      if (post.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: post.tags
                              .map((tag) => Chip(label: Text('#$tag')))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              ref.read(communityProvider.notifier).toggleLike(post.id);
                            },
                            icon: Icon(
                              post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 18,
                              color: post.isLiked ? AppColors.coral : AppColors.inkSoft,
                            ),
                            label: Text('${post.likeCount}'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final hasNew = await showCommentSheet(context, post.id);
                              if (hasNew) {
                                ref.read(communityProvider.notifier).incrementCommentCount(post.id);
                              }
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: Text('${post.commentCount}'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
