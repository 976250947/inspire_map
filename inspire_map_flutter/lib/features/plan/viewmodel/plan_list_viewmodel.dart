import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/plan_model.dart';
import '../data/plan_repository.dart';

final planListProvider = AsyncNotifierProvider<PlanListNotifier, List<TravelPlan>>(() {
  return PlanListNotifier();
});

class PlanListNotifier extends AsyncNotifier<List<TravelPlan>> {
  @override
  Future<List<TravelPlan>> build() async {
    return _fetchPlans();
  }

  Future<List<TravelPlan>> _fetchPlans() async {
    final repo = ref.read(planRepositoryProvider);
    return await repo.getPlans();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPlans());
  }
}
