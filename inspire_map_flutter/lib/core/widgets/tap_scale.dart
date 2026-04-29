// 通用点击缩放反馈包装器
// 为可点击组件提供统一的 scale 动效
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final double pressedOpacity;
  final Duration pressInDuration;
  final SpringDescription spring;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
    this.pressedOpacity = 0.94,
    this.pressInDuration = const Duration(milliseconds: 80),
    this.spring = const SpringDescription(
      mass: 1,
      stiffness: 620,
      damping: 34,
    ),
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
      duration: widget.pressInDuration,
    );
  }

  Future<void> _handleTapDown() async {
    await _controller.animateTo(
      1,
      duration: widget.pressInDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _release() {
    _controller.animateWith(
      SpringSimulation(widget.spring, _controller.value, 0.0, -1.8),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) {
        _release();
        widget.onTap?.call();
      },
      onTapCancel: _release,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final scale = lerpDouble(1.0, widget.scaleDown, t) ?? 1.0;
          final opacity = lerpDouble(1.0, widget.pressedOpacity, t) ?? 1.0;

          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
