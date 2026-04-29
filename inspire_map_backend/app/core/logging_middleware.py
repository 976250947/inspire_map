"""
请求日志中间件
记录每个请求的方法、路径、状态码、耗时
使用 structlog 输出结构化日志
"""
import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

import structlog

logger = structlog.get_logger("inspire_map.access")


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    结构化请求日志中间件

    记录：method, path, status_code, duration_ms, client_ip
    跳过健康检查和静态资源的详细日志
    """

    # 不记录详细日志的路径前缀
    _SKIP_PATHS = {"/health", "/docs", "/openapi.json", "/redoc", "/uploads/"}

    async def dispatch(self, request: Request, call_next) -> Response:
        path = request.url.path

        # 跳过高频低价值路径
        if any(path.startswith(p) for p in self._SKIP_PATHS):
            return await call_next(request)

        start_time = time.perf_counter()
        client_ip = request.client.host if request.client else "unknown"
        method = request.method

        try:
            response = await call_next(request)
            duration_ms = round((time.perf_counter() - start_time) * 1000, 1)

            # 按状态码级别分类日志
            log_data = {
                "method": method,
                "path": path,
                "status": response.status_code,
                "duration_ms": duration_ms,
                "client_ip": client_ip,
            }

            if response.status_code >= 500:
                logger.error("request_error", **log_data)
            elif response.status_code >= 400:
                logger.warning("request_client_error", **log_data)
            else:
                logger.info("request_ok", **log_data)

            return response
        except Exception as exc:
            duration_ms = round((time.perf_counter() - start_time) * 1000, 1)
            logger.error(
                "request_exception",
                method=method,
                path=path,
                duration_ms=duration_ms,
                client_ip=client_ip,
                error=str(exc),
            )
            raise
