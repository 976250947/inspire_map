"""
《灵感经纬》数据库连接池与依赖注入
PostgreSQL & Redis 连接管理
"""
from typing import AsyncGenerator, Optional
import redis.asyncio as redis
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    create_async_engine,
    async_sessionmaker
)
from sqlalchemy.pool import NullPool

from app.core.config import settings

# PostgreSQL 异步引擎
# connect_args 中禁用 SSL，避免 Windows 本地开发环境 asyncpg SSL 握手失败
engine = create_async_engine(
    str(settings.DATABASE_URL),
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    pool_pre_ping=True,
    echo=settings.DEBUG,
    connect_args={"ssl": False},
)

# 异步会话工厂
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

# Redis 连接池 (延迟初始化)
_redis_pool: Optional[redis.Redis] = None


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    获取数据库会话 (依赖注入用)

    Yields:
        AsyncSession: 数据库异步会话
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def get_db_session() -> AsyncSession:
    """
    直接获取数据库会话 (非依赖注入场景)

    Returns:
        AsyncSession: 数据库异步会话
    """
    return AsyncSessionLocal()


async def init_redis() -> redis.Redis:
    """
    初始化 Redis 连接

    Returns:
        Redis: Redis 客户端实例
    """
    global _redis_pool
    if _redis_pool is None:
        _redis_pool = redis.from_url(
            str(settings.REDIS_URL),
            encoding="utf-8",
            decode_responses=True
        )
    return _redis_pool


async def get_redis() -> redis.Redis:
    """
    获取 Redis 连接 (依赖注入用)

    Returns:
        Redis: Redis 客户端实例
    """
    if _redis_pool is None:
        await init_redis()
    return _redis_pool


async def close_redis():
    """关闭 Redis 连接"""
    global _redis_pool
    if _redis_pool:
        await _redis_pool.close()
        _redis_pool = None


async def init_db():
    """初始化数据库 (创建表)"""
    from app.models.base import Base
    async with engine.begin() as conn:
        # 开发环境自动创建表，生产环境应使用 Alembic
        if settings.ENV == "development":
            await conn.run_sync(Base.metadata.create_all)


async def close_db():
    """关闭数据库连接"""
    await engine.dispose()
