import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/footprint_model.dart';

class FootprintService {
  static const String _boxName = 'footprints';

  Box<FootprintModel> get _box => Hive.box<FootprintModel>(_boxName);

  void addFootprint({
    required String poiId,
    required String poiName,
    required String category,
    required double longitude,
    required double latitude,
    String? note,
  }) {
    final footprint = FootprintModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      poiId: poiId,
      poiName: poiName,
      category: category,
      longitude: longitude,
      latitude: latitude,
      note: note,
      checkedAt: DateTime.now(),
    );
    _box.add(footprint);
  }

  List<FootprintModel> getFootprints() {
    final list = _box.values.toList();
    list.sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    return list;
  }

  int getFootprintCount() {
    return _box.length;
  }

  bool hasCheckedIn(String poiId) {
    return _box.values.any((item) => item.poiId == poiId);
  }

  int getUniquePoiCount() {
    return _box.values.map((item) => item.poiId).toSet().length;
  }

  Future<void> deleteFootprint(int index) async {
    await _box.deleteAt(index);
  }
}

final footprintServiceProvider = Provider<FootprintService>((ref) {
  return FootprintService();
});
