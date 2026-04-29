"""
Agent 对话状态管理 (Conversation Memory)

使用 Redis Hash 持久化 Agent 的多轮对话状态，
支持 SKILL.md 定义的 "偏好采集→检索→生成→迭代优化" 四阶段工作流。

TTL = 2 小时（7200 秒），超时后状态自动清除。
"""
import json
import time
import uuid
import logging
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Dict, Any

logger = logging.getLogger(__name__)

# 对话状态默认 TTL（秒）
MEMORY_TTL = 7200  # 2 小时


class WorkflowPhase:
    """Agent 工作流阶段常量"""
    COLLECTING = "collecting"   # 正在采集用户偏好
    PLANNING = "planning"       # 信息充足，正在调用工具生成攻略
    ITERATING = "iterating"     # 攻略已生成，进入迭代优化模式
    CHATTING = "chatting"       # 自由对话（非行程规划）


# 对话消息历史的最大保留轮次（每轮 = 1 user + 1 assistant）
MAX_HISTORY_TURNS = 10


@dataclass
class AgentState:
    """
    Agent 对话状态

    Attributes:
        conversation_id: 会话 ID
        intent: 识别的功能意图
        scene: 垂直场景（family_trip / couple_trip / ...）
        workflow_phase: 当前工作流阶段
        collected_info: 已采集的偏好信息
        user_profile: 用户画像（MBTI、旅行风格等）
        tool_results_summary: 最近的工具调用结果摘要（避免重复检索）
        generated_plan: 已生成的行程方案（用于迭代修改）
        conversation_messages: 实际对话消息记录 [{"role": "user/assistant", "content": "..."}]
        message_count: 对话轮次计数
        created_at: 创建时间戳
    """
    conversation_id: str = ""
    intent: Optional[str] = None
    scene: Optional[str] = None
    workflow_phase: str = WorkflowPhase.COLLECTING
    collected_info: Dict[str, Any] = field(default_factory=dict)
    user_profile: Dict[str, Any] = field(default_factory=dict)
    tool_results_summary: List[str] = field(default_factory=list)
    generated_plan: Optional[str] = None
    conversation_messages: List[Dict[str, str]] = field(default_factory=list)
    message_count: int = 0
    created_at: float = 0.0

    def add_message(self, role: str, content: str) -> None:
        """
        追加一条对话消息到历史记录

        自动截断超出 MAX_HISTORY_TURNS 的旧消息（保留最近 N 轮）
        """
        self.conversation_messages.append({"role": role, "content": content})
        # 保留最近 MAX_HISTORY_TURNS 轮（每轮 2 条）
        max_messages = MAX_HISTORY_TURNS * 2
        if len(self.conversation_messages) > max_messages:
            self.conversation_messages = self.conversation_messages[-max_messages:]

    def is_info_sufficient(self) -> bool:
        """
        判断偏好信息是否充足，可以进入规划阶段

        必须项：destination（目的地）
        至少有一项：days（天数）或 companions（出行人群）
        """
        info = self.collected_info
        has_destination = bool(info.get("destination"))
        has_secondary = bool(info.get("days")) or bool(info.get("companions"))
        return has_destination and has_secondary

    def get_missing_info_hints(self) -> List[str]:
        """
        获取缺失信息的提示列表，用于指导 Agent 追问

        Returns:
            缺失的关键信息名称列表
        """
        info = self.collected_info
        missing: List[str] = []
        if not info.get("destination"):
            missing.append("目的地")
        if not info.get("days"):
            missing.append("出行天数")
        if not info.get("companions"):
            missing.append("出行人群（和谁一起去）")
# 模块级全局字典，用于在 Redis 不可用时保持单例内存缓存
# 防止因每次请求创建新 ConversationMemory 实例导致依赖回退策略时数据全部丢失
_global_local_cache: Dict[str, AgentState] = {}


class ConversationMemory:
    """
    基于 Redis 的对话状态管理器

    每个 conversation_id 对应一个 AgentState，
    存储为 Redis Hash，自动续期 TTL。
    """

    def __init__(self, redis=None):
        """
        Args:
            redis: aioredis 客户端实例（None 时降级为内存存储）
        """
        self.redis = redis
        # 降级用的内存缓存（Redis 不可用时），现在指向模块级全局字典
        self._local_cache: Dict[str, AgentState] = _global_local_cache

    def _redis_key(self, conversation_id: str) -> str:
        """生成 Redis Key"""
        return f"agent:conv:{conversation_id}"

    async def get_state(self, conversation_id: str) -> AgentState:
        """
        获取对话状态，不存在则创建新状态

        Args:
            conversation_id: 会话 ID

        Returns:
            AgentState 对象
        """
        if not conversation_id:
            # 无 conversation_id，创建临时状态
            return AgentState(
                conversation_id=str(uuid.uuid4()),
                created_at=time.time(),
            )

        if self.redis:
            try:
                return await self._get_from_redis(conversation_id)
            except Exception as e:
                logger.warning(f"Redis 读取对话状态失败: {e}，降级到内存")

        # 降级：内存缓存
        if conversation_id in self._local_cache:
            return self._local_cache[conversation_id]

        state = AgentState(
            conversation_id=conversation_id,
            created_at=time.time(),
        )
        self._local_cache[conversation_id] = state
        return state

    async def save_state(self, state: AgentState) -> None:
        """
        保存对话状态到 Redis（自动续期 TTL）

        Args:
            state: 要保存的 AgentState
        """
        if self.redis:
            try:
                await self._save_to_redis(state)
                return
            except Exception as e:
                logger.warning(f"Redis 保存对话状态失败: {e}，降级到内存")

        # 降级：内存缓存
        self._local_cache[state.conversation_id] = state

    async def update_state(
        self,
        conversation_id: str,
        **kwargs: Any
    ) -> AgentState:
        """
        部分更新对话状态

        Args:
            conversation_id: 会话 ID
            **kwargs: 要更新的字段

        Returns:
            更新后的 AgentState
        """
        state = await self.get_state(conversation_id)

        for key, value in kwargs.items():
            if hasattr(state, key):
                setattr(state, key, value)

        await self.save_state(state)
        return state

    async def increment_message_count(self, conversation_id: str) -> int:
        """
        增加消息计数

        Returns:
            更新后的消息计数
        """
        state = await self.get_state(conversation_id)
        state.message_count += 1
        await self.save_state(state)
        return state.message_count

    async def _get_from_redis(self, conversation_id: str) -> AgentState:
        """从 Redis Hash 恢复 AgentState"""
        key = self._redis_key(conversation_id)
        data = await self.redis.hgetall(key)

        if not data:
            state = AgentState(
                conversation_id=conversation_id,
                created_at=time.time(),
            )
            await self._save_to_redis(state)
            return state

        # Redis 返回的都是字符串，需要反序列化
        conv_msgs_raw = data.get("conversation_messages", "[]")
        conv_msgs = _json_loads(conv_msgs_raw)
        if not isinstance(conv_msgs, list):
            conv_msgs = []

        return AgentState(
            conversation_id=_str(data.get("conversation_id", conversation_id)),
            intent=_str_or_none(data.get("intent")),
            scene=_str_or_none(data.get("scene")),
            workflow_phase=_str(data.get("workflow_phase", WorkflowPhase.COLLECTING)),
            collected_info=_json_loads(data.get("collected_info", "{}")),
            user_profile=_json_loads(data.get("user_profile", "{}")),
            tool_results_summary=_json_loads(data.get("tool_results_summary", "[]")),
            generated_plan=_str_or_none(data.get("generated_plan")),
            conversation_messages=conv_msgs,
            message_count=int(data.get("message_count", 0)),
            created_at=float(data.get("created_at", time.time())),
        )

    async def _save_to_redis(self, state: AgentState) -> None:
        """将 AgentState 序列化存入 Redis Hash"""
        key = self._redis_key(state.conversation_id)

        # 序列化复杂字段为 JSON 字符串
        mapping = {
            "conversation_id": state.conversation_id,
            "intent": state.intent or "",
            "scene": state.scene or "",
            "workflow_phase": state.workflow_phase,
            "collected_info": json.dumps(state.collected_info, ensure_ascii=False),
            "user_profile": json.dumps(state.user_profile, ensure_ascii=False),
            "tool_results_summary": json.dumps(state.tool_results_summary, ensure_ascii=False),
            "generated_plan": state.generated_plan or "",
            "conversation_messages": json.dumps(state.conversation_messages, ensure_ascii=False),
            "message_count": str(state.message_count),
            "created_at": str(state.created_at),
        }

        await self.redis.hset(key, mapping=mapping)
        await self.redis.expire(key, MEMORY_TTL)


# ═══════════════════════════════════════════════════
#  辅助函数
# ═══════════════════════════════════════════════════

def _str(val: Any) -> str:
    """安全转换为 str（兼容 bytes）"""
    if isinstance(val, bytes):
        return val.decode("utf-8")
    return str(val) if val is not None else ""


def _str_or_none(val: Any) -> Optional[str]:
    """转换为 str 或 None"""
    s = _str(val)
    return s if s else None


def _json_loads(val: Any) -> Any:
    """安全地解析 JSON 字符串"""
    s = _str(val)
    if not s:
        return {}
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        return {}
