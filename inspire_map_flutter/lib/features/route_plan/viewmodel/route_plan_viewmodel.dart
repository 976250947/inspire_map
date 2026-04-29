import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_service.dart';
import '../../../data/local/user_prefs_service.dart';

class RouteStop {
  final String time;
  final String poiName;
  final String? poiId;
  final String duration;
  final String activity;
  final String? tips;
  final String? transportToNext;

  const RouteStop({
    required this.time,
    required this.poiName,
    this.poiId,
    required this.duration,
    required this.activity,
    this.tips,
    this.transportToNext,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      time: json['time'] as String? ?? '',
      poiName: json['poi_name'] as String? ?? '',
      poiId: json['poi_id'] as String?,
      duration: json['duration'] as String? ?? '',
      activity: json['activity'] as String? ?? '',
      tips: json['tips'] as String?,
      transportToNext: json['transport_to_next'] as String?,
    );
  }
}

class RouteDay {
  final int day;
  final String theme;
  final String? summary;
  final List<RouteStop> stops;

  const RouteDay({
    required this.day,
    required this.theme,
    this.summary,
    required this.stops,
  });

  factory RouteDay.fromJson(Map<String, dynamic> json) {
    return RouteDay(
      day: json['day'] as int? ?? 1,
      theme: json['theme'] as String? ?? '',
      summary: json['summary'] as String?,
      stops: (json['stops'] as List<dynamic>? ?? [])
          .map((item) => RouteStop.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RoutePlan {
  final String city;
  final int days;
  final String mbtiMatch;
  final List<RouteDay> routes;
  final String? budgetEstimate;
  final List<String>? packingTips;

  const RoutePlan({
    required this.city,
    required this.days,
    required this.mbtiMatch,
    required this.routes,
    this.budgetEstimate,
    this.packingTips,
  });

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    return RoutePlan(
      city: json['city'] as String? ?? '',
      days: json['days'] as int? ?? 0,
      mbtiMatch: json['mbti_match'] as String? ?? '',
      routes: (json['routes'] as List<dynamic>? ?? [])
          .map((item) => RouteDay.fromJson(item as Map<String, dynamic>))
          .toList(),
      budgetEstimate: json['budget_estimate'] as String?,
      packingTips: (json['packing_tips'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList(),
    );
  }
}

enum PlanPhase { idle, streaming, done, error }

class RoutePlanState {
  final PlanPhase phase;
  final String rawContent;
  final RoutePlan? plan;
  final String? errorMessage;
  final String? latestSavedPlanId;
  final String? latestSavedPlanTitle;

  const RoutePlanState({
    this.phase = PlanPhase.idle,
    this.rawContent = '',
    this.plan,
    this.errorMessage,
    this.latestSavedPlanId,
    this.latestSavedPlanTitle,
  });

  RoutePlanState copyWith({
    PlanPhase? phase,
    String? rawContent,
    RoutePlan? plan,
    String? errorMessage,
    String? latestSavedPlanId,
    String? latestSavedPlanTitle,
  }) {
    return RoutePlanState(
      phase: phase ?? this.phase,
      rawContent: rawContent ?? this.rawContent,
      plan: plan ?? this.plan,
      errorMessage: errorMessage,
      latestSavedPlanId: latestSavedPlanId ?? this.latestSavedPlanId,
      latestSavedPlanTitle: latestSavedPlanTitle ?? this.latestSavedPlanTitle,
    );
  }
}

class RoutePlanViewModel extends StateNotifier<RoutePlanState> {
  final Ref ref;
  StreamSubscription<Map<String, dynamic>>? _sub;

  RoutePlanViewModel(this.ref) : super(const RoutePlanState());

  Future<void> planRoute({
    required String city,
    required int days,
    List<String>? preferences,
    String? pace,
    String? budgetLevel,
  }) async {
    await _sub?.cancel();

    final prefs = ref.read(userPrefsProvider);
    final mbti = prefs.getMBTI();

    state = const RoutePlanState(phase: PlanPhase.streaming);
    final stream = ApiService().streamRoutePlan(
      destination: city,
      days: days,
      preferences: preferences,
      mbtiType: mbti,
      pace: pace,
      budgetLevel: budgetLevel,
    );

    var accumulated = '';
    _sub = stream.listen(
      (chunk) {
        final type = chunk['type'] as String? ?? '';
        final content = chunk['content'] as String? ?? '';
        final isComplete = chunk['is_complete'] as bool? ?? false;

        if (type == 'error') {
          state = RoutePlanState(
            phase: PlanPhase.error,
            errorMessage: content.isEmpty ? '生成失败，请稍后重试' : content,
            rawContent: accumulated,
          );
          return;
        }

        if (type == 'plan_saved') {
          state = state.copyWith(
            latestSavedPlanId: chunk['plan_id'] as String?,
            latestSavedPlanTitle: chunk['title'] as String? ?? '新行程',
          );
          return;
        }

        if (type == 'complete') {
          if (state.phase == PlanPhase.streaming) {
            _tryParseResult(accumulated);
            state = state.copyWith(phase: PlanPhase.done);
          }
          return;
        }

        accumulated += content;
        state = state.copyWith(
          rawContent: accumulated,
          phase: isComplete ? PlanPhase.done : PlanPhase.streaming,
        );

        if (isComplete) {
          _tryParseResult(accumulated);
        }
      },
      onError: (_) {
        state = RoutePlanState(
          phase: PlanPhase.error,
          errorMessage: '网络连接失败，请稍后重试',
          rawContent: accumulated,
        );
      },
      onDone: () {
        if (state.phase == PlanPhase.streaming) {
          _tryParseResult(accumulated);
          state = state.copyWith(phase: PlanPhase.done);
        }
      },
    );
  }

  void _tryParseResult(String raw) {
    try {
      var cleaned = raw.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }

      final parsed = jsonDecode(cleaned.trim()) as Map<String, dynamic>;
      state = state.copyWith(plan: RoutePlan.fromJson(parsed), phase: PlanPhase.done);
    } catch (_) {
      try {
        final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
        if (match == null) {
          state = state.copyWith(phase: PlanPhase.done);
          return;
        }
        final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        state = state.copyWith(plan: RoutePlan.fromJson(parsed), phase: PlanPhase.done);
      } catch (_) {
        state = state.copyWith(phase: PlanPhase.done);
      }
    }
  }

  void reset() {
    _sub?.cancel();
    state = const RoutePlanState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final routePlanProvider = StateNotifierProvider<RoutePlanViewModel, RoutePlanState>((ref) {
  return RoutePlanViewModel(ref);
});
