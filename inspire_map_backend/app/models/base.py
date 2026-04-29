"""
SQLAlchemy ORM 基础模型
"""
from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, String
from sqlalchemy.orm import declarative_base, declared_attr


class CustomBase:
    """内部混入基础类"""
    # 自动生成表名
    @declared_attr.directive
    def __tablename__(cls) -> str:
        return cls.__name__.lower()

    # 通用字段
    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


Base = declarative_base(cls=CustomBase)
