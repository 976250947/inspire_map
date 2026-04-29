# InspireMap 灵感经纬

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/FastAPI-async-009688?logo=fastapi" alt="FastAPI">
  <img src="https://img.shields.io/badge/Python-3.12+-3776AB?logo=python" alt="Python">
  <img src="https://img.shields.io/badge/PostgreSQL-15+-336791?logo=postgresql" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/Redis-cache-DC382D?logo=redis" alt="Redis">
  <img src="https://img.shields.io/badge/LLM-DeepSeek%20%2F%20Qwen-111827" alt="LLM">
</p>

InspireMap 是一个大模型驱动的智能伴游与打卡社区项目。项目以“Map is the UI”为核心理念，把地图作为主交互界面，将个性化 POI 推荐、AI 攻略摘要、流式行程规划、UGC 社区经验问答和足迹打卡整合到同一个地图体验中。

传统旅游产品通常依赖图文信息流，用户需要在攻略、地图、点评、社交平台之间反复切换。InspireMap 希望把“查攻略、选地点、排路线、问经验”压缩成一次地图上的连续决策过程。

## 目录

- [核心特性](#核心特性)
- [技术栈](#技术栈)
- [系统架构](#系统架构)
- [仓库结构](#仓库结构)
- [快速开始](#快速开始)
- [环境变量](#环境变量)
- [开发规范](#开发规范)
- [测试](#测试)
- [路线图](#路线图)
- [贡献指南](#贡献指南)
- [License](#license)

## 核心特性

| 模块 | 说明 |
| --- | --- |
| 地图优先交互 | 以地图作为主界面，POI、路线、摘要、足迹和社区内容都围绕地理位置展开。 |
| MBTI 个性化推荐 | 基于用户旅行人格、兴趣标签和当前位置，对 POI 进行个性化聚合、排序和高亮。 |
| AI 攻略摘要卡片 | 点击 POI 后生成结构化攻略摘要，帮助用户快速判断“值不值得去、怎么去、怎么避坑”。 |
| 流式行程规划 | 基于大模型生成结构化 JSON 时间轴，并通过 SSE 流式返回给客户端。 |
| UGC + RAG 问答 | 将社区内容向量化存入 ChromaDB，让 AI 问答优先引用本地真实经验。 |
| 成本控制 | 大模型调用前置 Redis 缓存，优先使用 DeepSeek-V3 / Qwen-Max 等低成本模型。 |
| 地图性能保护 | 面向大量 POI 场景提供聚合数据，避免客户端一次性渲染过多 Marker。 |

## 技术栈

### Flutter 客户端

| 类别 | 技术 |
| --- | --- |
| 框架 | Flutter 3.x / Dart |
| 架构 | Feature-First + MVVM |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 网络 | Dio / Retrofit |
| 本地存储 | Hive / SharedPreferences |
| 地图 | amap_flutter_map 规划适配，当前工程含 MapLibre GL 适配实现 |
| UI | flutter_screenutil / flutter_svg / flutter_animate / timelines_plus |

### FastAPI 后端

| 类别 | 技术 |
| --- | --- |
| 框架 | FastAPI / async-await |
| ORM | SQLAlchemy 2.x async |
| 数据校验 | Pydantic V2 |
| 主数据库 | PostgreSQL + asyncpg |
| 缓存 | Redis |
| 向量库 | ChromaDB |
| AI 编排 | LangChain |
| 模型层 | DeepSeek-V3 / Qwen-Max，OpenAI Compatible API |

## 系统架构

```mermaid
flowchart TB
  subgraph Client["Flutter Client"]
    Map["Map UI"]
    POI["POI Cluster & Highlight"]
    Plan["Route Plan Timeline"]
    Community["UGC Community"]
    Local["Hive Local Cache"]
  end

  subgraph API["FastAPI Backend"]
    Router["API Routers"]
    Service["Services"]
    Repo["Repositories"]
    AICore["AI Core / LangChain"]
  end

  subgraph Storage["Storage"]
    PG["PostgreSQL"]
    Redis["Redis Cache"]
    Chroma["ChromaDB Vector Store"]
  end

  subgraph LLM["LLM Providers"]
    DeepSeek["DeepSeek-V3"]
    Qwen["Qwen-Max"]
  end

  Client -->|REST / SSE| Router
  Router --> Service
  Service --> Repo
  Service --> AICore
  Repo --> PG
  Service --> Redis
  AICore --> Redis
  AICore --> Chroma
  AICore --> DeepSeek
  AICore --> Qwen
  Community --> Local
  POI --> Map
  Plan --> Map
```

## 仓库结构

```text
inspire_map/
├── inspire_map_flutter/          # Flutter 客户端
│   ├── lib/
│   │   ├── core/                 # 全局基础设施：主题、路由、网络、通用组件
│   │   ├── data/                 # 数据模型、本地存储、数据源
│   │   ├── features/             # Feature-First 业务模块
│   │   └── main.dart             # 应用入口
│   ├── assets/                   # 图片、图标、字体、地理数据
│   └── test/                     # Flutter 测试
├── inspire_map_backend/          # FastAPI 后端
│   ├── app/
│   │   ├── api/                  # API 路由层，只做参数校验和响应封装
│   │   ├── services/             # 业务逻辑层
│   │   ├── models/               # SQLAlchemy 模型
│   │   ├── schemas/              # Pydantic Schema
│   │   ├── ai_core/              # LangChain、Prompt、RAG、模型调用
│   │   ├── core/                 # 配置、安全、日志、限流
│   │   └── utils/                # 工具函数
│   ├── alembic/                  # 数据库迁移
│   ├── seeds/                    # 种子数据
│   └── tests/                    # Pytest 测试
├── chroma_db/                    # 本地向量库数据目录
├── AGENTS.md                     # AI 协作与项目开发规范
└── README.md                     # 项目说明
```

## 快速开始

### 前置要求

- Python 3.12+
- Flutter 3.x / Dart 3.x
- PostgreSQL 15+
- Redis 7+
- 可选：ChromaDB 本地持久化目录

### 启动后端

```bash
cd inspire_map_backend

python -m venv venv
source venv/bin/activate
# Windows: venv\Scripts\activate

pip install -r requirements.txt
cp .env.example .env

alembic upgrade head
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

后端默认提供：

- API 服务：`http://localhost:8000`
- Swagger 文档：`http://localhost:8000/docs`
- ReDoc 文档：`http://localhost:8000/redoc`

### 启动客户端

```bash
cd inspire_map_flutter

flutter pub get
flutter run
```

如果需要指定后端地址：

```bash
flutter run --dart-define=BACKEND_HOST=192.168.x.x
```

## 环境变量

后端配置文件位于 `inspire_map_backend/.env.example`。复制为 `.env` 后按实际环境填写。

| 变量 | 说明 |
| --- | --- |
| `DATABASE_URL` | PostgreSQL 异步连接字符串，例如 `postgresql+asyncpg://user:password@localhost:5432/inspire_map`。 |
| `REDIS_URL` | Redis 连接地址，例如 `redis://localhost:6379/0`。 |
| `SECRET_KEY` | JWT 签名密钥，生产环境必须使用高强度随机值。 |
| `LLM_PROVIDER` | 默认模型提供商，可选 `deepseek` 或 `qwen`。 |
| `DEEPSEEK_API_KEY` | DeepSeek API Key。 |
| `QWEN_API_KEY` | Qwen API Key。 |
| `ENABLE_AI_CACHE` | 是否启用 AI 响应缓存。 |
| `AI_CACHE_TTL` | AI 缓存 TTL，默认建议 7 天。 |
| `CHROMA_PERSIST_DIRECTORY` | ChromaDB 持久化目录。 |
| `AMAP_API_KEY` | 高德地图 API Key。 |
| `CORS_ORIGINS` | 允许跨域访问的前端地址。 |

不要把 `.env`、数据库密码或模型 API Key 提交到 Git 仓库。

## 开发规范

### 后端分层

后端遵循 Controller-Service-Repository 思路：

- `app/api/`：只负责请求参数、鉴权入口和统一响应。
- `app/services/`：承载核心业务逻辑和跨资源编排。
- `app/models/`：定义 SQLAlchemy ORM 模型。
- `app/schemas/`：定义 Pydantic V2 请求与响应模型。
- `app/ai_core/`：集中放置 LangChain、Prompt、RAG、模型调用和结构化输出逻辑。

所有后端 API 响应应统一包裹为：

```json
{
  "code": 200,
  "message": "success",
  "data": {}
}
```

### AI 调用约束

- 大模型调用必须先查询 Redis 缓存，命中缓存时不消耗 Token。
- 行程规划、攻略摘要等面向客户端解析的内容必须输出合法 JSON。
- AI 流式接口优先使用 SSE。
- 单元测试中必须 Mock 外部模型请求，避免真实消耗 Token。

### 地图性能约束

- 客户端不应直接渲染超过 500 个原生 Marker。
- 大规模 POI 应由后端按视窗、距离或 GeoHash 提供聚合数据。
- Flutter 端只渲染当前视窗必要数据，冷启动和足迹数据优先使用本地缓存。

## 测试

### 后端

```bash
cd inspire_map_backend
pytest
```

运行指定测试：

```bash
pytest tests/test_map_service.py -v
pytest tests/test_user_service.py -v
```

### 前端

```bash
cd inspire_map_flutter
flutter test
flutter analyze
```

## 路线图

- [ ] 完善 POI 聚合接口和地图视窗查询策略。
- [ ] 完善 MBTI 旅行人格与 POI 权重模型。
- [ ] 接入攻略摘要缓存与结构化 JSON 输出校验。
- [ ] 完成 SSE 行程规划时间轴。
- [ ] 建立 UGC 内容向量化入库与 RAG 问答链路。
- [ ] 增加关键 ViewModel 单元测试和 AI 服务 Mock 测试。
- [ ] 补齐 Docker Compose 本地开发环境。

## 贡献指南

欢迎提交 Issue 和 Pull Request。建议流程：

1. Fork 本仓库并创建特性分支。
2. 保持改动聚焦，避免在同一个 PR 中混入无关重构。
3. 后端代码需要包含类型注解和必要的 Docstring。
4. 涉及 AI、数据库、地图聚合或状态管理的改动需要补充测试。
5. 提交 PR 前运行对应测试和静态检查。

## License

本项目计划采用 MIT License。正式开源前请以仓库中的 `LICENSE` 文件为准。
