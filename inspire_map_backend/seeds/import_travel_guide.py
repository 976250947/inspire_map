"""
travel_guide.xlsx 数据集导入脚本
将 804 条旅游攻略数据导入 PostgreSQL (POI + UserPost) + ChromaDB (向量库)

数据列: 目的地 | 交通安排 | 住宿推荐 | 必打卡景点 | 美食推荐 | 实用小贴士 | 旅行感悟

运行方式:
    cd inspire_map_backend
    python -m seeds.import_travel_guide
"""
import asyncio
import sys
import os
import re
import hashlib
from typing import Optional

sys.path.insert(0, os.getcwd())

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.models.base import Base
from app.models.user import User
from app.models.content import POIBase, UserPost, UserFootprint
from app.core.config import settings


# ════════════════════════════════════════════════════
#  地名→经纬度映射（覆盖高频城市/景区）
#  实际生产环境可用高德地理编码 API 补齐
# ════════════════════════════════════════════════════
GEO_LOOKUP = {
    "凤凰": (109.5996, 27.9482, "湖南省", "湘西州"),
    "阳朔": (110.4966, 24.7747, "广西", "桂林市"),
    "丽江": (100.2271, 26.8721, "云南省", "丽江市"),
    "婺源": (117.8613, 29.2485, "江西省", "上饶市"),
    "篁岭": (117.8613, 29.2485, "江西省", "上饶市"),
    "千岛湖": (119.0019, 29.6048, "浙江省", "杭州市"),
    "黄果树": (105.6660, 25.9918, "贵州省", "安顺市"),
    "平遥": (112.1761, 37.1897, "山西省", "晋中市"),
    "武隆": (107.7602, 29.3254, "重庆市", "重庆市"),
    "喜洲": (100.1500, 25.8167, "云南省", "大理州"),
    "荔波": (107.8838, 25.4221, "贵州省", "黔南州"),
    "嵊泗": (122.4513, 30.7253, "浙江省", "舟山市"),
    "黄姚": (111.2373, 24.3850, "广西", "贺州市"),
    "腾冲": (98.4973, 25.0197, "云南省", "保山市"),
    "四姑娘山": (102.8951, 31.0886, "四川省", "阿坝州"),
    "霞浦": (120.0046, 26.8818, "福建省", "宁德市"),
    "张家界": (110.4791, 29.1171, "湖南省", "张家界市"),
    "七彩丹霞": (100.4147, 38.5633, "甘肃省", "张掖市"),
    "张掖": (100.4147, 38.5633, "甘肃省", "张掖市"),
    "云和梯田": (119.5713, 28.1149, "浙江省", "丽水市"),
    "宏村": (117.9830, 30.0000, "安徽省", "黄山市"),
    "朱家尖": (122.3899, 29.9111, "浙江省", "舟山市"),
    "双廊": (100.1859, 25.8167, "云南省", "大理州"),
    "木格措": (101.5167, 30.1500, "四川省", "甘孜州"),
    "镇远": (108.4276, 27.0465, "贵州省", "黔东南州"),
    "云水谣": (117.4200, 24.6300, "福建省", "漳州市"),
    "九寨沟": (103.9170, 33.2600, "四川省", "阿坝州"),
    "香格里拉": (99.7067, 27.8295, "云南省", "迪庆州"),
    "普达措": (99.8600, 27.8700, "云南省", "迪庆州"),
    "崂山": (120.6206, 36.1592, "山东省", "青岛市"),
    "安吉": (119.6804, 30.6381, "浙江省", "湖州市"),
    "稻城": (100.2979, 29.0378, "四川省", "甘孜州"),
    "亚丁": (100.2979, 29.0378, "四川省", "甘孜州"),
    "武夷山": (117.9600, 27.7600, "福建省", "南平市"),
    "曲阜": (116.9863, 35.5849, "山东省", "济宁市"),
    "峨眉山": (103.4846, 29.5200, "四川省", "乐山市"),
    "大连": (121.6148, 38.9140, "辽宁省", "大连市"),
    "金石滩": (121.9700, 39.1000, "辽宁省", "大连市"),
    "色达": (100.3323, 32.2705, "四川省", "甘孜州"),
    "普陀山": (122.3850, 30.0069, "浙江省", "舟山市"),
    "景德镇": (117.1789, 29.2688, "江西省", "景德镇市"),
    "西湖": (120.1485, 30.2421, "浙江省", "杭州市"),
    "杭州": (120.1551, 30.2741, "浙江省", "杭州市"),
    "元阳": (102.8374, 23.2195, "云南省", "红河州"),
    "东极岛": (122.7650, 30.2000, "浙江省", "舟山市"),
    "呼伦贝尔": (119.7653, 49.2117, "内蒙古", "呼伦贝尔市"),
    "乐山": (103.7467, 29.5521, "四川省", "乐山市"),
    "犍为": (103.9461, 29.2102, "四川省", "乐山市"),
    "西江": (108.1550, 26.7099, "贵州省", "黔东南州"),
    "千户苗寨": (108.1550, 26.7099, "贵州省", "黔东南州"),
    "瘦西湖": (119.4225, 32.4003, "江苏省", "扬州市"),
    "扬州": (119.4225, 32.4003, "江苏省", "扬州市"),
    "竹博园": (119.6804, 30.6381, "浙江省", "湖州市"),
    "遇龙河": (110.4966, 24.7547, "广西", "桂林市"),
    "肇兴": (109.0300, 25.8500, "贵州省", "黔东南州"),
    "拉卜楞寺": (102.5100, 35.1917, "甘肃省", "甘南州"),
    "崇武": (118.9200, 24.8800, "福建省", "泉州市"),
    "莫尔道嘎": (120.7200, 51.5300, "内蒙古", "呼伦贝尔市"),
    "甪直": (120.9800, 31.2200, "江苏省", "苏州市"),
    "石浦": (121.9600, 29.2000, "浙江省", "宁波市"),
    "巍山": (100.3067, 25.2299, "云南省", "大理州"),
    "紫柏山": (106.8500, 33.5800, "陕西省", "汉中市"),
    "小七孔": (107.8838, 25.4221, "贵州省", "黔南州"),
    "大七孔": (107.8838, 25.4221, "贵州省", "黔南州"),
    "茶卡盐湖": (99.0806, 36.8014, "青海省", "海西州"),
    "桃花源": (111.4500, 28.8300, "湖南省", "常德市"),
    "黄龙": (103.8178, 32.7650, "四川省", "阿坝州"),
    "漠河": (122.5362, 52.9722, "黑龙江省", "大兴安岭"),
    "北极村": (122.5362, 52.9722, "黑龙江省", "大兴安岭"),
    "开元寺": (118.6754, 24.9078, "福建省", "泉州市"),
    "三峡": (111.0026, 30.8235, "湖北省", "宜昌市"),
    "喀纳斯": (87.0100, 48.6820, "新疆", "阿勒泰"),
    "禾木": (87.3400, 48.8400, "新疆", "阿勒泰"),
    "土楼": (117.0100, 24.5600, "福建省", "龙岩市"),
    "永定": (117.0100, 24.5600, "福建省", "龙岩市"),
    "南靖": (117.4200, 24.6300, "福建省", "漳州市"),
    "沙溪": (99.9300, 26.3600, "云南省", "大理州"),
    "莫干山": (119.8700, 30.5500, "浙江省", "湖州市"),
    "仙都": (120.0800, 28.6500, "浙江省", "丽水市"),
    "郎德": (108.0700, 26.5800, "贵州省", "黔东南州"),
    "额济纳": (101.0554, 41.9586, "内蒙古", "阿拉善盟"),
    "龙脊梯田": (110.1100, 25.7900, "广西", "桂林市"),
    "南浔": (120.4168, 30.8700, "浙江省", "湖州市"),
    "云台山": (113.4500, 35.4100, "河南省", "焦作市"),
    "若尔盖": (102.9670, 33.5739, "四川省", "阿坝州"),
    "永春": (118.2943, 25.3219, "福建省", "泉州市"),
    "玉龙雪山": (100.1848, 27.1165, "云南省", "丽江市"),
    "波密": (95.7708, 29.8614, "西藏", "林芝市"),
    "祁连": (100.2461, 38.1680, "青海省", "海北州"),
    "恩施": (109.4870, 30.2721, "湖北省", "恩施州"),
    "丰宁": (116.6487, 41.2049, "河北省", "承德市"),
    "浮梁": (117.2360, 29.3510, "江西省", "景德镇市"),
    "平江路": (120.6312, 31.3189, "江苏省", "苏州市"),
    "苏州": (120.6312, 31.3189, "江苏省", "苏州市"),
    "大理": (100.1675, 25.6065, "云南省", "大理州"),
    "洱海": (100.1859, 25.8167, "云南省", "大理州"),
    "束河": (100.1819, 26.9010, "云南省", "丽江市"),
    "兴坪": (110.5000, 24.6200, "广西", "桂林市"),
    "古堰画乡": (119.9200, 28.4500, "浙江省", "丽水市"),
    "平潭": (119.7907, 25.4982, "福建省", "福州市"),
    "塔尔寺": (101.5724, 36.4789, "青海省", "西宁市"),
    "长隆": (113.3285, 22.5965, "广东省", "珠海市"),
    "蜈支洲岛": (109.7553, 18.3122, "海南省", "三亚市"),
    "独克宗": (99.7067, 27.8295, "云南省", "迪庆州"),
    "屏山峡谷": (110.3300, 29.8800, "湖北省", "恩施州"),
    "额尔古纳": (120.1810, 50.2413, "内蒙古", "呼伦贝尔市"),
    "那拉提": (83.8000, 43.3000, "新疆", "伊犁州"),
    "延吉": (129.5095, 42.8917, "吉林省", "延边州"),
    "雅鲁藏布": (95.0000, 29.6000, "西藏", "林芝市"),
    "翡翠湖": (95.3500, 37.8500, "青海省", "海西州"),
    "松阳": (119.4792, 28.4493, "浙江省", "丽水市"),
    "鼓浪屿": (118.0683, 24.4468, "福建省", "厦门市"),
    "厦门": (118.0894, 24.4798, "福建省", "厦门市"),
    "西安": (108.9402, 34.3413, "陕西省", "西安市"),
    "临潼": (109.2142, 34.3672, "陕西省", "西安市"),
    "潮州": (116.6221, 23.6567, "广东省", "潮州市"),
    "珠海": (113.5768, 22.2706, "广东省", "珠海市"),
    "红海滩": (122.0300, 40.8600, "辽宁省", "盘锦市"),
    "喀什": (75.9892, 39.4704, "新疆", "喀什地区"),
    "三亚": (109.5082, 18.2479, "海南省", "三亚市"),
    "毕棚沟": (102.5800, 31.2700, "四川省", "阿坝州"),
    "鼎湖山": (112.5400, 23.1700, "广东省", "肇庆市"),
    "洱源": (99.9500, 26.1100, "云南省", "大理州"),
    "海螺沟": (101.9500, 29.5600, "四川省", "甘孜州"),
    "阆中": (105.9700, 31.5800, "四川省", "南充市"),
    "长岛": (120.7300, 37.9200, "山东省", "烟台市"),
    "西街": (110.4966, 24.7747, "广西", "桂林市"),
    "柯桥": (120.4883, 30.0652, "浙江省", "绍兴市"),
    "宝兴": (102.8144, 30.3683, "四川省", "雅安市"),
    "明月山": (114.0800, 27.5600, "江西省", "宜春市"),
    "利川": (108.9361, 30.2913, "湖北省", "恩施州"),
    "阿坝": (101.7068, 32.9020, "四川省", "阿坝州"),
    "西递": (117.9885, 30.0477, "安徽省", "黄山市"),
    "黄山": (118.1689, 30.1375, "安徽省", "黄山市"),
    "歙县": (118.4280, 29.8616, "安徽省", "黄山市"),
    "徽州": (118.4280, 29.8616, "安徽省", "黄山市"),
    # ── 补充：大城市 & 常见景区 ──
    "北京": (116.4074, 39.9042, "北京市", "北京市"),
    "故宫": (116.3972, 39.9163, "北京市", "北京市"),
    "上海": (121.4737, 31.2304, "上海市", "上海市"),
    "外滩": (121.4905, 31.2398, "上海市", "上海市"),
    "成都": (104.0657, 30.5723, "四川省", "成都市"),
    "都江堰": (103.6190, 31.0029, "四川省", "成都市"),
    "锦江": (104.0836, 30.6583, "四川省", "成都市"),
    "深圳": (114.0579, 22.5431, "广东省", "深圳市"),
    "华侨城": (113.9854, 22.5351, "广东省", "深圳市"),
    "广州": (113.2644, 23.1291, "广东省", "广州市"),
    "白云山": (113.2984, 23.1849, "广东省", "广州市"),
    "昆明": (102.8329, 25.0389, "云南省", "昆明市"),
    "石林": (103.2713, 24.7718, "云南省", "昆明市"),
    "哈尔滨": (126.6424, 45.7570, "黑龙江省", "哈尔滨市"),
    "冰雪大世界": (126.6307, 45.7930, "黑龙江省", "哈尔滨市"),
    "太阳岛": (126.6177, 45.7915, "黑龙江省", "哈尔滨市"),
    "中央大街": (126.6177, 45.7725, "黑龙江省", "哈尔滨市"),
    "拉萨": (91.1322, 29.6604, "西藏", "拉萨市"),
    "布达拉宫": (91.1176, 29.6558, "西藏", "拉萨市"),
    "敦煌": (94.6618, 40.1421, "甘肃省", "酒泉市"),
    "莫高窟": (94.8053, 40.0368, "甘肃省", "酒泉市"),
    "鸣沙山": (94.6714, 40.0816, "甘肃省", "酒泉市"),
    "月牙泉": (94.6714, 40.0816, "甘肃省", "酒泉市"),
    "沈阳": (123.4315, 41.8057, "辽宁省", "沈阳市"),
    "沈阳故宫": (123.4555, 41.7968, "辽宁省", "沈阳市"),
    "洛阳": (112.4539, 34.6197, "河南省", "洛阳市"),
    "龙门石窟": (112.4713, 34.5578, "河南省", "洛阳市"),
    "白马寺": (112.5680, 34.7250, "河南省", "洛阳市"),
    "济南": (117.0009, 36.6758, "山东省", "济南市"),
    "趵突泉": (117.0100, 36.6580, "山东省", "济南市"),
    "福州": (119.2965, 26.0745, "福建省", "福州市"),
    "三坊七巷": (119.2921, 26.0878, "福建省", "福州市"),
    "兰州": (103.8343, 36.0611, "甘肃省", "兰州市"),
    "崆峒山": (106.5169, 35.5413, "甘肃省", "平凉市"),
    "白塔山": (103.8232, 36.0725, "甘肃省", "兰州市"),
    "呼和浩特": (111.7510, 40.8427, "内蒙古", "呼和浩特市"),
    "赤峰": (118.9564, 42.2580, "内蒙古", "赤峰市"),
    "阿斯哈图": (117.5333, 43.3167, "内蒙古", "赤峰市"),
    "长白山": (128.0827, 41.9536, "吉林省", "延边州"),
    "长春": (125.3245, 43.8868, "吉林省", "长春市"),
    "吉林": (126.5501, 43.8436, "吉林省", "吉林市"),
    "南京": (118.7969, 32.0603, "江苏省", "南京市"),
    "夫子庙": (118.7877, 32.0226, "江苏省", "南京市"),
    "庐山": (115.9727, 29.5628, "江西省", "九江市"),
    "秦皇岛": (119.5865, 39.9425, "河北省", "秦皇岛市"),
    "山海关": (119.7757, 40.0175, "河北省", "秦皇岛市"),
    "西双版纳": (100.7971, 22.0017, "云南省", "西双版纳州"),
    "景洪": (100.7971, 22.0017, "云南省", "西双版纳州"),
    "贵阳": (106.6302, 26.6477, "贵州省", "贵阳市"),
    "青岩古镇": (106.5866, 26.4761, "贵州省", "贵阳市"),
    "青岛": (120.3826, 36.0671, "山东省", "青岛市"),
    "西宁": (101.7782, 36.6171, "青海省", "西宁市"),
    "丹东": (124.3548, 40.0006, "辽宁省", "丹东市"),
    "鸭绿江": (124.3951, 40.1196, "辽宁省", "丹东市"),
    "开封": (114.3070, 34.7971, "河南省", "开封市"),
    "清明上河园": (114.3529, 34.7879, "河南省", "开封市"),
    "龙亭": (114.3530, 34.8019, "河南省", "开封市"),
    "安阳": (114.3928, 36.0997, "河南省", "安阳市"),
    "殷墟": (114.3201, 36.1227, "河南省", "安阳市"),
    "郑州": (113.6254, 34.7466, "河南省", "郑州市"),
    "少林寺": (112.9370, 34.5076, "河南省", "郑州市"),
    "嵩山": (112.9445, 34.4844, "河南省", "郑州市"),
    "延安": (109.4896, 36.5853, "陕西省", "延安市"),
    "黄帝陵": (109.2675, 35.5930, "陕西省", "延安市"),
    "张家口": (114.8872, 40.8245, "河北省", "张家口市"),
    "崇礼": (115.2826, 40.9742, "河北省", "张家口市"),
    "遵义": (106.9371, 27.7256, "贵州省", "遵义市"),
    "赤水": (105.6976, 28.5901, "贵州省", "遵义市"),
    "大同": (113.2955, 40.0903, "山西省", "大同市"),
    "云冈石窟": (113.1300, 40.1100, "山西省", "大同市"),
    "宁夏": (106.2586, 38.4712, "宁夏", "银川市"),
    "沙坡头": (104.9503, 37.4458, "宁夏", "中卫市"),
    "中卫": (104.9503, 37.4458, "宁夏", "中卫市"),
    "温州": (120.6994, 28.0015, "浙江省", "温州市"),
    "雁荡山": (121.0689, 28.3837, "浙江省", "温州市"),
    "洞头": (121.1568, 27.8362, "浙江省", "温州市"),
    "甘南": (102.9110, 34.9860, "甘肃省", "甘南州"),
    "扎尕那": (103.2086, 34.2511, "甘肃省", "甘南州"),
    "夏河": (102.5100, 35.1917, "甘肃省", "甘南州"),
    "阿尔山": (119.9432, 47.1774, "内蒙古", "兴安盟"),
    "榆林": (109.7345, 38.2903, "陕西省", "榆林市"),
    "镇北堡": (106.0896, 38.5816, "宁夏", "银川市"),
    "三沙": (112.3383, 16.8310, "海南省", "三沙市"),
    "永兴岛": (112.3383, 16.8310, "海南省", "三沙市"),
    "漓江": (110.2880, 24.9660, "广西", "桂林市"),
    "桂林": (110.2990, 25.2742, "广西", "桂林市"),
}


def lookup_geo(destination: str):
    """
    根据目的地文本查找经纬度
    优先匹配最长的键名，同时考虑城市/省份上下文

    Args:
        destination: 目的地名称

    Returns:
        (lng, lat, province, city) or None
    """
    # 收集所有匹配的候选项，按键名长度降序
    candidates = []
    for key in sorted(GEO_LOOKUP.keys(), key=len, reverse=True):
        if key in destination:
            candidates.append((key, GEO_LOOKUP[key]))

    if not candidates:
        return None

    # 如果只有一个匹配或最长匹配远大于其他的，直接返回最长
    if len(candidates) == 1:
        return candidates[0][1]

    # 多个候选时：优先选择城市/省份也出现在目的地名中的（上下文一致）
    for key, val in candidates:
        lng, lat, province, city = val
        # 如果省份或城市名也出现在目的地文本中，说明上下文匹配
        city_short = city.rstrip("市州区县")
        province_short = province.rstrip("省市")
        if city_short and city_short in destination:
            return val
        if province_short and province_short in destination:
            return val

    # 兜底：返回最长键名对应的结果
    return candidates[0][1]


def generate_poi_id(destination: str) -> str:
    """根据目的地名称生成稳定的 poi_id"""
    h = hashlib.md5(destination.encode()).hexdigest()[:8]
    # 取关键地名做前缀
    short = re.sub(r'[省市县区州镇村岛]', '', destination)
    short = short[-6:]  # 最多6个中文字符
    return f"tg-{short}-{h}"


async def main():
    import openpyxl

    xlsx_path = os.path.join(os.path.dirname(os.getcwd()), "travel_guide.xlsx")
    if not os.path.exists(xlsx_path):
        # 尝试当前目录
        xlsx_path = os.path.join(os.getcwd(), "..", "travel_guide.xlsx")
    if not os.path.exists(xlsx_path):
        xlsx_path = r"d:\vibe_grid\travel_guide.xlsx"

    print(f"{'='*60}")
    print(f"  《灵感经纬》travel_guide.xlsx 数据集导入工具")
    print(f"{'='*60}")

    wb = openpyxl.load_workbook(xlsx_path, read_only=True)
    ws = wb["Sheet1"]

    # 读取所有数据行（跳过表头）
    rows = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[0]:  # 有目的地
            # 安全取值，防止列数不足
            def safe_col(idx):
                return str(row[idx] or "").strip() if idx < len(row) and row[idx] else ""
            rows.append({
                "destination": safe_col(0),
                "transport": safe_col(1),
                "accommodation": safe_col(2),
                "attractions": safe_col(3),
                "food": safe_col(4),
                "tips": safe_col(5),
                "thoughts": safe_col(6)
            })
    wb.close()

    print(f"📦 共读取 {len(rows)} 条攻略数据\n")

    # 去重：同一目的地合并内容
    merged = {}
    for r in rows:
        key = r["destination"]
        if key not in merged:
            merged[key] = r
        else:
            # 追加不同的内容
            for field in ["transport", "accommodation", "attractions", "food", "tips", "thoughts"]:
                if r[field] and r[field] not in merged[key][field]:
                    merged[key][field] += f"\n\n{r[field]}"

    unique_destinations = list(merged.values())
    print(f"📍 去重后 {len(unique_destinations)} 个唯一目的地\n")

    # 连接数据库
    engine = create_async_engine(str(settings.DATABASE_URL), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    # 获取或创建系统用户
    async with async_session() as session:
        system_user = await _get_or_create_system_user(session)
        system_user_id = str(system_user.id)
        await session.commit()

    # 初始化 RAG
    from app.ai_core.rag_engine import RAGEngine
    rag = RAGEngine()

    poi_created = 0
    post_created = 0
    rag_success = 0
    rag_fail = 0

    for i, item in enumerate(unique_destinations, 1):
        dest = item["destination"]
        geo = lookup_geo(dest)

        if not geo:
            print(f"  [{i}/{len(unique_destinations)}] ⚠️  无法定位: {dest}，跳过")
            continue

        lng, lat, province, city = geo
        poi_id = generate_poi_id(dest)

        # ── 1. 创建或更新 POI ──
        async with async_session() as session:
            existing = await session.execute(
                select(POIBase).where(POIBase.poi_id == poi_id)
            )
            poi = existing.scalar_one_or_none()

            if not poi:
                # 生成 AI 摘要（从景点和美食中提取核心信息）
                summary_parts = []
                if item["attractions"]:
                    # 取前200字
                    summary_parts.append(item["attractions"][:200])
                if item["food"]:
                    summary_parts.append("美食：" + item["food"][:100])

                ai_summary = "。".join(summary_parts)[:300]

                # 提取 tips
                tips_list = []
                if item["tips"]:
                    # 按数字编号或换行分割
                    raw_tips = re.split(r'\d+\.\s*|\n', item["tips"])
                    tips_list = [t.strip() for t in raw_tips if t.strip() and len(t.strip()) > 5][:5]

                # 判断分类
                category = "景点"
                if any(kw in dest for kw in ["美食", "小吃", "餐"]):
                    category = "美食"
                elif any(kw in dest for kw in ["古城", "古镇", "古村", "故居", "寺"]):
                    category = "人文"
                elif any(kw in dest for kw in ["山", "湖", "海", "草原", "梯田", "瀑布", "峡谷", "雪山", "沟"]):
                    category = "自然"

                poi = POIBase(
                    poi_id=poi_id,
                    name=dest,
                    category=category,
                    longitude=lng,
                    latitude=lat,
                    address=f"{province}{city}",
                    ai_summary_static=ai_summary,
                    tips=tips_list,
                    rating=4.5
                )
                session.add(poi)
                await session.flush()
                poi_created += 1

            await session.commit()

        # ── 2. 创建 UserPost (每个目的地一条汇总贴) ──
        # 将 xlsx 的各列拼成一段完整的攻略文本
        full_text_parts = []
        if item["transport"]:
            full_text_parts.append(f"【交通】{item['transport']}")
        if item["accommodation"]:
            full_text_parts.append(f"【住宿】{item['accommodation']}")
        if item["attractions"]:
            full_text_parts.append(f"【景点】{item['attractions']}")
        if item["food"]:
            full_text_parts.append(f"【美食】{item['food']}")
        if item["tips"]:
            full_text_parts.append(f"【贴士】{item['tips']}")
        if item["thoughts"]:
            full_text_parts.append(f"【感悟】{item['thoughts']}")

        full_text = "\n".join(full_text_parts)

        async with async_session() as session:
            post = UserPost(
                author_id=system_user_id,
                poi_id=poi_id,
                content=full_text[:2000],  # 限制长度
                images=[],
                tags=["攻略数据集", "来源:travel_guide"],
                is_vectorized=False
            )
            session.add(post)
            await session.flush()
            post_id = str(post.id)
            await session.commit()
            post_created += 1

        # ── 3. 向量化入 ChromaDB ──
        # 分段向量化：景点、美食、交通、tips 各自独立入库，提高检索精度
        segments = []
        if item["attractions"]:
            segments.append(("attractions", f"{dest}景点攻略：{item['attractions']}"))
        if item["food"]:
            segments.append(("food", f"{dest}美食推荐：{item['food']}"))
        if item["transport"]:
            segments.append(("transport", f"{dest}交通指南：{item['transport']}"))
        if item["accommodation"]:
            segments.append(("accommodation", f"{dest}住宿推荐：{item['accommodation']}"))
        if item["tips"]:
            segments.append(("tips", f"{dest}实用贴士：{item['tips']}"))

        seg_ok = 0
        for seg_type, seg_text in segments:
            doc_id = f"tg_{poi_id}_{seg_type}"
            try:
                ok = await rag.vectorize_external_content(
                    doc_id=doc_id,
                    text=seg_text[:500],  # 每段控制长度
                    poi_id=poi_id,
                    source="dataset",
                    source_platform="travel_guide",
                    extra_meta={
                        "destination": dest,
                        "segment_type": seg_type,
                        "province": province,
                        "city": city
                    }
                )
                if ok:
                    seg_ok += 1
            except Exception as e:
                print(f"    RAG segment [{seg_type}] failed: {e}")

        if seg_ok > 0:
            rag_success += 1
            # 标记已向量化
            async with async_session() as session:
                from sqlalchemy import update
                await session.execute(
                    update(UserPost).where(UserPost.id == post_id).values(is_vectorized=True)
                )
                await session.commit()
        else:
            rag_fail += 1

        status = "✅" if seg_ok > 0 else "❌"
        print(f"  [{i}/{len(unique_destinations)}] {status} {dest} (POI:{poi_id}, {seg_ok}/{len(segments)}段入库)")

    await engine.dispose()

    print(f"\n{'='*60}")
    print(f"📊 导入完成:")
    print(f"   POI 新建: {poi_created}")
    print(f"   动态写入: {post_created}")
    print(f"   RAG 成功: {rag_success} | 失败: {rag_fail}")
    print(f"{'='*60}")


async def _get_or_create_system_user(session) -> User:
    """获取或创建系统导入专用用户"""
    result = await session.execute(
        select(User).where(User.phone == "system_import")
    )
    user = result.scalar_one_or_none()
    if user:
        return user

    user = User(
        phone="system_import",
        password_hash="not_a_real_password",
        nickname="灵感经纬·攻略收录",
        mbti_type="INFJ",
        avatar_url="",
    )
    session.add(user)
    await session.flush()
    print("🤖 创建了系统导入用户: 灵感经纬·攻略收录")
    return user


if __name__ == "__main__":
    asyncio.run(main())
