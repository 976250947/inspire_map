"""Travel plan persistence models."""

from sqlalchemy import JSON, Column, Integer, String

from app.models.base import Base


class TravelPlan(Base):
    """用户保存的结构化旅行攻略。"""

    __tablename__ = "travel_plan"

    user_id = Column(String(36), nullable=False, index=True, comment="关联的用户 ID")
    title = Column(String(200), nullable=False, comment="行程标题")
    city = Column(String(100), nullable=False, comment="目的地城市")
    days = Column(Integer, nullable=False, comment="行程天数")
    itinerary_data = Column(JSON, default=list, comment="按天拆分的行程结构")
    checklist_data = Column(JSON, default=list, comment="行前待办勾选清单")
    guide_data = Column(JSON, default=dict, comment="完整攻略结构化数据")
    status = Column(String(20), default="active", comment="状态: active/completed/archived")

    @property
    def plan_id(self) -> str:
        """兼容前端既有字段命名。"""

        return self.id
