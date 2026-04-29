class ChecklistItem {
  final String item;
  final bool checked;

  const ChecklistItem({
    required this.item,
    this.checked = false,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      item: json['item'] as String? ?? '',
      checked: json['checked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'item': item,
        'checked': checked,
      };

  ChecklistItem copyWith({String? item, bool? checked}) {
    return ChecklistItem(
      item: item ?? this.item,
      checked: checked ?? this.checked,
    );
  }
}

class RouteStop {
  final String time;
  final String poiName;
  final String activity;
  final String? duration;
  final String? tips;
  final String? transportToNext;

  const RouteStop({
    required this.time,
    required this.poiName,
    required this.activity,
    this.duration,
    this.tips,
    this.transportToNext,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      time: json['time'] as String? ?? '',
      poiName: json['poi_name'] as String? ?? '',
      activity: json['activity'] as String? ?? '',
      duration: json['duration'] as String?,
      tips: json['tips'] as String?,
      transportToNext: json['transport_to_next'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'poi_name': poiName,
        'activity': activity,
        'duration': duration,
        'tips': tips,
        'transport_to_next': transportToNext,
      };

  RouteStop copyWith({
    String? time,
    String? poiName,
    String? activity,
    String? duration,
    String? tips,
    String? transportToNext,
  }) {
    return RouteStop(
      time: time ?? this.time,
      poiName: poiName ?? this.poiName,
      activity: activity ?? this.activity,
      duration: duration ?? this.duration,
      tips: tips ?? this.tips,
      transportToNext: transportToNext ?? this.transportToNext,
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

  Map<String, dynamic> toJson() => {
        'day': day,
        'theme': theme,
        'summary': summary,
        'stops': stops.map((item) => item.toJson()).toList(),
      };

  RouteDay copyWith({
    int? day,
    String? theme,
    String? summary,
    List<RouteStop>? stops,
  }) {
    return RouteDay(
      day: day ?? this.day,
      theme: theme ?? this.theme,
      summary: summary ?? this.summary,
      stops: stops ?? this.stops,
    );
  }
}

class TravelPreparation {
  final String? bestSeason;
  final List<String> longDistanceTransport;
  final List<String> cityTransport;
  final List<String> packingList;
  final List<String> documents;

  const TravelPreparation({
    this.bestSeason,
    this.longDistanceTransport = const [],
    this.cityTransport = const [],
    this.packingList = const [],
    this.documents = const [],
  });

  factory TravelPreparation.fromJson(Map<String, dynamic> json) {
    List<String> parseList(String key) {
      return (json[key] as List<dynamic>? ?? []).map((item) => item.toString()).toList();
    }

    return TravelPreparation(
      bestSeason: json['best_season'] as String?,
      longDistanceTransport: parseList('long_distance_transport'),
      cityTransport: parseList('city_transport'),
      packingList: parseList('packing_list'),
      documents: parseList('documents'),
    );
  }

  Map<String, dynamic> toJson() => {
        'best_season': bestSeason,
        'long_distance_transport': longDistanceTransport,
        'city_transport': cityTransport,
        'packing_list': packingList,
        'documents': documents,
      };

  TravelPreparation copyWith({
    String? bestSeason,
    List<String>? longDistanceTransport,
    List<String>? cityTransport,
    List<String>? packingList,
    List<String>? documents,
  }) {
    return TravelPreparation(
      bestSeason: bestSeason ?? this.bestSeason,
      longDistanceTransport: longDistanceTransport ?? this.longDistanceTransport,
      cityTransport: cityTransport ?? this.cityTransport,
      packingList: packingList ?? this.packingList,
      documents: documents ?? this.documents,
    );
  }
}

class AccommodationSuggestion {
  final String tier;
  final String name;
  final String? priceRange;
  final List<String> highlights;

  const AccommodationSuggestion({
    required this.tier,
    required this.name,
    this.priceRange,
    this.highlights = const [],
  });

  factory AccommodationSuggestion.fromJson(Map<String, dynamic> json) {
    return AccommodationSuggestion(
      tier: json['tier'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceRange: json['price_range'] as String?,
      highlights: (json['highlights'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'tier': tier,
        'name': name,
        'price_range': priceRange,
        'highlights': highlights,
      };
}

class BudgetItem {
  final String category;
  final String amountRange;

  const BudgetItem({required this.category, required this.amountRange});

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      category: json['category'] as String? ?? '',
      amountRange: json['amount_range'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'amount_range': amountRange,
      };
}

class TravelGuideData {
  final String? summary;
  final String? travelType;
  final String? scene;
  final List<String> styleTags;
  final TravelPreparation preparation;
  final List<AccommodationSuggestion> accommodation;
  final List<BudgetItem> budget;
  final List<String> avoidTips;
  final List<String> notes;

  const TravelGuideData({
    this.summary,
    this.travelType,
    this.scene,
    this.styleTags = const [],
    this.preparation = const TravelPreparation(),
    this.accommodation = const [],
    this.budget = const [],
    this.avoidTips = const [],
    this.notes = const [],
  });

  factory TravelGuideData.fromJson(Map<String, dynamic> json) {
    return TravelGuideData(
      summary: json['summary'] as String?,
      travelType: json['travel_type'] as String?,
      scene: json['scene'] as String?,
      styleTags: (json['style_tags'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      preparation: TravelPreparation.fromJson(
        (json['preparation'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      accommodation: (json['accommodation'] as List<dynamic>? ?? [])
          .map((item) => AccommodationSuggestion.fromJson(item as Map<String, dynamic>))
          .toList(),
      budget: (json['budget'] as List<dynamic>? ?? [])
          .map((item) => BudgetItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      avoidTips: (json['avoid_tips'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      notes: (json['notes'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'travel_type': travelType,
        'scene': scene,
        'style_tags': styleTags,
        'preparation': preparation.toJson(),
        'accommodation': accommodation.map((item) => item.toJson()).toList(),
        'budget': budget.map((item) => item.toJson()).toList(),
        'avoid_tips': avoidTips,
        'notes': notes,
      };

  TravelGuideData copyWith({
    String? summary,
    String? travelType,
    String? scene,
    List<String>? styleTags,
    TravelPreparation? preparation,
    List<AccommodationSuggestion>? accommodation,
    List<BudgetItem>? budget,
    List<String>? avoidTips,
    List<String>? notes,
  }) {
    return TravelGuideData(
      summary: summary ?? this.summary,
      travelType: travelType ?? this.travelType,
      scene: scene ?? this.scene,
      styleTags: styleTags ?? this.styleTags,
      preparation: preparation ?? this.preparation,
      accommodation: accommodation ?? this.accommodation,
      budget: budget ?? this.budget,
      avoidTips: avoidTips ?? this.avoidTips,
      notes: notes ?? this.notes,
    );
  }
}

class TravelPlan {
  final String planId;
  final String userId;
  final String title;
  final String city;
  final int days;
  final List<RouteDay> itineraryData;
  final List<ChecklistItem> checklistData;
  final TravelGuideData guideData;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TravelPlan({
    required this.planId,
    required this.userId,
    required this.title,
    required this.city,
    required this.days,
    required this.itineraryData,
    required this.checklistData,
    required this.guideData,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TravelPlan.fromJson(Map<String, dynamic> json) {
    return TravelPlan(
      planId: json['plan_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      city: json['city'] as String? ?? '',
      days: json['days'] as int? ?? 0,
      itineraryData: (json['itinerary_data'] as List<dynamic>? ?? [])
          .map((item) => RouteDay.fromJson(item as Map<String, dynamic>))
          .toList(),
      checklistData: (json['checklist_data'] as List<dynamic>? ?? [])
          .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      guideData: TravelGuideData.fromJson(
        (json['guide_data'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      status: json['status'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'plan_id': planId,
        'user_id': userId,
        'title': title,
        'city': city,
        'days': days,
        'itinerary_data': itineraryData.map((item) => item.toJson()).toList(),
        'checklist_data': checklistData.map((item) => item.toJson()).toList(),
        'guide_data': guideData.toJson(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toUpdatePayload() => {
        'title': title,
        'itinerary_data': itineraryData.map((item) => item.toJson()).toList(),
        'checklist_data': checklistData.map((item) => item.toJson()).toList(),
        'guide_data': guideData.toJson(),
        'status': status,
      };

  TravelPlan copyWith({
    String? title,
    List<RouteDay>? itineraryData,
    List<ChecklistItem>? checklistData,
    TravelGuideData? guideData,
    String? status,
    DateTime? updatedAt,
  }) {
    return TravelPlan(
      planId: planId,
      userId: userId,
      title: title ?? this.title,
      city: city,
      days: days,
      itineraryData: itineraryData ?? this.itineraryData,
      checklistData: checklistData ?? this.checklistData,
      guideData: guideData ?? this.guideData,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
