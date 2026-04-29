"""
conftest.py — pytest 全局 fixture
提供异步数据库会话、Mock Redis 等公共测试基础设施
"""
import asyncio
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from app.models.base import Base


# 使用 SQLite 内存库替代 PostgreSQL，避免测试依赖外部服务
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def db_session():
    """提供一个干净的异步数据库会话（每个测试用例独立）"""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with session_factory() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest.fixture
def mock_redis():
    """Mock Redis 客户端"""
    redis = AsyncMock()
    redis.get = AsyncMock(return_value=None)
    redis.setex = AsyncMock(return_value=True)
    return redis


@pytest.fixture
def mock_llm_client():
    """Mock LLM 客户端（绝不消耗真实 Token）"""
    client = MagicMock()
    client.chat = AsyncMock(return_value="这是一条模拟的 AI 回答。")
    client.chat_stream = MagicMock(return_value=_async_gen(["这是", "一条", "模拟回答。"]))
    client._get_default_model = MagicMock(return_value="mock-model")
    return client


async def _async_gen(items):
    for item in items:
        yield item
