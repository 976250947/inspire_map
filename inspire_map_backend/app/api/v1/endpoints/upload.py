"""
文件上传 API
POST /api/v1/upload/image — 上传单张图片，返回 URL
"""
import os
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from app.core.security import get_current_user_id
from app.schemas.base import success_response

router = APIRouter()

# 允许的图片 MIME 类型
_ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
# 最大文件大小 5MB
_MAX_SIZE = 5 * 1024 * 1024
# 上传存储根目录（生产环境应使用云存储）
_UPLOAD_DIR = Path("uploads/images")


@router.post("/image")
async def upload_image(
    file: UploadFile = File(..., description="图片文件 (JPEG/PNG/WebP/GIF, ≤5MB)"),
    user_id: str = Depends(get_current_user_id),
):
    """
    上传单张图片

    - 校验类型和大小
    - 存储到本地 uploads/ 目录（生产环境应替换为 OSS/S3）
    - 返回可访问的 URL
    """
    # 校验 MIME 类型
    if file.content_type not in _ALLOWED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"不支持的文件类型: {file.content_type}，仅支持 JPEG/PNG/WebP/GIF",
        )

    # 读取文件内容并校验大小
    content = await file.read()
    if len(content) > _MAX_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"文件大小超过限制 ({len(content) // 1024}KB > {_MAX_SIZE // 1024}KB)",
        )

    # 生成安全的唯一文件名（不使用原始文件名，防止路径穿越）
    ext_map = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/gif": ".gif",
    }
    ext = ext_map.get(file.content_type, ".jpg")
    date_prefix = datetime.now().strftime("%Y%m%d")
    safe_filename = f"{date_prefix}_{user_id[:8]}_{uuid.uuid4().hex[:12]}{ext}"

    # 确保目录存在
    save_dir = _UPLOAD_DIR / date_prefix
    save_dir.mkdir(parents=True, exist_ok=True)

    # 写入文件
    save_path = save_dir / safe_filename
    with open(save_path, "wb") as f:
        f.write(content)

    # 返回相对 URL（前端拼接 base_url 访问）
    url = f"/uploads/images/{date_prefix}/{safe_filename}"

    return success_response({"url": url, "filename": safe_filename}, message="上传成功")
