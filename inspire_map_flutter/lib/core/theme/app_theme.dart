/// 《灵感经纬》全局主题配置
/// Editorial Paper 亮色主题 + 墨舆暗色主题
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'mbti_theme_extension.dart';

class AppTheme {
  AppTheme._();

  static ThemeData getTheme(String? mbtiType, {bool isDark = false}) {
    Color mbtiColor = AppColors.teal;
    Color mbtiLight = AppColors.tealWash;

    if (mbtiType != null && mbtiType.length >= 2) {
      final ei = mbtiType[0].toUpperCase();
      final ns = mbtiType[1].toUpperCase();

      if (ei == 'E' && ns == 'S') {
        // ES 型（ESFP/ESTP/ESFJ/ESTJ）— 热情珊瑚，活力暖色
        mbtiColor = const Color(0xFFE86452);
        mbtiLight = const Color(0xFFFDE8E5);
      } else if (ei == 'E' && ns == 'N') {
        // EN 型（ENFP/ENTP/ENFJ/ENTJ）— 明亮琥珀，探索感
        mbtiColor = const Color(0xFFE07B39);
        mbtiLight = const Color(0xFFFAEDE3);
      } else if (ei == 'I' && ns == 'N') {
        // IN 型（INFP/INTP/INFJ/INTJ）— 柔和薰衣草，沉静内敛
        mbtiColor = const Color(0xFF7B6BA5);
        mbtiLight = const Color(0xFFEDE8F5);
      } else if (ei == 'I' && ns == 'S') {
        // IS 型（ISFP/ISTP/ISFJ/ISTJ）— 自然薄荷，稳重平和
        mbtiColor = const Color(0xFF4A9A8C);
        mbtiLight = const Color(0xFFE3F2EE);
      }
    }

    final mbtiExt = MbtiThemeExtension(
      mbtiPrimary: mbtiColor,
      mbtiSecondary: mbtiLight,
      mbtiShadowSoft: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 30,
          offset: const Offset(0, 12),
        )
      ],
      mbtiShadowFloat: [
        BoxShadow(
          color: mbtiColor.withValues(alpha: 0.15),
          blurRadius: 40,
          offset: const Offset(0, 20),
        )
      ],
    );

    return isDark ? _buildDark(mbtiColor, mbtiExt) : _buildLight(mbtiColor, mbtiExt);
  }

  // ══════════════════════════════════════════
  //  亮色主题 — Editorial Paper
  // ══════════════════════════════════════════
  static ThemeData _buildLight(Color primaryColor, MbtiThemeExtension ext) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: AppColors.paper,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paper,
      extensions: [ext],

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSerifSc(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),

      textTheme: TextTheme(
        // 衬线标题
        displayLarge: GoogleFonts.notoSerifSc(
          fontSize: 36, fontWeight: FontWeight.w700,
          color: AppColors.ink, height: 1.15, letterSpacing: -0.02,
        ),
        displayMedium: GoogleFonts.notoSerifSc(
          fontSize: 30, fontWeight: FontWeight.w700,
          color: AppColors.ink, height: 1.2,
        ),
        headlineLarge: GoogleFonts.notoSerifSc(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: AppColors.ink, height: 1.4,
        ),
        headlineMedium: GoogleFonts.notoSerifSc(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: AppColors.ink, height: 1.3,
        ),
        // 无衬线正文
        titleLarge: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: AppColors.inkMid, height: 1.65, letterSpacing: 0.2,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: AppColors.inkMid, height: 1.6,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: AppColors.inkSoft, height: 1.5,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w500,
          color: AppColors.paper,
        ),
        labelMedium: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: AppColors.inkMid,
        ),
        labelSmall: GoogleFonts.dmSans(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.teal,
          letterSpacing: 0.12 * 11,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.paper,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.paper,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      // 输入框 — editorial 底线风格由自定义组件实现，此处备用
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: GoogleFonts.dmSans(color: AppColors.inkFaint, fontSize: 16, fontWeight: FontWeight.w300),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.rule)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.rule)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.ink)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        dragHandleColor: AppColors.rule,
        dragHandleSize: Size(32, 3),
        showDragHandle: false,
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // ══════════════════════════════════════════
  //  暗色主题 — 墨舆
  // ══════════════════════════════════════════
  static ThemeData _buildDark(Color primaryColor, MbtiThemeExtension ext) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [ext],
      scaffoldBackgroundColor: AppColors.inkDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.amber,
        onPrimary: AppColors.textOnAccent,
        secondary: AppColors.mint,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.coral,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: 'Roboto', fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5, height: 1.3),
        headlineMedium: TextStyle(fontFamily: 'Roboto', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.3, height: 1.3),
        titleLarge: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 0.2),
        titleMedium: TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.6),
        bodyMedium: TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
        labelLarge: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.amber, letterSpacing: 0.8),
        labelSmall: TextStyle(fontFamily: 'Roboto', fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary, letterSpacing: 0.5),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassBg,
        hintStyle: const TextStyle(fontFamily: 'Roboto', color: AppColors.textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.amber, width: 1)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.textOnAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkDarkLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        dragHandleColor: AppColors.textTertiary,
        dragHandleSize: Size(36, 4),
        showDragHandle: true,
      ),
    );
  }
}
