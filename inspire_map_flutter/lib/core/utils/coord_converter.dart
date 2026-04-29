import 'dart:math';

/// WGS-84 ↔ GCJ-02 坐标转换工具
///
/// 高德地图栅格瓦片使用 GCJ-02 (国测局/火星坐标系)，
/// 而 MapLibre 默认按 WGS-84 投影 GeoJSON 坐标。
/// 当底图为高德瓦片时，需要将 POI 坐标从 WGS-84 转为 GCJ-02，
/// 否则 POI 会偏移约 500-1000 米。
class CoordConverter {
  // 长半轴 (Krasovsky 1940 ellipsoid)
  static const double _a = 6378245.0;
  // 扁率
  static const double _ee = 0.00669342162296594323;

  /// 判断坐标是否在中国境内（粗略矩形边界）
  /// 仅中国境内坐标需要偏移，境外直接返回原值
  static bool _outOfChina(double lat, double lon) {
    if (lon < 72.004 || lon > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
  }

  static double _transformLat(double x, double y) {
    var ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * sqrt(x.abs());
    ret +=
        (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret +=
        (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLon(double x, double y) {
    var ret = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * sqrt(x.abs());
    ret +=
        (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret +=
        (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) *
        2.0 /
        3.0;
    return ret;
  }

  /// WGS-84 → GCJ-02 转换
  /// 返回 (latitude, longitude)
  static (double lat, double lon) wgs84ToGcj02(double wgsLat, double wgsLon) {
    if (_outOfChina(wgsLat, wgsLon)) return (wgsLat, wgsLon);

    var dLat = _transformLat(wgsLon - 105.0, wgsLat - 35.0);
    var dLon = _transformLon(wgsLon - 105.0, wgsLat - 35.0);
    final radLat = wgsLat / 180.0 * pi;
    var magic = sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * pi);
    dLon = (dLon * 180.0) / (_a / sqrtMagic * cos(radLat) * pi);

    return (wgsLat + dLat, wgsLon + dLon);
  }

  /// GCJ-02 → WGS-84（逆向近似，精度 ~1m）
  static (double lat, double lon) gcj02ToWgs84(double gcjLat, double gcjLon) {
    final (gLat, gLon) = wgs84ToGcj02(gcjLat, gcjLon);
    final dLat = gLat - gcjLat;
    final dLon = gLon - gcjLon;
    return (gcjLat - dLat, gcjLon - dLon);
  }
}
