"""下载 Noto Sans Regular SDF 字体 PBF 到 font_cache/ 目录
使用 demotiles.maplibre.org 作为主要来源（glyphs 更完整）
只下载常用 Latin/Symbol 范围（CJK 由 localIdeographFontFamily 处理）
"""
import asyncio
import pathlib
import httpx

FONT = "Noto Sans Regular"
OUT_DIR = pathlib.Path(__file__).parent / "font_cache" / FONT

# 关键范围：Latin(0-255), Latin Ext(256-511), General Punct(8192-8447),
# Circled Numbers(9216-9471), Arrows/Symbols(8448-8703, 8704-8959)
KEY_RANGES = [
    "0-255", "256-511", "512-767", "768-1023",
    "8192-8447", "8448-8703", "8704-8959", "8960-9215", "9216-9471",
    "9472-9727", "9728-9983",
]

CDN_URLS = [
    f"https://demotiles.maplibre.org/font/{FONT}/{{range}}.pbf",
    f"https://fonts.openmaptiles.org/{FONT}/{{range}}.pbf",
]


async def download_range(client: httpx.AsyncClient, rng: str) -> None:
    out = OUT_DIR / f"{rng}.pbf"
    if out.exists() and out.stat().st_size > 100:
        print(f"  [skip] {rng}.pbf already cached ({out.stat().st_size} B)")
        return

    for tpl in CDN_URLS:
        url = tpl.format(range=rng)
        try:
            r = await client.get(url)
            if r.status_code == 200 and len(r.content) > 100:
                out.write_bytes(r.content)
                print(f"  [ok]   {rng}.pbf  {len(r.content):>7,} B  ← {url.split('/')[2]}")
                return
        except httpx.HTTPError:
            continue

    print(f"  [FAIL] {rng}.pbf — all CDNs failed")


async def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {len(KEY_RANGES)} PBF ranges to {OUT_DIR}")
    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as c:
        await asyncio.gather(*(download_range(c, r) for r in KEY_RANGES))
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
