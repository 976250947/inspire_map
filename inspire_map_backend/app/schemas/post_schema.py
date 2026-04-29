"""
社区动态/足迹相关 Schema
"""
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field

from app.schemas.base import BaseResponse
from app.schemas.user_schema import UserMinimalResponse


# ========== 动态发布 ==========

class PostCreateRequest(BaseModel):
    """发布动态请求"""
    poi_id: Optional[str] = Field(None, description="关联的POI ID")
    content: str = Field(..., min_length=1, max_length=2000, description="内容")
    images: List[str] = Field(default_factory=list, description="图片URL列表")
    longitude: Optional[float] = Field(None, description="经度")
    latitude: Optional[float] = Field(None, description="纬度")
    tags: List[str] = Field(default_factory=list, description="标签")


class PostUpdateRequest(BaseModel):
    """更新动态请求"""
    content: Optional[str] = Field(None, max_length=2000)
    images: Optional[List[str]] = None
    tags: Optional[List[str]] = None


# ========== 响应 Schema ==========

class PostResponse(BaseResponse):
    """动态响应"""
    author: UserMinimalResponse
    poi_id: Optional[str]
    poi_name: Optional[str] = None
    content: str
    images: List[str]
    tags: List[str]
    longitude: Optional[float]
    latitude: Optional[float]
    like_count: int
    comment_count: int
    is_liked: bool = False


class PostListResponse(BaseModel):
    """动态列表响应"""
    posts: List[PostResponse]
    total: int


# ========== 足迹相关 ==========

class FootprintCreateRequest(BaseModel):
    """创建足迹请求"""
    poi_id: Optional[str] = Field(None, description="POI ID")
    longitude: float = Field(..., ge=-180, le=180)
    latitude: float = Field(..., ge=-90, le=90)
    province: Optional[str] = Field(None, max_length=50, description="省份")
    city: Optional[str] = Field(None, max_length=50, description="城市")
    check_in_note: Optional[str] = Field(None, max_length=500)
    images: List[str] = Field(default_factory=list)


class FootprintResponse(BaseResponse):
    """足迹响应"""
    poi_id: Optional[str]
    poi_name: Optional[str]
    longitude: float
    latitude: float
    province: Optional[str]
    city: Optional[str]
    check_in_note: Optional[str]
    images: List[str]


class FootprintStatsResponse(BaseModel):
    """足迹统计响应"""
    total_footprints: int
    total_cities: int
    total_provinces: int
    footprint_map: dict  # 省份-数量映射


# ========== 评论相关 ==========

class CommentCreateRequest(BaseModel):
    """创建评论请求"""
    content: str = Field(..., min_length=1, max_length=500, description="评论内容")
    parent_id: Optional[str] = Field(None, description="父评论ID（回复时填写）")


class CommentResponse(BaseResponse):
    """评论响应"""
    user: UserMinimalResponse
    post_id: str
    content: str
    parent_id: Optional[str] = None


class CommentListResponse(BaseModel):
    """评论列表响应"""
    comments: List[CommentResponse]
    total: int
