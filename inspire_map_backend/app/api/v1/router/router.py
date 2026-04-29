"""
API v1 路由统合
整合所有端点
"""
from fastapi import APIRouter

from app.api.v1.endpoints import map, ai, post, user, social, tiles, upload, plan

api_router = APIRouter()

# 用户相关
api_router.include_router(
    user.router,
    prefix="/users",
    tags=["用户"]
)

# 地图相关
api_router.include_router(
    map.router,
    prefix="/map",
    tags=["地图"]
)

# AI 相关
api_router.include_router(
    ai.router,
    prefix="/ai",
    tags=["AI伴游"]
)

# 社区动态/足迹相关
api_router.include_router(
    post.router,
    prefix="/posts",
    tags=["社区"]
)

# 社交关系相关
api_router.include_router(
    social.router,
    prefix="/social",
    tags=["社交"]
)

# 文件上传
api_router.include_router(
    upload.router,
    prefix="/upload",
    tags=["文件上传"]
)

# 瓦片代理（供模拟器/弱网环境使用）
api_router.include_router(
    tiles.router,
    tags=["瓦片代理"]
)

# 行程规划
api_router.include_router(
    plan.router,
    prefix="/plans",
    tags=["行程规划"]
)
