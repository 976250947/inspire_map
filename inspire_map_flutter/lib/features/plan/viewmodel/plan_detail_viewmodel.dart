import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/plan_model.dart';
import '../data/plan_repository.dart';

final planDetailProvider = AsyncNotifierProviderFamily<PlanDetailNotifier, TravelPlan?, String>(() {
  return PlanDetailNotifier();
});

class PlanDetailNotifier extends FamilyAsyncNotifier<TravelPlan?, String> {
  @override
  Future<TravelPlan?> build(String arg) async {
    return _fetchPlan(arg);
  }

  Future<TravelPlan?> _fetchPlan(String planId) async {
    final repo = ref.read(planRepositoryProvider);
    return await repo.getPlanDetail(planId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPlan(arg));
  }

  Future<void> toggleChecklist(int index) async {
    final currentPlan = state.value;
    if (currentPlan == null) return;

    final newList = List<ChecklistItem>.from(currentPlan.checklistData);
    final target = newList[index];
    newList[index] = target.copyWith(checked: !target.checked);
    final updatedPlan = currentPlan.copyWith(checklistData: newList);
    state = AsyncValue.data(updatedPlan);

    final repo = ref.read(planRepositoryProvider);
    final success = await repo.updateChecklist(currentPlan.planId, newList);
    if (!success) {
      state = AsyncValue.data(currentPlan);
    }
  }

  Future<bool> savePlan(TravelPlan plan) async {
    state = AsyncValue.data(plan);
    final repo = ref.read(planRepositoryProvider);
    final updated = await repo.updatePlan(plan);
    if (updated == null) {
      return false;
    }
    state = AsyncValue.data(updated);
    return true;
  }
}
