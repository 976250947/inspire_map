import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';

class _CommentItem {
  final String id;
  final String nickname;
  final String content;
  final String? mbtiType;
  final String? parentId;
  final DateTime createdAt;

  const _CommentItem({
    required this.id,
    required this.nickname,
    required this.content,
    this.mbtiType,
    this.parentId,
    required this.createdAt,
  });

  factory _CommentItem.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return _CommentItem(
      id: (json['id'] ?? '').toString(),
      nickname: user['nickname'] as String? ?? '匿名用户',
      content: json['content'] as String? ?? '',
      mbtiType: user['mbti_type'] as String?,
      parentId: json['parent_id']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

Future<bool> showCommentSheet(BuildContext context, String postId) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentSheet(postId: postId),
  );
  return result ?? false;
}

class _CommentSheet extends StatefulWidget {
  final String postId;

  const _CommentSheet({required this.postId});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_CommentItem> _comments = <_CommentItem>[];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasNewComment = false;
  String? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final result = await _apiService.fetchComments(widget.postId);
    if (!mounted) {
      return;
    }

    final comments = ((result?['comments'] as List<dynamic>?) ?? <dynamic>[])
        .map((item) => _CommentItem.fromJson(item as Map<String, dynamic>))
        .toList();

    setState(() {
      _comments = comments;
      _isLoading = false;
    });
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    final result = await _apiService.createComment(
      widget.postId,
      content: text,
      parentId: _replyToId,
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      _controller.clear();
      _replyToId = null;
      _replyToName = null;
      _hasNewComment = true;
      await _loadComments();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }

    setState(() => _isSending = false);
  }

  Future<void> _deleteComment(_CommentItem comment) async {
    final success = await _apiService.deleteComment(comment.id);
    if (!mounted) {
      return;
    }
    if (success) {
      _hasNewComment = true;
      await _loadComments();
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}/${time.day}';
  }

  _CommentItem? _findParent(String? parentId) {
    if (parentId == null) {
      return null;
    }
    for (final item in _comments) {
      if (item.id == parentId) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.rule,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          ListTile(
            title: Text(
              '评论',
              style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_comments.length} 条',
              style: GoogleFonts.dmSans(color: AppColors.inkSoft),
            ),
            trailing: IconButton(
              onPressed: () => Navigator.of(context).pop(_hasNewComment),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          const Divider(height: 1, color: AppColors.rule),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.teal),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          '还没有评论，来抢个沙发吧。',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.rule),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final parent = _findParent(comment.parentId);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Text(
                                  comment.nickname,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((comment.mbtiType ?? '').isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealWash,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Text(
                                      comment.mbtiType!,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.tealDeep,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (parent != null)
                                  Text(
                                    '回复 ${parent.nickname}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: AppColors.tealDeep,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  comment.content,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: AppColors.inkMid,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      _formatTime(comment.createdAt),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: AppColors.inkFaint,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _replyToId = comment.id;
                                          _replyToName = comment.nickname;
                                        });
                                      },
                                      child: Text(
                                        '回复',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => _deleteComment(comment),
                                      child: Text(
                                        '删除',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: AppColors.inkFaint,
                                        ),
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
          if (_replyToName != null)
            Container(
              width: double.infinity,
              color: AppColors.paperWarm,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '正在回复 $_replyToName',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.tealDeep,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      });
                    },
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 3,
                    minLines: 1,
                    style: GoogleFonts.dmSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _replyToName == null ? '说点什么...' : '回复 $_replyToName...',
                      filled: true,
                      fillColor: AppColors.paperWarm,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSending ? null : _sendComment,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
