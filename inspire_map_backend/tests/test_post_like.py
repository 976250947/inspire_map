"""
帖子点赞服务单元测试
验证点赞/取消点赞/防重复点赞逻辑
"""
import pytest
import pytest_asyncio
from uuid import uuid4
from unittest.mock import patch, MagicMock

from app.models.content import UserPost
from app.models.user import User
from app.services.post_service import PostService


@pytest_asyncio.fixture
async def seed_data(db_session):
    """创建测试用户和帖子"""
    user = User(
        id=str(uuid4()),
        nickname="测试用户",
        phone="13800000001",
        password_hash="$2b$12$fake",
    )
    db_session.add(user)
    await db_session.flush()

    post = UserPost(
        id=str(uuid4()),
        author_id=user.id,
        content="这是一条测试动态",
        like_count=0,
        comment_count=0,
        tags=[],
        images=[],
    )
    db_session.add(post)
    await db_session.flush()
    await db_session.refresh(post)

    return user, post


@pytest.mark.asyncio
class TestLikePost:

    async def test_like_increments_count(self, db_session, seed_data):
        """点赞应将 like_count +1"""
        user, post = seed_data
        with patch("app.services.post_service.RAGEngine", MagicMock()):
            service = PostService(db_session)
            result = await service.like_post(user.id, str(post.id))
        assert result is True

        await db_session.refresh(post)
        assert post.like_count == 1

    async def test_duplicate_like_returns_false(self, db_session, seed_data):
        """重复点赞应返回 False，不重复计数"""
        user, post = seed_data
        with patch("app.services.post_service.RAGEngine", MagicMock()):
            service = PostService(db_session)
            await service.like_post(user.id, str(post.id))
            result = await service.like_post(user.id, str(post.id))
        assert result is False

        await db_session.refresh(post)
        assert post.like_count == 1

    async def test_unlike_decrements_count(self, db_session, seed_data):
        """取消点赞应将 like_count -1"""
        user, post = seed_data
        with patch("app.services.post_service.RAGEngine", MagicMock()):
            service = PostService(db_session)
            await service.like_post(user.id, str(post.id))
            result = await service.unlike_post(user.id, str(post.id))
        assert result is True

        await db_session.refresh(post)
        assert post.like_count == 0

    async def test_unlike_without_like_returns_false(self, db_session, seed_data):
        """未曾点赞时取消应返回 False"""
        user, post = seed_data
        with patch("app.services.post_service.RAGEngine", MagicMock()):
            service = PostService(db_session)
            result = await service.unlike_post(user.id, str(post.id))
        assert result is False

    async def test_is_liked(self, db_session, seed_data):
        """is_liked 应正确反映点赞状态"""
        user, post = seed_data
        with patch("app.services.post_service.RAGEngine", MagicMock()):
            service = PostService(db_session)
            assert await service.is_liked(user.id, str(post.id)) is False
            await service.like_post(user.id, str(post.id))
            assert await service.is_liked(user.id, str(post.id)) is True
