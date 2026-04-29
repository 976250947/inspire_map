import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/coord_converter.dart';
import '../../../data/models/poi_model.dart';
import '../viewmodel/map_viewmodel.dart';

const bool _kUseMapTilerStyle = bool.fromEnvironment(
  'USE_MAPTILER_STYLE',
  defaultValue: false,
);
const String _kBackendHostOverride = String.fromEnvironment('BACKEND_HOST');
const String _kMapTilerApiKey = String.fromEnvironment('MAPTILER_API_KEY');
const int _tileProxyPort = 8000;

const String _kSourceId = 'poi-source';
const String _kCircleLayerId = 'poi-circle-layer';
const String _kGlowLayerId = 'poi-glow-layer';
const String _kLabelLayerId = 'poi-label-layer';
const String _kClusterCircleLayerId = 'cluster-circle-layer';
const String _kClusterLabelLayerId = 'cluster-label-layer';
const String _kRouteSourceId = 'route-line-source';
const String _kRouteLineLayerId = 'route-line-layer';
const String _kRoutePointLayerId = 'route-point-layer';
const String _kRouteLabelLayerId = 'route-label-layer';
const String _kRasterLayerId = 'amap-raster';
const LatLng _kDefaultCenter = LatLng(39.9163, 116.3972);
const CameraPosition _kInitialCameraPosition = CameraPosition(
  target: LatLng(35.0, 105.0),
  zoom: 4.0,
);

String get _backendHost {
  if (_kBackendHostOverride.isNotEmpty) {
    return _kBackendHostOverride;
  }
  if (kIsWeb) {
    return 'localhost';
  }
  if (Platform.isAndroid) {
    return '10.0.2.2';
  }
  return 'localhost';
}

class _RasterMbtiStyle {
  final double hueRotate;
  final double saturation;
  final double contrast;
  final double brightnessMin;
  final double brightnessMax;

  const _RasterMbtiStyle({
    required this.hueRotate,
    required this.saturation,
    required this.contrast,
    required this.brightnessMin,
    required this.brightnessMax,
  });
}

/// MapLibre 地图核心视图。
///
/// 负责底图样式、POI/聚合图层、路线图层，以及页面层调用的相机控制。
class MaplibreCoreView extends StatefulWidget {
  final List<POIModel> pois;
  final List<POIClusterModel> clusters;
  final void Function(POIModel poi) onMarkerTap;
  final void Function(POIClusterModel cluster)? onClusterTap;
  final void Function(LatLngBounds bounds, int zoom)? onBoundsChanged;
  final String? mbtiType;
  final List<List<double>> routeLineCoords;
  final List<RoutePoint> routePoints;

  const MaplibreCoreView({
    super.key,
    required this.pois,
    this.clusters = const <POIClusterModel>[],
    required this.onMarkerTap,
    this.onClusterTap,
    this.onBoundsChanged,
    this.mbtiType,
    this.routeLineCoords = const <List<double>>[],
    this.routePoints = const <RoutePoint>[],
  });

  @override
  State<MaplibreCoreView> createState() => MaplibreCoreViewState();
}

class MaplibreCoreViewState extends State<MaplibreCoreView> {
  MapLibreMapController? _mapController;
  String? _localizedStyleString;
  bool _usingOfflineStyleFallback = true;
  bool _sourceAdded = false;
  bool _routeSourceAdded = false;

  @override
  void initState() {
    super.initState();
    _localizedStyleString = _buildOfflineFallbackStyle();
    _loadLocalizedStyle();
  }

  @override
  void didUpdateWidget(covariant MaplibreCoreView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pois != widget.pois || oldWidget.clusters != widget.clusters) {
      _syncMarkers();
    }

    if (oldWidget.routeLineCoords != widget.routeLineCoords ||
        oldWidget.routePoints != widget.routePoints) {
      _syncRouteLine();
    }

    if (oldWidget.mbtiType != widget.mbtiType) {
      if (_shouldUseMapTilerStyle) {
        _loadLocalizedStyle();
      } else {
        _applyRasterMbtiTheme();
        _syncMarkers();
        _syncRouteLine();
      }
    }
  }

  @override
  void dispose() {
    _mapController?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  bool get _shouldUseMapTilerStyle =>
      _kUseMapTilerStyle && _kMapTilerApiKey.isNotEmpty;

  /// 供页面层调用，回到默认中心点。
  void animateToCenter() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _kDefaultCenter, zoom: 12.0),
      ),
      duration: const Duration(milliseconds: 500),
    );
  }

  /// 当前地图缩放级别，用于页面层平滑放大/平移。
  double get currentZoom =>
      _mapController?.cameraPosition?.zoom ?? _kInitialCameraPosition.zoom;

  /// 平滑移动到指定经纬度。
  void animateTo(double lat, double lng, {double? zoom}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: zoom ?? currentZoom,
        ),
      ),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _loadLocalizedStyle() async {
    if (!_shouldUseMapTilerStyle) {
      if (!mounted) {
        return;
      }
      setState(() {
        _localizedStyleString = _buildOfflineFallbackStyle();
        _usingOfflineStyleFallback = true;
        _sourceAdded = false;
        _routeSourceAdded = false;
      });
      return;
    }

    try {
      final response = await Dio().get<String>(
        _getStyleUrl(),
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      var styleJson = response.data ?? '';
      if (styleJson.isEmpty) {
        throw StateError('empty style response');
      }

      styleJson = styleJson
          .replaceAll('"name:en"', '"name:zh"')
          .replaceAll('"name:latin"', '"name:zh"')
          .replaceAll('"name:nonlatin"', '"name:zh"')
          .replaceAll('{name:latin}', '{name:zh}')
          .replaceAll('{name:nonlatin}', '{name:zh}')
          .replaceAll('{name:en}', '{name:zh}')
          .replaceAll('"Roboto Regular"', '"Noto Sans Regular"')
          .replaceAll('"Roboto Medium"', '"Noto Sans Bold"')
          .replaceAll('"Roboto Italic"', '"Noto Sans Italic"')
          .replaceAll('"Open Sans Regular"', '"Noto Sans Regular"')
          .replaceAll('"Open Sans Semibold"', '"Noto Sans Bold"');

      if (!mounted) {
        return;
      }
      setState(() {
        _localizedStyleString = styleJson;
        _usingOfflineStyleFallback = false;
        _sourceAdded = false;
        _routeSourceAdded = false;
      });
    } catch (error) {
      debugPrint('[Map] style download failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _localizedStyleString = _buildOfflineFallbackStyle();
        _usingOfflineStyleFallback = true;
        _sourceAdded = false;
        _routeSourceAdded = false;
      });
    }
  }

  String _buildOfflineFallbackStyle() {
    final host = _backendHost;
    return '''
{
  "version": 8,
  "name": "domestic-raster-fallback",
  "glyphs": "http://$host:$_tileProxyPort/api/v1/fonts/{fontstack}/{range}.pbf?v=20260407",
  "sources": {
    "amap": {
      "type": "raster",
      "tiles": [
        "http://$host:$_tileProxyPort/api/v1/tiles/{z}/{x}/{y}"
      ],
      "tileSize": 256,
      "attribution": "AutoNavi"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#F5F3EE"
      }
    },
    {
      "id": "$_kRasterLayerId",
      "type": "raster",
      "source": "amap",
      "minzoom": 0,
      "maxzoom": 19
    }
  ]
}
''';
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == _kClusterCircleLayerId || layerId == _kClusterLabelLayerId) {
      final cluster = widget.clusters.cast<POIClusterModel?>().firstWhere(
            (item) => item?.clusterId == id,
            orElse: () => null,
          );
      if (cluster != null) {
        widget.onClusterTap?.call(cluster);
      }

      final zoom = currentZoom;
      final targetZoom = math.min(math.max(zoom + 1.5, 9.0), 11.2);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: coordinates, zoom: targetZoom),
        ),
        duration: const Duration(milliseconds: 400),
      );
      return;
    }

    final poi = widget.pois.cast<POIModel?>().firstWhere(
          (item) => item?.poiId == id,
          orElse: () => null,
        );
    if (poi != null) {
      widget.onMarkerTap(poi);
    }
  }

  Future<void> _onCameraIdle() async {
    final controller = _mapController;
    if (controller == null || widget.onBoundsChanged == null) {
      return;
    }

    final rawBounds = await controller.getVisibleRegion();
    final bounds = _usingOfflineStyleFallback ? _toWgsBounds(rawBounds) : rawBounds;
    final zoom = (controller.cameraPosition?.zoom ?? _kInitialCameraPosition.zoom)
        .floor()
        .clamp(3, 20);

    widget.onBoundsChanged?.call(bounds, zoom);
  }

  LatLngBounds _toWgsBounds(LatLngBounds gcjBounds) {
    final (swLat, swLon) = CoordConverter.gcj02ToWgs84(
      gcjBounds.southwest.latitude,
      gcjBounds.southwest.longitude,
    );
    final (neLat, neLon) = CoordConverter.gcj02ToWgs84(
      gcjBounds.northeast.latitude,
      gcjBounds.northeast.longitude,
    );

    final south = math.min(swLat, neLat);
    final north = math.max(swLat, neLat);
    final west = math.min(swLon, neLon);
    final east = math.max(swLon, neLon);

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  _RasterMbtiStyle _getRasterMbtiStyle(String? mbtiType) {
    if (mbtiType == null || mbtiType.length < 2) {
      return const _RasterMbtiStyle(
        hueRotate: 0,
        saturation: 0,
        contrast: 0,
        brightnessMin: 0,
        brightnessMax: 1,
      );
    }

    final ei = mbtiType[0].toUpperCase();
    final ns = mbtiType[1].toUpperCase();

    if (ei == 'E' && ns == 'S') {
      return const _RasterMbtiStyle(
        hueRotate: -8,
        saturation: 0.22,
        contrast: 0.10,
        brightnessMin: 0.05,
        brightnessMax: 1,
      );
    }

    if (ei == 'E' && ns == 'N') {
      return const _RasterMbtiStyle(
        hueRotate: -4,
        saturation: 0.30,
        contrast: 0.14,
        brightnessMin: 0.06,
        brightnessMax: 1,
      );
    }

    if (ei == 'I' && ns == 'N') {
      return const _RasterMbtiStyle(
        hueRotate: 16,
        saturation: -0.25,
        contrast: -0.04,
        brightnessMin: 0.02,
        brightnessMax: 0.93,
      );
    }

    return const _RasterMbtiStyle(
      hueRotate: 8,
      saturation: -0.12,
      contrast: 0,
      brightnessMin: 0.02,
      brightnessMax: 0.96,
    );
  }

  Future<void> _applyRasterMbtiTheme() async {
    final controller = _mapController;
    if (controller == null || !_usingOfflineStyleFallback) {
      return;
    }

    try {
      final style = _getRasterMbtiStyle(widget.mbtiType);
      await controller.setLayerProperties(
        _kRasterLayerId,
        RasterLayerProperties(
          rasterHueRotate: style.hueRotate,
          rasterSaturation: style.saturation,
          rasterContrast: style.contrast,
          rasterBrightnessMin: style.brightnessMin,
          rasterBrightnessMax: style.brightnessMax,
        ),
      );
    } catch (error) {
      debugPrint('[Map] apply raster MBTI theme failed: $error');
    }
  }

  String _getStyleUrl() {
    const base = 'https://api.maptiler.com/maps';
    final mbti = widget.mbtiType;

    if (mbti == null || mbti.length < 2) {
      return '$base/basic-v2/style.json?key=$_kMapTilerApiKey&language=zh-Hans';
    }

    final ei = mbti[0].toUpperCase();
    final ns = mbti[1].toUpperCase();

    if (ei == 'E' && ns == 'S') {
      return '$base/streets-v2/style.json?key=$_kMapTilerApiKey&language=zh-Hans';
    }
    if (ei == 'E' && ns == 'N') {
      return '$base/bright-v2/style.json?key=$_kMapTilerApiKey&language=zh-Hans';
    }
    if (ei == 'I' && ns == 'N') {
      return '$base/pastel/style.json?key=$_kMapTilerApiKey&language=zh-Hans';
    }
    if (ei == 'I' && ns == 'S') {
      return '$base/outdoor-v2/style.json?key=$_kMapTilerApiKey&language=zh-Hans';
    }
    return '$base/basic-v2/style.json?key=$_kMapTilerApiKey&language=zh-Hans';
  }

  String _colorToHex(Color color) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);
    return '#${red.toRadixString(16).padLeft(2, '0')}${green.toRadixString(16).padLeft(2, '0')}${blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  String _getMarkerColor() {
    return _colorToHex(AppColors.mbtiAccent(widget.mbtiType));
  }

  String _getRecommendedColor() {
    final hsl = HSLColor.fromColor(AppColors.mbtiAccent(widget.mbtiType));
    final brightened = hsl
        .withSaturation((hsl.saturation + 0.15).clamp(0.0, 1.0))
        .withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0));
    return _colorToHex(brightened.toColor());
  }

  Map<String, dynamic> _buildGeoJson() {
    final needGcj = _usingOfflineStyleFallback;
    final features = <Map<String, dynamic>>[];

    for (final poi in widget.pois) {
      var latitude = poi.latitude;
      var longitude = poi.longitude;

      // 高德栅格底图使用 GCJ-02，这里将 WGS-84 数据转换后再渲染。
      if (needGcj) {
        final (gcjLat, gcjLon) = CoordConverter.wgs84ToGcj02(latitude, longitude);
        latitude = gcjLat;
        longitude = gcjLon;
      }

      features.add(<String, dynamic>{
        'type': 'Feature',
        'id': poi.poiId,
        'geometry': <String, dynamic>{
          'type': 'Point',
          'coordinates': <double>[longitude, latitude],
        },
        'properties': <String, dynamic>{
          'poiId': poi.poiId,
          'name': poi.name,
          'category': poi.category,
          'rating': poi.rating,
          'isRecommended': poi.isRecommended ? 1 : 0,
          'isCluster': 0,
          'clusterCount': 0,
          'clusterLabel': '',
        },
      });
    }

    for (final cluster in widget.clusters) {
      var latitude = cluster.latitude;
      var longitude = cluster.longitude;
      if (needGcj) {
        final (gcjLat, gcjLon) = CoordConverter.wgs84ToGcj02(latitude, longitude);
        latitude = gcjLat;
        longitude = gcjLon;
      }

      final province = cluster.province?.trim();
      final countLabel = province != null && province.isNotEmpty
          ? '$province\n${cluster.count}'
          : '${cluster.count}';

      features.add(<String, dynamic>{
        'type': 'Feature',
        'id': cluster.clusterId,
        'geometry': <String, dynamic>{
          'type': 'Point',
          'coordinates': <double>[longitude, latitude],
        },
        'properties': <String, dynamic>{
          'poiId': cluster.clusterId,
          'name': province != null && province.isNotEmpty
              ? '$province ${cluster.count}'
              : '${cluster.count}',
          'clusterLabel': countLabel,
          'province': province ?? '',
          'category': cluster.topCategory ?? '',
          'rating': 0,
          'isRecommended': 0,
          'isCluster': 1,
          'clusterCount': cluster.count,
        },
      });
    }

    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  Future<void> _safeRemoveLayer(String layerId) async {
    try {
      await _mapController?.removeLayer(layerId);
    } catch (_) {}
  }

  Future<void> _safeRemoveSource(String sourceId) async {
    try {
      await _mapController?.removeSource(sourceId);
    } catch (_) {}
  }

  Future<void> _removeMarkerLayers() async {
    await _safeRemoveLayer(_kClusterLabelLayerId);
    await _safeRemoveLayer(_kClusterCircleLayerId);
    await _safeRemoveLayer(_kLabelLayerId);
    await _safeRemoveLayer(_kCircleLayerId);
    await _safeRemoveLayer(_kGlowLayerId);
    await _safeRemoveSource(_kSourceId);
    _sourceAdded = false;
  }

  Future<void> _removeRouteLayers() async {
    await _safeRemoveLayer(_kRouteLabelLayerId);
    await _safeRemoveLayer(_kRoutePointLayerId);
    await _safeRemoveLayer(_kRouteLineLayerId);
    await _safeRemoveSource(_kRouteSourceId);
    _routeSourceAdded = false;
  }

  Future<void> _syncMarkers() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final geoJson = _buildGeoJson();
    if (_sourceAdded) {
      try {
        await controller.setGeoJsonSource(_kSourceId, geoJson);
        return;
      } catch (error) {
        debugPrint('[Map] setGeoJsonSource failed: $error');
        _sourceAdded = false;
      }
    }

    await _removeMarkerLayers();

    try {
      await controller.addGeoJsonSource(_kSourceId, geoJson, promoteId: 'poiId');

      final markerColor = _getMarkerColor();
      final recommendedColor = _getRecommendedColor();

      await controller.addCircleLayer(
        _kSourceId,
        _kClusterCircleLayerId,
        CircleLayerProperties(
          circleColor: markerColor,
          circleRadius: <Object>[
            'interpolate',
            <String>['linear'],
            <String>['get', 'clusterCount'],
            2,
            18.0,
            10,
            24.0,
            50,
            32.0,
            200,
            40.0,
          ],
          circleOpacity: 0.78,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2.5,
        ),
        filter: <Object>['==', <String>['get', 'isCluster'], 1],
        enableInteraction: true,
      );

      await controller.addSymbolLayer(
        _kSourceId,
        _kClusterLabelLayerId,
        const SymbolLayerProperties(
          textField: <String>['get', 'clusterLabel'],
          textFont: <String>['Noto Sans Regular'],
          textSize: 12.0,
          textColor: '#FFFFFF',
          textHaloColor: 'rgba(0,0,0,0.18)',
          textHaloWidth: 1.0,
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        filter: <Object>['==', <String>['get', 'isCluster'], 1],
        enableInteraction: true,
      );

      await controller.addCircleLayer(
        _kSourceId,
        _kGlowLayerId,
        CircleLayerProperties(
          circleColor: recommendedColor,
          circleRadius: 20.0,
          circleOpacity: 0.16,
          circleStrokeWidth: 0.0,
        ),
        filter: <Object>[
          'all',
          <Object>['==', <String>['get', 'isCluster'], 0],
          <Object>['==', <String>['get', 'isRecommended'], 1],
        ],
        enableInteraction: false,
      );

      await controller.addCircleLayer(
        _kSourceId,
        _kCircleLayerId,
        CircleLayerProperties(
          circleColor: <Object>[
            'case',
            <Object>['==', <String>['get', 'isRecommended'], 1],
            recommendedColor,
            markerColor,
          ],
          circleRadius: <Object>[
            'case',
            <Object>['==', <String>['get', 'isRecommended'], 1],
            12.0,
            6.0,
          ],
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: <Object>[
            'case',
            <Object>['==', <String>['get', 'isRecommended'], 1],
            2.5,
            1.5,
          ],
          circleOpacity: <Object>[
            'case',
            <Object>['==', <String>['get', 'isRecommended'], 1],
            0.90,
            0.68,
          ],
        ),
        filter: <Object>['==', <String>['get', 'isCluster'], 0],
        enableInteraction: true,
      );

      await controller.addSymbolLayer(
        _kSourceId,
        _kLabelLayerId,
        SymbolLayerProperties(
          textField: const <String>['get', 'name'],
          textFont: const <String>['Noto Sans Regular'],
          textOffset: const <double>[0.0, 1.3],
          textSize: 11.0,
          textColor: markerColor,
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
          textAllowOverlap: false,
          textIgnorePlacement: false,
        ),
        filter: <Object>['==', <String>['get', 'isCluster'], 0],
        enableInteraction: true,
      );

      _sourceAdded = true;
    } catch (error) {
      debugPrint('[Map] marker sync failed: $error');
      _sourceAdded = false;
    }
  }

  Future<void> _syncRouteLine() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final hasRoute = widget.routeLineCoords.isNotEmpty || widget.routePoints.isNotEmpty;
    if (!hasRoute) {
      await _removeRouteLayers();
      return;
    }

    final needGcj = _usingOfflineStyleFallback;
    final lineCoordinates = <List<double>>[];
    final pointFeatures = <Map<String, dynamic>>[];

    if (widget.routePoints.isNotEmpty) {
      for (var i = 0; i < widget.routePoints.length; i++) {
        final routePoint = widget.routePoints[i];
        var latitude = routePoint.latitude;
        var longitude = routePoint.longitude;

        if (needGcj && !routePoint.isGcj02) {
          final (gcjLat, gcjLon) = CoordConverter.wgs84ToGcj02(latitude, longitude);
          latitude = gcjLat;
          longitude = gcjLon;
        }

        final stopNumber = routePoint.index > 0 ? routePoint.index : i + 1;
        final shortLabel = 'D${routePoint.day}-${_circledNumber(stopNumber)}';

        lineCoordinates.add(<double>[longitude, latitude]);
        pointFeatures.add(<String, dynamic>{
          'type': 'Feature',
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[longitude, latitude],
          },
          'properties': <String, dynamic>{
            'index': i,
            'day': routePoint.day,
            'stopIndex': stopNumber,
            'name': routePoint.name,
            'label': '$shortLabel ${routePoint.name}',
            'shortLabel': shortLabel,
          },
        });
      }
    } else {
      for (var i = 0; i < widget.routeLineCoords.length; i++) {
        final coord = widget.routeLineCoords[i];
        if (coord.length < 2) {
          continue;
        }

        var latitude = coord[0];
        var longitude = coord[1];
        if (needGcj) {
          final (gcjLat, gcjLon) = CoordConverter.wgs84ToGcj02(latitude, longitude);
          latitude = gcjLat;
          longitude = gcjLon;
        }

        lineCoordinates.add(<double>[longitude, latitude]);
        pointFeatures.add(<String, dynamic>{
          'type': 'Feature',
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[longitude, latitude],
          },
          'properties': <String, dynamic>{
            'index': i,
            'label': '${i + 1}',
            'shortLabel': '${i + 1}',
          },
        });
      }
    }

    final geoJson = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': lineCoordinates,
          },
          'properties': const <String, dynamic>{},
        },
        ...pointFeatures,
      ],
    };

    if (_routeSourceAdded) {
      try {
        await controller.setGeoJsonSource(_kRouteSourceId, geoJson);
        return;
      } catch (error) {
        debugPrint('[Map] route source update failed: $error');
        _routeSourceAdded = false;
      }
    }

    await _removeRouteLayers();

    try {
      await controller.addGeoJsonSource(_kRouteSourceId, geoJson);

      await controller.addLineLayer(
        _kRouteSourceId,
        _kRouteLineLayerId,
        LineLayerProperties(
          lineColor: _getMarkerColor(),
          lineWidth: 3.5,
          lineOpacity: 0.85,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        filter: <Object>['==', <String>['geometry-type'], 'LineString'],
      );

      await controller.addCircleLayer(
        _kRouteSourceId,
        _kRoutePointLayerId,
        CircleLayerProperties(
          circleColor: _getMarkerColor(),
          circleRadius: 14.0,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2.5,
          circleOpacity: 0.92,
        ),
        filter: <Object>['==', <String>['geometry-type'], 'Point'],
      );

      await controller.addSymbolLayer(
        _kRouteSourceId,
        _kRouteLabelLayerId,
        const SymbolLayerProperties(
          textField: <String>['get', 'shortLabel'],
          textFont: <String>['Noto Sans Regular'],
          textSize: 10.0,
          textColor: '#FFFFFF',
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textOffset: <double>[0.0, 0.0],
        ),
        filter: <Object>['==', <String>['geometry-type'], 'Point'],
      );

      _routeSourceAdded = true;
    } catch (error) {
      debugPrint('[Map] route line sync failed: $error');
      _routeSourceAdded = false;
    }
  }

  String _circledNumber(int number) {
    const circled = <String>['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩'];
    if (number >= 1 && number <= circled.length) {
      return circled[number - 1];
    }
    return '$number';
  }

  @override
  Widget build(BuildContext context) {
    final styleString = _localizedStyleString;
    if (styleString == null) {
      return Container(color: AppColors.paper);
    }

    return MapLibreMap(
      initialCameraPosition: _kInitialCameraPosition,
      styleString: styleString,
      trackCameraPosition: true,
      onMapCreated: _onMapCreated,
      onCameraIdle: _onCameraIdle,
      onStyleLoadedCallback: () {
        _applyRasterMbtiTheme();
        _syncMarkers();
        _syncRouteLine();
      },
      myLocationEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      attributionButtonMargins: const math.Point<num>(9999, 9999),
    );
  }
}
