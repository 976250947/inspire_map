"""
地图相关 Schema
"""
from typing import Optional, List
from pydantic import BaseModel, Field


class POIListRequest(BaseModel):
    """POI 列表查询请求"""
    longitude: float = Field(..., ge=-180, le=180, description="中心经度")
    latitude: float = Field(..., ge=-90, le=90, description="中心纬度")
    radius: int = Field(5000, ge=100, le=50000, description="半径(米)")
    category: Optional[str] = Field(None, description="分类筛选")
    zoom_level: int = Field(14, ge=3, le=20, description="地图缩放级别")
    mbti_type: Optional[str] = Field(None, description="用户MBTI类型用于加权")
    cluster_mode: Optional[str] = Field(None, description="聚类模式: province/grid")
    selected_province: Optional[str] = Field(None, description="指定省份，返回该省全部POI")


class POIResponse(BaseModel):
    """POI 响应"""
    poi_id: str
    name: str
    category: str
    sub_category: Optional[str]
    longitude: float
    latitude: float
    address: Optional[str]
    ai_summary: Optional[str] = Field(None, description="AI摘要")
    rating: float
    is_recommended: bool = Field(False, description="是否个性化推荐")


class POIDetailResponse(POIResponse):
    """POI 详情响应"""
    best_visit_time: Optional[str]
    tips: List[str]
    ai_summary_mbti: Optional[str] = Field(None, description="针对用户MBTI的AI摘要")
    ai_highlights: List[str] = Field(default_factory=list, description="AI提炼的关键信息要点")


class POIClusterResponse(BaseModel):
    """POI 聚合响应 (用于缩小地图时聚合显示)"""
    cluster_id: str
    longitude: float
    latitude: float
    count: int = Field(..., description="聚合的POI数量")
    top_category: Optional[str] = Field(None, description="该聚合中最多的分类")
    province: Optional[str] = Field(None, description="省份名称（省级聚类模式）")
    is_cluster: bool = True


class MapBounds(BaseModel):
    """地图边界"""
    min_lon: float
    max_lon: float
    min_lat: float
    max_lat: float


class POIQueryByBounds(BaseModel):
    """按地图边界查询POI"""
    bounds: MapBounds
    zoom_level: int = Field(14, ge=3, le=20)
    category: Optional[str] = None
    mbti_type: Optional[str] = None
