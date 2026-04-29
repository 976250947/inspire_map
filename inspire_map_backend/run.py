"""
启动入口 — 在 uvicorn 创建事件循环之前设置 Windows 兼容策略
Windows 上 asyncio 默认使用 ProactorEventLoop，与 asyncpg 不兼容，
必须在任何 uvicorn 代码运行之前切换为 SelectorEventLoop。

用法:
    .\\venv\\Scripts\\python.exe run.py
"""
import sys
import os

# 确保 CWD 是本文件所在目录，使 pydantic-settings 能找到 .env
os.chdir(os.path.dirname(os.path.abspath(__file__)))

if sys.platform == "win32":
    import asyncio
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        reload=False,
    )
