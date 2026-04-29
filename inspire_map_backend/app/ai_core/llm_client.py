"""
LLM 客户端
封装对 DeepSeek/Qwen 的底层 API 调用
"""
from typing import AsyncGenerator, List, Optional
import httpx
from openai import AsyncOpenAI

from app.core.config import settings
from app.schemas.ai_schema import AIChatMessage


class LLMClient:
    """大语言模型客户端"""

    def __init__(self, provider: Optional[str] = None):
        self.provider = provider or settings.LLM_PROVIDER
        self.client = self._init_client()

    def _init_client(self) -> AsyncOpenAI:
        """初始化 OpenAI 兼容客户端"""
        if self.provider == "deepseek":
            return AsyncOpenAI(
                api_key=settings.DEEPSEEK_API_KEY or "dummy-key",
                base_url=settings.DEEPSEEK_API_BASE
            )
        elif self.provider == "qwen":
            return AsyncOpenAI(
                api_key=settings.QWEN_API_KEY or "dummy-key",
                base_url=settings.QWEN_API_BASE
            )
        else:
            raise ValueError(f"不支持的 LLM 提供商: {self.provider}")

    async def chat(
        self,
        messages: List[AIChatMessage],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        """
        非流式对话

        Args:
            messages: 消息列表
            model: 模型名称
            temperature: 温度
            max_tokens: 最大token数

        Returns:
            完整响应文本
        """
        model_name = model or self._get_default_model()

        # 转换消息格式
        msg_dicts = [{"role": m.role, "content": m.content} for m in messages]

        try:
            response = await self.client.chat.completions.create(
                model=model_name,
                messages=msg_dicts,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=False
            )
            return response.choices[0].message.content
        except Exception as e:
            # 降级处理：返回错误信息
            return f"[AI服务暂时不可用: {str(e)}]"

    async def chat_stream(
        self,
        messages: List[AIChatMessage],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> AsyncGenerator[str, None]:
        """
        流式对话 (SSE)

        Args:
            messages: 消息列表
            model: 模型名称
            temperature: 温度
            max_tokens: 最大token数

        Yields:
            文本块
        """
        model_name = model or self._get_default_model()
        msg_dicts = [{"role": m.role, "content": m.content} for m in messages]

        try:
            stream = await self.client.chat.completions.create(
                model=model_name,
                messages=msg_dicts,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=True
            )

            async for chunk in stream:
                if chunk.choices and chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content

        except Exception as e:
            yield f"[AI服务错误: {str(e)}]"

    async def generate_embedding(self, text: str) -> List[float]:
        """
        生成文本向量
        使用 sentence-transformers 本地模型

        Args:
            text: 输入文本

        Returns:
            向量列表
        """
        try:
            from sentence_transformers import SentenceTransformer
            import asyncio

            # 懒加载模型，避免启动时占用大量内存
            if not hasattr(self, "_embedding_model"):
                loop = asyncio.get_event_loop()
                self._embedding_model = await loop.run_in_executor(
                    None,
                    lambda: SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
                )

            loop = asyncio.get_event_loop()
            embedding = await loop.run_in_executor(
                None,
                lambda: self._embedding_model.encode(text, convert_to_numpy=True)
            )
            return embedding.tolist()
        except Exception as e:
            # 降级：使用文本的简单哈希作为伪嵌入（仅供开发/演示）
            import hashlib
            hash_val = int(hashlib.sha256(text.encode()).hexdigest(), 16)
            # 生成 384 维伪向量（与 all-MiniLM-L6-v2 维度一致）
            return [(hash_val >> (i * 8)) % 1000 / 1000.0 for i in range(384)]

    def _get_default_model(self) -> str:
        """获取默认模型名称"""
        if self.provider == "deepseek":
            return "deepseek-chat"
        elif self.provider == "qwen":
            return "qwen-max"
        return "gpt-3.5-turbo"
