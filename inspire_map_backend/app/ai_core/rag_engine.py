"""
RAG (Retrieval-Augmented Generation) 引擎
负责对 ChromaDB 的文本切片、向量化存储与相似度检索
"""
from typing import List, Optional, Dict
import hashlib
import asyncio

import chromadb
from chromadb.config import Settings
from chromadb.api.types import EmbeddingFunction, Documents, Embeddings

from app.core.config import settings

class LocalEmbeddingFunction(EmbeddingFunction):
    """
    本地 Embedding 函数
    使用 sentence-transformers 模型生成向量
    """

    def __init__(self):
        self._model = None
        self._lock = asyncio.Lock()

    def _load_model(self):
        """懒加载 sentence-transformers 模型"""
        if self._model is None:
            from sentence_transformers import SentenceTransformer
            self._model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

    def __call__(self, input: Documents) -> Embeddings:
        """
        生成文本向量

        Args:
            input: 文本列表

        Returns:
            向量列表
        """
        try:
            self._load_model()
            embeddings = self._model.encode(input, convert_to_numpy=True)
            return embeddings.tolist()
        except Exception:
            # 降级：使用 hash 生成伪向量
            vectors = []
            for text in input:
                h = int(hashlib.sha256(text.encode()).hexdigest(), 16)
                vectors.append([(h >> (i * 8)) % 1000 / 1000.0 for i in range(384)])
            return vectors


# 全局单例 embedding 函数
_embedding_fn = LocalEmbeddingFunction()


class RAGEngine:
    """
    RAG 检索增强生成引擎
    实现社区内容的向量化存储与语义检索
    """

    _instance = None
    _client = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if self._client is None:
            self._client = chromadb.PersistentClient(
                path=settings.CHROMA_PERSIST_DIRECTORY,
                settings=Settings(
                    anonymized_telemetry=False
                )
            )
            # 获取或创建集合，传入自定义 embedding 函数
            self.collection = self._client.get_or_create_collection(
                name="community_posts",
                metadata={"hnsw:space": "cosine"},
                embedding_function=_embedding_fn
            )

    async def add_document(
        self,
        doc_id: str,
        text: str,
        metadata: Optional[Dict] = None
    ) -> bool:
        """
        添加文档到向量库

        Args:
            doc_id: 文档ID
            text: 文本内容
            metadata: 元数据 (如 poi_id, author_id 等)

        Returns:
            是否成功
        """
        try:
            # 文本切片
            chunks = self._split_text(text)

            # 为每个切片生成ID
            chunk_ids = [
                f"{doc_id}_chunk_{i}"
                for i in range(len(chunks))
            ]

            # 添加元数据
            metadatas = []
            for i in range(len(chunks)):
                meta = metadata or {}
                meta["doc_id"] = doc_id
                meta["chunk_index"] = i
                metadatas.append(meta)

            # 添加到 ChromaDB（同步调用，放入线程池避免阻塞事件循环）
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: self.collection.add(
                    ids=chunk_ids,
                    documents=chunks,
                    metadatas=metadatas
                )
            )

            return True
        except Exception as e:
            print(f"RAG添加文档失败: {e}")
            return False

    async def retrieve(
        self,
        query: str,
        top_k: int = 3,
        filters: Optional[Dict] = None
    ) -> List[Dict]:
        """
        语义检索

        Args:
            query: 查询文本
            top_k: 返回数量
            filters: 过滤条件 (如 {"poi_id": "xxx"})

        Returns:
            检索结果列表
        """
        try:
            # ChromaDB 同步查询，放入线程池避免阻塞事件循环
            loop = asyncio.get_event_loop()
            results = await loop.run_in_executor(
                None,
                lambda: self.collection.query(
                    query_texts=[query],
                    n_results=top_k,
                    where=filters
                )
            )

            retrieved = []
            if results["documents"] and results["documents"][0]:
                for i, doc in enumerate(results["documents"][0]):
                    retrieved.append({
                        "content": doc,
                        "metadata": results["metadatas"][0][i] if results["metadatas"] else {},
                        "distance": results["distances"][0][i] if results["distances"] else 0
                    })

            return retrieved
        except Exception as e:
            print(f"RAG检索失败: {e}")
            return []

    async def retrieve_poi_context(
        self,
        poi_id: str,
        query: str,
        top_k: int = 3
    ) -> str:
        """
        检索特定 POI 的社区内容

        Args:
            poi_id: POI ID
            query: 用户问题
            top_k: 返回数量

        Returns:
            拼接的上下文文本
        """
        results = await self.retrieve(
            query=query,
            top_k=top_k,
            filters={"poi_id": poi_id}
        )

        if not results:
            return ""

        # 拼接上下文
        contexts = []
        for r in results:
            content = r["content"]
            contexts.append(content)

        return "\n\n---\n\n".join(contexts)

    async def retrieve_general_context(
        self,
        query: str,
        top_k: int = 5
    ) -> str:
        """
        通用语义检索（不限定 POI，用于自由对话 RAG 增强）

        Args:
            query: 用户问题
            top_k: 返回数量

        Returns:
            拼接的上下文文本
        """
        results = await self.retrieve(
            query=query,
            top_k=top_k,
            filters=None
        )

        if not results:
            return ""

        contexts = []
        for r in results:
            source = r["metadata"].get("source_platform", "社区用户")
            content = r["content"]
            contexts.append(f"[{source}] {content}")

        return "\n\n---\n\n".join(contexts)

    async def delete_document(self, doc_id: str) -> bool:
        """
        删除文档及其切片

        Args:
            doc_id: 文档ID

        Returns:
            是否成功
        """
        try:
            # 删除该文档的所有切片
            self.collection.delete(
                where={"doc_id": doc_id}
            )
            return True
        except Exception as e:
            print(f"RAG删除文档失败: {e}")
            return False

    def _split_text(
        self,
        text: str,
        chunk_size: int = 200,
        chunk_overlap: int = 50
    ) -> List[str]:
        """
        文本切片
        使用简单的滑动窗口切片

        Args:
            text: 原始文本
            chunk_size: 每块大小 (字符数)
            chunk_overlap: 重叠大小

        Returns:
            切片列表
        """
        if len(text) <= chunk_size:
            return [text]

        chunks = []
        start = 0

        while start < len(text):
            end = start + chunk_size
            chunk = text[start:end]

            # 尝试在句子边界分割
            if end < len(text):
                # 找最近的句号、问号、感叹号
                for sep in [".", "。", "?", "？", "!", "！", "\n"]:
                    last_sep = chunk.rfind(sep)
                    if last_sep > chunk_size * 0.5:  # 至少保留一半内容
                        end = start + last_sep + 1
                        chunk = text[start:end]
                        break

            chunks.append(chunk.strip())
            start = end - chunk_overlap

        return chunks

    async def vectorize_post(self, post) -> bool:
        """
        向量化社区动态 (供异步任务调用)

        Args:
            post: UserPost 对象

        Returns:
            是否成功
        """
        # 构建完整文本
        text = f"用户分享：{post.content}"
        if post.tags:
            text += f"\n标签：{', '.join(post.tags)}"

        # ChromaDB 不接受 None 值，需过滤掉
        metadata = {
            "author_id": str(post.author_id),
            "post_id": str(post.id),
            "source": "ugc"
        }
        if post.poi_id:
            metadata["poi_id"] = post.poi_id

        success = await self.add_document(
            doc_id=str(post.id),
            text=text,
            metadata=metadata
        )

        if success:
            # 更新标记
            post.is_vectorized = True

        return success

    async def vectorize_external_content(
        self,
        doc_id: str,
        text: str,
        poi_id: Optional[str] = None,
        source: str = "external",
        source_platform: str = "unknown",
        extra_meta: Optional[Dict] = None
    ) -> bool:
        """
        向量化外部导入内容（抖音/小红书摘要等）

        Args:
            doc_id: 唯一文档ID
            text: AI 总结后的文本
            poi_id: 关联的POI ID
            source: 来源类型 (external/crawl)
            source_platform: 来源平台 (douyin/xiaohongshu)
            extra_meta: 额外元数据

        Returns:
            是否成功
        """
        metadata: Dict = {
            "source": source,
            "source_platform": source_platform,
            "doc_id": doc_id
        }
        if poi_id:
            metadata["poi_id"] = poi_id
        if extra_meta:
            # 过滤 None 值
            metadata.update({k: v for k, v in extra_meta.items() if v is not None})

        return await self.add_document(
            doc_id=doc_id,
            text=text,
            metadata=metadata
        )
