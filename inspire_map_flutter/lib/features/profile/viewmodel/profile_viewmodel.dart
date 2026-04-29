import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_service.dart';
import '../../../data/local/footprint_service.dart';
import '../../../data/local/user_prefs_service.dart';

class ProfileState {
  final String? userId;
  final String? nickname;
  final String? avatarUrl;
  final String? mbti;
  final String? persona;
  final List<String> travelTags;
  final int footprintCount;
  final int uniquePoiCount;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final bool isLoading;

  const ProfileState({
    this.userId,
    this.nickname,
    this.avatarUrl,
    this.mbti,
    this.persona,
    this.travelTags = const [],
    this.footprintCount = 0,
    this.uniquePoiCount = 0,
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isLoading = false,
  });

  bool get hasProfile => mbti != null;

  ProfileState copyWith({
    String? userId,
    String? nickname,
    String? avatarUrl,
    String? mbti,
    String? persona,
    List<String>? travelTags,
    int? footprintCount,
    int? uniquePoiCount,
    int? postCount,
    int? followerCount,
    int? followingCount,
    bool? isLoading,
  }) {
    return ProfileState(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mbti: mbti ?? this.mbti,
      persona: persona ?? this.persona,
      travelTags: travelTags ?? this.travelTags,
      footprintCount: footprintCount ?? this.footprintCount,
      uniquePoiCount: uniquePoiCount ?? this.uniquePoiCount,
      postCount: postCount ?? this.postCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProfileViewModel extends StateNotifier<ProfileState> {
  final UserPrefsService _prefs;
  final FootprintService _footprintService;

  ProfileViewModel(this._prefs, this._footprintService) : super(const ProfileState()) {
    loadLocalData();
    fetchRemoteProfile();
  }

  void loadLocalData() {
    state = state.copyWith(
      mbti: _prefs.getMBTI(),
      persona: _prefs.getPersona(),
      travelTags: _prefs.getTravelTags(),
      footprintCount: _footprintService.getFootprintCount(),
      uniquePoiCount: _footprintService.getUniquePoiCount(),
    );
  }

  Future<void> fetchRemoteProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await ApiService().fetchCurrentUser();
      if (user != null) {
        state = state.copyWith(
          userId: user['id']?.toString(),
          nickname: user['nickname'] as String?,
          avatarUrl: user['avatar_url'] as String?,
          postCount: int.tryParse('${user['post_count'] ?? 0}') ?? 0,
          followerCount: int.tryParse('${user['follower_count'] ?? 0}') ?? 0,
          followingCount: int.tryParse('${user['following_count'] ?? 0}') ?? 0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    loadLocalData();
    await fetchRemoteProfile();
  }
}

final profileProvider = StateNotifierProvider<ProfileViewModel, ProfileState>((ref) {
  final prefs = ref.read(userPrefsProvider);
  final footprints = ref.read(footprintServiceProvider);
  return ProfileViewModel(prefs, footprints);
});
