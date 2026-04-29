"""
《灵感经纬》全局配置
读取环境变量 (.env) 中的配置项
"""
import secrets
from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings
from pydantic import PostgresDsn, RedisDsn


class Settings(BaseSettings):
    """应用配置类"""

    # 基础配置
    PROJECT_NAME: str = "灵感经纬"
    PROJECT_VERSION: str = "1.0.0"
    PROJECT_DESCRIPTION: str = "基于大模型与地图交互的智能伴游社区"

    # 环境配置
    ENV: str = "development"
    DEBUG: bool = True

    # 服务器配置
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # 数据库配置
    DATABASE_URL: PostgresDsn = "postgresql+asyncpg://postgres:postgres@localhost:5432/inspire_map"
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 10

    # Redis 配置
    REDIS_URL: RedisDsn = "redis://localhost:6379/0"
    REDIS_CACHE_TTL: int = 604800  # 7天缓存

    # JWT 安全配置
    # 如未在 .env 中设置，每次启动随机生成（重启后旧 Token 失效）
    SECRET_KEY: str = secrets.token_hex(32)
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7天

    # AI 大模型配置
    LLM_PROVIDER: str = "deepseek"  # deepseek / qwen
    DEEPSEEK_API_KEY: Optional[str] = None
    DEEPSEEK_API_BASE: str = "https://api.deepseek.com"
    QWEN_API_KEY: Optional[str] = None
    QWEN_API_BASE: str = "https://dashscope.aliyuncs.com/api/v1"

    # AI 请求降本配置
    ENABLE_AI_CACHE: bool = True
    AI_CACHE_TTL: int = 604800  # 7天
    MAX_AI_CONTEXT_ROUNDS: int = 5

    # 向量数据库配置
    CHROMA_PERSIST_DIRECTORY: str = "./chroma_db"
    EMBEDDING_MODEL: str = "sentence-transformers/all-MiniLM-L6-v2"

    # 高德地图配置
    AMAP_API_KEY: Optional[str] = None
    AMAP_API_SECRET: Optional[str] = None

    # 内容安全
    CONTENT_AUDIT_ENABLED: bool = True

    # CORS 配置
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080,http://localhost:5000"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """获取缓存的配置实例"""
    return Settings()


settings = get_settings()
