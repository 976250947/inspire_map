"""Pydantic schemas for structured travel plans."""

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class ChecklistItem(BaseModel):
    """用户可勾选的待办项。"""

    item: str = Field(..., description="待办事项名称")
    checked: bool = Field(default=False, description="是否已完成")


class ChecklistUpdate(BaseModel):
    """更新清单请求。"""

    checklist: list[ChecklistItem]


class RouteStopInput(BaseModel):
    """单个行程节点。"""

    time: str = Field(..., description="时间节点，如 09:00")
    poi_name: str = Field(..., description="地点名称")
    activity: str = Field(..., description="活动描述")
    duration: Optional[str] = Field(None, description="预计停留时长")
    tips: Optional[str] = Field(None, description="实用提示或避坑建议")
    transport_to_next: Optional[str] = Field(None, description="前往下一站的交通建议")


class RouteDayInput(BaseModel):
    """单日行程。"""

    day: int = Field(..., ge=1, description="第几天")
    theme: str = Field(..., description="当日主题")
    summary: Optional[str] = Field(None, description="当日摘要")
    stops: list[RouteStopInput] = Field(default_factory=list)


class TravelPreparationSection(BaseModel):
    """行前准备。"""

    best_season: Optional[str] = Field(None, description="最佳季节与出行提醒")
    long_distance_transport: list[str] = Field(default_factory=list, description="往返交通建议")
    city_transport: list[str] = Field(default_factory=list, description="市内交通建议")
    packing_list: list[str] = Field(default_factory=list, description="随身物品建议")
    documents: list[str] = Field(default_factory=list, description="证件或预订提醒")


class AccommodationSuggestion(BaseModel):
    """住宿建议。"""

    tier: str = Field(..., description="档位，如高档/中档/经济")
    name: str = Field(..., description="住宿名称")
    price_range: Optional[str] = Field(None, description="价格区间")
    highlights: list[str] = Field(default_factory=list, description="亮点说明")


class BudgetItem(BaseModel):
    """预算表单行。"""

    category: str = Field(..., description="预算类别")
    amount_range: str = Field(..., description="预算范围")


class TravelGuideData(BaseModel):
    """完整攻略结构。"""

    summary: Optional[str] = Field(None, description="整份攻略摘要")
    travel_type: Optional[str] = Field(None, description="旅行类型")
    scene: Optional[str] = Field(None, description="识别出的垂直场景")
    style_tags: list[str] = Field(default_factory=list, description="风格标签")
    preparation: TravelPreparationSection = Field(default_factory=TravelPreparationSection)
    accommodation: list[AccommodationSuggestion] = Field(default_factory=list)
    budget: list[BudgetItem] = Field(default_factory=list)
    avoid_tips: list[str] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)


class TravelPlanSaveInput(BaseModel):
    """智能体保存结构化攻略时使用的输入。"""

    title: str = Field(..., description="行程标题")
    city: str = Field(..., description="目的地城市")
    days: int = Field(..., ge=1, le=30)
    itinerary: list[RouteDayInput] = Field(default_factory=list, description="按天拆分的行程")
    checklist: list[str] = Field(default_factory=list, description="待办事项")
    guide_data: TravelGuideData = Field(default_factory=TravelGuideData, description="完整攻略数据")


class TravelPlanResponse(BaseModel):
    """行程详情响应。"""

    plan_id: str
    user_id: str
    title: str
    city: str
    days: int
    itinerary_data: list[RouteDayInput]
    checklist_data: list[ChecklistItem]
    guide_data: TravelGuideData
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class TravelPlanListResponse(BaseModel):
    """行程列表响应。"""

    total: int
    items: list[TravelPlanResponse]


class TravelPlanUpdate(BaseModel):
    """更新行程请求。"""

    title: Optional[str] = None
    itinerary_data: Optional[list[RouteDayInput]] = None
    checklist_data: Optional[list[ChecklistItem]] = None
    guide_data: Optional[TravelGuideData] = None
    status: Optional[str] = None


def normalize_guide_data(raw: Optional[dict[str, Any]]) -> TravelGuideData:
    """将数据库中的 JSON 安全转换为强类型攻略结构。"""

    if not raw:
        return TravelGuideData()
    return TravelGuideData.model_validate(raw)
