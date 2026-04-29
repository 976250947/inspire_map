"""
PostService 单元测试
验证动态 CRUD、评论 CRUD、点赞
"""
import pytest
import pytest_asyncio
from unittest.mock import patch, AsyncMock, MagicMock

from fastapi import HTTPException

from app.models.user import User
from app.models.content import POIBase, UserPost
from app.models.social import UserComment
from app.services.post_service import PostService
from app.schemas.post_schema import (
    PostCreateRequest,
    CommentCreateRequest,
)


@pytest_asyncio.fixture
async def seed_user_and_poi(db_session):
    """创建测试用户和 POI"""
    user = User(
        phone="13800001111",
        password_hash="$2b$12$fake_hash",
        nickname="测试旅行者",
        mbti_type="INTJ",
    )
    db_session.add(user)

    poi = POIBase(
        poi_id="test-poi-search",
        name="成都武侯祠",
        category="景点",
        sub_category="历史",
        longitude=104.0476,
        latitude=30.6462,
        address="成都市武侯区",
        ai_summary_static="三国蜀国祠堂",
        rating=4.6,
    )
    db_session.add(poi)
    await db_session.flush()
    return user, poi


def _mock_rag_and_ai():
    """返回用于 mock RAGEngine 和 AIService.moderate_content 的上下文管理器组合"""
    mock_rag_cls = MagicMock()
    mock_rag_instance = MagicMock()
    mock_rag_instance.vectorize_post = AsyncMock()
    mock_rag_instance.delete_document = AsyncMock()
    mock_rag_cls.return_value = mock_rag_instance

    mock_ai_cls = MagicMock()
    mock_ai_instance = MagicMock()
    mock_ai_instance.moderate_content = AsyncMock(return_value={"passed": True})
    mock_ai_cls.return_value = mock_ai_instance

    return (
        patch("app.services.post_service.RAGEngine", mock_rag_cls),
        # AIService 是在 create_post 内部通过 from app.services.ai_service import AIService 延迟导入的
        patch("app.services.ai_service.AIService", mock_ai_cls),
    )


@pytest.mark.asyncio
class TestPostCRUD:
    """动态发布与获取"""

    async def test_create_post(self, db_session, seed_user_and_poi):
        """发布动态应成功并返回完整响应"""
        user, poi = seed_user_and_poi

        rag_patch, ai_patch = _mock_rag_and_ai()
        with rag_patch, ai_patch:
            service = PostService(db_session)
            request = PostCreateRequest(
                content="武侯祠的红墙竹影真的绝了！",
                poi_id=poi.poi_id,
                tags=["成都", "三国"],
            )
            result = await service.create_post(user.id, request)

        assert result is not None
        assert result.content == "武侯祠的红墙竹影真的绝了！"
        assert result.author.nickname == "测试旅行者"
        assert result.poi_name == "成都武侯祠"

    async def test_get_posts_paginated(self, db_session, seed_user_and_poi):
        """获取动态列表应支持分页"""
        user, _ = seed_user_and_poi

        # 创建 3 条动态
        for i in range(3):
            post = UserPost(
                author_id=user.id,
                content=f"动态内容 {i}",
                tags=[],
                images=[],
            )
            db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            result = await service.get_posts(page=1, page_size=2)

        assert result.total >= 3
        assert len(result.posts) == 2  # page_size=2

    async def test_delete_post_owner(self, db_session, seed_user_and_poi):
        """动态作者可以删除自己的动态"""
        user, _ = seed_user_and_poi

        post = UserPost(
            author_id=user.id,
            content="即将被删除的动态",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            result = await service.delete_post(str(post.id), user.id)
        assert result is True

    async def test_delete_post_forbidden(self, db_session, seed_user_and_poi):
        """非作者不能删除动态"""
        user, _ = seed_user_and_poi

        other = User(phone="13800009999", password_hash="x", nickname="路人")
        db_session.add(other)

        post = UserPost(
            author_id=user.id,
            content="不能被别人删",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            with pytest.raises(HTTPException) as exc_info:
                await service.delete_post(str(post.id), other.id)
        assert exc_info.value.status_code == 403


@pytest.mark.asyncio
class TestLike:
    """点赞与取消点赞"""

    async def test_like_and_unlike(self, db_session, seed_user_and_poi):
        """点赞后 like_count +1，取消后 -1"""
        user, _ = seed_user_and_poi

        post = UserPost(
            author_id=user.id,
            content="点赞测试帖",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            assert await service.like_post(user.id, str(post.id)) is True
            await db_session.refresh(post)
            assert post.like_count == 1

            # 重复点赞应返回 False
            assert await service.like_post(user.id, str(post.id)) is False

            # 取消点赞
            assert await service.unlike_post(user.id, str(post.id)) is True
            await db_session.refresh(post)
            assert post.like_count == 0


@pytest.mark.asyncio
class TestCommentCRUD:
    """评论创建、获取、删除"""

    async def test_create_comment(self, db_session, seed_user_and_poi):
        """发表评论应成功并更新帖子计数"""
        user, _ = seed_user_and_poi

        post = UserPost(
            author_id=user.id,
            content="来一条有评论的动态",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            request = CommentCreateRequest(content="说得太对了！")
            result = await service.create_comment(user.id, str(post.id), request)

        assert result.content == "说得太对了！"
        assert result.user.nickname == "测试旅行者"
        # 帖子评论计数应 +1
        await db_session.refresh(post)
        assert post.comment_count == 1

    async def test_create_reply_comment(self, db_session, seed_user_and_poi):
        """回复评论应正确关联 parent_id"""
        user, _ = seed_user_and_poi

        post = UserPost(
            author_id=user.id,
            content="讨论帖",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)

            # 创建主评论
            c1 = await service.create_comment(
                user.id, str(post.id), CommentCreateRequest(content="主评论")
            )
            # 回复主评论
            c2 = await service.create_comment(
                user.id, str(post.id),
                CommentCreateRequest(content="回复你", parent_id=str(c1.id))
            )

        assert c2.parent_id == str(c1.id)
        await db_session.refresh(post)
        assert post.comment_count == 2

    async def test_get_comments(self, db_session, seed_user_and_poi):
        """获取评论列表应返回正确分页数据"""
        user, _ = seed_user_and_poi

        post = UserPost(
            author_id=user.id,
            content="评论列表测试",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            for i in range(5):
                await service.create_comment(
                    user.id, str(post.id),
                    CommentCreateRequest(content=f"评论 {i}")
                )

            result = await service.get_comments(str(post.id), page=1, page_size=3)
        assert result.total == 5
        assert len(result.comments) == 3

    async def test_delete_comment_by_author(self, db_session, seed_user_and_poi):
        """评论作者可以删除自己的评论"""
        user, _ = seed_user_and_poi

        post = UserPost(
            author_id=user.id,
            content="删评测试",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            comment = await service.create_comment(
                user.id, str(post.id),
                CommentCreateRequest(content="即将被删除")
            )

            result = await service.delete_comment(str(comment.id), user.id)
        assert result is True
        # 评论计数应回到 0
        await db_session.refresh(post)
        assert post.comment_count == 0

    async def test_delete_comment_forbidden(self, db_session, seed_user_and_poi):
        """非作者不能删除评论"""
        user, _ = seed_user_and_poi

        other_user = User(
            phone="13800002222",
            password_hash="$2b$12$fake2",
            nickname="其他用户",
        )
        db_session.add(other_user)

        post = UserPost(
            author_id=user.id,
            content="权限测试",
            tags=[],
            images=[],
        )
        db_session.add(post)
        await db_session.flush()

        rag_patch, _ = _mock_rag_and_ai()
        with rag_patch:
            service = PostService(db_session)
            comment = await service.create_comment(
                user.id, str(post.id),
                CommentCreateRequest(content="不是你的评论")
            )

            with pytest.raises(HTTPException) as exc_info:
                await service.delete_comment(str(comment.id), other_user.id)
        assert exc_info.value.status_code == 403
