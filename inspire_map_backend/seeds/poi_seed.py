"""
POI 种子数据脚本
初始化多城市的基础 POI 数据（北京 / 成都 / 上海）

运行方式:
    cd inspire_map_backend
    python -m seeds.poi_seed
"""
import asyncio
import sys
import os

# 将项目路径添加到 sys.path
sys.path.insert(0, os.getcwd())

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

# 核心：必须先导入所有模型以确保 Registry 完整
from app.models.base import Base
from app.models.user import User
from app.models.content import POIBase, UserPost, UserFootprint # 提前导入所有关系模型
from app.core.config import settings


# ════════════════════════════════════════════════════
#  北京地区 POI 种子数据
# ════════════════════════════════════════════════════
BEIJING_POIS = [
    {
        "poi_id": "bj-001",
        "name": "故宫",
        "category": "景点",
        "sub_category": "历史",
        "longitude": 116.3975,
        "latitude": 39.9087,
        "address": "北京市东城区景山前街4号",
        "ai_summary_static": "故宫是中国明清两代的皇家宫殿，世界现存最大规模的古代宫殿建筑群。建议从午门进入，沿中轴线游览约需3小时。珍宝馆和钟表馆是隐藏精华，别错过。",
        "ai_summary_mbti": {
            "INTJ": "故宫的建筑规制和政治隐喻值得深度解读。建议避开中轴线人流，直奔西六宫和珍宝馆，那里藏着最耐人寻味的历史细节。",
            "ENFP": "故宫超适合拍照！午门广场的对称构图、角楼的倒影都是出片神器。记得穿汉服来，氛围感直接拉满！",
            "ISFJ": "建议提前在官网预约并下载导览APP。按中轴线→东六宫→珍宝馆的顺序游览最省力，全程约4小时。",
        },
        "rating": 4.8,
        "best_visit_time": "建议平日去，节假日人流量是平日的3-5倍；8:30开门时进入可避开人流高峰",
        "tips": ["提前在故宫官网预约门票", "建议请导游或使用导览APP", "午门进入，神武门离开", "周一闭馆"],
    },
    {
        "poi_id": "bj-002",
        "name": "南锣鼓巷",
        "category": "美食",
        "sub_category": "文化",
        "longitude": 116.4039,
        "latitude": 39.9407,
        "address": "北京市东城区南锣鼓巷",
        "ai_summary_static": "南锣鼓巷是北京著名的胡同文化街区，集市集、美食与文艺于一体，适合漫步探索老北京风情。主街商业气息浓，真正的惊喜在旁边的胡同里。",
        "rating": 4.5,
        "best_visit_time": "下午4点后光线最美；平日比周末人少一半",
        "tips": ["不要在主街吃饭，价格虚高", "钻进旁边的小胡同有惊喜", "文宇奶酪店需要排队但值得"],
    },
    {
        "poi_id": "bj-003",
        "name": "颐和园",
        "category": "景点",
        "sub_category": "历史",
        "longitude": 116.2733,
        "latitude": 39.9996,
        "address": "北京市海淀区新建宫门路19号",
        "ai_summary_static": "颐和园是中国现存规模最大、保存最完整的皇家园林，昆明湖与万寿山构成绝美山水画卷。十七孔桥的夕阳是必看景色。",
        "rating": 4.7,
        "best_visit_time": "建议下午去，看夕阳下的十七孔桥；4-5月昆明湖边柳树最美",
        "tips": ["北宫门进可以先爬山看佛香阁", "昆明湖可以坐船，节省脚力", "联票比大门票多30元但值得"],
    },
    {
        "poi_id": "bj-004",
        "name": "798艺术区",
        "category": "文化",
        "sub_category": "艺术",
        "longitude": 116.4977,
        "latitude": 39.9836,
        "address": "北京市朝阳区酒仙桥路4号",
        "ai_summary_static": "798艺术区是北京著名的当代艺术展览区，融合工业遗产与艺术创作。周末常有限定展览和艺术市集，适合文艺青年慢逛半天。",
        "rating": 4.3,
        "best_visit_time": "周末下午常有新展开幕；平时免费展览居多",
        "tips": ["园区很大，至少需要半天", "里面的餐厅价格偏高，建议自带食物", "UCCA是必看的美术馆"],
    },
    {
        "poi_id": "bj-005",
        "name": "天坛",
        "category": "景点",
        "sub_category": "历史",
        "longitude": 116.4109,
        "latitude": 39.8822,
        "address": "北京市东城区天坛公园内",
        "ai_summary_static": "天坛是明清两代皇帝祭天祈谷的场所，祈年殿的三重檐攒尖顶是中国古建筑的巅峰之作。清晨来这里还能感受北京大爷大妈的市井烟火气。",
        "rating": 4.6,
        "best_visit_time": "建议清晨6:30前到达，可以拍到晨练的烟火气",
        "tips": ["东门进离祈年殿最近", "联票比大门票多14元，绝对值得", "回音壁需要耐心体验"],
    },
    {
        "poi_id": "bj-006",
        "name": "三里屯",
        "category": "购物",
        "sub_category": "商圈",
        "longitude": 116.4536,
        "latitude": 39.9385,
        "address": "北京市朝阳区三里屯路",
        "ai_summary_static": "三里屯是北京最时尚的商圈，夜生活丰富。太古里南区以设计品牌为主，北区偏高端，附近巷子里藏着很棒的精酿酒吧。",
        "rating": 4.4,
        "best_visit_time": "晚上6点后氛围最佳；周末下午经常有快闪活动",
        "tips": ["南区价格亲民，北区奢牌集中", "附近巷子里有很棒的精酿酒吧", "适合夜间打卡拍照"],
    },
    {
        "poi_id": "bj-007",
        "name": "北海公园",
        "category": "景点",
        "sub_category": "自然",
        "longitude": 116.3922,
        "latitude": 39.9289,
        "address": "北京市西城区文津街1号",
        "ai_summary_static": "北海公园是北京最古老的皇家园林，白塔矗立于琼华岛之上，湖光塔影构成经典北京画面。可以租船游湖，价格实惠。",
        "rating": 4.5,
        "best_visit_time": "春秋两季最美；冬季可以看冰封的湖面",
        "tips": ["从南门进可以直接看到白塔", "可以租船游湖，价格合理", "仿膳饭庄的豌豆黄值得一试"],
    },
    {
        "poi_id": "bj-008",
        "name": "国家博物馆",
        "category": "文化",
        "sub_category": "博物馆",
        "longitude": 116.4066,
        "latitude": 39.9042,
        "address": "北京市东城区东长安街16号",
        "ai_summary_static": "中国国家博物馆是世界上建筑面积最大的博物馆，收藏了从远古到现代的珍贵文物。后母戊鼎、四羊方尊等国宝级文物不容错过。",
        "rating": 4.7,
        "best_visit_time": "建议提前在官网预约；平日下午人最少",
        "tips": ["安检非常严格，不要带打火机", "建议预留4小时以上", "有免费定时讲解", "周一闭馆"],
    },
    {
        "poi_id": "bj-009",
        "name": "什刹海",
        "category": "景点",
        "sub_category": "自然",
        "longitude": 116.3886,
        "latitude": 39.9388,
        "address": "北京市西城区什刹海",
        "ai_summary_static": "什刹海是北京内城唯一一处开放水域，前海、后海、西海三海相连。白天可以环湖骑行，晚上酒吧街灯火通明，是感受北京新旧交融的绝佳地点。",
        "rating": 4.4,
        "best_visit_time": "傍晚时分最佳，夕阳映湖面；夏天夜晚最热闹",
        "tips": ["烟袋斜街值得一逛", "后海酒吧驻唱水平参差不齐", "银锭桥看西山是经典角度"],
    },
    {
        "poi_id": "bj-010",
        "name": "胡同串子咖啡",
        "category": "美食",
        "sub_category": "咖啡",
        "longitude": 116.4042,
        "latitude": 39.9415,
        "address": "北京市东城区方家胡同46号",
        "ai_summary_static": "隐藏在胡同深处的独立咖啡馆，老板是咖啡师出身，手冲咖啡水平极高。只有6个座位，适合安静地消磨一个下午。",
        "rating": 4.6,
        "best_visit_time": "任何时候都可以，这里就是用来发呆的",
        "tips": ["只有6个座位，建议提前打电话", "招牌是手冲肯尼亚", "不接受外卖订单"],
    },
    {
        "poi_id": "bj-011",
        "name": "簋街",
        "category": "美食",
        "sub_category": "夜宵",
        "longitude": 116.4311,
        "latitude": 39.9361,
        "address": "北京市东城区东直门内大街",
        "ai_summary_static": "簋街是北京最有名的美食街，以麻辣小龙虾闻名。深夜时分最有氛围，几百米长的街道灯火通明，是北京夜生活的缩影。",
        "rating": 4.3,
        "best_visit_time": "晚上8点后最热闹；夏天夜宵氛围最好",
        "tips": ["胡大饭馆的小龙虾是招牌", "晚上排队很长，建议提前取号", "注意控制预算，容易点多"],
    },
]

# ════════════════════════════════════════════════════
#  成都地区 POI 种子数据
# ════════════════════════════════════════════════════
CHENGDU_POIS = [
    {
        "poi_id": "cd-001",
        "name": "武侯祠",
        "category": "景点",
        "sub_category": "历史",
        "longitude": 104.0476,
        "latitude": 30.6462,
        "address": "成都市武侯区武侯祠大街231号",
        "ai_summary_static": "武侯祠是纪念诸葛亮的祠堂，也是全国影响最大的三国遗迹博物馆。红墙竹影的小路是最出片的角度，适合历史爱好者细细品味。",
        "rating": 4.6,
        "best_visit_time": "清晨或傍晚人少，光线也最好",
        "tips": ["与锦里一墙之隔，可以一起逛", "红墙竹影小路必拍", "讲解器值得租"],
    },
    {
        "poi_id": "cd-002",
        "name": "锦里",
        "category": "美食",
        "sub_category": "文化",
        "longitude": 104.0487,
        "latitude": 30.6451,
        "address": "成都市武侯区武侯祠大街231号附1号",
        "ai_summary_static": "锦里是成都最具代表性的古街，汇集了川味小吃和手工艺品。虽然商业化程度高，但夜晚灯笼亮起时的氛围感无可替代。",
        "rating": 4.3,
        "best_visit_time": "晚上灯笼亮起后最美；平日比周末好逛",
        "tips": ["三大炮、糖油果子必吃", "主街商业化严重，小巷更有意思", "晚上拍照效果更好"],
    },
    {
        "poi_id": "cd-003",
        "name": "大熊猫繁育研究基地",
        "category": "景点",
        "sub_category": "自然",
        "longitude": 104.1468,
        "latitude": 30.7328,
        "address": "成都市成华区熊猫大道1375号",
        "ai_summary_static": "成都大熊猫基地是全球最大的大熊猫人工繁育基地。清晨是看熊猫进食和活动的最佳时间，下午熊猫基本都在睡觉。",
        "rating": 4.8,
        "best_visit_time": "务必清晨7:30到达，9点后熊猫开始睡觉",
        "tips": ["一定要早去！下午熊猫全在睡觉", "月亮产房看幼崽需排队", "园区很大，建议坐观光车到山顶再步行下山"],
    },
    {
        "poi_id": "cd-004",
        "name": "春熙路太古里",
        "category": "购物",
        "sub_category": "商圈",
        "longitude": 104.0817,
        "latitude": 30.6552,
        "address": "成都市锦江区中纱帽街8号",
        "ai_summary_static": "太古里是成都最时尚的开放式商业街区，低密度建筑与传统大慈寺和谐共存。方所书店、Line Friends等是必逛的特色店铺。",
        "rating": 4.5,
        "best_visit_time": "下午到晚上最佳；周末有各种快闪活动",
        "tips": ["方所书店可以逛很久", "IFS楼顶的熊猫爬墙是打卡点", "大慈寺可以免费进入"],
    },
    {
        "poi_id": "cd-005",
        "name": "人民公园鹤鸣茶社",
        "category": "美食",
        "sub_category": "茶馆",
        "longitude": 104.0597,
        "latitude": 30.6603,
        "address": "成都市青羊区少城路12号人民公园内",
        "ai_summary_static": "鹤鸣茶社是成都最老牌的露天茶馆，体验老成都生活方式的最佳去处。点一杯盖碗茶坐上一下午，感受成都人的慢生活哲学。",
        "ai_summary_mbti": {
            "INTJ": "鹤鸣茶社是观察成都市民社会的最佳窗口。点杯竹叶青，带本书，在这里可以安静思考一个下午。",
            "ESFP": "来这里一定要体验掏耳朵！然后和旁边的大爷大妈聊天，他们会告诉你最地道的成都玩法。",
        },
        "rating": 4.7,
        "best_visit_time": "下午2-5点最有氛围，可以感受地道的成都慢生活",
        "tips": ["盖碗茶10-20元不等，性价比极高", "可以体验采耳服务", "周围荷花池拍照很美"],
    },
    {
        "poi_id": "cd-006",
        "name": "宽窄巷子",
        "category": "景点",
        "sub_category": "文化",
        "longitude": 104.0558,
        "latitude": 30.6696,
        "address": "成都市青羊区宽窄巷子",
        "ai_summary_static": "宽窄巷子由宽巷子、窄巷子、井巷子三条平行的老街组成，是成都遗留的清朝古街道。适合体验成都的市井文化与休闲生活。",
        "rating": 4.4,
        "best_visit_time": "清晨或晚上人少体验好；白天人流量很大",
        "tips": ["窄巷子比宽巷子安静", "三联韬奋书店值得一坐", "避开节假日"],
    },
    {
        "poi_id": "cd-007",
        "name": "杜甫草堂",
        "category": "景点",
        "sub_category": "历史",
        "longitude": 104.0341,
        "latitude": 30.6598,
        "address": "成都市青羊区青华路37号",
        "ai_summary_static": "杜甫草堂是唐代诗人杜甫流寓成都时的故居，也是中国规模最大的杜甫纪念建筑群。竹林幽深，茅屋古朴，是闹市中难得的清幽之地。",
        "rating": 4.5,
        "best_visit_time": "春季竹林最美；清晨游客少体验好",
        "tips": ["建议租讲解器，了解诗歌背景", "花径和茅屋是核心景点", "隔壁浣花溪公园免费且很美"],
    },
    {
        "poi_id": "cd-008",
        "name": "建设路小吃街",
        "category": "美食",
        "sub_category": "小吃",
        "longitude": 104.1029,
        "latitude": 30.6655,
        "address": "成都市成华区建设路",
        "ai_summary_static": "建设路是成都本地人最爱的小吃聚集地，比锦里更地道、更便宜。降龙爪爪、钵钵鸡、冰粉都是必吃项目，晚上氛围最好。",
        "rating": 4.6,
        "best_visit_time": "晚上6点后最热闹，适合觅食",
        "tips": ["降龙爪爪排队长但值得", "钵钵鸡选冷锅的更地道", "夏天一定要来杯冰粉"],
    },
    {
        "poi_id": "cd-009",
        "name": "金沙遗址博物馆",
        "category": "文化",
        "sub_category": "博物馆",
        "longitude": 104.0145,
        "latitude": 30.6802,
        "address": "成都市青羊区金沙遗址路2号",
        "ai_summary_static": "金沙遗址博物馆展示了古蜀文明的辉煌成就，太阳神鸟金饰已成为中国文化遗产标志。遗迹馆可以看到真实的考古发掘现场。",
        "rating": 4.6,
        "best_visit_time": "平日下午人少；周末有亲子活动",
        "tips": ["太阳神鸟是镇馆之宝", "遗迹馆比陈列馆更震撼", "可以和三星堆联票参观"],
    },
]

# ════════════════════════════════════════════════════
#  上海地区 POI 种子数据
# ════════════════════════════════════════════════════
SHANGHAI_POIS = [
    {
        "poi_id": "sh-001",
        "name": "外滩",
        "category": "景点",
        "sub_category": "建筑",
        "longitude": 121.4913,
        "latitude": 31.2400,
        "address": "上海市黄浦区中山东一路",
        "ai_summary_static": "外滩是上海的标志性景观，一侧是万国建筑博览群，一侧是浦东陆家嘴天际线。夜景是灵魂，建议日落前到达占据好位置。",
        "ai_summary_mbti": {
            "INTJ": "外滩的建筑群是近代上海历史的活化石。建议拿一本《外滩建筑地图》，逐栋了解每栋大楼背后的故事。",
            "ENFP": "外滩夜景绝了！记得站在南京路步行街出口位置，可以同时拍到万国建筑和对岸三件套。",
        },
        "rating": 4.7,
        "best_visit_time": "日落前1小时到达等夜景；避开国庆等大型节假日",
        "tips": ["南京路步行街出口是最佳拍摄点", "可以坐轮渡到浦东只要2元", "注意防扒手"],
    },
    {
        "poi_id": "sh-002",
        "name": "豫园",
        "category": "景点",
        "sub_category": "历史",
        "longitude": 121.4926,
        "latitude": 31.2275,
        "address": "上海市黄浦区安仁街137号",
        "ai_summary_static": "豫园是上海最著名的古典园林，始建于明代，亭台楼阁错落有致。园外的城隍庙商圈汇集了各种上海特色小吃和纪念品。",
        "rating": 4.4,
        "best_visit_time": "开门时进入人最少；灯会期间别错过",
        "tips": ["南翔馒头店的小笼包是经典", "园内比园外安静很多", "春节期间有灯会"],
    },
    {
        "poi_id": "sh-003",
        "name": "田子坊",
        "category": "文化",
        "sub_category": "艺术",
        "longitude": 121.4706,
        "latitude": 31.2110,
        "address": "上海市黄浦区泰康路210弄",
        "ai_summary_static": "田子坊是上海最具文艺气息的弄堂创意园区，石库门建筑里藏着画廊、手作工坊和设计师店铺。适合午后闲逛，感受上海的小资情调。",
        "rating": 4.2,
        "best_visit_time": "下午2-5点最佳；工作日人少体验好",
        "tips": ["很多店铺只收现金", "弄堂深处有惊喜", "可以和思南公馆一起逛"],
    },
    {
        "poi_id": "sh-004",
        "name": "武康路",
        "category": "景点",
        "sub_category": "建筑",
        "longitude": 121.4379,
        "latitude": 31.2108,
        "address": "上海市徐汇区武康路",
        "ai_summary_static": "武康路是上海最有腔调的马路之一，梧桐树荫下排列着各式洋楼别墅。武康大楼的船型建筑是网红打卡点，但街道本身的生活气息才是精华。",
        "rating": 4.6,
        "best_visit_time": "秋天梧桐叶变色时最美；清晨散步体验最好",
        "tips": ["武康大楼打卡人很多，建议早去", "安福路和武康路交叉口有很多咖啡馆", "可以骑自行车慢慢逛"],
    },
    {
        "poi_id": "sh-005",
        "name": "思南公馆",
        "category": "文化",
        "sub_category": "历史",
        "longitude": 121.4721,
        "latitude": 31.2176,
        "address": "上海市黄浦区思南路55号",
        "ai_summary_static": "思南公馆保留了51栋花园洋房，是上海最集中的花园住宅群。周末常有读书会和文化沙龙，是感受海派文化底蕴的好去处。",
        "rating": 4.4,
        "best_visit_time": "周末下午有文化活动；春天梧桐树下最美",
        "tips": ["周末集市值得逛", "思南书局是网红书店", "可以和田子坊串联游览"],
    },
    {
        "poi_id": "sh-006",
        "name": "M50创意园",
        "category": "文化",
        "sub_category": "艺术",
        "longitude": 121.4445,
        "latitude": 31.2479,
        "address": "上海市普陀区莫干山路50号",
        "ai_summary_static": "M50是上海最纯粹的当代艺术园区，入驻了大量画廊和艺术工作室。比起798的商业气息，M50更加安静和专注于艺术本身。",
        "rating": 4.3,
        "best_visit_time": "工作日下午最安静；开幕展通常在周末",
        "tips": ["香格纳画廊是标杆", "很多展览免费", "附近的苏州河畔适合散步"],
    },
    {
        "poi_id": "sh-007",
        "name": "上海博物馆（人民广场馆）",
        "category": "文化",
        "sub_category": "博物馆",
        "longitude": 121.4737,
        "latitude": 31.2294,
        "address": "上海市黄浦区人民大道201号",
        "ai_summary_static": "上海博物馆拥有近百万件珍贵文物，青铜器和陶瓷馆尤为精彩。建筑本身造型如古代铜鼎，免费开放，是了解中华文明的宝库。",
        "rating": 4.7,
        "best_visit_time": "工作日上午人少；建议预留3小时",
        "tips": ["免费但需预约", "青铜器馆是镇馆之宝", "有免费讲解，关注公众号预约"],
    },
    {
        "poi_id": "sh-008",
        "name": "愚园路",
        "category": "美食",
        "sub_category": "咖啡",
        "longitude": 121.4302,
        "latitude": 31.2258,
        "address": "上海市长宁区愚园路",
        "ai_summary_static": "愚园路是上海最有生活气息的马路之一，梧桐掩映下藏着无数精品咖啡馆和买手店。比武康路更本地化、更有烟火气。",
        "rating": 4.5,
        "best_visit_time": "下午茶时段最佳；比武康路人少",
        "tips": ["Manner Coffee最早的门店在附近", "弄堂里的小店比路边更有意思", "适合citywalk"],
    },
    {
        "poi_id": "sh-009",
        "name": "新天地",
        "category": "购物",
        "sub_category": "商圈",
        "longitude": 121.4747,
        "latitude": 31.2194,
        "address": "上海市黄浦区太仓路181弄",
        "ai_summary_static": "新天地是上海石库门建筑改造的典范，将老上海弄堂改造为时尚餐饮和零售空间。白天是休闲漫步地，晚上是社交聚会场。",
        "rating": 4.3,
        "best_visit_time": "晚上氛围最好；周末有街头表演",
        "tips": ["一大会址就在旁边，免费参观", "餐厅价格偏高但环境好", "适合和朋友聚会"],
    },
    {
        "poi_id": "sh-010",
        "name": "甜爱路",
        "category": "景点",
        "sub_category": "文化",
        "longitude": 121.4797,
        "latitude": 31.2676,
        "address": "上海市虹口区甜爱路",
        "ai_summary_static": "甜爱路是上海最浪漫的小马路，路两旁的围墙上刻满了情诗。只有短短500米，却是文艺青年必打卡的小众景点。旁边的鲁迅公园也值得一逛。",
        "rating": 4.2,
        "best_visit_time": "任何时候都很安静；下午光影最美",
        "tips": ["路口有个爱心邮筒可以寄明信片", "旁边就是鲁迅故居", "适合散步拍照"],
    },
]

# 合并所有 POI 数据
ALL_POIS = BEIJING_POIS + CHENGDU_POIS + SHANGHAI_POIS


async def seed_pois():
    """执行 POI 种子数据导入"""
    engine = create_async_engine(str(settings.DATABASE_URL), echo=True)

    async with engine.begin() as conn:
        # 仅创建 POIBase 表（不删除其他表）
        await conn.run_sync(Base.metadata.create_all)

    async_session = async_sessionmaker(engine, expire_on_commit=False)

    added_count = 0
    async with async_session() as session:
        for poi_data in ALL_POIS:
            # 检查是否已存在
            result = await session.execute(
                select(POIBase).where(POIBase.poi_id == poi_data["poi_id"])
            )
            existing = result.scalar_one_or_none()

            if existing:
                print(f"⏭️  {poi_data['name']} 已存在，跳过")
                continue

            poi = POIBase(**poi_data)
            session.add(poi)
            added_count += 1
            print(f"✅ 添加 POI: {poi_data['name']} ({poi_data['poi_id']})")

        await session.commit()

    print(f"\n🎉 新增 {added_count} 条 POI，总数据量 {len(ALL_POIS)} 条")
    print(f"   📍 北京: {len(BEIJING_POIS)} 条")
    print(f"   📍 成都: {len(CHENGDU_POIS)} 条")
    print(f"   📍 上海: {len(SHANGHAI_POIS)} 条")
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed_pois())
