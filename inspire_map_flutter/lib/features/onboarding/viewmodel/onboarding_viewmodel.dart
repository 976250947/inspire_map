import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_service.dart';
import '../../../data/local/user_prefs_service.dart';

class OnboardingState {
  final Map<int, int> selectedAnswers; // questionIndex -> optionIndex
  final bool isCompleted;
  final String? resultMbti;
  final String? resultPersona;

  OnboardingState({
    required this.selectedAnswers,
    this.isCompleted = false,
    this.resultMbti,
    this.resultPersona,
  });

  OnboardingState copyWith({
    Map<int, int>? selectedAnswers,
    bool? isCompleted,
    String? resultMbti,
    String? resultPersona,
  }) {
    return OnboardingState(
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      isCompleted: isCompleted ?? this.isCompleted,
      resultMbti: resultMbti ?? this.resultMbti,
      resultPersona: resultPersona ?? this.resultPersona,
    );
  }
}

/// MBTI 旅行人格映射表
/// 根据 4 字母组合，生成贴合旅行场景的人格昵称
const Map<String, String> _mbtiPersonaMap = {
  'INTJ': '城市观察者',
  'INTP': '人文探索家',
  'ENTJ': '旅行策划师',
  'ENTP': '跨界冒险王',
  'INFJ': '心灵旅者',
  'INFP': '诗意漫游者',
  'ENFJ': '文化传播者',
  'ENFP': '多巴胺寻猎者',
  'ISTJ': '经典路线守护者',
  'ISFJ': '温柔记录者',
  'ESTJ': '特种兵团长',
  'ESFJ': '旅行社交官',
  'ISTP': '野外求生者',
  'ISFP': '光影捕手',
  'ESTP': '极限体验官',
  'ESFP': '派对发起人',
};

class OnboardingViewModel extends StateNotifier<OnboardingState> {
  final Ref ref;

  OnboardingViewModel(this.ref) : super(OnboardingState(selectedAnswers: {}));

  void selectAnswer(int questionIndex, int optionIndex) {
    final newAnswers = Map<int, int>.from(state.selectedAnswers);
    newAnswers[questionIndex] = optionIndex;
    state = state.copyWith(selectedAnswers: newAnswers);
  }

  /// 在最后一题完成后调用，计算 MBTI
  ///
  /// 问卷与计分规则（对应 OnboardingPage 中的4道题）：
  /// - Q0: 选项 0,1 → I   选项 2,3 → E
  /// - Q1: 选项 0,1 → N   选项 2,3 → S
  /// - Q2: 选项 0,1 → F   选项 2,3 → T
  /// - Q3: 选项 0,1 → P   选项 2,3 → J
  Future<void> completeAndCalculateMBTI() async {
    final answers = state.selectedAnswers;

    // 四个维度判定：选项 0/1 = 第一个字母，选项 2/3 = 第二个字母
    final String ei = (answers[0] != null && answers[0]! <= 1) ? 'I' : 'E';
    final String ns = (answers[1] != null && answers[1]! <= 1) ? 'N' : 'S';
    final String tf = (answers[2] != null && answers[2]! <= 1) ? 'F' : 'T';
    final String jp = (answers[3] != null && answers[3]! <= 1) ? 'P' : 'J';

    final String mbti = '$ei$ns$tf$jp';

    // 根据 MBTI 维度生成旅行标签
    final List<String> travelTags = [];
    travelTags.add(ei == 'I' ? '喜欢安静' : '喜欢热闹');
    travelTags.add(ns == 'N' ? '探索未知' : '经典路线');
    travelTags.add(tf == 'F' ? '氛围至上' : '效率优先');
    travelTags.add(jp == 'J' ? '计划控' : '随性派');

    // 从 Q0 具体选项推断自然/城市偏好
    if (answers[0] == 1) {
      travelTags.add('亲近自然'); // 选了 "亲近自然"
    } else {
      travelTags.add('都市探索');
    }

    // 查找旅行人格昵称
    final String persona = _mbtiPersonaMap[mbti] ?? '自由旅行者';

    // 存储至 Hive
    final prefs = ref.read(userPrefsProvider);
    await prefs.saveMBTI(mbti);
    await prefs.savePersona(persona);
    await prefs.saveTravelTags(travelTags);

    // 异步上传到服务端（fire-and-forget，不阻塞本地流程）
    ApiService().uploadMBTI(
      mbtiType: mbti,
      persona: persona,
      travelTags: travelTags,
    );

    state = state.copyWith(
      isCompleted: true,
      resultMbti: mbti,
      resultPersona: persona,
    );
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingViewModel, OnboardingState>((ref) {
  return OnboardingViewModel(ref);
});
