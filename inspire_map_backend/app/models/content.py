"""
内容相关模型：POI、动态、足迹
使用纯 float 存储经纬度，不依赖 PostGIS/shapely
"""
from sqlalchemy import Column, String, Text, Float, ForeignKey, Boolean, JSON, Integer
from sqlalchemy.orm import relationship

from app.models.base import Base


class POIBase(Base):
    """POI 基础信息表"""

    poi_id = Column(String(64), unique=True, nullable=False, index=True, comment="高德/外部POI ID")
    name = Column(String(200), nullable=False, comment="地点名称")
    category = Column(String(50), nullable=False, comment="分类:景点/餐饮/人文等")
    sub_category = Column(String(50), nullable=True, comment="子分类")

    # 地理位置 - 使用纯 float 存储，不依赖 shapely/PostGIS
    longitude = Column(Float, nullable=False, index=True, comment="经度")
    latitude = Column(Float, nullable=False, index=True, comment="纬度")
    address = Column(String(500), nullable=True, comment="详细地址")

    # AI 生成内容
    ai_summary_static = Column(Text, nullable=True, comment="预生成AI摘要")
    ai_summary_mbti = Column(JSON, default=dict, comment="针对不同MBTI的AI摘要")
    best_visit_time = Column(String(200), nullable=True, comment="最佳游玩时间")
    tips = Column(JSON, default=list, comment="避坑/攻略提示")

    # 原始数据
    amap_raw_data = Column(JSON, nullable=True, comment="高德原始数据")

    # 统计
    rating = Column(Float, default=5.0, comment="评分")
    visit_count = Column(Integer, default=0, comment="打卡次数")

    # 关联
    posts = relationship("UserPost", back_populates="poi", lazy="selectin")


class UserPost(Base):
    """用户动态/足迹内容表 (RAG数据源)"""

    author_id = Column(String(36), ForeignKey("user.id"), nullable=False, index=True)
    poi_id = Column(String(64), ForeignKey("poibase.poi_id"), nullable=True, index=True)

    # 内容
    content = Column(Text, nullable=False, comment="用户真实评价/攻略内容")
    images = Column(JSON, default=list, comment="图片URL列表")

    # 标签
    tags = Column(JSON, default=list, comment="标签")

    # RAG 处理状态
    is_vectorized = Column(Boolean, default=False, comment="是否已向量化存入向量库")
    vector_chunk_ids = Column(JSON, default=list, comment="向量库中的chunk IDs")

    # 互动统计
    like_count = Column(Integer, default=0)
    comment_count = Column(Integer, default=0)
    share_count = Column(Integer, default=0)

    # 关联
    author = relationship("User", back_populates="posts")
    poi = relationship("POIBase", back_populates="posts")


class UserFootprint(Base):
    """用户足迹打卡表"""

    user_id = Column(String(36), ForeignKey("user.id"), nullable=False, index=True)
    poi_id = Column(String(64), ForeignKey("poibase.poi_id"), nullable=True, index=True)

    # 打卡信息 - 使用纯 float 存储经纬度
    longitude = Column(Float, nullable=False)
    latitude = Column(Float, nullable=False)

    # 地理信息 - 打卡时直接记录，避免每次都查 POI 表
    province = Column(String(50), nullable=True, index=True, comment="省份")
    city = Column(String(50), nullable=True, index=True, comment="城市")

    # 内容
    check_in_note = Column(String(500), nullable=True, comment="打卡留言")
    images = Column(JSON, default=list, comment="打卡图片")

    # 关联
    user = relationship("User", back_populates="footprints")
