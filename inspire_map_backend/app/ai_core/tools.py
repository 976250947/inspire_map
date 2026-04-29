"""Function-calling tool definitions for the travel agent."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class ToolParameter:
    """Schema for a single tool parameter."""

    name: str
    type: str
    description: str
    required: bool = True
    enum: Optional[List[str]] = None


@dataclass
class ToolDefinition:
    """OpenAI-compatible tool definition."""

    name: str
    description: str
    parameters: List[ToolParameter] = field(default_factory=list)

    def to_openai_tool(self) -> dict:
        properties: Dict[str, Any] = {}
        required: list[str] = []
        for parameter in self.parameters:
            value: Dict[str, Any] = {"type": parameter.type, "description": parameter.description}
            if parameter.enum:
                value["enum"] = parameter.enum
            properties[parameter.name] = value
            if parameter.required:
                required.append(parameter.name)

        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": {
                    "type": "object",
                    "properties": properties,
                    "required": required,
                },
            },
        }


TOOL_SEARCH_COMMUNITY = ToolDefinition(
    name="search_community",
    description="检索社区旅行经验、避坑、排队和本地玩法。",
    parameters=[
        ToolParameter(name="query", type="string", description="检索关键词"),
        ToolParameter(name="poi_id", type="string", description="POI ID", required=False),
    ],
)

TOOL_GET_POI_DETAIL = ToolDefinition(
    name="get_poi_detail",
    description="获取景点、餐厅或地点的详细信息。",
    parameters=[
        ToolParameter(name="poi_name", type="string", description="地点名称"),
    ],
)

TOOL_PLAN_ROUTE = ToolDefinition(
    name="plan_route",
    description="生成多日行程草案。",
    parameters=[
        ToolParameter(name="city", type="string", description="目的地城市"),
        ToolParameter(name="days", type="integer", description="旅行天数"),
        ToolParameter(name="preferences", type="string", description="偏好标签，逗号分隔", required=False),
    ],
)

TOOL_SEARCH_NEARBY = ToolDefinition(
    name="search_nearby",
    description="搜索某个地点附近的景点、美食、住宿等。",
    parameters=[
        ToolParameter(name="location", type="string", description="参考地点或城市"),
        ToolParameter(
            name="category",
            type="string",
            description="搜索类别",
            required=False,
            enum=["景点", "美食", "住宿", "咖啡", "夜生活", "自然", "人文"],
        ),
    ],
)

TOOL_GET_TRANSPORT = ToolDefinition(
    name="get_transport_info",
    description="获取前往某地的交通建议。",
    parameters=[
        ToolParameter(name="destination", type="string", description="目的地"),
        ToolParameter(name="origin", type="string", description="出发地", required=False),
    ],
)

TOOL_GET_FOOD_RECOMMEND = ToolDefinition(
    name="get_food_recommendation",
    description="获取美食推荐。",
    parameters=[
        ToolParameter(name="location", type="string", description="地点或城市"),
        ToolParameter(name="food_type", type="string", description="美食类型", required=False),
    ],
)

TOOL_GET_ACCOMMODATION = ToolDefinition(
    name="get_accommodation_info",
    description="获取住宿推荐。",
    parameters=[
        ToolParameter(name="location", type="string", description="地点或城市"),
        ToolParameter(name="style", type="string", description="住宿风格", required=False),
    ],
)

TOOL_GET_USER_PROFILE = ToolDefinition(
    name="get_user_profile",
    description="获取当前用户画像与旅行偏好。",
    parameters=[],
)

TOOL_SAVE_TRAVEL_PLAN = ToolDefinition(
    name="save_travel_plan",
    description="将结构化旅行攻略保存到用户的我的行程页。",
    parameters=[
        ToolParameter(name="title", type="string", description="行程标题"),
        ToolParameter(name="city", type="string", description="目的地城市"),
        ToolParameter(name="days", type="integer", description="行程天数"),
        ToolParameter(name="itinerary", type="array", description="按天拆分的 itinerary 列表"),
        ToolParameter(name="checklist", type="array", description="待办清单字符串数组"),
        ToolParameter(name="guide_data", type="object", description="完整攻略结构数据", required=False),
        ToolParameter(name="plan_id", type="string", description="已有行程 ID，用于覆盖更新", required=False),
    ],
)

ALL_TOOLS = [
    TOOL_SEARCH_COMMUNITY,
    TOOL_GET_POI_DETAIL,
    TOOL_PLAN_ROUTE,
    TOOL_SEARCH_NEARBY,
    TOOL_GET_TRANSPORT,
    TOOL_GET_FOOD_RECOMMEND,
    TOOL_GET_ACCOMMODATION,
    TOOL_GET_USER_PROFILE,
    TOOL_SAVE_TRAVEL_PLAN,
]


def get_all_tools_openai_format() -> List[dict]:
    """Return all tools in OpenAI function-calling format."""

    return [tool.to_openai_tool() for tool in ALL_TOOLS]


def get_tools_by_names(names: List[str]) -> List[dict]:
    """Return only the tools whose names are requested."""

    wanted = set(names)
    return [tool.to_openai_tool() for tool in ALL_TOOLS if tool.name in wanted]
