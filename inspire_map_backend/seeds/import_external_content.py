"""
外部内容导入脚本
从 JSON 文件批量导入抖音/小红书等平台的攻略数据到 PostgreSQL + ChromaDB

数据来源说明：
  1. 人工收集：直接在抖音/小红书看博主视频/图文，手动摘录关键信息到 JSON
  2. 平台 AI 摘要：如抖音的豆包 AI 自动生成的视频摘要，复制到 JSON
  3. 合规爬虫：通过平台公开 API 或授权接口获取的公开内容

运行方式:
    cd inspire_map_backend
    python -m seeds.import_external_content --file seeds/data/douyin_beijing.json
    python -m seeds.import_external_content --file seeds/data/xiaohongshu_chengdu.json --summarize
"""
import asyncio
import argparse
import json
import sys
import os
import uuid
from typing import List, Dict, Optional
from pathlib import Path

# 将项目路径添加到 sys.path
sys.path.insert(0, os.getcwd())

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.models.base import Base
from app.models.user import User
from app.models.content import POIBase, UserPost, UserFootprint
from app.core.config import settings


# ════════════════════════════════════════════════════
#  数据格式定义
# ════════════════════════════════════════════════════
SAMPLE_SCHEMA = """
JSON 数据格式要求:
{
    "platform": "小红书" | "抖音",
    "items": [
        {
            "poi_id": "bj-001",           // 对应 POIBase.poi_id，必填
            "poi_name": "故宫",            // 地点名称，用于 AI 总结
            "author_name": "旅行达人小张",  // 博主昵称
            "source_url": "https://...",   // 原始链接（可选）
            "content": "博主的文案或AI摘要文本...",
            "ai_summary": "已经由豆包等AI总结好的内容（可选，有则跳过再次AI总结）",
            "tags": ["美食", "打卡"],
            "publish_date": "2026-03-20"   // 原始发布日期（可选）
        }
    ]
}
"""


async def load_json(file_path: str) -> Dict:
    """加载并校验 JSON 数据文件"""
    path = Path(file_path)
    if not path.exists():
        print(f"❌ 文件不存在: {file_path}")
        sys.exit(1)

    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if "items" not in data:
        print(f"❌ JSON 缺少 'items' 字段。期望格式:\n{SAMPLE_SCHEMA}")
        sys.exit(1)

    platform = data.get("platform", "unknown")
    items = data["items"]
    print(f"📦 加载了 {len(items)} 条来自 [{platform}] 的数据")
    return data


async def summarize_with_ai(poi_name: str, raw_text: str, platform: str) -> Optional[str]:
    """
    用大模型总结博主内容为结构化数据

    Args:
        poi_name: 地点名称
        raw_text: 博主原始文案
        platform: 来源平台

    Returns:
        AI 总结的文本（用于向量化），失败返回 None
    """
    from app.ai_core.llm_client import LLMClient
    from app.ai_core.prompts import PromptTemplates
    from app.schemas.ai_schema import AIChatMessage

    llm = LLMClient()
    prompt = PromptTemplates.get_external_content_summary_prompt(
        poi_name=poi_name,
        raw_text=raw_text,
        source_platform=platform
    )

    try:
        messages = [AIChatMessage(role="user", content=prompt)]
        result = await llm.chat(messages, temperature=0.3)

        # 尝试解析确保是合法 JSON
        import re
        json_match = re.search(r'\{.*\}', result, re.DOTALL)
        if json_match:
            parsed = json.loads(json_match.group())
            # 拼成纯文本用于向量化
            text_parts = []
            if parsed.get("summary"):
                text_parts.append(parsed["summary"])
            if parsed.get("tips"):
                text_parts.append("避坑提示：" + "；".join(parsed["tips"]))
            if parsed.get("highlights"):
                text_parts.append("亮点：" + "；".join(parsed["highlights"]))
            if parsed.get("suitable_for"):
                text_parts.append("适合：" + "、".join(parsed["suitable_for"]))
            return "\n".join(text_parts)

        return result
    except Exception as e:
        print(f"  ⚠️  AI 总结失败: {e}")
        return None


async def import_to_db_and_rag(
    data: Dict,
    do_summarize: bool = False
):
    """
    将数据写入 PostgreSQL (UserPost) + ChromaDB (向量库)

    Args:
        data: 解析后的 JSON 数据
        do_summarize: 是否用 AI 再次总结 content 字段
    """
    from app.ai_core.rag_engine import RAGEngine

    engine = create_async_engine(str(settings.DATABASE_URL), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    rag = RAGEngine()
    platform = data.get("platform", "unknown")
    items = data["items"]

    success_count = 0
    skip_count = 0
    fail_count = 0

    # 需要一个系统用户来作为外部导入内容的 author
    async with async_session() as session:
        system_user = await _get_or_create_system_user(session)
        system_user_id = str(system_user.id)
        await session.commit()

    for i, item in enumerate(items, 1):
        poi_id = item.get("poi_id")
        poi_name = item.get("poi_name", "")
        content = item.get("content", "")
        ai_summary = item.get("ai_summary", "")
        tags = item.get("tags", [])
        author_name = item.get("author_name", "")
        source_url = item.get("source_url", "")

        if not poi_id or (not content and not ai_summary):
            print(f"  [{i}/{len(items)}] ⏭️  跳过（缺少 poi_id 或 content）")
            skip_count += 1
            continue

        # 确定向量化的文本
        rag_text = ai_summary or content

        # 如果用户要求 AI 总结，且没有现成的 ai_summary
        if do_summarize and not ai_summary and content:
            print(f"  [{i}/{len(items)}] 🤖 AI 总结中: {poi_name}...")
            summarized = await summarize_with_ai(poi_name, content, platform)
            if summarized:
                rag_text = summarized
            # AI 调用间隔，避免频率限制
            await asyncio.sleep(1)

        # ── 写入 PostgreSQL (UserPost 表) ──
        async with async_session() as session:
            try:
                # 检查 POI 是否存在
                poi_result = await session.execute(
                    select(POIBase).where(POIBase.poi_id == poi_id)
                )
                poi = poi_result.scalar_one_or_none()
                if not poi:
                    print(f"  [{i}/{len(items)}] ⚠️  POI {poi_id} 不存在，仅入向量库")

                # 构造标记来源的内容
                display_content = f"[{platform}·{author_name}] {rag_text}" if author_name else rag_text

                post = UserPost(
                    author_id=system_user_id,
                    poi_id=poi_id if poi else None,
                    content=display_content,
                    images=[],
                    tags=tags + [f"来源:{platform}"],
                    is_vectorized=False
                )
                session.add(post)
                await session.flush()

                post_id = str(post.id)
                await session.commit()
            except Exception as e:
                print(f"  [{i}/{len(items)}] ❌ DB写入失败: {e}")
                await session.rollback()
                fail_count += 1
                continue

        # ── 写入 ChromaDB (向量库) ──
        try:
            doc_id = f"ext_{platform}_{post_id}"
            extra_meta = {
                "author_name": author_name,
            }
            if source_url:
                extra_meta["source_url"] = source_url

            ok = await rag.vectorize_external_content(
                doc_id=doc_id,
                text=rag_text,
                poi_id=poi_id,
                source="external",
                source_platform=platform,
                extra_meta=extra_meta
            )

            if ok:
                # 回写 is_vectorized
                async with async_session() as session:
                    from sqlalchemy import update
                    await session.execute(
                        update(UserPost)
                        .where(UserPost.id == post_id)
                        .values(is_vectorized=True)
                    )
                    await session.commit()

                success_count += 1
                print(f"  [{i}/{len(items)}] ✅ {poi_name or poi_id}")
            else:
                fail_count += 1
                print(f"  [{i}/{len(items)}] ❌ 向量化失败: {poi_name or poi_id}")

        except Exception as e:
            fail_count += 1
            print(f"  [{i}/{len(items)}] ❌ RAG写入失败: {e}")

    await engine.dispose()

    print(f"\n{'='*50}")
    print(f"📊 导入完成: ✅成功 {success_count} | ⏭️跳过 {skip_count} | ❌失败 {fail_count}")
    print(f"{'='*50}")


async def _get_or_create_system_user(session) -> User:
    """获取或创建系统导入专用用户"""
    result = await session.execute(
        select(User).where(User.phone == "system_import")
    )
    user = result.scalar_one_or_none()
    if user:
        return user

    user = User(
        phone="system_import",
        hashed_password="not_a_real_password",
        nickname="灵感经纬·攻略收录",
        mbti_type="INFJ",
        avatar_url="",
    )
    session.add(user)
    await session.flush()
    print("🤖 创建了系统导入用户: 灵感经纬·攻略收录")
    return user


async def main():
    parser = argparse.ArgumentParser(description="《灵感经纬》外部攻略数据导入工具")
    parser.add_argument("--file", "-f", required=True, help="JSON 数据文件路径")
    parser.add_argument(
        "--summarize", "-s",
        action="store_true",
        default=False,
        help="是否用 AI 大模型总结原始内容（会消耗 Token，建议仅对未经处理的原始文案使用）"
    )
    args = parser.parse_args()

    print(f"{'='*50}")
    print(f" 《灵感经纬》外部数据导入工具")
    print(f" AI 总结: {'开启 🤖' if args.summarize else '关闭'}")
    print(f"{'='*50}")

    data = await load_json(args.file)
    await import_to_db_and_rag(data, do_summarize=args.summarize)


if __name__ == "__main__":
    asyncio.run(main())
