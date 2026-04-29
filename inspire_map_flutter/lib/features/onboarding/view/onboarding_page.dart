/// 问卷页 — Editorial Paper 风格
/// 编号列表选项 + 分段进度点 + 衬线问题
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/arrow_button.dart';
import '../../../data/local/user_prefs_service.dart';
import '../viewmodel/onboarding_viewmodel.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentPage = 0;
  int _prevPage = -1;

  final List<Map<String, dynamic>> _questions = [
    {
      'title': '出去玩的时候，\n你通常更喜欢哪种状态？',
      'options': [
        {'title': '安静独处', 'desc': '找家没人的咖啡馆发呆，或者在博物馆里慢慢逛。', 'value': 'I'},
        {'title': '亲近自然', 'desc': '去爬山、去徒步，离开城市去看看山野的风景。', 'value': 'I'},
        {'title': '市井烟火', 'desc': '钻进当地的菜市场，或者去最热闹的夜市吃路边摊。', 'value': 'E'},
        {'title': '深度沉浸', 'desc': '一个地方住一周，像当地人一样生活。', 'value': 'E'},
      ]
    },
    {
      'title': '到了一个新城市，\n你会先做什么？',
      'options': [
        {'title': '漫无目的走走', 'desc': '看到有趣的巷子就拐进去，迷路也是种乐趣。', 'value': 'N'},
        {'title': '找个高处看全景', 'desc': '先搞清楚这个城市的格局，脑中建个地图。', 'value': 'N'},
        {'title': '直奔美食地图', 'desc': '保存好的攻略一个个吃过去，认真做记录。', 'value': 'S'},
        {'title': '打卡经典景点', 'desc': '先完成"必去"清单，一个都不能落下。', 'value': 'S'},
      ]
    },
    {
      'title': '选旅行目的地的时候，\n你更看重什么？',
      'options': [
        {'title': '氛围和感觉', 'desc': '有没有那种"一到就很舒服"的气质最重要。', 'value': 'F'},
        {'title': '人文和故事', 'desc': '想要了解这个地方的历史，去和当地人聊天。', 'value': 'F'},
        {'title': '性价比', 'desc': '花最少的钱获得最好的体验，精打细算也是一种乐趣。', 'value': 'T'},
        {'title': '效率和方便', 'desc': '交通方便、行程紧凑、把时间用在刀刃上。', 'value': 'T'},
      ]
    },
    {
      'title': '旅行中你更偏向\n哪种行程安排？',
      'options': [
        {'title': '完全随缘', 'desc': '不做任何计划，走到哪算哪，旅途就是意外。', 'value': 'P'},
        {'title': '大方向确定就好', 'desc': '定好住哪、大致路线，其余随机应变。', 'value': 'P'},
        {'title': '精确到小时', 'desc': '每天的景点、餐厅、交通提前安排好，不浪费一分钟。', 'value': 'J'},
        {'title': '留出备选方案', 'desc': '定好计划，但每天备两三个替代选项。', 'value': 'J'},
      ]
    },
  ];

  void _selectOption(int questionIndex, int optionIndex) {
    HapticFeedback.selectionClick();
    ref.read(onboardingProvider.notifier).selectAnswer(questionIndex, optionIndex);
    setState(() {});
  }

  void _nextPage() {
    final state = ref.read(onboardingProvider);
    if (state.selectedAnswers[_currentPage] == null) return;

    if (_currentPage < _questions.length - 1) {
      HapticFeedback.mediumImpact();
      setState(() {
        _prevPage = _currentPage;
        _currentPage++;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    ref.read(onboardingProvider.notifier).completeAndCalculateMBTI();
    ref.invalidate(userPrefsProvider);
    if (mounted) context.go(AppRouter.map);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final total = _questions.length;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          // Question header
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.rule)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step
                  Text(
                    'STEP ${(_currentPage + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.3,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Question text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: double.infinity,
                      key: ValueKey(_currentPage),
                      child: Text(
                        _questions[_currentPage]['title'],
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress dots
                  Row(
                    children: List.generate(total, (i) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3,
                          margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: i <= _currentPage ? AppColors.teal : AppColors.rule,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Options list
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final isForward = _currentPage > _prevPage;
                final offset = Tween<Offset>(
                  begin: Offset(isForward ? 0.3 : -0.3, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: ListView.builder(
                key: ValueKey('options_$_currentPage'),
                padding: EdgeInsets.zero,
              itemCount: (_questions[_currentPage]['options'] as List).length,
              itemBuilder: (context, oIndex) {
                final options = _questions[_currentPage]['options'] as List;
                final opt = options[oIndex];
                final isSelected = state.selectedAnswers[_currentPage] == oIndex;
                final numStr = (oIndex + 1).toString().padLeft(2, '0');

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectOption(_currentPage, oIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.tealMist : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? AppColors.teal : Colors.transparent,
                          width: 3,
                        ),
                        bottom: const BorderSide(color: AppColors.rule),
                      ),
                    ),
                    constraints: const BoxConstraints(minHeight: 72),
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Serif number
                        SizedBox(
                          width: 38,
                          child: Text(
                            numStr,
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.teal : AppColors.inkFaint,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Body
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title'],
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                opt['desc'],
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Check circle
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppColors.teal : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? AppColors.teal : AppColors.inkFaint,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),
          ),

          // Footer button
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
            child: ArrowButton(
              text: _currentPage < total - 1 ? '下一题' : '开启我的地图',
              onTap: _nextPage,
            ),
          ),
        ],
      ),
    );
  }
}
