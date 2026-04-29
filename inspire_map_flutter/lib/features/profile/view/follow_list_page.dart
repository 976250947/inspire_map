import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';

enum FollowListType { followers, following }

class FollowListPage extends StatefulWidget {
  final String userId;
  final FollowListType type;

  const FollowListPage({
    super.key,
    required this.userId,
    required this.type,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _users = <Map<String, dynamic>>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = widget.type == FollowListType.followers
        ? await _apiService.fetchFollowers(widget.userId)
        : await _apiService.fetchFollowing(widget.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == FollowListType.followers ? '粉丝' : '关注';
    final emptyText = widget.type == FollowListType.followers
        ? '还没有粉丝'
        : '还没有关注的人';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        title: Text(
          title,
          style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            )
          : _users.isEmpty
              ? Center(
                  child: Text(
                    emptyText,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.inkSoft,
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.rule),
                    itemBuilder: (context, index) {
                      return _FollowUserTile(user: _users[index]);
                    },
                  ),
                ),
    );
  }
}

class _FollowUserTile extends StatefulWidget {
  final Map<String, dynamic> user;

  const _FollowUserTile({required this.user});

  @override
  State<_FollowUserTile> createState() => _FollowUserTileState();
}

class _FollowUserTileState extends State<_FollowUserTile> {
  final ApiService _apiService = ApiService();
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    final userId = widget.user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      return;
    }
    final isFollowing = await _apiService.isFollowing(userId);
    if (!mounted) {
      return;
    }
    setState(() => _isFollowing = isFollowing);
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) {
      return;
    }
    final userId = widget.user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isLoading = true);

    final success = _isFollowing
        ? await _apiService.unfollowUser(userId)
        : await _apiService.followUser(userId);

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() => _isFollowing = !_isFollowing);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final nickname = widget.user['nickname'] as String? ?? '旅行者';
    final mbti = widget.user['mbti_type'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.teal,
            child: Text(
              nickname.isEmpty ? '旅' : nickname[0],
              style: GoogleFonts.notoSerifSc(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                if (mbti.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tealWash,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      mbti,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _isLoading ? null : _toggleFollow,
            style: FilledButton.styleFrom(
              backgroundColor: _isFollowing ? AppColors.paperWarm : AppColors.ink,
              foregroundColor: _isFollowing ? AppColors.ink : Colors.white,
            ),
            child: Text(_isFollowing ? '已关注' : '关注'),
          ),
        ],
      ),
    );
  }
}
