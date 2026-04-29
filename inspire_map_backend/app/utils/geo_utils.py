"""
地理工具类
经纬度距离计算、GeoHash 转换
"""
import math
from typing import Tuple


def haversine_distance(
    lon1: float,
    lat1: float,
    lon2: float,
    lat2: float
) -> float:
    """
    计算两点间的球面距离 (Haversine 公式)

    Args:
        lon1: 点1经度
        lat1: 点1纬度
        lon2: 点2经度
        lat2: 点2纬度

    Returns:
        距离 (米)
    """
    R = 6371000  # 地球半径 (米)

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


def get_bounding_box(
    longitude: float,
    latitude: float,
    radius_meters: float
) -> Tuple[float, float, float, float]:
    """
    根据中心点和半径计算边界框

    Args:
        longitude: 中心经度
        latitude: 中心纬度
        radius_meters: 半径 (米)

    Returns:
        (min_lon, max_lon, min_lat, max_lat)
    """
    # 1度纬度约等于111公里
    lat_delta = radius_meters / 111000

    # 1度经度随纬度变化
    lon_delta = radius_meters / (111000 * math.cos(math.radians(latitude)))

    return (
        longitude - lon_delta,  # min_lon
        longitude + lon_delta,  # max_lon
        latitude - lat_delta,   # min_lat
        latitude + lat_delta    # max_lat
    )


def lat_lon_to_geohash(
    latitude: float,
    longitude: float,
    precision: int = 9
) -> str:
    """
    将经纬度转换为 GeoHash

    Args:
        latitude: 纬度
        longitude: 经度
        precision: GeoHash 精度

    Returns:
        GeoHash 字符串
    """
    # 使用 geohash2 库或内置实现
    # 这里使用简化版 Base32 编码
    base32 = '0123456789bcdefghjkmnpqrstuvwxyz'

    lat_range = [-90.0, 90.0]
    lon_range = [-180.0, 180.0]

    geohash = []
    bits = 0
    bits_count = 0
    is_lon = True

    while len(geohash) < precision:
        if is_lon:
            mid = (lon_range[0] + lon_range[1]) / 2
            if longitude > mid:
                bits = bits * 2 + 1
                lon_range[0] = mid
            else:
                bits = bits * 2
                lon_range[1] = mid
        else:
            mid = (lat_range[0] + lat_range[1]) / 2
            if latitude > mid:
                bits = bits * 2 + 1
                lat_range[0] = mid
            else:
                bits = bits * 2
                lat_range[1] = mid

        is_lon = not is_lon
        bits_count += 1

        if bits_count == 5:
            geohash.append(base32[bits])
            bits = 0
            bits_count = 0

    return ''.join(geohash)


def geohash_neighbors(geohash: str) -> list:
    """
    获取 GeoHash 的相邻区块

    Args:
        geohash: GeoHash 字符串

    Returns:
        相邻 GeoHash 列表 (8个方向)
    """
    # 简化实现，实际应使用 geohash2 库
    # 这里返回空列表作为占位
    return []


def calculate_zoom_level(radius_meters: float) -> int:
    """
    根据半径估算地图缩放级别

    Args:
        radius_meters: 半径 (米)

    Returns:
        缩放级别 (3-20)
    """
    if radius_meters > 500000:  # > 500km
        return 5
    elif radius_meters > 200000:  # > 200km
        return 7
    elif radius_meters > 50000:   # > 50km
        return 9
    elif radius_meters > 20000:   # > 20km
        return 11
    elif radius_meters > 5000:    # > 5km
        return 13
    elif radius_meters > 1000:    # > 1km
        return 15
    else:
        return 17
