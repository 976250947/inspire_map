"""
瓦片 & 字体代理服务器 —— 必须运行，APK 加载地图底图依赖此服务
无需 PostgreSQL / Redis，使用项目 venv 中的 fastapi + httpx 即可启动

用法（在 inspire_map_backend 目录下）：
    # Windows:
    venv\Scripts\python.exe tile_proxy_standalone.py

默认监听 0.0.0.0:8000，手机与电脑须在同一 WiFi 下。
"""
import re
import pathlib
import httpx
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

app = FastAPI(title="瓦片代理", docs_url=None, redoc_url=None)

# 本地预下载字体目录
_FONT_CACHE_DIR = pathlib.Path(__file__).resolve().parent / "font_cache"

# 允许所有来源（仅调试用）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)

# 复用单个 httpx 客户端
_client: httpx.AsyncClient | None = None


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            timeout=10.0,
            follow_redirects=True,
            limits=httpx.Limits(max_connections=50, max_keepalive_connections=20),
        )
    return _client


@app.get("/api/v1/tiles/{z}/{x}/{y}")
async def proxy_tile(z: int, x: int, y: int) -> Response:
    """代理高德栅格瓦片"""
    node = (x % 4) + 1
    url = (
        f"https://webrd0{node}.is.autonavi.com/appmaptile"
        f"?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}"
    )
    try:
        resp = await _get_client().get(url)
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail="tile fetch failed")
        return Response(
            content=resp.content,
            media_type="image/png",
            headers={"Cache-Control": "public, max-age=86400"},
        )
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"upstream error: {e}") from e


@app.get("/")
async def health():
    return {"status": "ok", "service": "tile-proxy"}


# ── SDF 字体 PBF 代理 ──
_font_cache: dict[str, bytes] = {}
_FONTSTACK_RE = re.compile(r"^[\w\s,\-]+$")
_FONT_UPSTREAM_URLS = [
    "https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf",
    "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
]


@app.get("/api/v1/fonts/{fontstack}/{range}.pbf")
async def proxy_font(fontstack: str, range: str) -> Response:
    """代理 SDF 字体 PBF"""
    if not _FONTSTACK_RE.match(fontstack):
        raise HTTPException(status_code=400, detail="invalid fontstack")

    cache_key = f"{fontstack}/{range}"
    if cache_key in _font_cache:
        return Response(
            content=_font_cache[cache_key],
            media_type="application/x-protobuf",
            headers={"Cache-Control": "public, max-age=604800"},
        )

    primary_font = fontstack.split(",")[0].strip()

    # 优先本地预下载文件
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

    # 上游 CDN
    for upstream_tpl in _FONT_UPSTREAM_URLS:
        url = upstream_tpl.format(fontstack=primary_font, range=range)
        try:
            resp = await _get_client().get(url)
            if resp.status_code == 200 and len(resp.content) > 100:
                _font_cache[cache_key] = resp.content
                return Response(
                    content=resp.content,
                    media_type="application/x-protobuf",
                    headers={"Cache-Control": "public, max-age=604800"},
                )
        except httpx.HTTPError:
            continue

    return Response(
        content=b"",
        media_type="application/x-protobuf",
        headers={"Cache-Control": "public, max-age=3600"},
    )


if __name__ == "__main__":
    print("🗺️  瓦片代理启动中...")
    print("📱 真机请将 Flutter 以如下命令运行：")
    print("   flutter run --dart-define=BACKEND_HOST=<本机WLAN IP>")
    uvicorn.run(app, host="0.0.0.0", port=8000)
