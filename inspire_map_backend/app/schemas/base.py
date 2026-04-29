"""
Pydantic 基础 Schema
"""
from datetime import datetime
from typing import Any, Generic, Optional, TypeVar
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BaseSchema(BaseModel):
    """基础 Schema"""
    model_config = ConfigDict(from_attributes=True)


class BaseResponse(BaseSchema):
    """基础响应"""
    id: UUID
    created_at: datetime
    updated_at: datetime


class PaginationParams(BaseSchema):
    """分页参数"""
    page: int = 1
    page_size: int = 20


class PaginatedResponse(BaseSchema):
    """分页响应"""
    total: int
    page: int
    page_size: int
    pages: int


T = TypeVar("T")


class StandardResponse(BaseModel, Generic[T]):
    """
    统一 API 响应格式

    所有非流式 API 必须使用此结构包裹返回值:
    {"code": 200, "message": "success", "data": {...}}
    """
    code: int = 200
    message: str = "success"
    data: T


def success_response(data: Any = None, message: str = "success") -> dict:
    """快捷构建统一成功响应"""
    return {"code": 200, "message": message, "data": data}


def error_response(code: int = 400, message: str = "error", data: Any = None) -> dict:
    """快捷构建统一错误响应"""
    return {"code": code, "message": message, "data": data}
