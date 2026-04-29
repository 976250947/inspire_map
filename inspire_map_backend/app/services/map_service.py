"""
地图服务层
处理 POI 查询，根据 MBTI 权重过滤地点
使用纯 Python 实现，不依赖 shapely/PostGIS
"""
from typing import List, Optional, Tuple
import re
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text

from app.models.content import POIBase
from app.schemas.map_schema import (
    POIResponse, POIDetailResponse, POIClusterResponse,
    MapBounds, POIListRequest
)
from app.ai_core.rag_engine import RAGEngine
from app.utils.geo_utils import get_bounding_box, haversine_distance


class MapService:
    """地图业务服务"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.rag = RAGEngine()

    async def search_pois(
        self,
        query: str,
        category: Optional[str] = None,
        mbti_type: Optional[str] = None,
        limit: int = 20
    ) -> List[POIResponse]:
        """
        POI 全文模糊搜索
        按名称、地址、子分类匹配关键词

        Args:
            query: 搜索关键词
            category: 可选分类筛选
            mbti_type: 用户MBTI类型（影响推荐排序）
            limit: 返回数量上限

        Returns:
            匹配的 POI 列表
        """
        keyword = f"%{query}%"
        stmt = select(POIBase).where(
            (POIBase.name.ilike(keyword))
            | (POIBase.address.ilike(keyword))
            | (POIBase.sub_category.ilike(keyword))
        )
        if category:
            stmt = stmt.where(POIBase.category == category)
        stmt = stmt.limit(limit)

        result = await self.db.execute(stmt)
        pois = result.scalars().all()

        responses = [
            POIResponse(
                poi_id=poi.poi_id,
                name=poi.name,
                category=poi.category,
                sub_category=poi.sub_category,
                longitude=poi.longitude,
                latitude=poi.latitude,
                address=poi.address,
                ai_summary=poi.ai_summary_static,
                rating=poi.rating,
                is_recommended=self._is_recommended_for_mbti(poi, mbti_type),
            )
            for poi in pois
        ]
        if mbti_type:
            responses.sort(key=lambda x: x.is_recommended, reverse=True)
        return responses

    async def get_pois(
        self,
        request: POIListRequest
    ) -> Tuple[List[POIResponse], List[POIClusterResponse]]:
        """
        获取地图 POI 列表
        根据缩放级别决定返回聚合点或详细 POI

        Args:
            request: POI查询请求

        Returns:
            (POI列表, 聚合点列表)
        """
        # 缩放级别判断：小于12级返回聚合点
        if request.zoom_level < 12:
            clusters = await self._get_clusters(
                request.longitude,
                request.latitude,
                request.radius,
                request.zoom_level
            )
            return [], clusters

        # 获取详细 POI
        pois = await self._query_pois_by_location(
            longitude=request.longitude,
            latitude=request.latitude,
            radius=request.radius,
            category=request.category,
            mbti_type=request.mbti_type
        )

        return pois, []

    async def get_pois_by_bounds(
        self,
        bounds: MapBounds,
        zoom_level: int = 14,
        category: Optional[str] = None,
        mbti_type: Optional[str] = None,
        cluster_mode: Optional[str] = None,
        selected_province: Optional[str] = None,
    ) -> Tuple[List[POIResponse], List[POIClusterResponse]]:
        """
        按地图边界查询 POI

        Args:
            bounds: 地图边界
            zoom_level: 缩放级别
            category: 分类筛选
            mbti_type: MBTI类型

        Returns:
            (POI列表, 聚合点列表)
        """
        # 省份锁定模式：点击省级聚合后，直接返回该省全部 POI（不受当前视窗限制）
        if selected_province:
            pois = await self._query_pois_by_province(
                province=selected_province,
                category=category,
                mbti_type=mbti_type,
            )
            return pois, []

        # 省级聚合模式：低缩放下按省份聚合，避免网格聚合抖动
        if cluster_mode == "province" and zoom_level < 10:
            clusters = await self._get_province_clusters_by_bounds(bounds, category)
            return [], clusters

        # 缩放级别较低时返回网格聚合点，较高时返回独立 POI
        # zoom >= 10 即开始展示独立 POI（配合聚合中 count <= 3 的自动展开）
        if zoom_level < 10:
            clusters = await self._get_clusters_by_bounds(
                bounds, zoom_level, category
            )
            return [], clusters

        # zoom 10-11: 混合模式 — 大聚合保留，小聚合(count<=3)展开为独立 POI
        if zoom_level < 12:
            clusters = await self._get_clusters_by_bounds(
                bounds, zoom_level, category
            )
            # 将 count <= 3 的聚合展开为独立 POI
            small_cluster_bounds = []
            big_clusters = []
            for c in clusters:
                if c.count <= 3:
                    small_cluster_bounds.append(c)
                else:
                    big_clusters.append(c)

            # 查询小聚合区域内的独立 POI
            expanded_pois: list[POIResponse] = []
            if small_cluster_bounds:
                query = select(POIBase).where(
                    POIBase.longitude >= bounds.min_lon,
                    POIBase.longitude <= bounds.max_lon,
                    POIBase.latitude >= bounds.min_lat,
                    POIBase.latitude <= bounds.max_lat
                )
                if category:
                    query = query.where(POIBase.category == category)
                query = query.limit(300)
                result = await self.db.execute(query)
                pois = result.scalars().all()
                # 找出落在小聚合网格内的 POI
                grid_size = self._get_grid_size_by_zoom(zoom_level)
                small_grids = {
                    (int(c.longitude // grid_size), int(c.latitude // grid_size))
                    for c in small_cluster_bounds
                }
                for poi in pois:
                    g = (int(poi.longitude // grid_size), int(poi.latitude // grid_size))
                    if g in small_grids:
                        expanded_pois.append(POIResponse(
                            poi_id=poi.poi_id,
                            name=poi.name,
                            category=poi.category,
                            sub_category=poi.sub_category,
                            longitude=poi.longitude,
                            latitude=poi.latitude,
                            address=poi.address,
                            ai_summary=poi.ai_summary_static,
                            rating=poi.rating,
                            is_recommended=self._is_recommended_for_mbti(poi, mbti_type)
                        ))

            if mbti_type and expanded_pois:
                expanded_pois.sort(key=lambda x: x.is_recommended, reverse=True)

            return expanded_pois, big_clusters

        # 直接使用边界框查询，不转换为 center+radius（避免 radius 超限）
        query = select(POIBase).where(
            POIBase.longitude >= bounds.min_lon,
            POIBase.longitude <= bounds.max_lon,
            POIBase.latitude >= bounds.min_lat,
            POIBase.latitude <= bounds.max_lat
        )

        if category:
            query = query.where(POIBase.category == category)

        query = query.limit(300)

        result = await self.db.execute(query)
        pois = result.scalars().all()

        responses = []
        for poi in pois:
            response = POIResponse(
                poi_id=poi.poi_id,
                name=poi.name,
                category=poi.category,
                sub_category=poi.sub_category,
                longitude=poi.longitude,
                latitude=poi.latitude,
                address=poi.address,
                ai_summary=poi.ai_summary_static,
                rating=poi.rating,
                is_recommended=self._is_recommended_for_mbti(poi, mbti_type)
            )
            responses.append(response)

        if mbti_type:
            responses.sort(key=lambda x: x.is_recommended, reverse=True)

        return responses, []

    async def get_poi_detail(
        self,
        poi_id: str,
        mbti_type: Optional[str] = None
    ) -> Optional[POIDetailResponse]:
        """
        获取 POI 详情

        Args:
            poi_id: POI ID
            mbti_type: 用户MBTI类型

        Returns:
            POI详情或None
        """
        result = await self.db.execute(
            select(POIBase).where(POIBase.poi_id == poi_id)
        )
        poi = result.scalar_one_or_none()

        if not poi:
            return None

        # 根据MBTI获取个性化摘要
        ai_summary = poi.ai_summary_static
        if mbti_type and poi.ai_summary_mbti:
            ai_summary = poi.ai_summary_mbti.get(mbti_type, ai_summary)

        return POIDetailResponse(
            poi_id=poi.poi_id,
            name=poi.name,
            category=poi.category,
            sub_category=poi.sub_category,
            longitude=poi.longitude,
            latitude=poi.latitude,
            address=poi.address,
            ai_summary=ai_summary,
            ai_summary_mbti=ai_summary if mbti_type else None,
            rating=poi.rating,
            is_recommended=self._is_recommended_for_mbti(poi, mbti_type),
            best_visit_time=poi.best_visit_time,
            tips=poi.tips or []
        )

    async def _query_pois_by_location(
        self,
        longitude: float,
        latitude: float,
        radius: int = 5000,
        category: Optional[str] = None,
        mbti_type: Optional[str] = None,
        limit: int = 300
    ) -> List[POIResponse]:
        """
        根据位置查询 POI
        使用矩形边界框查询 + 纯 Python 距离过滤 (不依赖 PostGIS)
        """
        # 计算边界框
        min_lon, max_lon, min_lat, max_lat = get_bounding_box(
            longitude, latitude, radius
        )

        # 构建查询 - 使用简单的范围查询
        query = select(POIBase).where(
            POIBase.longitude >= min_lon,
            POIBase.longitude <= max_lon,
            POIBase.latitude >= min_lat,
            POIBase.latitude <= max_lat
        )

        if category:
            query = query.where(POIBase.category == category)

        query = query.limit(limit)

        result = await self.db.execute(query)
        pois = result.scalars().all()

        # 转换为响应模型，并计算实际距离
        responses = []
        for poi in pois:
            # 计算实际距离（米）
            distance = haversine_distance(
                longitude, latitude,
                poi.longitude, poi.latitude
            )

            # 只返回半径范围内的
            if distance <= radius:
                response = POIResponse(
                    poi_id=poi.poi_id,
                    name=poi.name,
                    category=poi.category,
                    sub_category=poi.sub_category,
                    longitude=poi.longitude,
                    latitude=poi.latitude,
                    address=poi.address,
                    ai_summary=poi.ai_summary_static,
                    rating=poi.rating,
                    is_recommended=self._is_recommended_for_mbti(poi, mbti_type)
                )
                responses.append(response)

        # 根据MBTI排序（个性化推荐优先）
        if mbti_type:
            responses.sort(key=lambda x: x.is_recommended, reverse=True)

        return responses

    async def _get_clusters(
        self,
        longitude: float,
        latitude: float,
        radius: int,
        zoom_level: int
    ) -> List[POIClusterResponse]:
        """
        获取 POI 聚合点
        使用网格聚合算法 — 纯 SQL 实现，不依赖 PostGIS
        通过 FLOOR(coord / grid_size) 将 POI 映射到网格，再按网格聚合
        """
        # 根据缩放级别决定网格大小（度）
        grid_size = self._get_grid_size_by_zoom(zoom_level)

        # 计算边界框
        min_lon, max_lon, min_lat, max_lat = get_bounding_box(
            longitude, latitude, radius
        )

        # 使用 FLOOR 将经纬度映射到网格坐标，按网格 GROUP BY
        # MODE() WITHIN GROUP 获取每个网格中最多的分类
        sql = text("""
            SELECT
                COUNT(*) as count,
                AVG(longitude) as avg_lon,
                AVG(latitude) as avg_lat,
                FLOOR(longitude / :grid_size) as grid_lon,
                FLOOR(latitude / :grid_size) as grid_lat,
                MODE() WITHIN GROUP (ORDER BY category) as top_category
            FROM poibase
            WHERE longitude >= :min_lon
              AND longitude <= :max_lon
              AND latitude >= :min_lat
              AND latitude <= :max_lat
            GROUP BY
                FLOOR(longitude / :grid_size),
                FLOOR(latitude / :grid_size)
            HAVING COUNT(*) > 0
        """)

        result = await self.db.execute(
            sql,
            {
                "grid_size": grid_size,
                "min_lon": min_lon,
                "max_lon": max_lon,
                "min_lat": min_lat,
                "max_lat": max_lat
            }
        )

        clusters = []
        for row in result:
            cluster_id = f"{int(row.grid_lon)}-{int(row.grid_lat)}"
            clusters.append(POIClusterResponse(
                cluster_id=cluster_id,
                longitude=float(row.avg_lon),
                latitude=float(row.avg_lat),
                count=int(row.count),
                top_category=row.top_category
            ))

        return clusters

    async def _get_clusters_by_bounds(
        self,
        bounds: MapBounds,
        zoom_level: int,
        category: Optional[str] = None
    ) -> List[POIClusterResponse]:
        """
        按地图边界获取 POI 聚合点（支持分类筛选）
        使用 FLOOR 网格聚合，直接使用边界框而非 center+radius
        """
        grid_size = self._get_grid_size_by_zoom(zoom_level)

        # 动态拼接 category 过滤条件
        category_filter = ""
        params = {
            "grid_size": grid_size,
            "min_lon": bounds.min_lon,
            "max_lon": bounds.max_lon,
            "min_lat": bounds.min_lat,
            "max_lat": bounds.max_lat,
        }
        if category:
            category_filter = "AND category = :category"
            params["category"] = category

        sql = text(f"""
            SELECT
                COUNT(*) as count,
                AVG(longitude) as avg_lon,
                AVG(latitude) as avg_lat,
                FLOOR(longitude / :grid_size) as grid_lon,
                FLOOR(latitude / :grid_size) as grid_lat,
                MODE() WITHIN GROUP (ORDER BY category) as top_category
            FROM poibase
            WHERE longitude >= :min_lon
              AND longitude <= :max_lon
              AND latitude >= :min_lat
              AND latitude <= :max_lat
              {category_filter}
            GROUP BY
                FLOOR(longitude / :grid_size),
                FLOOR(latitude / :grid_size)
            HAVING COUNT(*) > 0
        """)

        result = await self.db.execute(sql, params)

        clusters = []
        for row in result:
            cluster_id = f"{int(row.grid_lon)}-{int(row.grid_lat)}"
            clusters.append(POIClusterResponse(
                cluster_id=cluster_id,
                longitude=float(row.avg_lon),
                latitude=float(row.avg_lat),
                count=int(row.count),
                top_category=row.top_category
            ))

        return clusters

    # 省会/行政中心坐标（经度、纬度）
    _PROVINCE_CENTERS: dict[str, tuple[float, float]] = {
        "北京": (116.41, 39.90),
        "天津": (117.20, 39.08),
        "河北": (114.51, 38.04),
        "山西": (112.55, 37.87),
        "内蒙古": (111.75, 40.84),
        "辽宁": (123.43, 41.84),
        "吉林": (125.32, 43.90),
        "黑龙江": (126.66, 45.74),
        "上海": (121.47, 31.23),
        "江苏": (118.76, 32.06),
        "浙江": (120.15, 30.28),
        "安徽": (117.28, 31.86),
        "福建": (119.30, 26.08),
        "江西": (115.89, 28.68),
        "山东": (117.00, 36.67),
        "河南": (113.65, 34.76),
        "湖北": (114.34, 30.55),
        "湖南": (112.98, 28.19),
        "广东": (113.28, 23.13),
        "广西": (108.33, 22.84),
        "海南": (110.35, 20.02),
        "重庆": (106.55, 29.56),
        "四川": (104.07, 30.57),
        "贵州": (106.71, 26.57),
        "云南": (102.71, 25.05),
        "西藏": (91.12, 29.65),
        "陕西": (108.95, 34.26),
        "甘肃": (103.83, 36.06),
        "青海": (101.78, 36.62),
        "宁夏": (106.27, 38.47),
        "新疆": (87.63, 43.79),
        "香港": (114.17, 22.28),
        "澳门": (113.55, 22.19),
        "台湾": (121.51, 25.05),
    }

    _PROVINCE_ALIASES: dict[str, tuple[str, ...]] = {
        "北京": ("北京市", "北京"),
        "天津": ("天津市", "天津"),
        "河北": ("河北省", "河北"),
        "山西": ("山西省", "山西"),
        "内蒙古": ("内蒙古自治区", "内蒙古"),
        "辽宁": ("辽宁省", "辽宁"),
        "吉林": ("吉林省", "吉林"),
        "黑龙江": ("黑龙江省", "黑龙江"),
        "上海": ("上海市", "上海"),
        "江苏": ("江苏省", "江苏"),
        "浙江": ("浙江省", "浙江"),
        "安徽": ("安徽省", "安徽"),
        "福建": ("福建省", "福建"),
        "江西": ("江西省", "江西"),
        "山东": ("山东省", "山东"),
        "河南": ("河南省", "河南"),
        "湖北": ("湖北省", "湖北"),
        "湖南": ("湖南省", "湖南"),
        "广东": ("广东省", "广东"),
        "广西": ("广西壮族自治区", "广西"),
        "海南": ("海南省", "海南"),
        "重庆": ("重庆市", "重庆"),
        "四川": ("四川省", "四川"),
        "贵州": ("贵州省", "贵州"),
        "云南": ("云南省", "云南"),
        "西藏": ("西藏自治区", "西藏"),
        "陕西": ("陕西省", "陕西"),
        "甘肃": ("甘肃省", "甘肃"),
        "青海": ("青海省", "青海"),
        "宁夏": ("宁夏回族自治区", "宁夏"),
        "新疆": ("新疆维吾尔自治区", "新疆"),
        "香港": ("香港特别行政区", "香港"),
        "澳门": ("澳门特别行政区", "澳门"),
        "台湾": ("台湾省", "台湾"),
    }

    def _extract_province_from_address(self, address: Optional[str]) -> Optional[str]:
        """优先从地址文本识别省份，精度高于仅靠中心点最近匹配。"""
        if not address:
            return None
        cleaned = re.sub(r"\s+", "", address)
        for province, aliases in self._PROVINCE_ALIASES.items():
            for alias in aliases:
                if cleaned.startswith(alias) or alias in cleaned[:12]:
                    return province
        return None

    def _infer_province(self, longitude: float, latitude: float, address: Optional[str] = None) -> str:
        """省份归属推断：先地址匹配，再最近省会中心点兜底。"""
        by_address = self._extract_province_from_address(address)
        if by_address:
            return by_address

        closest = "未知"
        min_dist = float("inf")
        for province, (center_lon, center_lat) in self._PROVINCE_CENTERS.items():
            # 这里使用 haversine 距离，精度足够且稳定
            dist = haversine_distance(longitude, latitude, center_lon, center_lat)
            if dist < min_dist:
                min_dist = dist
                closest = province
        return closest

    async def _get_province_clusters_by_bounds(
        self,
        bounds: MapBounds,
        category: Optional[str] = None,
    ) -> List[POIClusterResponse]:
        """按省份聚类：每省一个聚合点，中心为该省在当前视窗内 POI 均值。"""
        query = select(POIBase).where(
            POIBase.longitude >= bounds.min_lon,
            POIBase.longitude <= bounds.max_lon,
            POIBase.latitude >= bounds.min_lat,
            POIBase.latitude <= bounds.max_lat,
        )
        if category:
            query = query.where(POIBase.category == category)

        query = query.limit(3000)
        result = await self.db.execute(query)
        pois = result.scalars().all()

        buckets: dict[str, dict] = {}
        for poi in pois:
            province = self._infer_province(poi.longitude, poi.latitude, poi.address)
            if province not in buckets:
                buckets[province] = {
                    "count": 0,
                    "sum_lon": 0.0,
                    "sum_lat": 0.0,
                    "cat": {},
                }
            b = buckets[province]
            b["count"] += 1
            b["sum_lon"] += poi.longitude
            b["sum_lat"] += poi.latitude
            cat = poi.category or ""
            b["cat"][cat] = b["cat"].get(cat, 0) + 1

        clusters: list[POIClusterResponse] = []
        for province, b in buckets.items():
            if b["count"] <= 0:
                continue
            top_category = None
            if b["cat"]:
                top_category = max(b["cat"].items(), key=lambda x: x[1])[0]

            # 聚合点定位到省会坐标，避免 POI 分布偏远导致气泡偏移
            center = self._PROVINCE_CENTERS.get(province)
            if center:
                clon, clat = center
            else:
                clon = b["sum_lon"] / b["count"]
                clat = b["sum_lat"] / b["count"]

            clusters.append(POIClusterResponse(
                cluster_id=f"province:{province}",
                longitude=float(clon),
                latitude=float(clat),
                count=int(b["count"]),
                top_category=top_category,
                province=province,
            ))

        clusters.sort(key=lambda c: c.count, reverse=True)
        return clusters

    async def _query_pois_by_province(
        self,
        province: str,
        category: Optional[str] = None,
        mbti_type: Optional[str] = None,
        limit: int = 3000,
    ) -> List[POIResponse]:
        """查询某一省份下的所有 POI（按经纬度推断省份归属）。"""
        query = select(POIBase)
        if category:
            query = query.where(POIBase.category == category)
        query = query.limit(limit)

        result = await self.db.execute(query)
        pois = result.scalars().all()

        responses: list[POIResponse] = []
        for poi in pois:
            if self._infer_province(poi.longitude, poi.latitude, poi.address) != province:
                continue
            responses.append(POIResponse(
                poi_id=poi.poi_id,
                name=poi.name,
                category=poi.category,
                sub_category=poi.sub_category,
                longitude=poi.longitude,
                latitude=poi.latitude,
                address=poi.address,
                ai_summary=poi.ai_summary_static,
                rating=poi.rating,
                is_recommended=self._is_recommended_for_mbti(poi, mbti_type),
            ))

        if mbti_type:
            responses.sort(key=lambda x: x.is_recommended, reverse=True)
        return responses

    # 四维度 MBTI → POI 偏好标签映射（权重: 高=3, 中=2, 低=1）
    # E/I: 社交倾向, N/S: 信息获取, T/F: 决策方式, J/P: 生活方式
    _MBTI_TAG_WEIGHTS: dict[str, dict[str, int]] = {
        # ── 分析家 (NT) ──
        'INTJ': {'历史': 3, '博物馆': 3, '科技': 3, '建筑': 3, '文化': 2, '艺术': 2, '书店': 2, '图书馆': 2, '历史古迹': 3, '公园': 1},
        'INTP': {'博物馆': 3, '科技': 3, '书店': 3, '图书馆': 3, '文化': 2, '艺术': 2, '咖啡': 2, '历史': 2, '文化创意': 2},
        'ENTJ': {'景点': 3, '商圈': 3, '建筑': 2, '历史': 2, '文化': 2, '美食': 2, '购物': 1, '科技': 2},
        'ENTP': {'文化创意': 3, '夜生活': 3, '美食': 2, '商圈': 2, '酒吧': 2, '娱乐': 2, '艺术': 2, '购物': 1},
        # ── 外交家 (NF) ──
        'INFJ': {'文化': 3, '艺术': 3, '美术馆': 3, '寺庙': 3, '书店': 2, '自然': 2, '公园': 2, '历史': 2, '文化创意': 2},
        'INFP': {'艺术': 3, '美术馆': 3, '书店': 3, '咖啡': 3, '文化': 2, '公园': 2, '自然': 2, '文化创意': 3, '茶馆': 2},
        'ENFJ': {'文化': 3, '美食': 3, '景点': 2, '购物': 2, '娱乐': 2, '商圈': 2, '夜生活': 1, '艺术': 2},
        'ENFP': {'美食': 3, '夜生活': 3, '文化创意': 3, '娱乐': 3, '酒吧': 2, '购物': 2, '艺术': 2, '自然': 1},
        # ── 哨兵 (SJ) ──
        'ISTJ': {'历史': 3, '历史古迹': 3, '博物馆': 3, '景点': 2, '建筑': 2, '自然': 1, '公园': 1, '文化': 2},
        'ISFJ': {'美食': 3, '茶馆': 3, '小吃': 3, '公园': 2, '文化': 2, '手工艺': 2, '自然': 2, '书店': 1},
        'ESTJ': {'景点': 3, '商圈': 3, '购物': 2, '历史': 2, '美食': 2, '建筑': 2, '娱乐': 1},
        'ESFJ': {'美食': 3, '购物': 3, '景点': 3, '商圈': 2, '娱乐': 2, '小吃': 2, '咖啡': 1, '夜生活': 1},
        # ── 探险家 (SP) ──
        'ISTP': {'户外': 3, '自然': 3, '自然景观': 3, '运动': 3, '科技': 2, '公园': 2, '建筑': 1},
        'ISFP': {'艺术': 3, '美术馆': 3, '自然': 3, '咖啡': 3, '公园': 2, '文化创意': 2, '摄影': 2, '自然景观': 2},
        'ESTP': {'户外': 3, '运动': 3, '夜生活': 3, '酒吧': 3, '娱乐': 2, '美食': 2, '购物': 1, '夜宵': 2},
        'ESFP': {'夜生活': 3, '娱乐': 3, '美食': 3, '购物': 3, '酒吧': 2, '商圈': 2, '小吃': 2, '夜宵': 2},
    }

    # 推荐阈值：POI 的类别/子类别的最大权重 >= 此值即推荐
    _RECOMMEND_THRESHOLD: int = 2

    def _is_recommended_for_mbti(
        self,
        poi: POIBase,
        mbti_type: Optional[str]
    ) -> bool:
        """
        基于完整四维 MBTI 判断 POI 是否推荐。
        对 16 种人格分别维护偏好标签 + 权重，取 POI category/sub_category
        与权重表交集的最大值，达到阈值即推荐。

        无 MBTI 时按评分 >= 4.5 作为兜底策略（热门推荐）。
        """
        if not mbti_type or len(mbti_type) < 4:
            # 兜底：未登录或未填问卷 → 按热度推荐高评分 POI
            return getattr(poi, 'rating', 0) >= 4.5

        cat = (poi.category or "").strip()
        sub = (poi.sub_category or "").strip()

        weights = self._MBTI_TAG_WEIGHTS.get(mbti_type.upper(), {})
        if not weights:
            return getattr(poi, 'rating', 0) >= 4.5

        # 取 category 和 sub_category 中权重最高的
        score = max(weights.get(cat, 0), weights.get(sub, 0))
        return score >= self._RECOMMEND_THRESHOLD

    def _get_grid_size_by_zoom(self, zoom_level: int) -> float:
        """根据缩放级别获取网格大小 (度)"""
        # 缩放级别越小，网格越大
        grid_sizes = {
            3: 10.0,
            4: 5.0,
            5: 2.5,
            6: 1.0,
            7: 0.5,
            8: 0.25,
            9: 0.1,
            10: 0.05,
            11: 0.025,
        }
        return grid_sizes.get(zoom_level, 0.01)
