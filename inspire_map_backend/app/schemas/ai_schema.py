"""
AI 相关 Schema
AI 返回的结构化 JSON 格式定义
"""
from typing import Any, Optional, List, Union
from enum import Enum
from pydantic import BaseModel, Field, field_validator


class RouteQueryType(str, Enum):
    """行程查询类型"""
    DAY_TRIP = "day_trip"           # 一日游
    MULTI_DAY = "multi_day"         # 多日游
    FOOD_TOUR = "food_tour"         # 美食之旅
    CULTURAL = "cultural"           # 文化深度游
    RELAXING = "relaxing"           # 休闲度假


class RouteStop(BaseModel):
    """行程单站"""
    time: str = Field(..., description="建议时间如'09:00'")
    poi_name: str = Field(..., description="地点名称")
    poi_id: Optional[str] = Field(None, description="POI ID")
    duration: str = Field(..., description="建议停留时长")
    activity: str = Field(..., description="活动内容")
    tips: Optional[str] = Field(None, description="温馨提示/避坑")
    transport_to_next: Optional[str] = Field(None, description="前往下一点的交通")


class RouteDay(BaseModel):
    """单日行程"""
    day: int = Field(..., ge=1, le=30)
    theme: str = Field(..., description="当日主题")
    stops: List[RouteStop]


class RoutePlanResponse(BaseModel):
    """结构化行程规划响应"""
    city: str = Field(..., description="目的地城市")
    days: int = Field(..., ge=1, le=30)
    mbti_match: str = Field(..., description="针对该MBTI的行程特色")
    routes: List[RouteDay]
    budget_estimate: Optional[str] = Field(None, description="预算估算")
    packing_tips: Optional[List[str]] = Field(None, description="携带建议")


class AIChatMessage(BaseModel):
    """AI 聊天消息"""
    role: str = Field(..., description="user/assistant/system")
    content: str
    timestamp: Optional[str] = None


class AIChatRequest(BaseModel):
    """AI 对话请求"""
    message: str = Field(..., min_length=1, max_length=2000)
    conversation_id: Optional[str] = None
    longitude: Optional[float] = None
    latitude: Optional[float] = None
    current_poi_id: Optional[str] = None
    mbti_type: Optional[str] = Field(None, description="用户MBTI类型")
    history: Optional[List[AIChatMessage]] = Field(None, description="历史对话记录")


class AIPlanRouteRequest(BaseModel):
    """AI 规划行程请求"""
    city: str = Field(..., description="目的地城市")
    days: int = Field(..., ge=1, le=7)
    mbti_type: Optional[str] = None
    preferences: List[str] = Field(default_factory=list)
    budget_level: Optional[str] = Field(None, description="budget_low/medium/high")
    avoid_crowds: bool = Field(False, description="是否避开人群")
    pace: Optional[str] = Field(None, description="悠闲/适中/紧凑")

    @field_validator("preferences", mode="before")
    @classmethod
    def _coerce_preferences(cls, v: Union[str, List[str], None]) -> List[str]:
        """兼容前端传入逗号分隔字符串的情况"""
        if v is None:
            return []
        if isinstance(v, str):
            return [s.strip() for s in v.split(",") if s.strip()]
        return v


class AIPOIQueryRequest(BaseModel):
    """AI POI 问答请求"""
    poi_id: str
    question: str = Field(..., min_length=1, max_length=500)
    mbti_type: Optional[str] = None


class AIConfirmPlanSaveRequest(BaseModel):
    """确认将 AI 生成的攻略写入“我的行程”."""

    plan_data: dict[str, Any] = Field(..., description="前端确认后的结构化攻略 JSON")
    plan_id: Optional[str] = Field(None, description="如果是修改已有行程，可传入已有 plan_id")


class AIStreamChunk(BaseModel):
    """AI 流式响应块 (SSE 格式)"""
    type: str = Field(..., description="chunk/route_complete/error")
    content: str
    is_complete: bool = False
    conversation_id: Optional[str] = None
