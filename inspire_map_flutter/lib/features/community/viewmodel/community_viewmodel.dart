import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_service.dart';

class CommunityPost {
  final String id;
  final String authorId;
  final String? authorNickname;
  final String? authorAvatar;
  final String? authorMbti;
  final String content;
  final String? poiName;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.authorNickname,
    this.authorAvatar,
    this.authorMbti,
    required this.content,
    this.poiName,
    required this.tags,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    required this.createdAt,
  });

  CommunityPost copyWith({int? likeCount, int? commentCount, bool? isLiked}) {
    return CommunityPost(
      id: id,
      authorId: authorId,
      authorNickname: authorNickname,
      authorAvatar: authorAvatar,
      authorMbti: authorMbti,
      content: content,
      poiName: poiName,
      tags: tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt,
    );
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? {};
    return CommunityPost(
      id: (json['id'] ?? '').toString(),
      authorId: (author['id'] ?? '').toString(),
      authorNickname: author['nickname'] as String?,
      authorAvatar: author['avatar_url'] as String?,
      authorMbti: author['mbti_type'] as String?,
      content: json['content'] as String? ?? '',
      poiName: json['poi_name'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class CommunityState {
  final List<CommunityPost> posts;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;

  const CommunityState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
  });

  CommunityState copyWith({
    List<CommunityPost>? posts,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
  }) {
    return CommunityState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class CommunityViewModel extends StateNotifier<CommunityState> {
  CommunityViewModel() : super(const CommunityState()) {
    loadPosts();
  }

  Future<void> loadPosts() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, currentPage: 1);

    final result = await ApiService().fetchPosts(page: 1);
    if (result != null) {
      final list = (result['posts'] as List<dynamic>? ?? [])
          .map((item) => CommunityPost.fromJson(item as Map<String, dynamic>))
          .toList();
      final total = result['total'] as int? ?? 0;
      state = CommunityState(
        posts: list,
        isLoading: false,
        hasMore: list.length < total,
        currentPage: 1,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    final nextPage = state.currentPage + 1;
    final result = await ApiService().fetchPosts(page: nextPage);
    if (result != null) {
      final list = (result['posts'] as List<dynamic>? ?? [])
          .map((item) => CommunityPost.fromJson(item as Map<String, dynamic>))
          .toList();
      final total = result['total'] as int? ?? 0;
      final allPosts = [...state.posts, ...list];
      state = state.copyWith(
        posts: allPosts,
        isLoading: false,
        hasMore: allPosts.length < total,
        currentPage: nextPage,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleLike(String postId) async {
    final idx = state.posts.indexWhere((post) => post.id == postId);
    if (idx < 0) return;

    final post = state.posts[idx];
    final newLiked = !post.isLiked;
    final newCount = post.likeCount + (newLiked ? 1 : -1);

    final updated = List<CommunityPost>.from(state.posts);
    updated[idx] = post.copyWith(isLiked: newLiked, likeCount: newCount);
    state = state.copyWith(posts: updated);

    final api = ApiService();
    final success = newLiked ? await api.likePost(postId) : await api.unlikePost(postId);
    if (!success) {
      final rollback = List<CommunityPost>.from(state.posts);
      rollback[idx] = post;
      state = state.copyWith(posts: rollback);
    }
  }

  void incrementCommentCount(String postId) {
    final idx = state.posts.indexWhere((post) => post.id == postId);
    if (idx < 0) return;
    final post = state.posts[idx];
    final updated = List<CommunityPost>.from(state.posts);
    updated[idx] = post.copyWith(commentCount: post.commentCount + 1);
    state = state.copyWith(posts: updated);
  }
}

final communityProvider = StateNotifierProvider<CommunityViewModel, CommunityState>((ref) {
  return CommunityViewModel();
});
