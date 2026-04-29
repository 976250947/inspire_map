"""
AI 服务层单元测试
验证 query_poi_with_rag 的缓存逻辑、LLM Mock、
plan_route SSE 流式输出、chat Agent 流式输出、内容审核
"""
import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from app.services.ai_service import AIService
from app.schemas.ai_schema import AIPlanRouteRequest, AIChatRequest


@pytest.mark.asyncio
class TestQueryPOIWithRAG:
    """验证 RAG POI 问答"""

    async def test_returns_cached_result(self, db_session, mock_redis):
        """当缓存命中时应直接返回，不调用 LLM"""
        mock_redis.get = AsyncMock(return_value="缓存的回答")

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.ENABLE_AI_CACHE = True

            service = AIService(db_session, redis=mock_redis)
            result = await service.query_poi_with_rag(
                poi_id="test-poi-1",
                question="这个地方好玩吗"
            )

            assert result == "缓存的回答"

    async def test_calls_llm_when_no_cache(self, db_session, mock_redis, mock_llm_client):
        """缓存未命中时应调用 LLM 并写入缓存"""
        mock_redis.get = AsyncMock(return_value=None)

        with patch("app.core.config.settings") as mock_settings, \
             patch("app.ai_core.rag_engine.RAGEngine") as MockRAG:
            mock_settings.ENABLE_AI_CACHE = True
            mock_settings.AI_CACHE_TTL = 3600

            # Mock RAG 返回空上下文
            rag_instance = MockRAG.return_value
            rag_instance.retrieve_poi_context = AsyncMock(return_value="")

            service = AIService(db_session, redis=mock_redis)
            service.llm = mock_llm_client

            # Mock POI 详情
            service.map_service.get_poi_detail = AsyncMock(return_value=MagicMock(
                name="测试景点",
                category="景点",
                ai_summary="这是一个测试景点"
            ))

            result = await service.query_poi_with_rag(
                poi_id="test-poi-1",
                question="这个地方好玩吗"
            )

            assert result == "这是一条模拟的 AI 回答。"
            mock_llm_client.chat.assert_called_once()
            mock_redis.setex.assert_called_once()

    async def test_works_without_redis(self, db_session, mock_llm_client):
        """Redis 不可用时应正常工作（无缓存降级）"""
        with patch("app.ai_core.rag_engine.RAGEngine") as MockRAG:
            rag_instance = MockRAG.return_value
            rag_instance.retrieve_poi_context = AsyncMock(return_value="")

            service = AIService(db_session, redis=None)
            service.llm = mock_llm_client
            service.map_service.get_poi_detail = AsyncMock(return_value=MagicMock(
                name="测试景点",
                category="景点",
                ai_summary=None
            ))

            result = await service.query_poi_with_rag(
                poi_id="test-poi-1",
                question="推荐一下"
            )

            assert isinstance(result, str)
            assert len(result) > 0


@pytest.mark.asyncio
class TestPlanRouteStream:
    """验证行程规划 SSE 流式输出"""

    async def test_stream_yields_chunks_and_complete(self, db_session, mock_redis, mock_llm_client):
        """流式输出应产生 chunk + complete 事件"""
        mock_redis.get = AsyncMock(return_value=None)

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.ENABLE_AI_CACHE = True
            mock_settings.AI_CACHE_TTL = 3600

            service = AIService(db_session, redis=mock_redis)
            service.llm = mock_llm_client

            request = AIPlanRouteRequest(city="成都", days=3)

            chunks = []
            async for sse_line in service.plan_route(request, stream=True):
                chunks.append(sse_line)

            # 至少有 chunk 事件 + complete 事件
            assert len(chunks) >= 2

            # 最后一个事件应为 complete
            last_data = json.loads(chunks[-1].replace("data: ", "").strip())
            assert last_data["type"] == "complete"

            # 之前的事件应为 chunk
            first_data = json.loads(chunks[0].replace("data: ", "").strip())
            assert first_data["type"] == "chunk"
            assert "content" in first_data

    async def test_stream_returns_cached(self, db_session, mock_redis):
        """有缓存时应模拟流式返回缓存内容"""
        mock_redis.get = AsyncMock(return_value="缓存的行程规划 JSON")

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.ENABLE_AI_CACHE = True

            service = AIService(db_session, redis=mock_redis)
            request = AIPlanRouteRequest(city="北京", days=2)

            chunks = []
            async for sse_line in service.plan_route(request, stream=True):
                chunks.append(sse_line)

            assert len(chunks) >= 1
            # complete 事件
            last_data = json.loads(chunks[-1].replace("data: ", "").strip())
            assert last_data["type"] == "complete"

    async def test_stream_error_yields_error_event(self, db_session, mock_redis):
        """LLM 调用失败时应产生 error 事件"""
        mock_redis.get = AsyncMock(return_value=None)

        async def _exploding_stream(messages):
            raise RuntimeError("LLM 连接超时")
            yield  # noqa: unreachable — 使此函数成为 async generator

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.ENABLE_AI_CACHE = True

            service = AIService(db_session, redis=mock_redis)
            service.llm = MagicMock()
            service.llm.chat_stream = _exploding_stream

            request = AIPlanRouteRequest(city="成都", days=3)

            chunks = []
            async for sse_line in service.plan_route(request, stream=True):
                chunks.append(sse_line)

            assert len(chunks) >= 1
            error_data = json.loads(chunks[0].replace("data: ", "").strip())
            assert error_data["type"] == "error"
            assert error_data["is_complete"] is True


@pytest.mark.asyncio
class TestChatStream:
    """验证 AI 自由对话 SSE 流式输出"""

    async def test_chat_yields_chunks(self, db_session, mock_redis):
        """chat 方法应产生流式 chunk 事件"""
        mock_redis.get = AsyncMock(return_value=None)

        async def mock_agent_stream(**kwargs):
            for text in ["你好", "，", "旅行者"]:
                yield text

        with patch("app.core.config.settings") as mock_settings, \
             patch("app.ai_core.agent.TravelAgent") as MockAgent:
            mock_settings.ENABLE_AI_CACHE = True
            mock_settings.AI_CACHE_TTL = 3600

            agent_instance = MockAgent.return_value
            agent_instance.chat_stream = mock_agent_stream

            service = AIService(db_session, redis=mock_redis)

            request = AIChatRequest(message="你好")

            chunks = []
            async for sse_line in service.chat(request):
                chunks.append(sse_line)

            # 3 个 chunk + 1 个 complete
            assert len(chunks) == 4

            # 验证内容拼接
            contents = []
            for c in chunks[:-1]:
                data = json.loads(c.replace("data: ", "").strip())
                contents.append(data["content"])
            assert "".join(contents) == "你好，旅行者"

            # 验证缓存写入
            mock_redis.setex.assert_called_once()

    async def test_chat_cached_returns_simulated_stream(self, db_session, mock_redis):
        """缓存命中时应模拟流式返回"""
        mock_redis.get = AsyncMock(return_value="这是缓存的回答。")

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.ENABLE_AI_CACHE = True

            service = AIService(db_session, redis=mock_redis)
            request = AIChatRequest(message="你好")

            chunks = []
            async for sse_line in service.chat(request):
                chunks.append(sse_line)

            # 应有模拟 chunk + complete
            assert len(chunks) >= 2
            last = json.loads(chunks[-1].replace("data: ", "").strip())
            assert last["type"] == "complete"


@pytest.mark.asyncio
class TestContentModeration:
    """验证内容审核"""

    async def test_moderation_disabled(self, db_session):
        """审核禁用时应直接通过"""
        with patch("app.core.config.settings") as mock_settings:
            mock_settings.CONTENT_AUDIT_ENABLED = False

            service = AIService(db_session, redis=None)
            result = await service.moderate_content("测试内容")

            assert result["passed"] is True

    async def test_moderation_parses_json(self, db_session, mock_llm_client):
        """审核应正确解析 LLM 返回的 JSON 结果"""
        mock_llm_client.chat = AsyncMock(
            return_value='{"passed": true, "reason": "内容合规", "sensitivity_score": 5}'
        )

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.CONTENT_AUDIT_ENABLED = True

            service = AIService(db_session, redis=None)
            service.llm = mock_llm_client

            result = await service.moderate_content("一段正常的旅行分享")

            assert result["passed"] is True
            assert result["sensitivity_score"] == 5

    async def test_moderation_handles_malformed_json(self, db_session, mock_llm_client):
        """LLM 返回非 JSON 时应保守拒绝"""
        mock_llm_client.chat = AsyncMock(return_value="这条内容没问题")

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.CONTENT_AUDIT_ENABLED = True

            service = AIService(db_session, redis=None)
            service.llm = mock_llm_client

            result = await service.moderate_content("测试")

            assert result["passed"] is False

    async def test_moderation_handles_exception(self, db_session, mock_llm_client):
        """LLM 调用异常时应保守拒绝"""
        mock_llm_client.chat = AsyncMock(side_effect=RuntimeError("API down"))

        with patch("app.core.config.settings") as mock_settings:
            mock_settings.CONTENT_AUDIT_ENABLED = True

            service = AIService(db_session, redis=None)
            service.llm = mock_llm_client

            result = await service.moderate_content("测试")

            assert result["passed"] is False
            assert result["sensitivity_score"] == 100
