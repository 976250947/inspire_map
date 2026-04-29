"""
MapService.search_pois 单元测试
验证 POI 模糊搜索、分类筛选、MBTI 推荐排序
"""
import pytest
import pytest_asyncio
from unittest.mock import patch, MagicMock

from app.models.content import POIBase
from app.services.map_service import MapService


@pytest_asyncio.fixture
async def seed_pois(db_session):
    """插入多条 POI 用于搜索测试"""
    pois_data = [
        POIBase(
            poi_id="poi-wuhouci",
            name="成都武侯祠",
            category="景点",
            sub_category="历史",
            longitude=104.0476,
            latitude=30.6462,
            address="成都市武侯区",
            ai_summary_static="三国蜀国祠堂",
            rating=4.8,
        ),
        POIBase(
            poi_id="poi-kuanzhai",
            name="宽窄巷子",
            category="景点",
            sub_category="文化街区",
            longitude=104.0553,
            latitude=30.6694,
            address="成都市青羊区",
            ai_summary_static="清代古街",
            rating=4.5,
        ),
        POIBase(
            poi_id="poi-hotpot",
            name="小龙坎火锅",
            category="美食",
            sub_category="火锅",
            longitude=104.0601,
            latitude=30.6572,
            address="成都市锦江区",
            ai_summary_static="正宗成都火锅",
            rating=4.3,
        ),
        POIBase(
            poi_id="poi-panda",
            name="成都大熊猫繁育研究基地",
            category="景点",
            sub_category="自然",
            longitude=104.1453,
            latitude=30.7347,
            address="成都市成华区",
            ai_summary_static="国宝大熊猫",
            rating=4.9,
        ),
    ]
    for poi in pois_data:
        db_session.add(poi)
    await db_session.flush()
    return pois_data


@pytest.mark.asyncio
class TestSearchPOIs:
    """POI 搜索服务"""

    async def test_search_by_name(self, db_session, seed_pois):
        """按名称关键词搜索"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("武侯祠")

        assert len(results) == 1
        assert results[0].poi_id == "poi-wuhouci"
        assert results[0].name == "成都武侯祠"

    async def test_search_by_address(self, db_session, seed_pois):
        """按地址关键词搜索"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("青羊区")

        assert len(results) == 1
        assert results[0].poi_id == "poi-kuanzhai"

    async def test_search_by_subcategory(self, db_session, seed_pois):
        """按子分类搜索"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("火锅")

        assert len(results) == 1
        assert results[0].poi_id == "poi-hotpot"

    async def test_search_broad_keyword(self, db_session, seed_pois):
        """宽泛关键词应返回多条结果"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("成都")

        # "成都" 出现在多个 POI 的名称或地址中
        assert len(results) >= 3

    async def test_search_with_category_filter(self, db_session, seed_pois):
        """按分类筛选搜索结果"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("成都", category="美食")

        assert len(results) == 1
        assert results[0].category == "美食"

    async def test_search_empty_result(self, db_session, seed_pois):
        """搜索无匹配内容应返回空列表"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("不存在的景点ABC")

        assert results == []

    async def test_search_limit(self, db_session, seed_pois):
        """limit 参数应限制返回数量"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("成都", limit=1)

        assert len(results) <= 1

    async def test_search_mbti_sorts_recommended_first(self, db_session, seed_pois):
        """指定 MBTI 时推荐 POI 应排在前面"""
        with patch("app.services.map_service.RAGEngine", MagicMock()):
            service = MapService(db_session)
            results = await service.search_pois("成都", mbti_type="INTJ")

        # 只要有 MBTI 即应按 is_recommended 降序排列
        if len(results) > 1:
            recommended = [r for r in results if r.is_recommended]
            not_recommended = [r for r in results if not r.is_recommended]
            # 推荐项应全部在不推荐项之前
            if recommended and not_recommended:
                last_rec_idx = max(results.index(r) for r in recommended)
                first_unrec_idx = min(results.index(r) for r in not_recommended)
                assert last_rec_idx < first_unrec_idx
