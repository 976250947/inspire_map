import 'package:hive_flutter/hive_flutter.dart';

part 'footprint_model.g.dart';

/// 足迹打卡数据模型 — Hive 本地存储
@HiveType(typeId: 1)
class FootprintModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String poiId;

  @HiveField(2)
  final String poiName;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final double latitude;

  @HiveField(6)
  final String? note;

  @HiveField(7)
  final DateTime checkedAt;

  FootprintModel({
    required this.id,
    required this.poiId,
    required this.poiName,
    required this.category,
    required this.longitude,
    required this.latitude,
    this.note,
    required this.checkedAt,
  });
}
