import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/mbti_theme_extension.dart';
import '../../../core/widgets/tap_scale.dart';
import '../../../data/local/user_prefs_service.dart';
import '../viewmodel/ai_chat_viewmodel.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 420),
          curve: const Cubic(0.2, 0.9, 0.2, 1.0),
        );
      }
    });
  }

  void _handleSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final userPrefs = ref.watch(userPrefsProvider);
    final persona = userPrefs.getPersona() ?? '旅行者';

    ref.listen(aiChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          (next.messages.isNotEmpty && next.messages.last.isStreaming)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          _buildHeader(persona, chatState.isSending),
          if (chatState.pendingPlanData != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PendingPlanCard(
                title: chatState.pendingPlanTitle ?? '新行程',
                city: chatState.pendingPlanCity,
                days: chatState.pendingPlanDays,
                isSaving: chatState.isConfirmingPlanSave,
                onConfirm: () => ref.read(aiChatProvider.notifier).confirmPendingPlanSave(),
                onDismiss: () => ref.read(aiChatProvider.notifier).dismissPendingPlan(),
              ),
            ),
          if (chatState.latestSavedPlanId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: InkWell(
                onTap: () => context.push('/plans/${chatState.latestSavedPlanId}'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tealWash,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_note_rounded,
                        color: AppColors.tealDeep,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '已保存到我的行程：${chatState.latestSavedPlanTitle ?? '新行程'}',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tealDeep,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.tealDeep,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final msg = chatState.messages[index];
                if (msg.isUser) {
                  return Padding(
                    key: ValueKey('user-${msg.id}'),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _MessageAppear(
                      delay: const Duration(milliseconds: 40),
                      child: _UserBubble(text: msg.content),
                    ),
                  );
                }
                return Padding(
                  key: ValueKey('ai-${msg.id}'),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MessageAppear(
                    delay: const Duration(milliseconds: 50),
                    child: _AiBubble(
                      text: msg.content,
                      isStreaming: msg.isStreaming,
                    ),
                  ),
                );
              },
            ),
          ),
          _buildInputBar(chatState.isSending),
        ],
      ),
    );
  }

  Widget _buildHeader(String persona, bool isSending) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 8,
        20,
        14,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.97),
        border: const Border(bottom: BorderSide(color: AppColors.rule)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.tealDeep, AppColors.teal],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '灵感伴游',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isSending ? '正在思考中...' : '已了解 $persona 的偏好',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: isSending ? AppColors.ochre : AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
          TapScale(
            onTap: () => context.push(AppRouter.routePlan),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.ochreWash,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.route_rounded,
                    size: 14,
                    color: AppColors.ochre,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '规划行程',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ochre,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          TapScale(
            onTap: () => ref.read(aiChatProvider.notifier).clearChat(),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.refresh_rounded,
                color: AppColors.inkSoft,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isSending) {
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomPad = keyboardUp
        ? 8.0
        : MediaQuery.of(context).padding.bottom + 72;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: AppColors.rule)),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 46, maxHeight: 120),
        padding: const EdgeInsets.only(left: 16, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.rule),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: '聊聊你的旅行想法...',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.inkFaint,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TapScale(
                onTap: isSending ? null : _handleSend,
                scaleDown: 0.9,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSending ? AppColors.inkFaint : AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: isSending
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPlanCard extends StatelessWidget {
  final String title;
  final String? city;
  final int? days;
  final bool isSaving;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _PendingPlanCard({
    required this.title,
    required this.city,
    required this.days,
    required this.isSaving,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (city != null && city!.isNotEmpty) city!,
      if (days != null && days! > 0) '$days天',
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFD6AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.ochre),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '攻略已生成',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TapScale(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.notoSerifSc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: isSaving ? null : onConfirm,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Center(
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '确认添加到我的行程',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TapScale(
                onTap: isSaving ? null : onDismiss,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.rule),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.md),
            topRight: Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            height: 1.6,
            color: AppColors.paper,
          ),
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final String text;
  final bool isStreaming;

  const _AiBubble({required this.text, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paperWarm,
          border: Border.all(color: AppColors.rule),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.md),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: AppColors.tealDeep,
                ),
                const SizedBox(width: 6),
                Text(
                  '灵感伴游',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.tealDeep,
                  ),
                ),
                if (isStreaming) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.tealDeep.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (text.isEmpty && isStreaming)
              Text(
                '思考中...',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.inkFaint,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                text,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.inkMid,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageAppear extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _MessageAppear({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_MessageAppear> createState() => _MessageAppearState();
}

class _MessageAppearState extends State<_MessageAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.2, 0.9, 0.2, 1.0),
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}
