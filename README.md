<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/FastAPI-0.109-009688?logo=fastapi" alt="FastAPI">
  <img src="https://img.shields.io/badge/Python-3.12+-3776AB?logo=python" alt="Python">
  <img src="https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/AI-DeepSeek%20/%20Qwen-FF6F00" alt="AI">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

<h1 align="center">🧭 灵感经纬 · InspireMap</h1>
<p align="center"><strong>基于大模型与地图交互的智能伴游与打卡社区</strong></p>
<p align="center"><em>"Map is the UI" — 以地图为底层界面，AI 驱动个性化旅行体验</em></p>

---

## 📖 项目简介

**灵感经纬（InspireMap）** 是一款 AI 原生的旅游社交应用，核心理念是将地图作为唯一的交互界面，摒弃传统图文信息流式的旅游 App 设计模式。

用户通过 **MBTI 旅行人格测试** 获得个性化标签后，地图上的 POI（兴趣点）将根据用户偏好进行权重排序与高亮展示。点击 POI 后弹出由 **大模型实时生成的全网攻略摘要卡片**，而非跳转到第三方页面。用户还可通过 **AI 智能行程规划** 生成结构化的旅行时间轴，并通过 **社区 UGC + RAG 检索增强** 获取真实、有时效性的旅行经验回答。

---

## ✨ 核心特色

| 特色 | 说明 |
|------|------|
| 🗺️ **Map is the UI** | 地图为唯一底层交互界面，POI 聚合显示，告别信息流翻阅 |
| 🧠 **MBTI 个性化推荐** | 基于旅行人格（如"INTJ-城市观察者"）动态调整 POI 权重、主题色、行程风格 |
| 🤖 **AI 全网攻略摘要** | 点击地图 POI，大模型实时生成 100 字精华摘要（怎么去/机位/避坑） |
| 📋 **智能行程规划** | 输入"北京3天游"，AI 输出结构化时间轴 JSON，SSE 流式打字机效果 |
| 💬 **RAG 社区问答** | 用户 UGC 自动向量化存入 ChromaDB，AI 问答优先检索社区真实经验 |
| 📍 **经纬打卡** | GPS 定位打卡，足迹可视化，点亮中国/世界地图 |
| 💰 **极致降本** | Redis 精确缓存 + 国产模型优先，单次 AI 查询成本 < 0.01 元 |

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────┐
│                   Flutter 客户端                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │ MapLibre │  │ AI Chat  │  │ Community│           │
│  │  地图核心 │  │ SSE 流式  │  │ UGC 社区 │           │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘           │
│       │ Riverpod MVVM │            │                  │
│  ┌────┴──────────────┴────────────┴─────┐            │
│  │         Dio + Interceptors            │            │
│  │    (Auth / 统一响应解包 / Token刷新)    │            │
│  └──────────────────┬───────────────────┘            │
└─────────────────────┼───────────────────────────────┘
                      │ REST + SSE
┌─────────────────────┼───────────────────────────────┐
│              FastAPI 后端 (async)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
│  │ API 路由  │→│ Service  │→│Repository│           │
│  │ (Pydantic)│  │ (业务逻辑)│  │ (SQLAlchemy)│        │
│  └──────────┘  └────┬─────┘  └──────────┘           │
│                     │                                 │
│  ┌──────────────────┴──────────────────────┐         │
│  │            AI Core 引擎                   │         │
│  │  ┌─────────┐ ┌────────┐ ┌────────────┐  │         │
│  │  │LangChain│ │Prompts │ │RAG Engine  │  │         │
│  │  │  Agent  │ │(精调模板)│ │(ChromaDB)  │  │         │
│  │  └────┬────┘ └────────┘ └─────┬──────┘  │         │
│  │       │                       │          │         │
│  │  DeepSeek / Qwen API    向量检索          │         │
│  └──────────────────────────────────────────┘         │
│                                                       │
│  ┌────────┐  ┌────────┐  ┌──────────┐                │
│  │PostgreSQL│  │ Redis  │  │ ChromaDB │                │
│  │ (主库)   │  │(缓存降本)│  │(向量库)  │                │
│  └────────┘  └────────┘  └──────────┘                │
└───────────────────────────────────────────────────────┘
```

---

## 🛠️ 技术栈

### 前端（Flutter）

| 类别 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x (Dart) | 跨平台客户端 |
| 状态管理 | Riverpod + MVVM | 响应式架构 |
| 路由 | go_router | 声明式导航 + 深度链接 |
| 网络 | Dio | 拦截器链（Auth/响应解包/Token 自动刷新） |
| 本地存储 | Hive | 高频足迹缓存、冷启动数据 |
| 地图引擎 | MapLibre GL | 高性能矢量地图渲染 |
| 国际化 | flutter_localizations | 中/英文支持 |

### 后端（Python）

| 类别 | 技术 | 说明 |
|------|------|------|
| 框架 | FastAPI 0.109 | 全异步 async/await |
| 数据库 | PostgreSQL + asyncpg | 异步连接池 |
| ORM | SQLAlchemy 2.0 | 异步 ORM |
| 校验 | Pydantic V2 | 请求/响应数据校验 |
| 缓存 | Redis | AI 调用降本核心（7 天 TTL） |
| 向量库 | ChromaDB | RAG 社区经验语义检索 |
| AI 编排 | LangChain | Agent + Tool + Prompt 管理 |
| 安全 | JWT + bcrypt + slowapi | 认证 + 限流 + 速率保护 |

### AI 模型

| 用途 | 模型 | 说明 |
|------|------|------|
| 对话/规划 | DeepSeek-V3 / Qwen-Max | 国产模型，降本 10-100 倍 |
| 文本向量化 | sentence-transformers | 社区 UGC 向量化入库 |
| API 格式 | OpenAI Compatible | 统一 API 调用格式 |

---

## 📁 项目结构

```
vibe_grid/
├── inspire_map_flutter/          # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart             # 应用入口
│   │   ├── core/                 # 核心基础设施
│   │   │   ├── theme/            # 色彩系统 (Editorial Paper)
│   │   │   ├── router/           # go_router 路由配置
│   │   │   ├── network/          # Dio 网络封装
│   │   │   └── widgets/          # 全局通用组件
│   │   ├── data/                 # 数据层
│   │   │   ├── local/            # Hive 本地存储
│   │   │   └── models/           # 数据模型
│   │   └── features/             # Feature-First 业务模块
│   │       ├── map/              # 🗺️ 地图核心（POI / 聚合 / AI摘要卡片）
│   │       ├── ai_chat/          # 🤖 AI 智能助手（SSE 流式对话）
│   │       ├── route_plan/       # 📋 行程规划（时间轴 UI）
│   │       ├── community/        # 💬 UGC 社区（发帖/评论/点赞）
│   │       ├── profile/          # 👤 个人中心（足迹/关注/海报）
│   │       ├── onboarding/       # 🎯 MBTI 旅行人格问卷
│   │       ├── auth/             # 🔐 登录注册
│   │       └── start/            # 🚀 启动引导页
│   └── assets/                   # 静态资源
│
├── inspire_map_backend/          # FastAPI 后端
│   ├── app/
│   │   ├── api/v1/endpoints/     # API 路由层
│   │   ├── services/             # 业务逻辑层
│   │   ├── models/               # SQLAlchemy 模型层
│   │   ├── schemas/              # Pydantic 校验层
│   │   ├── ai_core/              # AI 引擎（LangChain / RAG / Prompts）
│   │   ├── core/                 # 配置/安全/限流/日志
│   │   └── utils/                # 工具函数
│   ├── alembic/                  # 数据库迁移
│   ├── seeds/                    # 数据种子脚本
│   ├── tests/                    # 单元测试
│   └── chroma_db/                # ChromaDB 本地向量存储
│
├── AGENTS.md                     # AI 开发规范文档
├── README.md                     # 项目说明文档
└── showcase.html                 # 答辩展示页面
```

---

## 🚀 快速开始

### 环境要求

- Python 3.12+
- Flutter 3.x（Dart SDK ≥ 3.0）
- PostgreSQL 15+
- Redis 7+

### 后端启动

```bash
cd inspire_map_backend

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env 填入 DATABASE_URL, REDIS_URL, DEEPSEEK_API_KEY 等

# 数据库迁移
alembic upgrade head

# 启动服务
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

### 前端启动

```bash
cd inspire_map_flutter

# 安装依赖
flutter pub get

# 运行（Android 模拟器）
flutter run

# 运行（指定后端地址，真机调试）
flutter run --dart-define=BACKEND_HOST=192.168.x.x
```

---

## 🧪 测试

```bash
cd inspire_map_backend

# 运行全部测试
pytest

# 运行指定模块
pytest tests/test_user_service.py -v
pytest tests/test_map_service.py -v
```

---

## 🔑 核心技术亮点

### 1. AI 调用极致降本

```
请求 → Redis 精确匹配缓存 → 命中则直接返回（0 Token 消耗）
                            → 未命中 → DeepSeek API → 缓存结果（TTL 7天）
```

- 缓存 Key = `hash(user_tags + city + query_intent)`
- 目标缓存命中率 > 60%
- 单次查询成本 < ¥0.01（对比 GPT-4 降本 10-100 倍）

### 2. RAG 社区经验闭环

```
用户发帖 → sentence-transformers 向量化 → ChromaDB 存储
                                          ↓
用户提问 → 语义检索 Top-K 相关 UGC → LangChain 组装 Prompt → 大模型回答
```

- 确保回答的**时效性**（优先引用最新社区内容）
- 确保回答的**真实性**（基于真实用户经验，非模型幻觉）

### 3. SSE 流式 AI 响应

- FastAPI `StreamingResponse` + 前端 `Stream<Map>` 逐帧解析
- 首字返回延迟 < 1.5 秒
- "打字机"效果显著提升感知速度

### 4. 地图性能保护

- 前端严格限制 Marker ≤ 500 个
- 后端基于缩放级别自动聚合：`zoom < 12` 返回气泡，`zoom ≥ 12` 返回详细 POI
- 聚合后帧率维持 ≥ 45 fps

---

## 🎨 设计语言

**Editorial Paper** — 纸质编辑型美学

- 浅色模式以米白纸张色 `#F8F5EF` 为底
- 品牌色为深青 `#1A7A8C`，搭配赭石暖色 `#B8732A`
- MBTI 动态配色：外向型偏暖（琥珀/珊瑚），内向型偏冷（薰衣草/薄荷）
- 字体采用 Noto Serif SC（衬线标题）+ DM Sans（正文）

---

## 📊 项目状态

| 阶段 | 状态 | 内容 |
|------|------|------|
| Phase 1 MVP | ✅ 完成 | 地图核心、MBTI 问卷、打卡、社区基础 |
| Phase 2 AI | ✅ 完成 | AI 行程规划、SSE 流式、RAG 问答、Agent 编排 |
| Phase 3 社交 | 🔄 进行中 | 关注/粉丝 UI、图片上传、深度链接 |

---

## 📜 License

MIT License

---

<p align="center">
  <strong>灵感经纬 · InspireMap</strong><br>
  <em>让每一次旅行，都有 AI 同行</em>
</p>
#   i n s p i r e _ m a p  
 