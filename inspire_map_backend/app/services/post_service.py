"""
社区动态/足迹服务层
"""
from typing import List, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func
from fastapi import HTTPException, status, BackgroundTasks

from app.models.content import UserPost, UserFootprint, POIBase
from app.models.user import User
from app.models.social import UserLike, UserComment
from app.schemas.post_schema import (
    PostCreateRequest,
    PostUpdateRequest,
    PostResponse,
    PostListResponse,
    FootprintCreateRequest,
    FootprintResponse,
    FootprintStatsResponse,
    CommentCreateRequest,
    CommentResponse,
    CommentListResponse
)
from app.schemas.user_schema import UserMinimalResponse
from app.ai_core.rag_engine import RAGEngine


class PostService:
    """社区动态业务服务"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.rag = RAGEngine()

    # ========== 动态相关 ==========

    async def create_post(
        self,
        user_id: str,
        request: PostCreateRequest,
        background_tasks: Optional[BackgroundTasks] = None
    ) -> PostResponse:
        """
        创建动态

        Args:
            user_id: 作者ID
            request: 创建请求
            background_tasks: FastAPI 后台任务队列，用于异步向量化

        Returns:
            创建的动态

        Raises:
            HTTPException: 内容审核未通过时拒绝发布
        """
        # 内容审核
        from app.services.ai_service import AIService
        audit = AIService(self.db, None)
        audit_result = await audit.moderate_content(request.content)
        if not audit_result.get("passed", False):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"内容审核未通过：{audit_result.get('reason', '未知原因')}"
            )

        post = UserPost(
            author_id=user_id,
            poi_id=request.poi_id,
            content=request.content,
            images=request.images,
            tags=request.tags,
            is_vectorized=False
        )

        self.db.add(post)
        await self.db.flush()
        await self.db.refresh(post)

        # 异步向量化：使用 BackgroundTasks 在响应返回后执行，不阻塞发帖
        if background_tasks is not None:
            background_tasks.add_task(self._vectorize_post_background, str(post.id), post.content, request.tags)
        else:
            # 兜底：无 background_tasks 时同步执行
            try:
                await self.rag.vectorize_post(post)
            except Exception as e:
                print(f"[WARN] RAG vectorize failed for post {post.id}: {e}")

        # 获取POI名称
        poi_name = None
        if request.poi_id:
            poi_result = await self.db.execute(
                select(POIBase).where(POIBase.poi_id == request.poi_id)
            )
            poi = poi_result.scalar_one_or_none()
            poi_name = poi.name if poi else None

        # 更新用户动态数
        await self._update_user_post_count(user_id)

        return await self._to_post_response(post, poi_name=poi_name)

    def _vectorize_post_background(
        self, post_id: str, content: str, tags: Optional[List[str]]
    ) -> None:
        """后台向量化任务 — 由 FastAPI BackgroundTasks 调度，不阻塞 HTTP 响应"""
        import asyncio
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            rag = RAGEngine()
            # 构建轻量级的伪 post 对象供向量化使用
            from types import SimpleNamespace
            pseudo_post = SimpleNamespace(
                id=post_id,
                content=content,
                tags=tags or [],
            )
            loop.run_until_complete(rag.vectorize_post(pseudo_post))
            print(f"[INFO] Background vectorize success for post {post_id}")
        except Exception as e:
            print(f"[WARN] Background vectorize failed for post {post_id}: {e}")
        finally:
            loop.close()

    async def get_posts(
        self,
        page: int = 1,
        page_size: int = 20,
        poi_id: Optional[str] = None,
        user_id: Optional[str] = None,
        current_user_id: Optional[str] = None
    ) -> PostListResponse:
        """
        获取动态列表

        Args:
            page: 页码
            page_size: 每页数量
            poi_id: 筛选特定POI的动态
            user_id: 筛选特定用户的动态

        Returns:
            动态列表
        """
        query = select(UserPost).order_by(desc(UserPost.created_at))

        if poi_id:
            query = query.where(UserPost.poi_id == poi_id)
        if user_id:
            query = query.where(UserPost.author_id == user_id)

        # 分页
        total_result = await self.db.execute(
            select(func.count()).select_from(query.subquery())
        )
        total = total_result.scalar()

        query = query.offset((page - 1) * page_size).limit(page_size)
        result = await self.db.execute(query)
        posts = result.scalars().all()

        post_responses = []
        for post in posts:
            response = await self._to_post_response(post, current_user_id=current_user_id)
            post_responses.append(response)

        return PostListResponse(
            posts=post_responses,
            total=total
        )

    async def get_post_by_id(self, post_id: str, current_user_id: Optional[str] = None) -> Optional[PostResponse]:
        """获取单条动态详情"""
        from uuid import UUID
        try:
            post_uuid = str(UUID(post_id))
        except ValueError:
            return None

        result = await self.db.execute(
            select(UserPost).where(UserPost.id == post_uuid)
        )
        post = result.scalar_one_or_none()

        if not post:
            return None

        return await self._to_post_response(post, current_user_id=current_user_id)

    async def update_post(
        self,
        post_id: str,
        user_id: str,
        request: PostUpdateRequest
    ) -> PostResponse:
        """
        更新动态

        Args:
            post_id: 动态ID
            user_id: 当前用户ID（用于权限校验）
            request: 更新内容

        Returns:
            更新后的动态
        """
        from uuid import UUID
        try:
            post_uuid = str(UUID(post_id))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="无效的动态ID格式"
            )

        result = await self.db.execute(
            select(UserPost).where(UserPost.id == post_uuid)
        )
        post = result.scalar_one_or_none()

        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="动态不存在"
            )

        if str(post.author_id) != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权修改此动态"
            )

        if request.content is not None:
            post.content = request.content
        if request.images is not None:
            post.images = request.images
        if request.tags is not None:
            post.tags = request.tags

        await self.db.flush()
        await self.db.refresh(post)

        return await self._to_post_response(post)

    async def delete_post(self, post_id: str, user_id: str) -> bool:
        """删除动态"""
        from uuid import UUID
        # 确保 post_id 是 UUID 类型
        try:
            post_uuid = str(UUID(post_id))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="无效的动态ID格式"
            )

        result = await self.db.execute(
            select(UserPost).where(UserPost.id == post_uuid)
        )
        post = result.scalar_one_or_none()

        if not post:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="动态不存在"
            )

        if str(post.author_id) != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权删除此动态"
            )

        await self.db.delete(post)
        await self._update_user_post_count(user_id, increment=False)

        # 同步删除向量库中的文档
        try:
            await self.rag.delete_document(post_id)
        except Exception as e:
            print(f"[WARN] RAG delete_document failed for {post_id}: {e}")

        return True

    # ========== 足迹相关 ==========

    async def create_footprint(
        self,
        user_id: str,
        request: FootprintCreateRequest
    ) -> FootprintResponse:
        """
        创建足迹打卡

        Args:
            user_id: 用户ID
            request: 创建请求

        Returns:
            创建的足迹
        """
        # 如果没有传入省份/城市，尝试从 POI 表补全
        province = request.province
        city = request.city
        poi_name = None

        if request.poi_id and (not province or not city):
            poi_result = await self.db.execute(
                select(POIBase).where(POIBase.poi_id == request.poi_id)
            )
            poi = poi_result.scalar_one_or_none()
            if poi:
                poi_name = poi.name
                if not province and poi.address:
                    province = poi.address.split(",")[0].strip() if "," in poi.address else poi.address.strip()
                if not city and poi.address and "," in poi.address:
                    city = poi.address.split(",")[1].strip()

        footprint = UserFootprint(
            user_id=user_id,
            poi_id=request.poi_id,
            longitude=request.longitude,
            latitude=request.latitude,
            province=province,
            city=city,
            check_in_note=request.check_in_note,
            images=request.images
        )

        self.db.add(footprint)

        # 更新POI打卡数
        if request.poi_id:
            await self._update_poi_visit_count(request.poi_id)

        # 更新用户足迹数
        await self._update_user_footprint_count(user_id)

        await self.db.flush()
        await self.db.refresh(footprint)

        return FootprintResponse(
            id=footprint.id,
            poi_id=footprint.poi_id,
            poi_name=poi_name,
            longitude=footprint.longitude,
            latitude=footprint.latitude,
            province=footprint.province,
            city=footprint.city,
            check_in_note=footprint.check_in_note,
            images=footprint.images or [],
            created_at=footprint.created_at,
            updated_at=footprint.updated_at
        )

    async def get_footprints(
        self,
        user_id: str,
        page: int = 1,
        page_size: int = 20
    ) -> List[FootprintResponse]:
        """获取用户足迹列表"""
        result = await self.db.execute(
            select(UserFootprint)
            .where(UserFootprint.user_id == user_id)
            .order_by(desc(UserFootprint.created_at))
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        footprints = result.scalars().all()

        responses = []
        for footprint in footprints:
            # 获取POI名称
            poi_name = None
            if footprint.poi_id:
                poi_result = await self.db.execute(
                    select(POIBase).where(POIBase.poi_id == footprint.poi_id)
                )
                poi = poi_result.scalar_one_or_none()
                poi_name = poi.name if poi else None

            responses.append(FootprintResponse(
                id=footprint.id,
                poi_id=footprint.poi_id,
                poi_name=poi_name,
                longitude=footprint.longitude,
                latitude=footprint.latitude,
                province=footprint.province,
                city=footprint.city,
                check_in_note=footprint.check_in_note,
                images=footprint.images or [],
                created_at=footprint.created_at,
                updated_at=footprint.updated_at
            ))

        return responses

    async def get_footprint_stats(self, user_id: str) -> FootprintStatsResponse:
        """获取足迹统计"""
        # 总足迹数
        result = await self.db.execute(
            select(func.count()).where(UserFootprint.user_id == user_id)
        )
        total = result.scalar()

        # 获取所有足迹用于地理统计
        footprints_result = await self.db.execute(
            select(UserFootprint).where(UserFootprint.user_id == user_id)
        )
        footprints = footprints_result.scalars().all()

        # 直接使用足迹表中的 province/city 字段
        provinces: set = set()
        cities: set = set()
        footprint_map: dict = {}

        for fp in footprints:
            if fp.province:
                provinces.add(fp.province)
                footprint_map[fp.province] = footprint_map.get(fp.province, 0) + 1
            if fp.city:
                cities.add(fp.city)

        return FootprintStatsResponse(
            total_footprints=total,
            total_cities=len(cities),
            total_provinces=len(provinces),
            footprint_map=footprint_map
        )

    # ========== 辅助方法 ==========

    async def _to_post_response(
        self,
        post: UserPost,
        poi_name: Optional[str] = None,
        current_user_id: Optional[str] = None
    ) -> PostResponse:
        """转换为响应模型"""
        # 获取作者信息
        result = await self.db.execute(
            select(User).where(User.id == post.author_id)
        )
        author = result.scalar_one_or_none()

        author_response = None
        if author:
            author_response = UserMinimalResponse(
                id=author.id,
                nickname=author.nickname,
                avatar_url=author.avatar_url,
                mbti_type=author.mbti_type
            )

        # 查询当前用户是否已点赞
        liked = False
        if current_user_id:
            like_result = await self.db.execute(
                select(UserLike).where(
                    UserLike.user_id == current_user_id,
                    UserLike.post_id == str(post.id)
                )
            )
            liked = like_result.scalar_one_or_none() is not None

        return PostResponse(
            id=post.id,
            author=author_response,
            poi_id=post.poi_id,
            poi_name=poi_name,
            content=post.content,
            images=post.images or [],
            tags=post.tags or [],
            longitude=None,
            latitude=None,
            like_count=post.like_count,
            comment_count=post.comment_count,
            is_liked=liked,
            created_at=post.created_at,
            updated_at=post.updated_at
        )

    async def _update_user_post_count(
        self,
        user_id: str,
        increment: bool = True
    ):
        """更新用户动态数"""
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        if user:
            current = int(user.post_count or "0")
            user.post_count = str(current + (1 if increment else -1))

    async def _update_user_footprint_count(self, user_id: str):
        """更新用户足迹数"""
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        if user:
            current = int(user.footprint_count or "0")
            user.footprint_count = str(current + 1)

    async def _update_poi_visit_count(self, poi_id: str):
        """更新POI访问数"""
        result = await self.db.execute(
            select(POIBase).where(POIBase.poi_id == poi_id)
        )
        poi = result.scalar_one_or_none()
        if poi:
            poi.visit_count = (poi.visit_count or 0) + 1

    # ========== 点赞相关 ==========

    async def like_post(self, user_id: str, post_id: str) -> bool:
        """
        点赞动态

        Returns:
            True 成功点赞，False 已经点过赞
        """
        from uuid import UUID
        try:
            post_uuid = str(UUID(post_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="无效的动态ID格式")

        # 检查是否已点赞
        existing = await self.db.execute(
            select(UserLike).where(
                UserLike.user_id == user_id,
                UserLike.post_id == post_uuid
            )
        )
        if existing.scalar_one_or_none():
            return False

        # 创建点赞记录
        like = UserLike(user_id=user_id, post_id=post_uuid)
        self.db.add(like)

        # 更新动态的点赞计数
        result = await self.db.execute(
            select(UserPost).where(UserPost.id == post_uuid)
        )
        post = result.scalar_one_or_none()
        if post:
            post.like_count = (post.like_count or 0) + 1

        await self.db.flush()
        return True

    async def unlike_post(self, user_id: str, post_id: str) -> bool:
        """
        取消点赞

        Returns:
            True 成功取消，False 未曾点赞
        """
        from uuid import UUID
        try:
            post_uuid = str(UUID(post_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="无效的动态ID格式")

        result = await self.db.execute(
            select(UserLike).where(
                UserLike.user_id == user_id,
                UserLike.post_id == post_uuid
            )
        )
        like = result.scalar_one_or_none()
        if not like:
            return False

        await self.db.delete(like)

        # 更新动态的点赞计数
        post_result = await self.db.execute(
            select(UserPost).where(UserPost.id == post_uuid)
        )
        post = post_result.scalar_one_or_none()
        if post and (post.like_count or 0) > 0:
            post.like_count = post.like_count - 1

        await self.db.flush()
        return True

    async def is_liked(self, user_id: str, post_id: str) -> bool:
        """检查用户是否已点赞某动态"""
        result = await self.db.execute(
            select(UserLike).where(
                UserLike.user_id == user_id,
                UserLike.post_id == post_id
            )
        )
        return result.scalar_one_or_none() is not None

    # ========== 评论相关 ==========

    async def create_comment(
        self,
        user_id: str,
        post_id: str,
        request: CommentCreateRequest
    ) -> CommentResponse:
        """
        创建评论

        Args:
            user_id: 评论用户ID
            post_id: 动态ID
            request: 评论内容

        Returns:
            创建的评论
        """
        from uuid import UUID
        try:
            post_uuid = str(UUID(post_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="无效的动态ID格式")

        # 检查动态是否存在
        post_result = await self.db.execute(
            select(UserPost).where(UserPost.id == post_uuid)
        )
        post = post_result.scalar_one_or_none()
        if not post:
            raise HTTPException(status_code=404, detail="动态不存在")

        # 如果是回复，检查父评论是否存在且属于同一动态
        if request.parent_id:
            parent_result = await self.db.execute(
                select(UserComment).where(
                    UserComment.id == request.parent_id,
                    UserComment.post_id == post_uuid
                )
            )
            if not parent_result.scalar_one_or_none():
                raise HTTPException(status_code=404, detail="父评论不存在")

        comment = UserComment(
            user_id=user_id,
            post_id=post_uuid,
            content=request.content,
            parent_id=request.parent_id
        )
        self.db.add(comment)

        # 更新动态评论计数
        post.comment_count = (post.comment_count or 0) + 1

        await self.db.flush()
        await self.db.refresh(comment)

        return await self._to_comment_response(comment)

    async def get_comments(
        self,
        post_id: str,
        page: int = 1,
        page_size: int = 20
    ) -> CommentListResponse:
        """获取动态的评论列表"""
        from uuid import UUID
        try:
            post_uuid = str(UUID(post_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="无效的动态ID格式")

        # 总数
        total_result = await self.db.execute(
            select(func.count()).where(UserComment.post_id == post_uuid)
        )
        total = total_result.scalar() or 0

        # 分页查询（按创建时间正序）
        result = await self.db.execute(
            select(UserComment)
            .where(UserComment.post_id == post_uuid)
            .order_by(UserComment.created_at)
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        comments = result.scalars().all()

        responses = []
        for comment in comments:
            responses.append(await self._to_comment_response(comment))

        return CommentListResponse(comments=responses, total=total)

    async def delete_comment(self, comment_id: str, user_id: str) -> bool:
        """
        删除评论（仅作者本人可删）

        Returns:
            True 成功删除
        """
        from uuid import UUID
        try:
            comment_uuid = str(UUID(comment_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="无效的评论ID格式")

        result = await self.db.execute(
            select(UserComment).where(UserComment.id == comment_uuid)
        )
        comment = result.scalar_one_or_none()
        if not comment:
            raise HTTPException(status_code=404, detail="评论不存在")
        if str(comment.user_id) != user_id:
            raise HTTPException(status_code=403, detail="无权删除此评论")

        post_id = comment.post_id
        await self.db.delete(comment)

        # 更新动态评论计数
        post_result = await self.db.execute(
            select(UserPost).where(UserPost.id == post_id)
        )
        post = post_result.scalar_one_or_none()
        if post and (post.comment_count or 0) > 0:
            post.comment_count = post.comment_count - 1

        await self.db.flush()
        return True

    async def _to_comment_response(self, comment: UserComment) -> CommentResponse:
        """转换评论为响应模型"""
        result = await self.db.execute(
            select(User).where(User.id == comment.user_id)
        )
        user = result.scalar_one_or_none()

        user_response = UserMinimalResponse(
            id=user.id if user else "",
            nickname=user.nickname if user else "未知用户",
            avatar_url=user.avatar_url if user else None,
            mbti_type=user.mbti_type if user else None
        )

        return CommentResponse(
            id=comment.id,
            user=user_response,
            post_id=str(comment.post_id),
            content=comment.content,
            parent_id=comment.parent_id,
            created_at=comment.created_at,
            updated_at=comment.updated_at
        )
