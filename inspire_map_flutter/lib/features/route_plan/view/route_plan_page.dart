import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../viewmodel/route_plan_viewmodel.dart';

class RoutePlanPage extends ConsumerStatefulWidget {
  const RoutePlanPage({super.key});

  @override
  ConsumerState<RoutePlanPage> createState() => _RoutePlanPageState();
}

class _RoutePlanPageState extends ConsumerState<RoutePlanPage> {
  static const List<String> _prefOptions = <String>[
    '美食',
    '文化',
    '摄影',
    '自然',
    '购物',
    '夜生活',
    '小众',
    '亲子',
  ];

  final TextEditingController _cityController = TextEditingController();
  final List<String> _selectedPrefs = <String>[];
  int _days = 3;
  String _pace = '适中';
  String _budget = 'medium';

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _startPlan() {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入目的地城市')),
      );
      return;
    }

    HapticFeedback.selectionClick();
    ref.read(routePlanProvider.notifier).planRoute(
          city: city,
          days: _days,
          preferences: _selectedPrefs.isEmpty ? null : _selectedPrefs,
          pace: _pace,
          budgetLevel: _budget,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routePlanProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        title: Text(
          'AI 行程规划',
          style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (state.phase != PlanPhase.idle)
            IconButton(
              onPressed: () => ref.read(routePlanProvider.notifier).reset(),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: state.phase == PlanPhase.idle
          ? _buildForm()
          : _buildResult(state),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '告诉我你想去哪里。',
          style: GoogleFonts.notoSerifSc(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '我会基于你的偏好输出结构化行程，并保存到“我的行程”。',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            height: 1.7,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _cityController,
          decoration: InputDecoration(
            labelText: '目的地',
            hintText: '例如：成都、东京、大理',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.rule),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              '旅行天数',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _days > 1 ? () => setState(() => _days -= 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_days 天',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: _days < 10 ? () => setState(() => _days += 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '偏好标签',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _prefOptions.map((item) {
            final selected = _selectedPrefs.contains(item);
            return FilterChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  if (selected) {
                    _selectedPrefs.remove(item);
                  } else {
                    _selectedPrefs.add(item);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _pace,
          decoration: const InputDecoration(
            labelText: '节奏',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: '悠闲', child: Text('悠闲')),
            DropdownMenuItem(value: '适中', child: Text('适中')),
            DropdownMenuItem(value: '紧凑', child: Text('紧凑')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _pace = value);
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _budget,
          decoration: const InputDecoration(
            labelText: '预算',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'budget_low', child: Text('经济')),
            DropdownMenuItem(value: 'medium', child: Text('舒适')),
            DropdownMenuItem(value: 'budget_high', child: Text('品质')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _budget = value);
            }
          },
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _startPlan,
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
            child: Text(
              '开始规划',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(RoutePlanState state) {
    if (state.phase == PlanPhase.streaming) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.rule),
          ),
          child: Text(
            state.rawContent.isEmpty ? '正在生成行程，请稍候...' : state.rawContent,
            style: GoogleFonts.dmSans(height: 1.7, color: AppColors.inkMid),
          ),
        ),
      );
    }

    if (state.phase == PlanPhase.error) {
      return Center(
        child: Text(
          state.errorMessage ?? '生成失败',
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.coral),
        ),
      );
    }

    if (state.plan == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.latestSavedPlanId != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.rule),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.task_alt_rounded, color: AppColors.tealDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '已保存到我的行程：${state.latestSavedPlanTitle ?? '新行程'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/plans/${state.latestSavedPlanId}'),
                      child: Text(
                        '查看',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  state.rawContent,
                  style: GoogleFonts.dmSans(height: 1.7, color: AppColors.inkMid),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final plan = state.plan!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (state.latestSavedPlanId != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.rule),
            ),
            child: Row(
              children: [
                const Icon(Icons.task_alt_rounded, color: AppColors.tealDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '已保存到我的行程：${state.latestSavedPlanTitle ?? '新行程'}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/plans/${state.latestSavedPlanId}'),
                  child: Text(
                    '查看',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.tealWash,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.city} · ${plan.days}天',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (plan.mbtiMatch.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plan.mbtiMatch,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.inkMid,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final day in plan.routes) ...[
          Text(
            'Day ${day.day} · ${day.theme}',
            style: GoogleFonts.notoSerifSc(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          ...day.stops.map(
            (stop) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.rule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stop.time} · ${stop.poiName}',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stop.activity,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.inkMid,
                    ),
                  ),
                  if ((stop.duration).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '建议停留：${stop.duration}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  if ((stop.tips ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '提示：${stop.tips!}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.ochre,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if ((plan.budgetEstimate ?? '').isNotEmpty)
          Text(
            '预算参考：${plan.budgetEstimate!}',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkMid),
          ),
        if ((plan.packingTips ?? <String>[]).isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plan.packingTips!
                .map((item) => Chip(label: Text(item)))
                .toList(),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            final savedPlanId = state.latestSavedPlanId;
            if (savedPlanId != null && savedPlanId.isNotEmpty) {
              context.push('/plans/$savedPlanId');
              return;
            }
            context.go(AppRouter.plans);
          },
          icon: const Icon(Icons.event_note_rounded),
          label: Text(
            state.latestSavedPlanId != null ? '打开已保存行程' : '前往我的行程',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
