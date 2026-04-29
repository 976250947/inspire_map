"""
《灵感经纬》FastAPI 启动入口
"""
import sys
import asyncio
import traceback

# Windows 上 Python 3.12 默认使用 ProactorEventLoop，与 asyncpg 不兼容
# 必须在任何 asyncpg/SQLAlchemy 导入之前切换到 SelectorEventLoop
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

# 添加项目路径
sys.path.append(".")

from app.core.config import settings
from app.core.db_deps import init_db, close_db, close_redis
from app.api.v1.router.router import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    应用生命周期管理
    """
    # 启动时执行
    print(f"🚀 启动 {settings.PROJECT_NAME}...")

    # 安全检查：SECRET_KEY 未通过 .env 显式设置时发出警告
    _insecure_defaults = {"your-secret-key-change-this-in-production", "change-in-production"}
    if settings.SECRET_KEY in _insecure_defaults:
        print("⚠️  警告: SECRET_KEY 为不安全的默认值，请在 .env 中设置强密钥！")
    elif len(settings.SECRET_KEY) < 32:
        print("⚠️  警告: SECRET_KEY 长度不足 32 字符，建议使用更长的密钥")

    await init_db()
    print("✅ 数据库初始化完成")

    yield

    # 关闭时执行
    print("🛑 正在关闭服务...")
    await close_db()
    await close_redis()
    print("✅ 服务已关闭")


# 创建 FastAPI 应用
app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.PROJECT_VERSION,
    lifespan=lifespan
)

# 注册速率限制
from app.core.rate_limit import limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# 配置 CORS
cors_origins = [o.strip() for o in settings.CORS_ORIGINS.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册结构化请求日志中间件
from app.core.logging_middleware import RequestLoggingMiddleware
app.add_middleware(RequestLoggingMiddleware)

# 注册 API 路由
app.include_router(
    api_router,
    prefix="/api/v1"
)

# 挂载静态文件目录（图片上传）
import os
_upload_dir = os.path.join(os.path.dirname(__file__), "uploads", "images")
os.makedirs(_upload_dir, exist_ok=True)
app.mount("/uploads/images", StaticFiles(directory=_upload_dir), name="uploaded_images")


# 全局异常处理：捕获未处理的 500 错误并打印详情
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """全局异常处理，打印完整错误堆栈"""
    tb = traceback.format_exception(type(exc), exc, exc.__traceback__)
    print(f"🔥 未处理异常 [{request.method} {request.url.path}]:")
    print("".join(tb))
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc)},
    )


@app.get("/")
async def root():
    """根路由 - 服务状态检查"""
    return {
        "name": settings.PROJECT_NAME,
        "version": settings.PROJECT_VERSION,
        "status": "running",
        "docs": "/docs"
    }


@app.get("/health")
async def health_check():
    """健康检查接口"""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info"
    )
