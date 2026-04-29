"""
用户相关 API
GET /api/v1/users/me
POST /api/v1/users/register
POST /api/v1/users/login
POST /api/v1/users/oauth/{provider}
PUT /api/v1/users/mbti
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_deps import get_db
from app.core.security import (
    get_current_user_id,
    decode_access_token_allow_expired,
    create_access_token,
    security,
)
from app.services.user_service import UserService
from app.schemas.user_schema import (
    UserRegisterRequest,
    UserLoginRequest,
    UserUpdateRequest,
    MBTIUpdateRequest,
    UserInfoResponse,
    TokenResponse
)

router = APIRouter()


@router.post("/refresh-token", response_model=TokenResponse)
async def refresh_token(
    credentials=Depends(security),
    db: AsyncSession = Depends(get_db)
):
    """
    刷新 JWT Token

    用现有 Token（可已过期）换取新 Token。
    Token 签名必须有效，仅跳过过期检查。
    """
    token = credentials.credentials
    payload = decode_access_token_allow_expired(token)

    if payload is None or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证凭据",
        )

    user_id = payload["sub"]
    service = UserService(db)
    user = await service.get_user_by_id(user_id)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在",
        )

    new_token = create_access_token(data={"sub": user_id})

    return TokenResponse(
        access_token=new_token,
        expires_in=60 * 24 * 7 * 60,
        user=user,
    )


@router.post("/register", response_model=TokenResponse)
async def register(
    request: UserRegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    用户注册

    - phone: 手机号 (11位)
    - password: 密码 (6-32位)
    - nickname: 昵称 (可选)
    """
    service = UserService(db)
    return await service.register(request)


@router.post("/login", response_model=TokenResponse)
async def login(
    request: UserLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    用户登录

    - phone: 手机号
    - password: 密码
    """
    service = UserService(db)
    return await service.login(request)


@router.get("/me", response_model=UserInfoResponse)
async def get_current_user(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取当前登录用户信息"""
    service = UserService(db)
    user = await service.get_user_by_id(user_id)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )

    return user


@router.put("/me", response_model=UserInfoResponse)
async def update_user(
    request: UserUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """更新当前用户信息"""
    service = UserService(db)
    return await service.update_user(user_id, request)


@router.put("/mbti", response_model=UserInfoResponse)
async def update_mbti(
    request: MBTIUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    更新 MBTI 测试结果

    - mbti_type: MBTI类型 (如 INTJ)
    - mbti_persona: 旅行人格 (如 "城市观察者")
    - travel_pref_tags: 旅行偏好标签列表
    """
    service = UserService(db)
    return await service.update_mbti(user_id, request)


@router.get("/{user_id}", response_model=UserInfoResponse)
async def get_user_by_id(
    user_id: str,
    db: AsyncSession = Depends(get_db)
):
    """根据 ID 获取用户信息"""
    service = UserService(db)
    user = await service.get_user_by_id(user_id)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )

    return user


# ========== 第三方登录 ==========

class OAuthRequest(BaseModel):
    """第三方登录请求"""
    code: str
    state: str | None = None

_SUPPORTED_PROVIDERS = {"wechat", "qq"}


@router.post("/oauth/{provider}", response_model=TokenResponse)
async def oauth_login(
    provider: str,
    request: OAuthRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    第三方 OAuth 登录

    - provider: 登录渠道 (wechat / qq)
    - code: OAuth 授权码
    - state: CSRF 防护 state (可选)

    流程：前端拉起第三方授权 → 获取 code → 传给此接口 → 后端换取用户信息 → 自动注册/登录
    """
    if provider not in _SUPPORTED_PROVIDERS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"不支持的登录方式: {provider}，仅支持 {', '.join(_SUPPORTED_PROVIDERS)}"
        )

    # TODO: 实际接入第三方 OAuth SDK
    # 1. 使用 code 向第三方服务器换取 access_token
    # 2. 使用 access_token 获取用户 openid / unionid
    # 3. 查询或创建用户
    # 4. 签发 JWT Token
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail=f"{provider} 登录接口正在接入中，请使用手机号登录"
    )
