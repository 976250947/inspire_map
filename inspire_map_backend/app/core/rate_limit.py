"""
《灵感经纬》API 速率限制
基于 slowapi 实现，防止 AI 端点被滥用
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

# 以客户端 IP 为限流键
# Windows 下 slowapi 默认会用系统编码读取 .env（常见为 gbk），
# 当 .env 为 UTF-8 时可能触发 UnicodeDecodeError。
# 这里显式关闭 slowapi 的 .env 读取，配置统一由 app.core.config 管理。
limiter = Limiter(key_func=get_remote_address, config_filename="")
