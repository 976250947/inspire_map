"""
社区动态/足迹相关 API

注意：足迹相关路由必须放在 /{post_id} 之前定义，
否则 FastAPI 会把 /footprints/stats 的 "footprints" 当作 post_id 匹配到 /{post_id}
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, Query, HTTPException, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_deps import get_db
from app.core.security import get_current_user_id, get_optional_user_id
from app.services.post_service import PostService
from app.schemas.post_schema import (
    PostCreateRequest,
    PostUpdateRequest,
    PostResponse,
    PostListResponse,
    FootprintCreateRequest,
    FootprintResponse,
    FootprintStatsResponse,
    CommentCreateRequest,
    CommentResponse,
    CommentListResponse
)

router = APIRouter()


# ========== 动态相关 ==========

@router.post("/publish", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def publish_post(
    request: PostCreateRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    发布动态

    - poi_id: 关联的POI ID (可选)
    - content: 内容 (1-2000字)
    - images: 图片URL列表
    - longitude/latitude: 位置坐标 (可选)
    - tags: 标签列表
    """
    service = PostService(db)
    return await service.create_post(user_id, request, background_tasks)


@router.get("", response_model=PostListResponse)
async def get_posts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    poi_id: Optional[str] = Query(None, description="筛选特定POI的动态"),
    user_id: Optional[str] = Query(None, description="筛选特定用户的动态"),
    current_user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    获取动态列表

    - 支持分页
    - 支持按 POI 或用户筛选
    - 已登录时返回 is_liked 状态
    """
    service = PostService(db)
    return await service.get_posts(
        page=page,
        page_size=page_size,
        poi_id=poi_id,
        user_id=user_id,
        current_user_id=current_user_id
    )


# ========== 足迹相关（必须在 /{post_id} 之前）==========

@router.post("/footprints", response_model=FootprintResponse, status_code=status.HTTP_201_CREATED)
async def create_footprint(
    request: FootprintCreateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    创建足迹打卡

    - poi_id: POI ID (可选)
    - longitude/latitude: 打卡坐标
    - province/city: 省市（可选，不填则自动从 POI 表补全）
    - check_in_note: 打卡留言 (可选)
    - images: 打卡图片
    """
    service = PostService(db)
    return await service.create_footprint(user_id, request)


@router.get("/footprints/my", response_model=List[FootprintResponse])
async def get_my_footprints(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取我的足迹列表"""
    service = PostService(db)
    return await service.get_footprints(user_id, page, page_size)


@router.get("/footprints/stats", response_model=FootprintStatsResponse)
async def get_footprint_stats(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取足迹统计"""
    service = PostService(db)
    return await service.get_footprint_stats(user_id)


# ========== 用户相关（必须在 /{post_id} 之后）==========

@router.get("/users/{user_id}/posts", response_model=PostListResponse)
async def get_user_posts(
    user_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    """获取特定用户的动态列表"""
    service = PostService(db)
    return await service.get_posts(
        page=page,
        page_size=page_size,
        user_id=user_id
    )


# ========== 动态详情（/{post_id} 必须放在所有 /footprints/* 和 /users/* 之后）==========

@router.get("/{post_id}", response_model=PostResponse)
async def get_post(
    post_id: str,
    current_user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取单条动态详情"""
    service = PostService(db)
    post = await service.get_post_by_id(post_id, current_user_id=current_user_id)

    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="动态不存在"
        )

    return post


@router.put("/{post_id}", response_model=PostResponse)
async def update_post(
    post_id: str,
    request: PostUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """更新动态"""
    service = PostService(db)
    return await service.update_post(post_id, user_id, request)


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(
    post_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """删除动态"""
    service = PostService(db)
    await service.delete_post(post_id, user_id)
    return None


# ========== 点赞相关 ==========

@router.post("/{post_id}/like", status_code=status.HTTP_200_OK)
async def like_post(
    post_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """点赞动态"""
    service = PostService(db)
    success = await service.like_post(user_id, post_id)
    return {"code": 200, "message": "点赞成功" if success else "已点赞", "data": {"liked": True}}


@router.delete("/{post_id}/like", status_code=status.HTTP_200_OK)
async def unlike_post(
    post_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """取消点赞"""
    service = PostService(db)
    success = await service.unlike_post(user_id, post_id)
    return {"code": 200, "message": "已取消点赞" if success else "未曾点赞", "data": {"liked": False}}


# ========== 评论相关 ==========

@router.post("/{post_id}/comments", response_model=CommentResponse, status_code=status.HTTP_201_CREATED)
async def create_comment(
    post_id: str,
    request: CommentCreateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    发表评论

    - content: 评论内容 (1-500字)
    - parent_id: 父评论ID（回复某条评论时填写，可选）
    """
    service = PostService(db)
    return await service.create_comment(user_id, post_id, request)


@router.get("/{post_id}/comments", response_model=CommentListResponse)
async def get_comments(
    post_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db)
):
    """获取动态的评论列表"""
    service = PostService(db)
    return await service.get_comments(post_id, page, page_size)


@router.delete("/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_comment(
    comment_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """删除评论（仅评论作者本人可删）"""
    service = PostService(db)
    await service.delete_comment(comment_id, user_id)
    return None
