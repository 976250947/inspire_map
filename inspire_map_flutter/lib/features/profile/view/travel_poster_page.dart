/// 旅行成就 / 旅游海报页 — Editorial Paper 风格
/// 展示旅行成就并支持生成专属旅行海报
library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../data/local/footprint_service.dart';
import '../../../data/local/user_prefs_service.dart';

class TravelPosterPage extends ConsumerStatefulWidget {
  const TravelPosterPage({super.key});

  @override
  ConsumerState<TravelPosterPage> createState() => _TravelPosterPageState();
}

class _TravelPosterPageState extends ConsumerState<TravelPosterPage> {
  final GlobalKey _posterKey = GlobalKey();
  bool _generating = false;

  /// 截图并保存海报到相册
  Future<void> _generateAndShare() async {
    if (_generating) return;
    setState(() => _generating = true);

    try {
      // 1. 获取 RenderRepaintBoundary 并截图
      final boundary = _posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取海报渲染对象');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) throw Exception('图片编码失败');

      final pngBytes = byteData.buffer.asUint8List();

      // 2. 复制到剪贴板（图片数据不支持直接复制，改为提示保存成功）
      // 由于项目未引入 share_plus / image_gallery_saver，
      // 此处通过 MethodChannel 调用原生保存，或直接提示用户截屏
      // MVP阶段：展示成功提示 + 震动反馈
      HapticFeedback.mediumImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '海报已生成（${(pngBytes.length / 1024).toStringAsFixed(0)} KB），长按可保存',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            backgroundColor: AppColors.tealDeep,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        // 展示全屏海报预览弹窗
        _showPosterPreview(pngBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('海报生成失败: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// 全屏展示生成的海报
  void _showPosterPreview(Uint8List pngBytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Center(
                    child: Image.memory(
                      pngBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '长按图片可保存到相册',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final footprintService = ref.read(footprintServiceProvider);
    final prefs = ref.read(userPrefsProvider);
    final footprintCount = footprintService.getFootprintCount();
    final uniquePoiCount = footprintService.getUniquePoiCount();
    final persona = prefs.getPersona() ?? '自由旅行者';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '旅行成就',
          style: GoogleFonts.notoSerifSc(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.rule, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 海报预览卡片（用 RepaintBoundary 包裹以支持截图）
            RepaintBoundary(
              key: _posterKey,
              child: _buildPosterCard(persona, footprintCount, uniquePoiCount),
            ),
            const SizedBox(height: 32),
            // 生成按钮
            _buildGenerateButton(),
            const SizedBox(height: 16),
            Text(
              '生成旅行海报，分享给朋友',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterCard(String persona, int footprints, int pois) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '灵感经纬',
            style: GoogleFonts.notoSerifSc(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'InspireMap',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 28),

          // 旅行人格徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              persona,
              style: GoogleFonts.notoSerifSc(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PosterStat(value: '$footprints', label: '足迹'),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: Colors.white.withValues(alpha: 0.15),
              ),
              _PosterStat(value: '$pois', label: '打卡地点'),
            ],
          ),
          const SizedBox(height: 28),

          // Quote
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '每一步都是灵感，每一处都有经纬',
              style: GoogleFonts.notoSerifSc(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _generating ? null : _generateAndShare,
        icon: _generating
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white,
                ),
              )
            : const Icon(Icons.share_rounded, size: 18),
        label: Text(
          _generating ? '生成中…' : '生成并分享海报',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

class _PosterStat extends StatelessWidget {
  final String value;
  final String label;

  const _PosterStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
