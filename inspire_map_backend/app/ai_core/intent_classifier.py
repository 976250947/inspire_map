"""
意图分类器 — LLM 驱动的场景识别与工具路由

每次新对话第一轮进行一次轻量 classification call（~100 tokens），
后续轮次复用已缓存的分类结果。

降级策略：LLM 调用失败时退化到关键词匹配。
"""
import json
import logging
from enum import Enum
from typing import Optional, Dict, Any

from app.ai_core.llm_client import LLMClient
from app.schemas.ai_schema import AIChatMessage

logger = logging.getLogger(__name__)


class TravelIntent(str, Enum):
    """旅行意图枚举"""
    # ── 垂直场景 ──
    FAMILY_TRIP = "family_trip"        # 亲子/家庭出游
    COUPLE_TRIP = "couple_trip"        # 情侣/蜜月
    SOLO_TRIP = "solo_trip"            # 独自旅行/背包客
    BUSINESS_TRIP = "business_trip"    # 商务出行
    ELDERLY_TRIP = "elderly_trip"      # 银发族/老年游
    GENERAL_TRIP = "general_trip"      # 通用旅行（未明确场景）

    # ── 功能意图 ──
    PLAN_ROUTE = "plan_route"          # 行程规划
    POI_QUERY = "poi_query"            # 景点查询
    FOOD_QUERY = "food_query"          # 美食推荐
    TRANSPORT_QUERY = "transport"      # 交通查询
    ACCOMMODATION_QUERY = "accommodation"  # 住宿查询
    REALTIME_QUERY = "realtime"        # 旅途中即时查询（附近/当下）
    JOURNAL_ASSIST = "journal"         # 游记整理
    SIMPLE_CHAT = "simple_chat"        # 闲聊


# 分类器 System Prompt — 极度精简以控制 tokens
_CLASSIFIER_SYSTEM_PROMPT = """你是一个意图分类器。根据用户消息，判断旅行场景和功能意图。

直接返回 JSON，无任何多余文字：
{"scene": "场景", "intent": "意图", "needs_more_info": true/false}

scene 可选值：family_trip, couple_trip, solo_trip, business_trip, elderly_trip, general_trip, unknown
intent 可选值：plan_route, poi_query, food_query, transport, accommodation, realtime, journal, simple_chat
needs_more_info：用户是否缺少关键信息（目的地、天数、出行人群等）"""


class IntentClassifier:
    """
    LLM 驱动的意图分类器

    使用极低 temperature + max_tokens 限制，
    单次分类调用约 100 tokens（成本 ≈ ¥0.0001）
    """

    def __init__(self, llm: Optional[LLMClient] = None):
        self.llm = llm or LLMClient()

    async def classify(
        self,
        message: str,
        context: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        对用户消息进行意图分类

        Args:
            message: 用户消息
            context: 可选上下文（如当前 POI 名称、用户画像摘要）

        Returns:
            {
                "scene": TravelIntent 场景值,
                "intent": TravelIntent 功能意图值,
                "needs_more_info": bool
            }
        """
        try:
            return await self._llm_classify(message, context)
        except Exception as e:
            logger.warning(f"LLM 意图分类失败，降级到关键词: {e}")
            return self._keyword_fallback(message)

    async def _llm_classify(
        self,
        message: str,
        context: Optional[str] = None
    ) -> Dict[str, Any]:
        """LLM 驱动的分类"""
        user_content = message
        if context:
            user_content = f"[上下文]{context}\n[用户消息]{message}"

        messages = [
            AIChatMessage(role="system", content=_CLASSIFIER_SYSTEM_PROMPT),
            AIChatMessage(role="user", content=user_content),
        ]

        response = await self.llm.chat(
            messages=messages,
            temperature=0.0,
            max_tokens=100,
        )

        # 从响应中提取 JSON
        result = self._parse_classification(response)
        logger.info(f"意图分类结果: scene={result['scene']}, "
                    f"intent={result['intent']}, "
                    f"needs_more_info={result['needs_more_info']}")
        return result

    @staticmethod
    def _parse_classification(response: str) -> Dict[str, Any]:
        """
        解析 LLM 返回的分类 JSON

        支持从混合文本中提取 JSON 块
        """
        # 尝试直接解析
        text = response.strip()
        try:
            data = json.loads(text)
            return _normalize_result(data)
        except json.JSONDecodeError:
            pass

        # 尝试提取 JSON 块
        import re
        json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
        if json_match:
            try:
                data = json.loads(json_match.group())
                return _normalize_result(data)
            except json.JSONDecodeError:
                pass

        # 解析失败，返回默认值
        logger.warning(f"意图分类 JSON 解析失败: {text[:200]}")
        return {
            "scene": TravelIntent.GENERAL_TRIP.value,
            "intent": TravelIntent.SIMPLE_CHAT.value,
            "needs_more_info": True,
        }

    @staticmethod
    def _keyword_fallback(message: str) -> Dict[str, Any]:
        """
        降级方案：基于关键词进行意图分类
        当 LLM 不可用时使用
        """
        msg = message.lower()

        # ── 场景识别 ──
        scene = TravelIntent.GENERAL_TRIP.value
        if any(kw in msg for kw in ["孩子", "小孩", "宝宝", "亲子", "带娃", "儿童"]):
            scene = TravelIntent.FAMILY_TRIP.value
        elif any(kw in msg for kw in ["老婆", "男友", "女友", "情侣", "蜜月", "求婚", "纪念日"]):
            scene = TravelIntent.COUPLE_TRIP.value
        elif any(kw in msg for kw in ["一个人", "独行", "独自", "背包", "穷游"]):
            scene = TravelIntent.SOLO_TRIP.value
        elif any(kw in msg for kw in ["出差", "商务", "会议", "客户"]):
            scene = TravelIntent.BUSINESS_TRIP.value
        elif any(kw in msg for kw in ["爸妈", "父母", "老人", "爷爷", "奶奶", "银发"]):
            scene = TravelIntent.ELDERLY_TRIP.value

        # ── 功能意图 ──
        intent = TravelIntent.SIMPLE_CHAT.value
        if any(kw in msg for kw in ["行程", "规划", "路线", "安排", "几天", "计划"]):
            intent = TravelIntent.PLAN_ROUTE.value
        elif any(kw in msg for kw in ["景点", "好玩", "值得去", "门票", "开放时间"]):
            intent = TravelIntent.POI_QUERY.value
        elif any(kw in msg for kw in ["吃", "美食", "餐厅", "小吃", "特色菜"]):
            intent = TravelIntent.FOOD_QUERY.value
        elif any(kw in msg for kw in ["交通", "怎么去", "地铁", "高铁", "飞机"]):
            intent = TravelIntent.TRANSPORT_QUERY.value
        elif any(kw in msg for kw in ["住", "酒店", "民宿", "住宿"]):
            intent = TravelIntent.ACCOMMODATION_QUERY.value
        elif any(kw in msg for kw in ["附近", "周边", "这里"]):
            intent = TravelIntent.REALTIME_QUERY.value
        elif any(kw in msg for kw in ["游记", "记录", "总结旅行"]):
            intent = TravelIntent.JOURNAL_ASSIST.value

        # 判断信息是否充足
        has_destination = any(kw in msg for kw in ["去", "到", "飞", "玩"])
        needs_more = intent != TravelIntent.SIMPLE_CHAT.value and not has_destination

        return {
            "scene": scene,
            "intent": intent,
            "needs_more_info": needs_more,
        }


def _normalize_result(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    标准化分类结果，确保字段存在且值合法
    """
    valid_scenes = {e.value for e in TravelIntent}

    scene = data.get("scene", "general_trip")
    if scene not in valid_scenes and scene != "unknown":
        scene = "general_trip"

    intent = data.get("intent", "simple_chat")
    if intent not in valid_scenes:
        intent = "simple_chat"

    return {
        "scene": scene,
        "intent": intent,
        "needs_more_info": bool(data.get("needs_more_info", True)),
    }
