/// 《灵感经纬》应用入口
/// InspireMap — 基于大模型与地图交互的智能伴游社区
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/models/footprint_model.dart';
import 'data/local/user_prefs_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();

  // 注册 Hive Adapter（足迹打卡模型）
  Hive.registerAdapter(FootprintModelAdapter());

  // 打开 Hive Box
  await Hive.openBox('user_prefs');
  await Hive.openBox<FootprintModel>('footprints');

  // 沉浸式状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 竖屏锁定
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: InspireMapApp(),
    ),
  );
}

class InspireMapApp extends ConsumerWidget {
  const InspireMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听本地存储的偏好 (包含 MBTI)
    final userPrefs = ref.watch(userPrefsProvider);
    final mbti = userPrefs.getMBTI();

    return MaterialApp.router(
      title: '灵感经纬',
      debugShowCheckedModeBanner: false,
      // 国际化配置 — 支持中文 locale
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      theme: AppTheme.getTheme(mbti, isDark: false),
      darkTheme: AppTheme.getTheme(mbti, isDark: true),
      // 这里的 themeMode 也可以存进 prefs，目前随系统
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}
