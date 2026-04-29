"""
用户注册/登录服务单元测试
验证注册、登录、密码校验、Token 生成逻辑
"""
import pytest
from unittest.mock import patch
from uuid import uuid4

from fastapi import HTTPException

from app.models.user import User
from app.services.user_service import UserService
from app.schemas.user_schema import (
    UserRegisterRequest,
    UserLoginRequest,
    MBTIUpdateRequest,
)
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    decode_access_token,
    decode_access_token_allow_expired,
)


# ══════════════════════════════════════════
#  密码哈希与 JWT 单元测试
# ══════════════════════════════════════════

class TestPasswordHash:

    def test_hash_and_verify(self):
        """密码哈希后应能正确验证"""
        raw = "test_password_123"
        hashed = get_password_hash(raw)
        assert hashed != raw
        assert verify_password(raw, hashed) is True

    def test_wrong_password_fails(self):
        """错误密码应验证失败"""
        hashed = get_password_hash("correct_password")
        assert verify_password("wrong_password", hashed) is False


class TestJWT:

    def test_create_and_decode_token(self):
        """创建的 Token 应能正确解码"""
        user_id = str(uuid4())
        token = create_access_token(data={"sub": user_id})
        payload = decode_access_token(token)

        assert payload is not None
        assert payload["sub"] == user_id

    def test_invalid_token_returns_none(self):
        """无效 Token 应返回 None"""
        result = decode_access_token("invalid.token.here")
        assert result is None

    def test_decode_allow_expired(self):
        """decode_access_token_allow_expired 应能解码过期 Token"""
        from datetime import timedelta
        user_id = str(uuid4())
        # 创建一个已过期的 Token
        token = create_access_token(
            data={"sub": user_id},
            expires_delta=timedelta(seconds=-10),
        )
        # 标准解码失败
        assert decode_access_token(token) is None
        # 允许过期的解码成功
        payload = decode_access_token_allow_expired(token)
        assert payload is not None
        assert payload["sub"] == user_id


# ══════════════════════════════════════════
#  用户服务层测试
# ══════════════════════════════════════════

@pytest.mark.asyncio
class TestUserRegister:

    async def test_register_success(self, db_session):
        """正常注册应返回 TokenResponse"""
        service = UserService(db_session)
        request = UserRegisterRequest(
            phone="13800000099",
            password="test123456",
            nickname="测试新用户",
        )
        result = await service.register(request)

        assert result.access_token is not None
        assert len(result.access_token) > 0
        assert result.user.phone == "13800000099"
        assert result.user.nickname == "测试新用户"

    async def test_register_duplicate_phone(self, db_session):
        """重复手机号应抛出 400 异常"""
        service = UserService(db_session)
        request = UserRegisterRequest(
            phone="13800000088",
            password="test123456",
        )
        await service.register(request)

        with pytest.raises(HTTPException) as exc_info:
            await service.register(request)
        assert exc_info.value.status_code == 400
        assert "已被注册" in exc_info.value.detail


@pytest.mark.asyncio
class TestUserLogin:

    async def test_login_success(self, db_session):
        """正确手机号密码应登录成功"""
        service = UserService(db_session)
        # 先注册
        await service.register(
            UserRegisterRequest(phone="13800000077", password="mypassword")
        )
        # 再登录
        result = await service.login(
            UserLoginRequest(phone="13800000077", password="mypassword")
        )
        assert result.access_token is not None
        assert result.user.phone == "13800000077"

    async def test_login_wrong_password(self, db_session):
        """错误密码应抛出 401 异常"""
        service = UserService(db_session)
        await service.register(
            UserRegisterRequest(phone="13800000066", password="correct")
        )

        with pytest.raises(HTTPException) as exc_info:
            await service.login(
                UserLoginRequest(phone="13800000066", password="wrong")
            )
        assert exc_info.value.status_code == 401

    async def test_login_nonexistent_phone(self, db_session):
        """不存在的手机号应抛出 401 异常"""
        service = UserService(db_session)
        with pytest.raises(HTTPException) as exc_info:
            await service.login(
                UserLoginRequest(phone="13899999999", password="any")
            )
        assert exc_info.value.status_code == 401


@pytest.mark.asyncio
class TestMBTIUpdate:

    async def test_update_mbti(self, db_session):
        """更新 MBTI 应正确保存"""
        service = UserService(db_session)
        reg = await service.register(
            UserRegisterRequest(phone="13800000055", password="test123456")
        )
        user_id = str(reg.user.id)

        result = await service.update_mbti(
            user_id,
            MBTIUpdateRequest(
                mbti_type="INTJ",
                mbti_persona="城市观察者",
                travel_pref_tags=["喜欢安静", "探索未知"],
            ),
        )
        assert result.mbti_type == "INTJ"
        assert result.mbti_persona == "城市观察者"
        assert "喜欢安静" in result.travel_pref_tags
