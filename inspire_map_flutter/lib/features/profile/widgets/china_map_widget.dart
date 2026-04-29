/// 中国省份地图组件 — 基于 GeoJSON 渲染
/// 解析标准 GeoJSON FeatureCollection，通过 CustomPainter 绘制
/// 已打卡省份高亮填色，未打卡省份浅灰描边
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

/// 中国地图 GeoJSON 可视化组件
class ChinaMapWidget extends StatefulWidget {
  /// 已点亮（已打卡）的省份名称集合
  final Set<String> litProvinces;

  /// 高亮色 — 可由 MBTI 色系驱动
  final Color accentColor;

  /// 是否显示省份名称
  final bool showLabels;

  const ChinaMapWidget({
    super.key,
    required this.litProvinces,
    this.accentColor = AppColors.teal,
    this.showLabels = false,
  });

  @override
  State<ChinaMapWidget> createState() => _ChinaMapWidgetState();
}

class _ChinaMapWidgetState extends State<ChinaMapWidget>
    with SingleTickerProviderStateMixin {
  List<_ProvinceData>? _provinces;
  late final AnimationController _animController;
  late final Animation<double> _animProgress;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animProgress = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadGeoJSON();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 加载 GeoJSON 资源文件并解析为省份绘制数据
  Future<void> _loadGeoJSON() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/geo/china_provinces.json',
      );
      final geoJson = json.decode(jsonString) as Map<String, dynamic>;
      final features = geoJson['features'] as List<dynamic>;

      final provinces = <_ProvinceData>[];
      for (final feature in features) {
        final properties = feature['properties'] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>;
        final name = properties['name'] as String;
        final center = (properties['center'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();

        final type = geometry['type'] as String;
        final coordinates = geometry['coordinates'] as List<dynamic>;

        // 解析多边形坐标（支持 Polygon 和 MultiPolygon）
        final polygons = <List<List<double>>>[];
        if (type == 'Polygon') {
          for (final ring in coordinates) {
            final points = <List<double>>[];
            for (final coord in ring as List<dynamic>) {
              final c = coord as List<dynamic>;
              points.add([
                (c[0] as num).toDouble(),
                (c[1] as num).toDouble(),
              ]);
            }
            polygons.add(points);
          }
        } else if (type == 'MultiPolygon') {
          for (final polygon in coordinates) {
            for (final ring in polygon as List<dynamic>) {
              final points = <List<double>>[];
              for (final coord in ring as List<dynamic>) {
                final c = coord as List<dynamic>;
                points.add([
                  (c[0] as num).toDouble(),
                  (c[1] as num).toDouble(),
                ]);
              }
              polygons.add(points);
            }
          }
        }

        provinces.add(_ProvinceData(
          name: name,
          centerLon: center[0],
          centerLat: center[1],
          polygons: polygons,
        ));
      }

      if (mounted) {
        setState(() => _provinces = provinces);
        _animController.forward();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ChinaMapWidget] Failed to load GeoJSON: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_provinces == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.teal,
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animProgress,
      builder: (context, _) {
        return SizedBox(
          width: double.infinity,
          height: 248,
          child: CustomPaint(
            painter: _ChinaMapPainter(
              provinces: _provinces!,
              litProvinces: widget.litProvinces,
              accentColor: widget.accentColor,
              showLabels: widget.showLabels,
              progress: _animProgress.value,
            ),
          ),
        );
      },
    );
  }
}

/// 省份绘制数据
class _ProvinceData {
  final String name;
  final double centerLon;
  final double centerLat;
  final List<List<List<double>>> polygons;

  const _ProvinceData({
    required this.name,
    required this.centerLon,
    required this.centerLat,
    required this.polygons,
  });
}

/// 自定义地图绘制器 — 使用接近 Web 地图的投影，避免纬度方向被压扁
class _ChinaMapPainter extends CustomPainter {
  final List<_ProvinceData> provinces;
  final Set<String> litProvinces;
  final Color accentColor;
  final bool showLabels;
  final double progress;

  // 中国经纬度边界
  static const double _minLon = 73.0;
  static const double _maxLon = 136.0;
  static const double _minLat = 17.0;
  static const double _maxLat = 54.0;

  _ChinaMapPainter({
    required this.provinces,
    required this.litProvinces,
    required this.accentColor,
    required this.showLabels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 10.0;
    final drawWidth = size.width - padding * 2;
    final drawHeight = size.height - padding * 2;

    final minX = _mercatorX(_minLon);
    final maxX = _mercatorX(_maxLon);
    final minY = _mercatorY(_minLat);
    final maxY = _mercatorY(_maxLat);
    final scaleX = drawWidth / (maxX - minX);
    final scaleY = drawHeight / (maxY - minY);
    final scale = min(scaleX, scaleY);

    final offsetX = padding + (drawWidth - (maxX - minX) * scale) / 2;
    final offsetY = padding + (drawHeight - (maxY - minY) * scale) / 2;

    Offset toCanvas(double lon, double lat) {
      final projectedX = _mercatorX(lon);
      final projectedY = _mercatorY(lat);
      return Offset(
        offsetX + (projectedX - minX) * scale,
        offsetY + (maxY - projectedY) * scale,
      );
    }

    // 未点亮省份的画刷
    final dimPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..style = PaintingStyle.fill;

    final dimStrokePaint = Paint()
      ..color = const Color(0xFFD0D0D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 点亮省份的画刷
    final litPaint = Paint()
      ..style = PaintingStyle.fill;

    final litStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 绘制每个省份
    for (final province in provinces) {
      final isLit = litProvinces.contains(province.name);

      for (final polygon in province.polygons) {
        if (polygon.length < 3) continue;

        final path = Path();
        final first = toCanvas(polygon[0][0], polygon[0][1]);
        path.moveTo(first.dx, first.dy);

        for (int i = 1; i < polygon.length; i++) {
          final p = toCanvas(polygon[i][0], polygon[i][1]);
          path.lineTo(p.dx, p.dy);
        }
        path.close();

        if (isLit) {
          // 点亮省份用 MBTI 主题渐变色，带动画透明度
          litPaint.color = accentColor.withValues(alpha: 0.15 + 0.55 * progress);
          canvas.drawPath(path, litPaint);
          canvas.drawPath(path, litStrokePaint);
        } else {
          canvas.drawPath(path, dimPaint);
          canvas.drawPath(path, dimStrokePaint);
        }
      }

      // 绘制省份名称标签（可选）
      if (showLabels && province.name.length <= 3) {
        final center = toCanvas(province.centerLon, province.centerLat);
        final textPainter = TextPainter(
          text: TextSpan(
            text: province.name,
            style: TextStyle(
              fontSize: 7,
              color: isLit
                  ? accentColor.withValues(alpha: progress)
                  : const Color(0xFFBBBBBB),
              fontWeight: isLit ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(center.dx - textPainter.width / 2,
              center.dy - textPainter.height / 2),
        );
      }
    }
  }

  static double _mercatorY(double lat) {
    final clampedLat = lat.clamp(-85.0, 85.0);
    final radians = clampedLat * pi / 180;
    return log(tan(pi / 4 + radians / 2));
  }

  static double _mercatorX(double lon) {
    return lon * pi / 180;
  }

  @override
  bool shouldRepaint(_ChinaMapPainter oldDelegate) {
    return oldDelegate.litProvinces != litProvinces ||
        oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor;
  }
}
