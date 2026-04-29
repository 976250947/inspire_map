"""Runtime bootstrap for Windows async compatibility.

This module is auto-imported by Python during startup (if present on sys.path).
It ensures Windows uses SelectorEventLoopPolicy before uvicorn creates the loop,
which avoids asyncpg connection issues under ProactorEventLoop.
"""

import sys

if sys.platform == "win32":
    import asyncio

    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
