"""
用户服务层
处理用户登录鉴权、资料管理
"""
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from fastapi import HTTPException, status

from app.models.user import User
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token
)
from app.schemas.user_schema import (
    UserRegisterRequest,
    UserLoginRequest,
    UserUpdateRequest,
    MBTIUpdateRequest,
    UserInfoResponse,
    TokenResponse
)


class UserService:
    """用户业务服务"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register(
        self,
        request: UserRegisterRequest
    ) -> TokenResponse:
        """
        用户注册

        Args:
            request: 注册请求

        Returns:
            登录令牌响应

        Raises:
            HTTPException: 手机号已存在
        """
        # 检查手机号是否已注册
        existing = await self._get_user_by_phone(request.phone)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="手机号已被注册"
            )

        # 创建新用户
        user = User(
            phone=request.phone,
            password_hash=get_password_hash(request.password),
            nickname=request.nickname or f"用户{request.phone[-4:]}"
        )

        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)

        # 生成令牌
        access_token = create_access_token(data={"sub": str(user.id)})

        return TokenResponse(
            access_token=access_token,
            expires_in=60 * 24 * 7 * 60,  # 7天，单位秒
            user=self._to_user_response(user)
        )

    async def login(
        self,
        request: UserLoginRequest
    ) -> TokenResponse:
        """
        用户登录

        Args:
            request: 登录请求

        Returns:
            登录令牌响应

        Raises:
            HTTPException: 手机号或密码错误
        """
        # 查找用户
        user = await self._get_user_by_phone(request.phone)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="手机号或密码错误",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # 验证密码
        if not verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="手机号或密码错误",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # 生成令牌
        access_token = create_access_token(data={"sub": str(user.id)})

        return TokenResponse(
            access_token=access_token,
            expires_in=60 * 24 * 7 * 60,
            user=self._to_user_response(user)
        )

    async def get_user_by_id(
        self,
        user_id: str
    ) -> Optional[UserInfoResponse]:
        """
        根据 ID 获取用户信息

        Args:
            user_id: 用户ID

        Returns:
            用户信息或None
        """
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()

        if not user:
            return None

        return self._to_user_response(user)

    async def update_user(
        self,
        user_id: str,
        request: UserUpdateRequest
    ) -> UserInfoResponse:
        """
        更新用户资料

        Args:
            user_id: 用户ID
            request: 更新请求

        Returns:
            更新后的用户信息
        """
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用户不存在"
            )

        if request.nickname is not None:
            user.nickname = request.nickname
        if request.avatar_url is not None:
            user.avatar_url = request.avatar_url

        await self.db.flush()
        await self.db.refresh(user)

        return self._to_user_response(user)

    async def update_mbti(
        self,
        user_id: str,
        request: MBTIUpdateRequest
    ) -> UserInfoResponse:
        """
        更新用户 MBTI 测试结果

        Args:
            user_id: 用户ID
            request: MBTI更新请求

        Returns:
            更新后的用户信息
        """
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="用户不存在"
            )

        user.mbti_type = request.mbti_type.upper()
        user.mbti_persona = request.mbti_persona
        user.travel_pref_tags = request.travel_pref_tags

        await self.db.flush()
        await self.db.refresh(user)

        return self._to_user_response(user)

    async def _get_user_by_phone(
        self,
        phone: str
    ) -> Optional[User]:
        """根据手机号获取用户"""
        result = await self.db.execute(
            select(User).where(User.phone == phone)
        )
        return result.scalar_one_or_none()

    def _to_user_response(self, user: User) -> UserInfoResponse:
        """转换为响应模型"""
        return UserInfoResponse(
            id=user.id,
            phone=user.phone,
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            mbti_type=user.mbti_type,
            mbti_persona=user.mbti_persona,
            travel_pref_tags=user.travel_pref_tags or [],
            footprint_count=user.footprint_count or "0",
            post_count=user.post_count or "0",
            follower_count=user.follower_count or "0",
            following_count=user.following_count or "0",
            created_at=user.created_at,
            updated_at=user.updated_at
        )
