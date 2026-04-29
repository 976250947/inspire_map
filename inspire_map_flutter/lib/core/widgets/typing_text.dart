/// 打字机效果文本组件
/// 模拟 AI 流式生成的逐字显示效果
/// 支持自定义打字速度、光标闪烁、完成回调
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TypingText extends StatefulWidget {
  /// 完整待显示文本
  final String fullText;

  /// 文本样式
  final TextStyle? style;

  /// 每个字符的显示间隔 (毫秒)
  final int charIntervalMs;

  /// 开始打字前的延迟 (毫秒)
  final int initialDelayMs;

  /// 是否显示闪烁光标
  final bool showCursor;

  /// 打字完成后的回调
  final VoidCallback? onComplete;

  const TypingText({
    super.key,
    required this.fullText,
    this.style,
    this.charIntervalMs = 35,
    this.initialDelayMs = 600,
    this.showCursor = true,
    this.onComplete,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText>
    with SingleTickerProviderStateMixin {
  String _displayedText = '';
  int _currentIndex = 0;
  Timer? _typingTimer;
  bool _isComplete = false;

  // 光标闪烁
  late final AnimationController _cursorController;
  late final Animation<double> _cursorOpacity;

  @override
  void initState() {
    super.initState();

    // 光标闪烁动画
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _cursorOpacity = CurvedAnimation(
      parent: _cursorController,
      curve: Curves.easeInOut,
    );

    // 延迟后开始打字
    Future.delayed(Duration(milliseconds: widget.initialDelayMs), () {
      if (mounted) _startTyping();
    });
  }

  void _startTyping() {
    _typingTimer = Timer.periodic(
      Duration(milliseconds: widget.charIntervalMs),
      (timer) {
        if (_currentIndex < widget.fullText.length) {
          setState(() {
            _currentIndex++;
            _displayedText = widget.fullText.substring(0, _currentIndex);
          });
        } else {
          timer.cancel();
          setState(() => _isComplete = true);
          _cursorController.stop();
          widget.onComplete?.call();
        }
      },
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const defaultStyle = TextStyle(
      fontSize: 13,
      color: AppColors.inkMid,
      height: 1.6,
      letterSpacing: 0.2,
    );

    return _displayedText.isEmpty && !_isComplete
        ? _buildLoadingState()
        : RichText(
            text: TextSpan(
              text: _displayedText,
              style: widget.style ?? defaultStyle,
              children: [
                if (widget.showCursor && !_isComplete)
                  WidgetSpan(
                    child: FadeTransition(
                      opacity: _cursorOpacity,
                      child: Container(
                        width: 2,
                        height: 16,
                        margin: const EdgeInsets.only(left: 1),
                        color: AppColors.teal,
                      ),
                    ),
                  ),
              ],
            ),
          );
  }

  /// 打字开始前的 AI 思考加载态
  Widget _buildLoadingState() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.teal.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'AI 正在分析...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.teal.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

