import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../data/local/user_prefs_service.dart';

class PublishPostPage extends ConsumerStatefulWidget {
  const PublishPostPage({super.key});

  @override
  ConsumerState<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends ConsumerState<PublishPostPage> {
  static const int _maxImages = 9;
  static const List<String> _tags = <String>[
    '种草',
    '避坑',
    '美食',
    '攻略',
    '打卡',
    '求助',
  ];

  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<String> _selectedImages = <String>[];
  bool _isPublishing = false;
  String _selectedTag = '种草';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _selectedImages.length;
    if (remaining <= 0) {
      return;
    }

    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) {
      return;
    }

    setState(() {
      for (final item in files) {
        if (_selectedImages.length < _maxImages) {
          _selectedImages.add(item.path);
        }
      }
    });
  }

  Future<void> _publish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showMessage('请输入想分享的内容');
      return;
    }

    if ((ApiService().getAuthToken() ?? '').isEmpty) {
      _showMessage('请先登录后再发布');
      return;
    }

    setState(() => _isPublishing = true);
    final imageUrls = _selectedImages.isEmpty
        ? <String>[]
        : await ApiService().uploadImages(_selectedImages);
    final result = await ApiService().publishPost(
      content: content,
      tags: <String>[_selectedTag],
      images: imageUrls,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isPublishing = false);

    if (result != null) {
      _showMessage('发布成功');
      context.pop();
      return;
    }

    _showMessage('发布失败，请稍后重试');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final persona = ref.watch(userPrefsProvider).getPersona() ?? '旅行者';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        title: Text(
          '发布动态',
          style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isPublishing ? null : _publish,
            child: Text(
              _isPublishing ? '发布中...' : '发布',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: AppColors.tealDeep,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.tealWash,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '当前旅行身份：$persona',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealDeep,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '标签',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final selected = _selectedTag == tag;
                return ChoiceChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedTag = tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              '图片（${_selectedImages.length}/$_maxImages）',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedImages.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(entry.value),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedImages.removeAt(entry.key));
                          },
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_selectedImages.length < _maxImages)
                  InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.rule),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _contentController,
              minLines: 8,
              maxLines: 12,
              maxLength: 2000,
              style: GoogleFonts.dmSans(fontSize: 15, height: 1.7),
              decoration: InputDecoration(
                hintText: '分享一下你的旅行见闻、路线心得或者避坑建议...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.inkFaint,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.rule),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.rule),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
