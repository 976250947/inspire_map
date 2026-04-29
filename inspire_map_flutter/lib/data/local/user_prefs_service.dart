import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 管理本地的用户偏好设置 (MBTI, 人格, 偏好标签等)
class UserPrefsService {
  final Box _box;

  UserPrefsService(this._box);

  // ══════════════════════════════════════════
  //  MBTI 相关
  // ══════════════════════════════════════════

  /// 保存 MBTI 类型 (如 "INTJ")
  Future<void> saveMBTI(String mbti) async {
    await _box.put('mbti_type', mbti);
  }

  /// 获取 MBTI 类型
  String? getMBTI() {
    return _box.get('mbti_type') as String?;
  }

  /// 保存旅行人格 (如 "城市观察者")
  Future<void> savePersona(String persona) async {
    await _box.put('mbti_persona', persona);
  }

  /// 获取旅行人格
  String? getPersona() {
    return _box.get('mbti_persona') as String?;
  }

  /// 保存旅行偏好标签 (如 ["喜欢安静", "文化探索"])
  Future<void> saveTravelTags(List<String> tags) async {
    await _box.put('travel_tags', tags);
  }

  /// 获取旅行偏好标签
  List<String> getTravelTags() {
    final raw = _box.get('travel_tags');
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }

  // ══════════════════════════════════════════
  //  引导状态
  // ══════════════════════════════════════════

  /// 是否已完成问卷引导
  bool get hasCompletedOnboarding {
    return getMBTI() != null;
  }

  // ══════════════════════════════════════════
  //  清理
  // ══════════════════════════════════════════

  /// 清除所有用户偏好
  Future<void> clearAll() async {
    await _box.clear();
  }
}

/// 提供全区单例的 Provider
final userPrefsProvider = Provider<UserPrefsService>((ref) {
  final box = Hive.box('user_prefs');
  return UserPrefsService(box);
});
