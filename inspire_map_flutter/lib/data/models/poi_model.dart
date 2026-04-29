/// POI 数据模型 — 与后端 POIResponse / POIDetailResponse 对齐
class POIModel {
  final String poiId;
  final String name;
  final String category;
  final String? subCategory;
  final double longitude;
  final double latitude;
  final String? address;
  final String? aiSummary;
  final double rating;
  final bool isRecommended;

  const POIModel({
    required this.poiId,
    required this.name,
    required this.category,
    this.subCategory,
    required this.longitude,
    required this.latitude,
    this.address,
    this.aiSummary,
    required this.rating,
    this.isRecommended = false,
  });

  factory POIModel.fromJson(Map<String, dynamic> json) {
    return POIModel(
      poiId: json['poi_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      subCategory: json['sub_category'] as String?,
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      address: json['address'] as String?,
      aiSummary: json['ai_summary'] as String?,
      rating: (json['rating'] as num).toDouble(),
      isRecommended: json['is_recommended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'poi_id': poiId,
        'name': name,
        'category': category,
        'sub_category': subCategory,
        'longitude': longitude,
        'latitude': latitude,
        'address': address,
        'ai_summary': aiSummary,
        'rating': rating,
        'is_recommended': isRecommended,
      };
}

/// POI 聚合模型 — 低缩放级别时后端返回的聚合气泡
class POIClusterModel {
  final String clusterId;
  final double longitude;
  final double latitude;
  final int count;
  final String? topCategory;
  final String? province;

  const POIClusterModel({
    required this.clusterId,
    required this.longitude,
    required this.latitude,
    required this.count,
    this.topCategory,
    this.province,
  });

  factory POIClusterModel.fromJson(Map<String, dynamic> json) {
    return POIClusterModel(
      clusterId: json['cluster_id'] as String,
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      count: json['count'] as int,
      topCategory: json['top_category'] as String?,
      province: json['province'] as String?,
    );
  }
}

/// POI 详情模型 — 包含额外的 tips、最佳游玩时间等
class POIDetailModel extends POIModel {
  final String? bestVisitTime;
  final List<String> tips;
  final String? aiSummaryMbti;
  final List<String> aiHighlights;

  const POIDetailModel({
    required super.poiId,
    required super.name,
    required super.category,
    super.subCategory,
    required super.longitude,
    required super.latitude,
    super.address,
    super.aiSummary,
    required super.rating,
    super.isRecommended,
    this.bestVisitTime,
    this.tips = const [],
    this.aiSummaryMbti,
    this.aiHighlights = const [],
  });

  factory POIDetailModel.fromJson(Map<String, dynamic> json) {
    return POIDetailModel(
      poiId: json['poi_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      subCategory: json['sub_category'] as String?,
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      address: json['address'] as String?,
      aiSummary: json['ai_summary'] as String?,
      rating: (json['rating'] as num).toDouble(),
      isRecommended: json['is_recommended'] as bool? ?? false,
      bestVisitTime: json['best_visit_time'] as String?,
      tips: (json['tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      aiSummaryMbti: json['ai_summary_mbti'] as String?,
      aiHighlights: (json['ai_highlights'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
