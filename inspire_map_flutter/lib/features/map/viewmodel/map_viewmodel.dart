import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/network/api_service.dart';
import '../../../data/local/user_prefs_service.dart';
import '../../../data/models/poi_model.dart';

class RoutePoint {
  final double latitude;
  final double longitude;
  final String name;
  final int day;
  final int index;
  final bool isGcj02;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.day,
    required this.index,
    this.isGcj02 = false,
  });
}

class MapState {
  final List<POIModel> pois;
  final List<POIClusterModel> clusters;
  final bool loading;
  final String? selectedCategory;
  final POIModel? selectedPoi;
  final String? selectedProvince;
  final List<List<double>> routeLineCoords;
  final List<RoutePoint> routePoints;
  final int? routeVisibleDay;

  const MapState({
    this.pois = const [],
    this.clusters = const [],
    this.loading = true,
    this.selectedCategory,
    this.selectedPoi,
    this.selectedProvince,
    this.routeLineCoords = const [],
    this.routePoints = const [],
    this.routeVisibleDay,
  });

  MapState copyWith({
    List<POIModel>? pois,
    List<POIClusterModel>? clusters,
    bool? loading,
    String? Function()? selectedCategory,
    POIModel? Function()? selectedPoi,
    String? Function()? selectedProvince,
    List<List<double>>? routeLineCoords,
    List<RoutePoint>? routePoints,
    int? Function()? routeVisibleDay,
  }) {
    return MapState(
      pois: pois ?? this.pois,
      clusters: clusters ?? this.clusters,
      loading: loading ?? this.loading,
      selectedCategory: selectedCategory != null ? selectedCategory() : this.selectedCategory,
      selectedPoi: selectedPoi != null ? selectedPoi() : this.selectedPoi,
      selectedProvince: selectedProvince != null ? selectedProvince() : this.selectedProvince,
      routeLineCoords: routeLineCoords ?? this.routeLineCoords,
      routePoints: routePoints ?? this.routePoints,
      routeVisibleDay: routeVisibleDay != null ? routeVisibleDay() : this.routeVisibleDay,
    );
  }

  bool get hasData => pois.isNotEmpty || clusters.isNotEmpty;

  int get totalCount =>
      clusters.isNotEmpty ? clusters.fold<int>(0, (sum, cluster) => sum + cluster.count) : pois.length;

  List<int> get routeDays {
    final days = routePoints.map((point) => point.day).toSet().toList()..sort();
    return days;
  }

  List<RoutePoint> get visibleRoutePoints {
    if (routeVisibleDay == null) return routePoints;
    return routePoints.where((point) => point.day == routeVisibleDay).toList();
  }

  List<List<double>> get visibleRouteCoords {
    if (routeVisibleDay == null) return routeLineCoords;
    final result = <List<double>>[];
    for (var i = 0; i < routePoints.length && i < routeLineCoords.length; i++) {
      if (routePoints[i].day == routeVisibleDay) {
        result.add(routeLineCoords[i]);
      }
    }
    return result;
  }

  bool get isRouteMode => routeLineCoords.isNotEmpty;
}

class MapViewModel extends StateNotifier<MapState> {
  final Ref ref;
  Timer? _debounceTimer;
  CancelToken? _cancelToken;
  int _requestSeq = 0;
  String? _lastFetchKey;

  MapViewModel(this.ref) : super(const MapState()) {
    _fetchInitialPOIs();
  }

  Future<void> _fetchInitialPOIs() async {
    final mbti = ref.read(userPrefsProvider).getMBTI();
    POIFetchResult result = const POIFetchResult();

    try {
      result = await ApiService().fetchPOIsByBoundsWithClusters(
        minLon: 73.0,
        maxLon: 135.0,
        minLat: 18.0,
        maxLat: 53.0,
        zoomLevel: 5,
        category: state.selectedCategory,
        mbtiType: mbti,
        clusterMode: 'province',
        useFallback: true,
      );
    } catch (e) {
      debugPrint('[MapVM] Initial fetch failed: $e');
    }

    if (!mounted) return;
    state = state.copyWith(
      pois: result.pois,
      clusters: result.clusters,
      loading: false,
    );
  }

  void setCategory(String? category) {
    _lastFetchKey = null;
    state = state.copyWith(
      selectedCategory: () => category,
      selectedProvince: () => null,
    );
    _fetchInitialPOIs();
  }

  Future<void> onClusterTap(POIClusterModel cluster) async {
    final province = cluster.province;
    if (province == null || province.isEmpty) return;
    _lastFetchKey = null;

    state = state.copyWith(
      selectedProvince: () => province,
      clusters: const [],
    );
    _debounceTimer?.cancel();

    _cancelToken?.cancel('new_request');
    _cancelToken = CancelToken();
    final currentSeq = ++_requestSeq;

    final mbti = ref.read(userPrefsProvider).getMBTI();
    try {
      final result = await ApiService().fetchPOIsByBoundsWithClusters(
        minLon: 73.0,
        maxLon: 135.0,
        minLat: 18.0,
        maxLat: 53.0,
        zoomLevel: 12,
        category: state.selectedCategory,
        mbtiType: mbti,
        clusterMode: 'province',
        selectedProvince: province,
        cancelToken: _cancelToken,
        useFallback: false,
      );

      if (!mounted || currentSeq != _requestSeq) return;
      state = state.copyWith(
        selectedProvince: () => province,
        pois: result.pois,
        clusters: const [],
      );
    } catch (e) {
      debugPrint('[MapVM] Province fetch failed: $e');
    }
  }

  void clearProvinceFocus() {
    _lastFetchKey = null;
    state = state.copyWith(selectedProvince: () => null);
    _fetchInitialPOIs();
  }

  void selectPoi(POIModel? poi) {
    state = state.copyWith(selectedPoi: () => poi);
  }

  void setRouteLine(List<List<double>> coords, {List<RoutePoint> points = const []}) {
    state = state.copyWith(
      routeLineCoords: coords,
      routePoints: points,
      routeVisibleDay: () => null,
    );
  }

  void clearRouteLine() {
    state = state.copyWith(
      routeLineCoords: const [],
      routePoints: const [],
      routeVisibleDay: () => null,
    );
    _lastFetchKey = '';
  }

  void setRouteVisibleDay(int? day) {
    state = state.copyWith(routeVisibleDay: () => day);
  }

  void onBoundsChanged(LatLngBounds bounds, int zoom) {
    if (state.routeLineCoords.isNotEmpty) return;
    if (state.selectedProvince != null) return;

    final key =
        '${bounds.southwest.longitude.toStringAsFixed(2)}:'
        '${bounds.southwest.latitude.toStringAsFixed(2)}:'
        '${bounds.northeast.longitude.toStringAsFixed(2)}:'
        '${bounds.northeast.latitude.toStringAsFixed(2)}:'
        '$zoom:${state.selectedCategory ?? ''}';
    if (_lastFetchKey == key) return;
    _lastFetchKey = key;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchPOIsByBounds(bounds, zoom);
    });
  }

  Future<void> _fetchPOIsByBounds(LatLngBounds bounds, int zoom) async {
    if (state.selectedProvince != null) return;

    _cancelToken?.cancel('new_request');
    _cancelToken = CancelToken();
    final currentSeq = ++_requestSeq;

    final mbti = ref.read(userPrefsProvider).getMBTI();

    try {
      final result = await ApiService().fetchPOIsByBoundsWithClusters(
        minLon: bounds.southwest.longitude,
        maxLon: bounds.northeast.longitude,
        minLat: bounds.southwest.latitude,
        maxLat: bounds.northeast.latitude,
        zoomLevel: zoom,
        category: state.selectedCategory,
        mbtiType: mbti,
        clusterMode: 'province',
        cancelToken: _cancelToken,
        useFallback: !state.hasData,
      );

      if (mounted && currentSeq == _requestSeq && result.isNotEmpty) {
        state = state.copyWith(
          pois: result.pois,
          clusters: result.clusters,
        );
      }
    } catch (e) {
      debugPrint('[MapVM] Bounds fetch failed: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}

final mapProvider = StateNotifierProvider<MapViewModel, MapState>((ref) {
  return MapViewModel(ref);
});
