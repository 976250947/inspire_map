/// 经纬度 → 省份反查工具
/// 基于省会城市中心坐标 + 距离阈值的轻量级匹配方案
/// MVP 阶段使用简化方案，后续可升级为 Point-in-Polygon
library;

import 'dart:math';

class GeoProvinceLookup {
  GeoProvinceLookup._();

  /// 省份中心坐标集合 (经度, 纬度)
  /// 基于各省会城市或行政区域几何中心
  static const Map<String, List<double>> _provinceCenters = {
    '北京': [116.41, 39.90],
    '天津': [117.20, 39.08],
    '河北': [114.51, 38.04],
    '山西': [112.55, 37.87],
    '内蒙古': [111.75, 40.84],
    '辽宁': [123.43, 41.84],
    '吉林': [125.32, 43.90],
    '黑龙江': [126.66, 45.74],
    '上海': [121.47, 31.23],
    '江苏': [118.76, 32.06],
    '浙江': [120.15, 30.28],
    '安徽': [117.28, 31.86],
    '福建': [119.30, 26.08],
    '江西': [115.89, 28.68],
    '山东': [117.00, 36.67],
    '河南': [113.65, 34.76],
    '湖北': [114.34, 30.55],
    '湖南': [112.98, 28.19],
    '广东': [113.28, 23.13],
    '广西': [108.33, 22.84],
    '海南': [110.35, 20.02],
    '重庆': [106.55, 29.56],
    '四川': [104.07, 30.57],
    '贵州': [106.71, 26.57],
    '云南': [102.71, 25.05],
    '西藏': [91.12, 29.65],
    '陕西': [108.95, 34.26],
    '甘肃': [103.83, 36.06],
    '青海': [101.78, 36.62],
    '宁夏': [106.27, 38.47],
    '新疆': [87.63, 43.79],
    '香港': [114.17, 22.28],
    '澳门': [113.55, 22.19],
    '台湾': [121.51, 25.05],
  };

  /// 根据经纬度查找最近的省份
  ///
  /// [longitude] 经度
  /// [latitude] 纬度
  /// [maxDistanceKm] 最大匹配距离 (公里)，超出则返回 null
  ///
  /// 返回省份名称，如 "北京"、"广东" 等
  static String? findProvince(
    double longitude,
    double latitude, {
    double maxDistanceKm = 500.0,
  }) {
    String? closestProvince;
    double minDistance = double.infinity;

    for (final entry in _provinceCenters.entries) {
      final center = entry.value;
      // 使用 Haversine 公式计算球面距离
      final distance = _haversineDistance(
        latitude,
        longitude,
        center[1],
        center[0],
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestProvince = entry.key;
      }
    }

    // 如果最近距离超过阈值，返回 null
    if (minDistance > maxDistanceKm) return null;

    return closestProvince;
  }

  /// 批量查找：从足迹经纬度列表中提取所有涉及的省份
  static Set<String> findProvinces(List<List<double>> coordinates) {
    final provinces = <String>{};
    for (final coord in coordinates) {
      if (coord.length >= 2) {
        final province = findProvince(coord[0], coord[1]);
        if (province != null) {
          provinces.add(province);
        }
      }
    }
    return provinces;
  }

  /// Haversine 球面距离公式
  /// 返回两点间的距离（公里）
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  /// 获取所有省份名称列表
  static List<String> get allProvinces => _provinceCenters.keys.toList();
}
