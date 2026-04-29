"""
清理社区导入数据 —— 删除通过 seeds/import_travel_guide.py 和
seeds/import_external_content.py 批量导入的 UserPost 数据

这些帖子由 system_import 用户发布，内容冗长，不适合社区展示。

用法（在 inspire_map_backend 目录下）：
    venv\Scripts\python.exe -m seeds.clean_community_posts
"""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select, delete, func
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models.content import UserPost
from app.models.user import User
from app.models.social import UserLike


async def main():
    engine = create_async_engine(str(settings.DATABASE_URL))
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # 1. 找到 system_import 用户
        result = await session.execute(
            select(User).where(User.phone == "system_import")
        )
        system_user = result.scalar_one_or_none()

        if system_user:
            system_id = str(system_user.id)
            # 统计该用户发布的帖子数
            count_result = await session.execute(
                select(func.count()).where(UserPost.author_id == system_id)
            )
            post_count = count_result.scalar() or 0
            print(f"📊 system_import 用户共有 {post_count} 条帖子")

            if post_count > 0:
                # 先删除相关点赞记录（外键约束）
                post_ids_result = await session.execute(
                    select(UserPost.id).where(UserPost.author_id == system_id)
                )
                post_ids = [str(r) for r in post_ids_result.scalars().all()]

                like_del = await session.execute(
                    delete(UserLike).where(UserLike.post_id.in_(post_ids))
                )
                print(f"🗑️  删除关联点赞 {like_del.rowcount} 条")

                # 删除帖子
                del_result = await session.execute(
                    delete(UserPost).where(UserPost.author_id == system_id)
                )
                print(f"🗑️  删除导入帖子 {del_result.rowcount} 条")

                # 重置用户计数
                system_user.post_count = "0"

                await session.commit()
                print("✅ 清理完成")
            else:
                print("ℹ️  没有需要清理的帖子")
        else:
            print("ℹ️  未找到 system_import 用户，跳过")

        # 2. 统计剩余帖子
        remaining = await session.execute(
            select(func.count()).select_from(UserPost)
        )
        print(f"📊 数据库剩余帖子: {remaining.scalar() or 0} 条")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
