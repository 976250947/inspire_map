"""
缓存工具类
Redis 缓存装饰器和辅助函数
"""
import json
import hashlib
import functools
from typing import Optional, Any

from app.core.db_deps import get_redis


async def get_cache(key: str) -> Optional[Any]:
    """
    获取缓存值

    Args:
        key: 缓存键

    Returns:
        缓存值或None
    """
    try:
        redis = await get_redis()
        value = await redis.get(key)
    except Exception:
        return None
    if value:
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value
    return None


async def set_cache(
    key: str,
    value: Any,
    ttl: int = 3600
) -> bool:
    """
    设置缓存

    Args:
        key: 缓存键
        value: 缓存值
        ttl: 过期时间 (秒)

    Returns:
        是否成功
    """
    try:
        redis = await get_redis()
        if isinstance(value, (dict, list)):
            value = json.dumps(value, ensure_ascii=False)
        await redis.setex(key, ttl, value)
        return True
    except Exception:
        return False


async def delete_cache(key: str) -> bool:
    """删除缓存"""
    try:
        redis = await get_redis()
        await redis.delete(key)
        return True
    except Exception:
        return False


def generate_cache_key(prefix: str, *args, **kwargs) -> str:
    """
    生成缓存键

    Args:
        prefix: 前缀
        *args: 位置参数
        **kwargs: 关键字参数

    Returns:
        缓存键
    """
    key_data = {
        "args": args,
        "kwargs": kwargs
    }
    key_str = json.dumps(key_data, sort_keys=True, default=str)
    hash_val = hashlib.md5(key_str.encode()).hexdigest()
    return f"{prefix}:{hash_val}"


def cached(prefix: str, ttl: int = 3600):
    """
    缓存装饰器

    Args:
        prefix: 缓存键前缀
        ttl: 过期时间

    Usage:
        @cached("user_info", ttl=3600)
        async def get_user_info(user_id: str):
            ...
    """
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            # 生成缓存键 (排除 db 等不可序列化参数)
            cache_args = [a for a in args if not hasattr(a, 'execute')]
            cache_kwargs = {k: v for k, v in kwargs.items() if not hasattr(v, 'execute')}

            key = generate_cache_key(prefix, *cache_args, **cache_kwargs)

            # 尝试获取缓存
            cached_val = await get_cache(key)
            if cached_val is not None:
                return cached_val

            # 执行原函数
            result = await func(*args, **kwargs)

            # 写入缓存
            await set_cache(key, result, ttl)

            return result

        return wrapper
    return decorator


async def invalidate_pattern(pattern: str) -> int:
    """
    批量删除匹配模式的缓存

    Args:
        pattern: 匹配模式 (如 "user:*")

    Returns:
        删除数量
    """
    try:
        redis = await get_redis()
        keys = await redis.keys(pattern)
        if keys:
            return await redis.delete(*keys)
        return 0
    except Exception:
        return 0
