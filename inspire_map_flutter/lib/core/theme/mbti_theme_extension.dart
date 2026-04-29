import 'package:flutter/material.dart';

/// 8pt grid 间距体系
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double xxxxl = 48.0;
}

/// 圆角体系 — 匹配 Editorial Paper 设计
class AppRadius {
  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double pill = 999.0;
}

/// MBTI 动态主题引擎
class MbtiThemeExtension extends ThemeExtension<MbtiThemeExtension> {
  final Color mbtiPrimary;
  final Color mbtiSecondary;
  final List<BoxShadow> mbtiShadowSoft;
  final List<BoxShadow> mbtiShadowFloat;

  const MbtiThemeExtension({
    required this.mbtiPrimary,
    required this.mbtiSecondary,
    required this.mbtiShadowSoft,
    required this.mbtiShadowFloat,
  });

  @override
  ThemeExtension<MbtiThemeExtension> copyWith({
    Color? mbtiPrimary,
    Color? mbtiSecondary,
    List<BoxShadow>? mbtiShadowSoft,
    List<BoxShadow>? mbtiShadowFloat,
  }) {
    return MbtiThemeExtension(
      mbtiPrimary: mbtiPrimary ?? this.mbtiPrimary,
      mbtiSecondary: mbtiSecondary ?? this.mbtiSecondary,
      mbtiShadowSoft: mbtiShadowSoft ?? this.mbtiShadowSoft,
      mbtiShadowFloat: mbtiShadowFloat ?? this.mbtiShadowFloat,
    );
  }

  @override
  ThemeExtension<MbtiThemeExtension> lerp(ThemeExtension<MbtiThemeExtension>? other, double t) {
    if (other is! MbtiThemeExtension) {
      return this;
    }
    return MbtiThemeExtension(
      mbtiPrimary: Color.lerp(mbtiPrimary, other.mbtiPrimary, t) ?? mbtiPrimary,
      mbtiSecondary: Color.lerp(mbtiSecondary, other.mbtiSecondary, t) ?? mbtiSecondary,
      mbtiShadowSoft: BoxShadow.lerpList(mbtiShadowSoft, other.mbtiShadowSoft, t) ?? mbtiShadowSoft,
      mbtiShadowFloat: BoxShadow.lerpList(mbtiShadowFloat, other.mbtiShadowFloat, t) ?? mbtiShadowFloat,
    );
  }
}
