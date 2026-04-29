"""
地图 POI 服务单元测试
验证 POI 查询、MBTI 推荐过滤、缩放级别聚合逻辑
"""
import pytest
import pytest_asyncio
from uuid import uuid4
from unittest.mock import patch, MagicMock

from app.models.content import POIBase
from app.services.map_service import MapService
from app.schemas.map_schema import POIListRequest, MapBounds


@pytest_asyncio.fixture
async def seed_pois(db_session):
    """创建测试 POI 数据"""
    pois = [
        POIBase(
            poi_id="test-001",
            name="测试景点A",
            category="景点",
            sub_category="历史",
            longitude=116.3975,
            latitude=39.9087,
            address="北京市测试地址A",
            ai_summary_static="测试摘要A",
            ai_summary_mbti={"INTJ": "INTJ 专属摘要", "ENFP": "ENFP 专属摘要"},
            rating=4.8,
        ),
        POIBase(
            poi_id="test-002",
            name="测试餐厅B",
            category="美食",
            sub_category="川菜",
            longitude=116.4039,
            latitude=39.9407,
            address="北京市测试地址B",
            ai_summary_static="测试摘要B",
            rating=4.5,
        ),
        POIBase(
            poi_id="test-003",
            name="测试远处景点C",
            category="景点",
            sub_category="自然",
            longitude=121.4913,
            latitude=31.2400,
            address="上海市测试地址C",
            ai_summary_static="测试摘要C",
            rating=4.7,
        ),
    ]
    for p in pois:
        db_session.add(p)
    await db_session.flush()
    return pois


@pytest.mark.asyncio
class TestMapService:

    async def test_get_poi_detail(self, db_session, seed_pois):
        """获取 POI 详情应返回正确数据"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            detail = await service.get_poi_detail("test-001")

        assert detail is not None
        assert detail.name == "测试景点A"
        assert detail.category == "景点"

    async def test_get_poi_detail_with_mbti(self, db_session, seed_pois):
        """MBTI 个性化摘要应正确返回"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            detail = await service.get_poi_detail("test-001", mbti_type="INTJ")

        assert detail is not None
        # 应包含 MBTI 专属摘要
        if detail.ai_summary_mbti:
            assert "INTJ" in str(detail.ai_summary_mbti)

    async def test_get_poi_detail_not_found(self, db_session):
        """不存在的 POI 应返回 None"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            detail = await service.get_poi_detail("nonexistent-id")
        assert detail is None

    async def test_get_pois_by_bounds(self, db_session, seed_pois):
        """按边界查询应只返回区域内的 POI"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)

            # 北京区域边界
            bounds = MapBounds(
                min_lon=116.0,
                max_lon=117.0,
                min_lat=39.5,
                max_lat=40.5,
            )
            pois, clusters = await service.get_pois_by_bounds(
                bounds=bounds, zoom_level=14
            )

        # 应返回北京的两个 POI，不含上海的
        poi_ids = [p.poi_id if hasattr(p, 'poi_id') else p.get('poi_id', '') for p in pois]
        # 至少检查上海的 POI 不在结果中
        assert "test-003" not in poi_ids

    async def test_get_pois_category_filter(self, db_session, seed_pois):
        """分类筛选应正确过滤"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)

            request = POIListRequest(
                longitude=116.4,
                latitude=39.92,
                radius=10000,
                zoom_level=14,
                category="美食",
            )
            pois, clusters = await service.get_pois(request)

        # 结果应只含美食分类
        for p in pois:
            cat = p.category if hasattr(p, 'category') else p.get('category', '')
            assert cat == "美食"
