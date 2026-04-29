import '../../../core/network/api_service.dart';
import 'plan_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ApiService());
});

class PlanRepository {
  final ApiService _apiService;

  PlanRepository(this._apiService);

  Future<List<TravelPlan>> getPlans() async {
    final list = await _apiService.fetchUserPlans();
    if (list == null) return [];
    return list.map((item) => TravelPlan.fromJson(item)).toList();
  }

  Future<TravelPlan?> getPlanDetail(String planId) async {
    final data = await _apiService.fetchPlanDetail(planId);
    if (data == null) return null;
    return TravelPlan.fromJson(data);
  }

  Future<bool> updateChecklist(String planId, List<ChecklistItem> checklist) async {
    final rawList = checklist.map((item) => item.toJson()).toList();
    return await _apiService.updatePlanChecklist(planId, rawList);
  }

  Future<TravelPlan?> updatePlan(TravelPlan plan) async {
    final data = await _apiService.updatePlan(plan.planId, plan.toUpdatePayload());
    if (data == null) return null;
    return TravelPlan.fromJson(data);
  }
}
