"""
地图相关 API
GET /api/v1/map/pois
GET /api/v1/map/pois/{poi_id}
GET /api/v1/map/pois/bounds
GET /api/v1/map/geocode
"""
import json
import logging
from typing import List, Optional

import httpx
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_deps import get_db, get_redis
from app.core.security import get_optional_user_id
from app.services.map_service import MapService
from app.ai_core.llm_client import LLMClient
from app.ai_core.prompts import PromptTemplates
from app.schemas.ai_schema import AIChatMessage
from app.schemas.base import success_response
from app.schemas.map_schema import (
    POIResponse,
    POIDetailResponse,
    POIClusterResponse,
    POIListRequest,
    MapBounds
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/pois", response_model=dict)
async def get_pois(
    longitude: float = Query(..., ge=-180, le=180, description="中心经度"),
    latitude: float = Query(..., ge=-90, le=90, description="中心纬度"),
    radius: int = Query(5000, ge=100, le=50000, description="半径(米)"),
    category: Optional[str] = Query(None, description="分类筛选"),
    zoom_level: int = Query(14, ge=3, le=20, description="地图缩放级别"),
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    获取地图 POI 列表

    根据缩放级别自动决定返回聚合点或详细 POI
    - zoom_level < 12: 返回聚合点
    - zoom_level >= 12: 返回详细 POI
    """
    # 获取用户 MBTI (用于个性化推荐)
    mbti_type = None
    if user_id:
        from app.services.user_service import UserService
        user_service = UserService(db)
        user = await user_service.get_user_by_id(user_id)
        if user:
            mbti_type = user.mbti_type

    service = MapService(db)

    request = POIListRequest(
        longitude=longitude,
        latitude=latitude,
        radius=radius,
        category=category,
        zoom_level=zoom_level,
        mbti_type=mbti_type
    )

    pois, clusters = await service.get_pois(request)

    return success_response({
        "pois": pois,
        "clusters": clusters,
        "total": len(pois) + len(clusters)
    })


@router.get("/pois/mock")
async def get_mock_pois():
    """
    Mock POI 接口 — 返回多城市测试数据，无需数据库
    包含北京、成都、上海三个城市的热门地点
    """
    mock_pois = [
        # ── 北京 ──
        POIResponse(
            poi_id="bj-001", name="故宫", category="景点", sub_category="历史",
            longitude=116.3975, latitude=39.9087,
            address="北京市东城区景山前街4号",
            ai_summary="故宫是中国明清两代的皇家宫殿，世界现存最大规模的古代宫殿建筑群。建议从午门进入，沿中轴线游览约需3小时。珍宝馆和钟表馆是隐藏精华。",
            rating=4.8, is_recommended=True,
        ),
        POIResponse(
            poi_id="bj-002", name="南锣鼓巷", category="美食", sub_category="文化",
            longitude=116.4039, latitude=39.9407,
            address="北京市东城区南锣鼓巷",
            ai_summary="南锣鼓巷是北京著名的胡同文化街区，集市集、美食与文艺于一体。主街商业气息浓，真正的惊喜在旁边的胡同里。",
            rating=4.5, is_recommended=False,
        ),
        POIResponse(
            poi_id="bj-003", name="颐和园", category="景点", sub_category="历史",
            longitude=116.2733, latitude=39.9996,
            address="北京市海淀区新建宫门路19号",
            ai_summary="颐和园是中国现存规模最大、保存最完整的皇家园林，昆明湖与万寿山构成绝美山水画卷。十七孔桥的夕阳是必看景色。",
            rating=4.7, is_recommended=True,
        ),
        POIResponse(
            poi_id="bj-004", name="798艺术区", category="文化", sub_category="艺术",
            longitude=116.4977, latitude=39.9836,
            address="北京市朝阳区酒仙桥路4号",
            ai_summary="798艺术区是北京著名的当代艺术展览区，融合工业遗产与艺术创作。周末常有限定展览和艺术市集。",
            rating=4.3, is_recommended=False,
        ),
        POIResponse(
            poi_id="bj-005", name="天坛", category="景点", sub_category="历史",
            longitude=116.4109, latitude=39.8822,
            address="北京市东城区天坛公园内",
            ai_summary="天坛是明清两代皇帝祭天祈谷的场所，祈年殿的三重檐攒尖顶是中国古建筑的巅峰之作。清晨来感受市井烟火气。",
            rating=4.6, is_recommended=True,
        ),
        POIResponse(
            poi_id="bj-006", name="三里屯", category="购物", sub_category="商圈",
            longitude=116.4536, latitude=39.9385,
            address="北京市朝阳区三里屯路",
            ai_summary="三里屯是北京最时尚的商圈，夜生活丰富。太古里南区以设计品牌为主，北区偏高端。",
            rating=4.4, is_recommended=False,
        ),
        POIResponse(
            poi_id="bj-007", name="北海公园", category="景点", sub_category="自然",
            longitude=116.3922, latitude=39.9289,
            address="北京市西城区文津街1号",
            ai_summary="北海公园是北京最古老的皇家园林，白塔矗立于琼华岛之上，湖光塔影构成经典北京画面。",
            rating=4.5, is_recommended=True,
        ),
        POIResponse(
            poi_id="bj-008", name="国家博物馆", category="文化", sub_category="博物馆",
            longitude=116.4066, latitude=39.9042,
            address="北京市东城区东长安街16号",
            ai_summary="中国国家博物馆是世界上建筑面积最大的博物馆，后母戊鼎、四羊方尊等国宝级文物不容错过。",
            rating=4.7, is_recommended=True,
        ),
        POIResponse(
            poi_id="bj-009", name="什刹海", category="景点", sub_category="自然",
            longitude=116.3886, latitude=39.9388,
            address="北京市西城区什刹海",
            ai_summary="什刹海是北京内城唯一开放水域，白天环湖骑行，晚上酒吧街灯火通明，感受北京新旧交融。",
            rating=4.4, is_recommended=False,
        ),
        POIResponse(
            poi_id="bj-010", name="胡同串子咖啡", category="美食", sub_category="咖啡",
            longitude=116.4042, latitude=39.9415,
            address="北京市东城区方家胡同46号",
            ai_summary="隐藏在胡同深处的独立咖啡馆，手冲咖啡水平极高。只有6个座位，适合安静消磨一个下午。",
            rating=4.6, is_recommended=False,
        ),
        POIResponse(
            poi_id="bj-011", name="簋街", category="美食", sub_category="夜宵",
            longitude=116.4311, latitude=39.9361,
            address="北京市东城区东直门内大街",
            ai_summary="簋街是北京最有名的美食街，以麻辣小龙虾闻名。深夜时分最有氛围，是北京夜生活的缩影。",
            rating=4.3, is_recommended=False,
        ),
        # ── 成都 ──
        POIResponse(
            poi_id="cd-001", name="武侯祠", category="景点", sub_category="历史",
            longitude=104.0476, latitude=30.6462,
            address="成都市武侯区武侯祠大街231号",
            ai_summary="武侯祠是纪念诸葛亮的祠堂，也是全国影响最大的三国遗迹博物馆。红墙竹影的小路是最出片的角度。",
            rating=4.6, is_recommended=True,
        ),
        POIResponse(
            poi_id="cd-002", name="锦里", category="美食", sub_category="文化",
            longitude=104.0487, latitude=30.6451,
            address="成都市武侯区武侯祠大街231号附1号",
            ai_summary="锦里是成都最具代表性的古街，汇集川味小吃和手工艺品。夜晚灯笼亮起时的氛围感无可替代。",
            rating=4.3, is_recommended=False,
        ),
        POIResponse(
            poi_id="cd-003", name="大熊猫繁育研究基地", category="景点", sub_category="自然",
            longitude=104.1468, latitude=30.7328,
            address="成都市成华区熊猫大道1375号",
            ai_summary="全球最大的大熊猫人工繁育基地。清晨是看熊猫进食和活动的最佳时间，下午熊猫基本都在睡觉。",
            rating=4.8, is_recommended=True,
        ),
        POIResponse(
            poi_id="cd-004", name="春熙路太古里", category="购物", sub_category="商圈",
            longitude=104.0817, latitude=30.6552,
            address="成都市锦江区中纱帽街8号",
            ai_summary="太古里是成都最时尚的开放式商业街区，低密度建筑与传统大慈寺和谐共存。方所书店是必逛。",
            rating=4.5, is_recommended=False,
        ),
        POIResponse(
            poi_id="cd-005", name="人民公园鹤鸣茶社", category="美食", sub_category="茶馆",
            longitude=104.0597, latitude=30.6603,
            address="成都市青羊区少城路12号人民公园内",
            ai_summary="成都最老牌的露天茶馆，体验老成都慢生活的最佳去处。盖碗茶只要10-20元，性价比极高。",
            rating=4.7, is_recommended=True,
        ),
        POIResponse(
            poi_id="cd-006", name="宽窄巷子", category="景点", sub_category="文化",
            longitude=104.0558, latitude=30.6696,
            address="成都市青羊区宽窄巷子",
            ai_summary="由宽巷子、窄巷子、井巷子三条平行老街组成，适合体验成都的市井文化与休闲生活。",
            rating=4.4, is_recommended=False,
        ),
        POIResponse(
            poi_id="cd-007", name="杜甫草堂", category="景点", sub_category="历史",
            longitude=104.0341, latitude=30.6598,
            address="成都市青羊区青华路37号",
            ai_summary="唐代诗人杜甫流寓成都时的故居。竹林幽深，茅屋古朴，是闹市中难得的清幽之地。",
            rating=4.5, is_recommended=True,
        ),
        POIResponse(
            poi_id="cd-008", name="建设路小吃街", category="美食", sub_category="小吃",
            longitude=104.1029, latitude=30.6655,
            address="成都市成华区建设路",
            ai_summary="成都本地人最爱的小吃聚集地，比锦里更地道、更便宜。降龙爪爪、钵钵鸡、冰粉都是必吃。",
            rating=4.6, is_recommended=False,
        ),
        POIResponse(
            poi_id="cd-009", name="金沙遗址博物馆", category="文化", sub_category="博物馆",
            longitude=104.0145, latitude=30.6802,
            address="成都市青羊区金沙遗址路2号",
            ai_summary="展示古蜀文明辉煌成就的博物馆，太阳神鸟金饰已成为中国文化遗产标志。遗迹馆更加震撼。",
            rating=4.6, is_recommended=True,
        ),
        # ── 上海 ──
        POIResponse(
            poi_id="sh-001", name="外滩", category="景点", sub_category="建筑",
            longitude=121.4913, latitude=31.2400,
            address="上海市黄浦区中山东一路",
            ai_summary="上海的标志性景观，一侧万国建筑博览群，一侧浦东天际线。夜景是灵魂，日落前到达占好位置。",
            rating=4.7, is_recommended=True,
        ),
        POIResponse(
            poi_id="sh-002", name="豫园", category="景点", sub_category="历史",
            longitude=121.4926, latitude=31.2275,
            address="上海市黄浦区安仁街137号",
            ai_summary="上海最著名的古典园林，始建于明代。园外城隍庙商圈汇集各种上海特色小吃和纪念品。",
            rating=4.4, is_recommended=False,
        ),
        POIResponse(
            poi_id="sh-003", name="田子坊", category="文化", sub_category="艺术",
            longitude=121.4706, latitude=31.2110,
            address="上海市黄浦区泰康路210弄",
            ai_summary="上海最具文艺气息的弄堂创意园区，石库门建筑里藏着画廊、手作工坊和设计师店铺。",
            rating=4.2, is_recommended=False,
        ),
        POIResponse(
            poi_id="sh-004", name="武康路", category="景点", sub_category="建筑",
            longitude=121.4379, latitude=31.2108,
            address="上海市徐汇区武康路",
            ai_summary="上海最有腔调的马路之一，梧桐树荫下排列着各式洋楼别墅。武康大楼的船型建筑是打卡点。",
            rating=4.6, is_recommended=True,
        ),
        POIResponse(
            poi_id="sh-005", name="思南公馆", category="文化", sub_category="历史",
            longitude=121.4721, latitude=31.2176,
            address="上海市黄浦区思南路55号",
            ai_summary="保留了51栋花园洋房，是上海最集中的花园住宅群。周末常有读书会和文化沙龙。",
            rating=4.4, is_recommended=False,
        ),
        POIResponse(
            poi_id="sh-006", name="M50创意园", category="文化", sub_category="艺术",
            longitude=121.4445, latitude=31.2479,
            address="上海市普陀区莫干山路50号",
            ai_summary="上海最纯粹的当代艺术园区，入驻大量画廊和艺术工作室。比798更安静、更专注于艺术。",
            rating=4.3, is_recommended=True,
        ),
        POIResponse(
            poi_id="sh-007", name="上海博物馆", category="文化", sub_category="博物馆",
            longitude=121.4737, latitude=31.2294,
            address="上海市黄浦区人民大道201号",
            ai_summary="拥有近百万件珍贵文物，青铜器和陶瓷馆尤为精彩。免费开放，是了解中华文明的宝库。",
            rating=4.7, is_recommended=True,
        ),
        POIResponse(
            poi_id="sh-008", name="愚园路", category="美食", sub_category="咖啡",
            longitude=121.4302, latitude=31.2258,
            address="上海市长宁区愚园路",
            ai_summary="上海最有生活气息的马路之一，梧桐掩映下藏着无数精品咖啡馆和买手店。比武康路更本地化。",
            rating=4.5, is_recommended=False,
        ),
        POIResponse(
            poi_id="sh-009", name="新天地", category="购物", sub_category="商圈",
            longitude=121.4747, latitude=31.2194,
            address="上海市黄浦区太仓路181弄",
            ai_summary="石库门建筑改造典范，将老上海弄堂改造为时尚餐饮零售空间。白天休闲漫步，晚上社交聚会。",
            rating=4.3, is_recommended=False,
        ),
        POIResponse(
            poi_id="sh-010", name="甜爱路", category="景点", sub_category="文化",
            longitude=121.4797, latitude=31.2676,
            address="上海市虹口区甜爱路",
            ai_summary="上海最浪漫的小马路，围墙上刻满情诗。只有500米，却是文艺青年必打卡的小众景点。",
            rating=4.2, is_recommended=False,
        ),
    ]

    return success_response({
        "pois": [p.model_dump() for p in mock_pois],
        "clusters": [],
        "total": len(mock_pois),
    })


@router.get("/pois/search", response_model=dict)
async def search_pois(
    q: str = Query(..., min_length=1, max_length=100, description="搜索关键词"),
    category: Optional[str] = Query(None, description="分类筛选"),
    limit: int = Query(20, ge=1, le=50, description="返回数量"),
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    POI 全文搜索

    支持按名称、地址、子分类模糊搜索 POI
    """
    # 获取用户 MBTI
    mbti_type = None
    if user_id:
        from app.services.user_service import UserService
        user_service = UserService(db)
        user = await user_service.get_user_by_id(user_id)
        if user:
            mbti_type = user.mbti_type

    service = MapService(db)
    pois = await service.search_pois(query=q, category=category, mbti_type=mbti_type, limit=limit)

    return success_response({
        "pois": pois,
        "total": len(pois),
    })


@router.get("/pois/bounds", response_model=dict)
async def get_pois_by_bounds(
    min_lon: float = Query(..., ge=-180, le=180),
    max_lon: float = Query(..., ge=-180, le=180),
    min_lat: float = Query(..., ge=-90, le=90),
    max_lat: float = Query(..., ge=-90, le=90),
    zoom_level: int = Query(14, ge=3, le=20),
    category: Optional[str] = Query(None),
    cluster_mode: Optional[str] = Query(None, description="聚类模式: province/grid"),
    selected_province: Optional[str] = Query(None, description="指定省份，返回该省全部POI"),
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    按地图边界查询 POI

    - 传入地图可视区域的四角坐标
    - 返回该区域内的 POI 或聚合点
    """
    bounds = MapBounds(
        min_lon=min_lon,
        max_lon=max_lon,
        min_lat=min_lat,
        max_lat=max_lat
    )

    # 获取用户 MBTI
    mbti_type = None
    if user_id:
        from app.services.user_service import UserService
        user_service = UserService(db)
        user = await user_service.get_user_by_id(user_id)
        if user:
            mbti_type = user.mbti_type

    service = MapService(db)
    pois, clusters = await service.get_pois_by_bounds(
        bounds=bounds,
        zoom_level=zoom_level,
        category=category,
        mbti_type=mbti_type,
        cluster_mode=cluster_mode,
        selected_province=selected_province,
    )

    return success_response({
        "pois": pois,
        "clusters": clusters,
        "total": len(pois) + len(clusters)
    })


@router.get("/pois/{poi_id}", response_model=POIDetailResponse)
async def get_poi_detail(
    poi_id: str,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    获取 POI 详情

    - 包含 AI 生成的摘要
    - 根据用户 MBTI 返回个性化摘要
    - 通过 AI 提炼关键信息要点（Redis 缓存）
    """
    # 获取用户 MBTI
    mbti_type = None
    if user_id:
        from app.services.user_service import UserService
        user_service = UserService(db)
        user = await user_service.get_user_by_id(user_id)
        if user:
            mbti_type = user.mbti_type

    service = MapService(db)
    poi = await service.get_poi_detail(poi_id, mbti_type)

    if not poi:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="POI 不存在"
        )

    # AI 关键信息提炼（Redis 缓存，避免重复调用 LLM）
    raw_summary = poi.ai_summary or ""
    if raw_summary:
        poi.ai_highlights = await _extract_highlights(
            poi_id, poi.name, raw_summary
        )

    return poi


async def _extract_highlights(
    poi_id: str, poi_name: str, raw_summary: str
) -> List[str]:
    """从原始摘要中提炼关键信息要点，结果缓存到 Redis"""
    cache_key = f"poi:highlights:{poi_id}"

    # 1) 尝试读缓存
    try:
        redis_client = await get_redis()
        cached = await redis_client.get(cache_key)
        if cached:
            return json.loads(cached)
    except Exception:
        redis_client = None

    # 2) 调用 LLM 提炼
    try:
        prompt = PromptTemplates.get_summary_highlights_prompt(poi_name, raw_summary)
        llm = LLMClient()
        result = await llm.chat(
            messages=[AIChatMessage(role="user", content=prompt)],
            temperature=0.3,
            max_tokens=300,
        )
        # 解析 JSON 数组
        highlights = json.loads(result.strip().strip("```json").strip("```"))
        if not isinstance(highlights, list):
            highlights = [str(highlights)]
    except Exception as e:
        logger.warning("AI highlights extraction failed for %s: %s", poi_id, e)
        # 降级：按句号拆分原始摘要
        highlights = [s.strip() for s in raw_summary.replace("。", "。\n").split("\n") if s.strip()][:5]

    # 3) 写入缓存（永久，POI 摘要不会频繁变化）
    try:
        if redis_client:
            await redis_client.set(cache_key, json.dumps(highlights, ensure_ascii=False))
    except Exception:
        pass

    return highlights


@router.get("/pois/{poi_id}/posts")
async def get_poi_posts(
    poi_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    """获取 POI 相关的社区动态"""
    from app.services.post_service import PostService

    service = PostService(db)
    posts = await service.get_posts(
        page=page,
        page_size=page_size,
        poi_id=poi_id
    )

    return success_response(posts)


@router.get("/geocode", response_model=dict)
async def geocode(
    address: str = Query(..., min_length=1, max_length=200, description="地点名称或地址"),
):
    """
    地理编码 — 将地名转换为经纬度坐标 (WGS-84)

    优先使用高德 API，降级到 Nominatim (OpenStreetMap)
    """
    from app.core.config import get_settings
    settings = get_settings()

    # 1. 尝试高德地理编码
    if settings.AMAP_API_KEY and settings.AMAP_API_KEY != "your-amap-api-key":
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(
                    "https://restapi.amap.com/v3/geocode/geo",
                    params={"key": settings.AMAP_API_KEY, "address": address},
                )
                data = resp.json()
                if data.get("status") == "1" and data.get("geocodes"):
                    location = data["geocodes"][0]["location"]  # "116.397428,39.90923"
                    lon_str, lat_str = location.split(",")
                    # 高德返回 GCJ-02 坐标，但前端 maplibre_core_view 已内置 WGS84→GCJ02 转换
                    # 这里返回 GCJ-02 坐标并标记坐标系
                    return success_response({
                        "latitude": float(lat_str),
                        "longitude": float(lon_str),
                        "address": data["geocodes"][0].get("formatted_address", address),
                        "crs": "GCJ-02",
                    })
        except Exception as e:
            logger.warning("Amap geocode failed for '%s': %s", address, e)

    # 2. 降级到 Nominatim (OpenStreetMap，WGS-84)
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params={
                    "q": address,
                    "format": "jsonv2",
                    "limit": 1,
                    "accept-language": "zh-CN",
                },
                headers={"User-Agent": "InspireMap/1.0"},
            )
            results = resp.json()
            if results:
                return success_response({
                    "latitude": float(results[0]["lat"]),
                    "longitude": float(results[0]["lon"]),
                    "address": results[0].get("display_name", address),
                    "crs": "WGS-84",
                })
    except Exception as e:
        logger.warning("Nominatim geocode failed for '%s': %s", address, e)

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"无法解析地址: {address}"
    )
