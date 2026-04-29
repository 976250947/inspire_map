"""
修复 POI 坐标错误
原因: lookup_geo() 按字典插入序迭代，短键"故宫"(北京)优先于"沈阳故宫"(沈阳)
修复: 用修正后的 lookup_geo() 重新计算所有 tg-* POI 的坐标
"""
import asyncio
import sys
import os

sys.path.insert(0, os.getcwd())

from sqlalchemy import select, update, text
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.models.content import POIBase
from app.core.config import settings
from seeds.import_travel_guide import lookup_geo


async def main():
    engine = create_async_engine(str(settings.DATABASE_URL), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    fixed = 0
    skipped = 0

    async with async_session() as session:
        # 只修复由 import_travel_guide 导入的 POI（poi_id 以 tg- 开头）
        result = await session.execute(
            select(POIBase).where(POIBase.poi_id.like("tg-%"))
        )
        pois = result.scalars().all()
        print(f"Found {len(pois)} tg-* POIs to check")

        for poi in pois:
            geo = lookup_geo(poi.name)
            if geo is None:
                skipped += 1
                continue

            lng, lat, province, city = geo
            if abs(poi.longitude - lng) > 0.01 or abs(poi.latitude - lat) > 0.01:
                print(
                    f"  FIX: {poi.name}: "
                    f"({poi.longitude:.4f},{poi.latitude:.4f}) → ({lng:.4f},{lat:.4f})"
                )
                poi.longitude = lng
                poi.latitude = lat
                poi.province = province
                poi.city = city
                fixed += 1

        await session.commit()

    await engine.dispose()
    print(f"\nDone: {fixed} fixed, {skipped} skipped (no geo match)")


if __name__ == "__main__":
    asyncio.run(main())
