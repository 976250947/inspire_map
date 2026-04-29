"""
社交关系相关 API
POST /api/v1/social/follow
DELETE /api/v1/social/follow/{user_id}
GET /api/v1/social/followers/{user_id}
GET /api/v1/social/following/{user_id}
"""
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, delete

from app.core.db_deps import get_db
from app.core.security import get_current_user_id
from app.models.user import User
from app.models.social import UserFollow
from app.schemas.user_schema import UserMinimalResponse
from app.schemas.base import success_response

router = APIRouter()


@router.post("/follow/{user_id}", status_code=status.HTTP_201_CREATED)
async def follow_user(
    user_id: str,
    follower_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    关注用户

    - user_id: 要关注的用户ID
    """
    # 不能关注自己
    if user_id == follower_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="不能关注自己"
        )

    # 检查目标用户是否存在
    target = await db.execute(select(User).where(User.id == user_id))
    if not target.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )

    # 检查是否已关注
    existing = await db.execute(
        select(UserFollow).where(
            UserFollow.follower_id == follower_id,
            UserFollow.following_id == user_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="已经关注过了"
        )

    # 创建关注关系
    follow = UserFollow(follower_id=follower_id, following_id=user_id)
    db.add(follow)

    # 更新被关注者的粉丝数
    target_user = await db.execute(select(User).where(User.id == user_id))
    user = target_user.scalar_one_or_none()
    if user:
        user.follower_count = str(int(user.follower_count or "0") + 1)

    # 更新关注者的关注数
    current_user = await db.execute(select(User).where(User.id == follower_id))
    me = current_user.scalar_one_or_none()
    if me:
        me.following_count = str(int(me.following_count or "0") + 1)

    await db.flush()

    return success_response({"followed": True}, message="关注成功")


@router.delete("/follow/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unfollow_user(
    user_id: str,
    follower_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    取消关注

    - user_id: 要取消关注的用户ID
    """
    result = await db.execute(
        select(UserFollow).where(
            UserFollow.follower_id == follower_id,
            UserFollow.following_id == user_id
        )
    )
    follow = result.scalar_one_or_none()

    if not follow:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="未关注该用户"
        )

    await db.execute(
        delete(UserFollow).where(UserFollow.id == follow.id)
    )

    # 更新被关注者的粉丝数
    target_user = await db.execute(select(User).where(User.id == user_id))
    user = target_user.scalar_one_or_none()
    if user:
        user.follower_count = str(max(0, int(user.follower_count or "0") - 1))

    # 更新关注者的关注数
    current_user = await db.execute(select(User).where(User.id == follower_id))
    me = current_user.scalar_one_or_none()
    if me:
        me.following_count = str(max(0, int(me.following_count or "0") - 1))

    await db.flush()
    return None


@router.get("/followers/{user_id}", response_model=List[UserMinimalResponse])
async def get_followers(
    user_id: str,
    page: int = 1,
    page_size: int = 20,
    db: AsyncSession = Depends(get_db)
):
    """
    获取用户的粉丝列表
    """
    offset = (page - 1) * page_size
    result = await db.execute(
        select(UserFollow)
        .where(UserFollow.following_id == user_id)
        .offset(offset)
        .limit(page_size)
    )
    follows = result.scalars().all()

    responses = []
    for follow in follows:
        user_result = await db.execute(select(User).where(User.id == follow.follower_id))
        user = user_result.scalar_one_or_none()
        if user:
            responses.append(UserMinimalResponse(
                id=user.id,
                nickname=user.nickname,
                avatar_url=user.avatar_url,
                mbti_type=user.mbti_type
            ))

    return responses


@router.get("/following/{user_id}", response_model=List[UserMinimalResponse])
async def get_following(
    user_id: str,
    page: int = 1,
    page_size: int = 20,
    db: AsyncSession = Depends(get_db)
):
    """
    获取用户关注列表
    """
    offset = (page - 1) * page_size
    result = await db.execute(
        select(UserFollow)
        .where(UserFollow.follower_id == user_id)
        .offset(offset)
        .limit(page_size)
    )
    follows = result.scalars().all()

    responses = []
    for follow in follows:
        user_result = await db.execute(select(User).where(User.id == follow.following_id))
        user = user_result.scalar_one_or_none()
        if user:
            responses.append(UserMinimalResponse(
                id=user.id,
                nickname=user.nickname,
                avatar_url=user.avatar_url,
                mbti_type=user.mbti_type
            ))

    return responses


@router.get("/is-following/{user_id}")
async def check_is_following(
    user_id: str,
    follower_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """检查当前用户是否关注了指定用户"""
    result = await db.execute(
        select(UserFollow).where(
            UserFollow.follower_id == follower_id,
            UserFollow.following_id == user_id
        )
    )
    is_following = result.scalar_one_or_none() is not None
    return success_response({"is_following": is_following})
