"""
用户模型
"""
from sqlalchemy import Column, String, JSON
from sqlalchemy.orm import relationship

from app.models.base import Base


class User(Base):
    """用户表"""

    # 基本信息
    phone = Column(String(20), unique=True, nullable=True, index=True, comment="手机号")
    password_hash = Column(String(255), nullable=True, comment="密码哈希")
    nickname = Column(String(50), nullable=True, comment="昵称")
    avatar_url = Column(String(500), nullable=True, comment="头像URL")

    # MBTI 与旅行偏好
    mbti_type = Column(String(4), nullable=True, index=True, comment="MBTI类型如INTJ")
    mbti_persona = Column(String(50), nullable=True, comment="旅行人格如'城市观察者'")
    travel_pref_tags = Column(JSON, default=list, comment="旅行偏好标签如['喜欢安静', '预算中等']")

    # 社交统计
    footprint_count = Column(String(10), default="0", comment="足迹数量")
    post_count = Column(String(10), default="0", comment="发布动态数量")
    follower_count = Column(String(10), default="0", comment="粉丝数")
    following_count = Column(String(10), default="0", comment="关注数")

    # 关联关系
    posts = relationship("UserPost", back_populates="author", lazy="selectin")
    footprints = relationship("UserFootprint", back_populates="user", lazy="selectin")
