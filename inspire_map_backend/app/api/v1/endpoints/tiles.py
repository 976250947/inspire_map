"""
瓦片 & 字体代理端点
- 高德栅格瓦片：使 Android 模拟器/真机通过后端获取底图，避免 CORS/DNS 问题
- SDF 字体 PBF：MapLibre 渲染 GeoJSON SymbolLayer 文字所需的 glyph 数据
"""
import re
import pathlib
import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

router = APIRouter()

# ── 字体缓存（内存） ──
# fontstack+range → bytes，避免重复请求上游
_font_cache: dict[str, bytes] = {}

# 本地预下载字体目录（优先使用，无需网络）
# tiles.py 位于 app/api/v1/endpoints，parents[4] 对应 inspire_map_backend 根目录
_FONT_CACHE_DIR = pathlib.Path(__file__).resolve().parents[4] / "font_cache"

# 高德栅格瓦片源（4 个负载均衡节点）
_AMAP_TILE_URLS = [
    "https://webrd0{n}.is.autonavi.com/appmaptile"
    "?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}"
]

# 复用单个 httpx 异步客户端（连接池）
_http_client: httpx.AsyncClient | None = None


def _get_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(
            timeout=10.0,
            follow_redirects=True,
            limits=httpx.Limits(max_connections=50, max_keepalive_connections=20),
        )
    return _http_client


@router.get("/tiles/{z}/{x}/{y}")
async def proxy_tile(z: int, x: int, y: int) -> Response:
    """
    代理高德栅格瓦片

    Args:
        z: 缩放级别
        x: 瓦片列号
        y: 瓦片行号

    Returns:
        PNG 图片
    """
    # 简单的负载均衡：根据 x 取模选节点
    node = (x % 4) + 1
    url = (
        f"https://webrd0{node}.is.autonavi.com/appmaptile"
        f"?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}"
    )

    client = _get_client()
    try:
        resp = await client.get(url)
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail="tile fetch failed")

        return Response(
            content=resp.content,
            media_type=resp.headers.get("content-type", "image/png"),
            headers={
                "Cache-Control": "public, max-age=86400",  # 浏览器/MapLibre 缓存 1 天
                "Access-Control-Allow-Origin": "*",
            },
        )
    except httpx.HTTPError as e:
        raise HTTPException(status_code=502, detail=f"tile proxy error: {e}")


# ── SDF 字体 PBF 代理 ──
# MapLibre 渲染 SymbolLayer 文字需要 SDF glyph PBF 文件
# 上游使用 MapTiler 免费字体源（Noto Sans 系列支持中文）
# Android/iOS 的 localIdeographFontFamily 默认 "sans-serif"，
# 会优先用系统字体渲染 CJK 字符，PBF 仅用于 ASCII/拉丁等非 CJK 字符

# 安全校验：fontstack 仅允许字母、数字、空格、逗号、连字符
_FONTSTACK_RE = re.compile(r"^[\w\s,\-]+$")

_FONT_UPSTREAM_URLS = [
    # 主源：MapLibre demo（PBF 包含完整 glyph 数据）
    "https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf",
    # 备用：OpenMapTiles 字体（Latin-only，CJK 范围缺失）
    "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
]


@router.get("/fonts/{fontstack}/{range}.pbf")
async def proxy_font(fontstack: str, range: str) -> Response:
    """
    代理 SDF 字体 PBF，供 MapLibre SymbolLayer 文字渲染使用

    Args:
        fontstack: 字体栈名称，如 "Noto Sans Regular"
        range: 字形范围，如 "0-255"
    """
    if not _FONTSTACK_RE.match(fontstack):
        raise HTTPException(status_code=400, detail="invalid fontstack")

    cache_key = f"{fontstack}/{range}"

    # 1. 内存缓存
    if cache_key in _font_cache:
        return Response(
            content=_font_cache[cache_key],
            media_type="application/x-protobuf",
            headers={"Cache-Control": "public, max-age=604800"},
        )

    # MapLibre 可能请求 "Noto Sans Regular,sans-serif" 等复合字体栈
    primary_font = fontstack.split(",")[0].strip()

    # 2. 本地预下载文件（无需网络，最可靠）
    local_path = _FONT_CACHE_DIR / primary_font / f"{range}.pbf"
    if local_path.is_file():
        data = local_path.read_bytes()
        if len(data) > 100:
            _font_cache[cache_key] = data
            return Response(
                content=data,
                media_type="application/x-protobuf",
                headers={"Cache-Control": "public, max-age=604800"},
            )

    # 3. 上游 CDN（首选 demotiles — glyph 更完整）
    client = _get_client()
    for upstream_tpl in _FONT_UPSTREAM_URLS:
        url = upstream_tpl.format(fontstack=primary_font, range=range)
        try:
            resp = await client.get(url)
            if resp.status_code == 200 and len(resp.content) > 100:
                _font_cache[cache_key] = resp.content
                return Response(
                    content=resp.content,
                    media_type="application/x-protobuf",
                    headers={"Cache-Control": "public, max-age=604800"},
                )
        except httpx.HTTPError:
            continue

    # 所有来源均失败 → 返回空 PBF（MapLibre CJK 由 localIdeographFontFamily 兜底）
    return Response(
        content=b"",
        media_type="application/x-protobuf",
        headers={"Cache-Control": "public, max-age=3600"},
    )
