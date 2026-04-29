"""
用户相关 Schema (登录/注册的请求与响应体)
"""
from typing import Optional, List
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.base import BaseResponse


# ========== 请求 Schema ==========

class UserRegisterRequest(BaseModel):
    """用户注册请求"""
    phone: str = Field(..., min_length=11, max_length=11, description="手机号")
    password: str = Field(..., min_length=6, max_length=32, description="密码")
    nickname: Optional[str] = Field(None, max_length=50, description="昵称")


class UserLoginRequest(BaseModel):
    """用户登录请求"""
    phone: str = Field(..., description="手机号")
    password: str = Field(..., description="密码")


class UserUpdateRequest(BaseModel):
    """用户资料更新请求"""
    nickname: Optional[str] = Field(None, max_length=50)
    avatar_url: Optional[str] = Field(None, max_length=500)


class MBTIUpdateRequest(BaseModel):
    """MBTI 测试结果更新"""
    mbti_type: str = Field(..., min_length=4, max_length=4, description="如INTJ")
    mbti_persona: str = Field(..., max_length=50, description="旅行人格")
    travel_pref_tags: List[str] = Field(default_factory=list, description="旅行偏好标签")


# ========== 响应 Schema ==========

class UserInfoResponse(BaseResponse):
    """用户信息响应"""
    phone: Optional[str]
    nickname: Optional[str]
    avatar_url: Optional[str]
    mbti_type: Optional[str]
    mbti_persona: Optional[str]
    travel_pref_tags: List[str]
    footprint_count: str
    post_count: str
    follower_count: str
    following_count: str


class UserMinimalResponse(BaseModel):
    """精简用户信息"""
    id: UUID
    nickname: Optional[str]
    avatar_url: Optional[str]
    mbti_type: Optional[str]


class TokenResponse(BaseModel):
    """登录令牌响应"""
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserInfoResponse
