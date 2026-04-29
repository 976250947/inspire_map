/// 《灵感经纬》全局色彩体系
/// 设计语言：Editorial Paper — 纸质编辑型美学
///
/// 主色调随 MBTI 动态变化：
/// - E人偏暖（琥珀/珊瑚）
/// - I人偏冷（靛蓝/薄荷）
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ══════════════════════════════════════════
  //  暗色基底 — 墨夜 (Dark theme)
  // ══════════════════════════════════════════
  static const Color inkDark = Color(0xFF0B0E17);
  static const Color inkDarkLight = Color(0xFF141829);
  static const Color inkDarkMid = Color(0xFF1C2137);
  static const Color surface = Color(0xFF232842);
  static const Color surfaceLight = Color(0xFF2D3352);

  // ══════════════════════════════════════════
  //  暗色主题金 (Dark theme)
  // ══════════════════════════════════════════
  static const Color amber = Color(0xFFE8A838);
  static const Color amberLight = Color(0xFFF2C97D);
  static const Color amberDim = Color(0xFF8B6914);

  // ══════════════════════════════════════════
  //  暗色功能色 (Dark theme)
  // ══════════════════════════════════════════
  static const Color coral = Color(0xFFFF6B6B);
  static const Color mint = Color(0xFF4ECDC4);
  static const Color lavender = Color(0xFF9B8EC4);
  static const Color sky = Color(0xFF45B7D1);

  // ══════════════════════════════════════════
  //  暗色文字 (Dark theme)
  // ══════════════════════════════════════════
  static const Color textPrimary = Color(0xFFF0EDE6);
  static const Color textSecondary = Color(0xFF9A9DB5);
  static const Color textTertiary = Color(0xFF5C6080);
  static const Color textOnAccent = Color(0xFF0B0E17);

  // ══════════════════════════════════════════
  //  暗色毛玻璃 & 遮罩 (Dark theme)
  // ══════════════════════════════════════════
  static const Color glassBg = Color(0x33232842);
  static const Color glassBorder = Color(0x22F0EDE6);
  static const Color overlay = Color(0x990B0E17);

  // ══════════════════════════════════════════
  //  亮色 — Paper Editorial 色系
  // ══════════════════════════════════════════
  static const Color paper = Color(0xFFF8F5EF);
  static const Color paperWarm = Color(0xFFF2EDE4);
  static const Color ink = Color(0xFF1C2B2D);
  static const Color inkMid = Color(0xFF3D5055);
  static const Color inkSoft = Color(0xFF7A8D90);
  static const Color inkFaint = Color(0xFFB8C5C7);
  static const Color rule = Color(0xFFE2DDD6);

  // ══════════════════════════════════════════
  //  品牌色 — Teal 系列
  // ══════════════════════════════════════════
  static const Color teal = Color(0xFF1A7A8C);
  static const Color tealDeep = Color(0xFF0D5260);
  static const Color tealDim = Color(0xFF2D6E7A);
  static const Color tealWash = Color(0xFFE8F3F5);
  static const Color tealMist = Color(0xFFF0F7F8);

  // ══════════════════════════════════════════
  //  暖色强调 — Ochre 赭石
  // ══════════════════════════════════════════
  static const Color ochre = Color(0xFFB8732A);
  static const Color ochreWash = Color(0xFFFBF0E4);

  // ══════════════════════════════════════════
  //  向后兼容别名 (逐步迁移)
  // ══════════════════════════════════════════
  static const Color bgLight = paper;
  static const Color cardWhite = paper;
  static const Color textDark = ink;
  static const Color textMedium = inkMid;
  static const Color textLight = inkSoft;
  static const Color divider = rule;
  static const Color tealSoft = tealWash;
  static const Color tealLight = Color(0xFF4DB6C4);

  // ══════════════════════════════════════════
  //  MBTI 四象限色系映射
  //  ES: 热情珊瑚 | EN: 明亮琥珀
  //  IN: 柔和薰衣草 | IS: 自然薄荷
  // ══════════════════════════════════════════
  static const Color mbtiES = Color(0xFFE86452);     // 外向感知 — 热情珊瑚
  static const Color mbtiEN = Color(0xFFE07B39);     // 外向直觉 — 明亮琥珀
  static const Color mbtiIN = Color(0xFF7B6BA5);     // 内向直觉 — 柔和薰衣草
  static const Color mbtiIS = Color(0xFF4A9A8C);     // 内向感知 — 自然薄荷

  static const Color mbtiESLight = Color(0xFFFDE8E5);
  static const Color mbtiENLight = Color(0xFFFAEDE3);
  static const Color mbtiINLight = Color(0xFFEDE8F5);
  static const Color mbtiISLight = Color(0xFFE3F2EE);

  static Color mbtiAccent(String? mbtiType) {
    if (mbtiType == null || mbtiType.isEmpty) return teal;
    final ei = mbtiType[0].toUpperCase();
    final ns = mbtiType.length > 1 ? mbtiType[1].toUpperCase() : '';

    if (ei == 'E' && ns == 'S') return mbtiES;
    if (ei == 'E' && ns == 'N') return mbtiEN;
    if (ei == 'I' && ns == 'N') return mbtiIN;
    if (ei == 'I' && ns == 'S') return mbtiIS;
    return teal;
  }

  static Color mbtiAccentLight(String? mbtiType) {
    if (mbtiType == null || mbtiType.isEmpty) return tealWash;
    final ei = mbtiType[0].toUpperCase();
    final ns = mbtiType.length > 1 ? mbtiType[1].toUpperCase() : '';

    if (ei == 'E' && ns == 'S') return mbtiESLight;
    if (ei == 'E' && ns == 'N') return mbtiENLight;
    if (ei == 'I' && ns == 'N') return mbtiINLight;
    if (ei == 'I' && ns == 'S') return mbtiISLight;
    return tealWash;
  }
}
