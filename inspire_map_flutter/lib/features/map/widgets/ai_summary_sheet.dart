import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/typing_text.dart';
import '../../../data/local/footprint_service.dart';
import '../../../data/local/user_prefs_service.dart';
import '../../../data/models/poi_model.dart';

class AiSummarySheet extends ConsumerStatefulWidget {
  final POIModel poi;
  final ScrollController scrollController;

  const AiSummarySheet({
    super.key,
    required this.poi,
    required this.scrollController,
  });

  @override
  ConsumerState<AiSummarySheet> createState() => _AiSummarySheetState();
}

class _AiSummarySheetState extends ConsumerState<AiSummarySheet> {
  final TextEditingController _questionController = TextEditingController();
  bool _hasCheckedIn = false;
  bool _isAsking = false;
  String? _qaAnswer;
  POIDetailModel? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _syncCheckinState();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final mbti = ref.read(userPrefsProvider).getMBTI();
    final detail = await ApiService().fetchPOIDetail(
      widget.poi.poiId,
      mbtiType: mbti,
    );
    if (!mounted) {
      return;
    }
    setState(() => _detail = detail);
  }

  void _syncCheckinState() {
    final service = ref.read(footprintServiceProvider);
    setState(() {
      _hasCheckedIn = service.hasCheckedIn(widget.poi.poiId);
    });
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isAsking) {
      return;
    }

    setState(() => _isAsking = true);
    final mbti = ref.read(userPrefsProvider).getMBTI();
    final answer = await ApiService().queryPOI(
      poiId: widget.poi.poiId,
      question: question,
      mbtiType: mbti,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _qaAnswer = answer ?? '暂时没有检索到合适答案，你可以换个问法再试试。';
      _isAsking = false;
    });
  }

  Future<void> _checkIn() async {
    ref.read(footprintServiceProvider).addFootprint(
          poiId: widget.poi.poiId,
          poiName: widget.poi.name,
          category: widget.poi.category,
          longitude: widget.poi.longitude,
          latitude: widget.poi.latitude,
        );
    await ApiService().syncFootprint(
      poiId: widget.poi.poiId,
      longitude: widget.poi.longitude,
      latitude: widget.poi.latitude,
    );
    if (!mounted) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _hasCheckedIn = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已加入足迹记录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tips = _detail?.tips ?? <String>[];
    final summary = _detail?.aiSummaryMbti ??
        _detail?.aiSummary ??
        widget.poi.aiSummary ??
        '暂时还没有这条地点的 AI 摘要。';
    final highlights = _buildHighlights(summary);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.rule,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildHero(),
          const SizedBox(height: 14),
          _buildSectionTitle(
            icon: Icons.auto_awesome_rounded,
            title: '看点速览',
          ),
          const SizedBox(height: 8),
          _buildSummaryCard(summary: summary, highlights: highlights),
          const SizedBox(height: 16),
          _buildSectionTitle(
            icon: Icons.lightbulb_rounded,
            title: '避坑指南',
          ),
          const SizedBox(height: 8),
          _buildTipsSection(tips),
          const SizedBox(height: 16),
          _buildSectionTitle(
            icon: Icons.chat_bubble_outline_rounded,
            title: '问问真实旅友',
            trailing: Text(
              '真实旅伴',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '基于社区反馈的真实点评为你解答',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              height: 1.5,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          _buildAskBar(),
          if (_qaAnswer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.rule),
              ),
              child: TypingText(
                fullText: _qaAnswer!,
                charIntervalMs: 16,
                initialDelayMs: 120,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  height: 1.75,
                  color: AppColors.inkMid,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('准备为你打开 ${widget.poi.name} 的导航。')),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: Text(
                      '地图导航',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildActionCircle(
                icon: _hasCheckedIn
                    ? Icons.check_circle_rounded
                    : Icons.add_location_alt_rounded,
                enabled: !_hasCheckedIn,
                onTap: _hasCheckedIn ? null : _checkIn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFEFF6F7),
            Color(0xFFF8F5EF),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Text(
              widget.poi.category,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.teal.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 56),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.poi.name,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.poi.address ?? '暂无详细地址',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9EEDC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: AppColors.ochre),
                    const SizedBox(width: 4),
                    Text(
                      widget.poi.rating.toStringAsFixed(1),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ochre,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(widget.poi.category),
              if ((widget.poi.subCategory ?? '').isNotEmpty) _heroChip(widget.poi.subCategory!),
              if ((_detail?.bestVisitTime ?? '').isNotEmpty) _heroChip(_detail!.bestVisitTime!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String summary,
    required List<String> highlights,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.teal),
              const SizedBox(width: 6),
              Text(
                '看点速览',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tealDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TypingText(
            fullText: summary,
            charIntervalMs: 14,
            initialDelayMs: 120,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.8,
              color: AppColors.inkMid,
            ),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 5, color: AppColors.teal),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.7,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipsSection(List<String> tips) {
    final displayTips = tips.isEmpty
        ? <String>['建议避开最热门时段前往，留出更从容的体验时间。']
        : tips;
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in displayTips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.location_on_rounded, size: 13, color: AppColors.ochre),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        height: 1.7,
                        color: AppColors.inkMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAskBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EBF0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '例如：这里什么时候去人最少？',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.inkFaint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isAsking ? null : _askQuestion,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isAsking ? AppColors.inkSoft : AppColors.tealDeep,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isAsking ? Icons.hourglass_top_rounded : Icons.send_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.teal),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.notoSerifSc(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: const BorderSide(color: AppColors.rule),
          backgroundColor: Colors.white,
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 18, color: enabled ? AppColors.ink : AppColors.inkFaint),
      ),
    );
  }

  Widget _heroChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.tealDeep,
        ),
      ),
    );
  }

  List<String> _buildHighlights(String summary) {
    final fromDetail = _detail?.aiHighlights ?? const <String>[];
    if (fromDetail.isNotEmpty) {
      return fromDetail.take(4).toList();
    }

    return summary
        .replaceAll('\r', '')
        .split(RegExp(r'[。\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList();
  }
}
