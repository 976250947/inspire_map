"""
Agent _sanitize_messages 单元测试
验证消息清洗逻辑能正确处理 tool 角色和空 content 的 assistant 消息
"""
import pytest
from unittest.mock import MagicMock, AsyncMock

from app.ai_core.agent import TravelAgent


@pytest.fixture
def agent():
    a = TravelAgent.__new__(TravelAgent)
    a.llm = MagicMock()
    a.tool_executor = MagicMock()
    a.tools_schema = []
    return a


class TestSanitizeMessages:
    """验证 _sanitize_messages 不会丢失工具上下文"""

    def test_keeps_normal_messages(self, agent):
        msgs = [
            {"role": "system", "content": "你是旅行助手"},
            {"role": "user", "content": "推荐成都美食"},
        ]
        result = agent._sanitize_messages(msgs)
        assert len(result) == 2
        assert result[0]["role"] == "system"
        assert result[1]["role"] == "user"

    def test_converts_tool_messages_to_assistant(self, agent):
        msgs = [
            {"role": "user", "content": "成都有什么好吃的?"},
            {"role": "assistant", "content": "", "tool_calls": [
                {"function": {"name": "search_community"}}
            ]},
            {"role": "tool", "tool_call_id": "call_1", "content": "找到3条美食评价..."},
        ]
        result = agent._sanitize_messages(msgs)

        # tool 消息应被转为 assistant
        assert result[-1]["role"] == "assistant"
        assert "工具返回结果" in result[-1]["content"]

    def test_preserves_assistant_tool_call_intent(self, agent):
        """assistant 消息 content 为空但有 tool_calls 时不应被丢弃"""
        msgs = [
            {"role": "user", "content": "帮我规划行程"},
            {"role": "assistant", "content": "", "tool_calls": [
                {"function": {"name": "plan_route"}}
            ]},
        ]
        result = agent._sanitize_messages(msgs)

        assert len(result) == 2
        assert "plan_route" in result[1]["content"]

    def test_drops_truly_empty_messages(self, agent):
        msgs = [
            {"role": "user", "content": "hello"},
            {"role": "assistant", "content": ""},
        ]
        result = agent._sanitize_messages(msgs)
        # 空 content 且无 tool_calls → 应被丢弃
        assert len(result) == 1


class TestIsSimpleChat:
    """验证简单闲聊检测"""

    def test_travel_keywords_detected(self):
        assert not TravelAgent._is_simple_chat("成都有什么好吃的")
        assert not TravelAgent._is_simple_chat("帮我规划三天行程")
        assert not TravelAgent._is_simple_chat("这个景点门票多少")

    def test_simple_chat_detected(self):
        assert TravelAgent._is_simple_chat("你好")
        assert TravelAgent._is_simple_chat("谢谢你")
        assert TravelAgent._is_simple_chat("你是谁")
