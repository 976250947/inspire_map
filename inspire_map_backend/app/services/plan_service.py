"""Service layer for reading and writing travel plans."""

from __future__ import annotations

from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.plan import TravelPlan
from app.schemas.plan_schema import (
    ChecklistItem,
    ChecklistUpdate,
    TravelPlanSaveInput,
    TravelPlanUpdate,
    normalize_guide_data,
)


class PlanService:
    """Encapsulates travel plan persistence and serialization."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def list_plans(self, user_id: str) -> list[dict]:
        """Return all plans for a user ordered by newest first."""

        result = await self.db.execute(
            select(TravelPlan)
            .where(TravelPlan.user_id == user_id)
            .order_by(TravelPlan.created_at.desc())
        )
        return [self.serialize_plan(plan) for plan in result.scalars().all()]

    async def get_plan(self, user_id: str, plan_id: str) -> TravelPlan:
        """Load a single plan or raise 404."""

        result = await self.db.execute(
            select(TravelPlan).where(
                TravelPlan.id == plan_id,
                TravelPlan.user_id == user_id,
            )
        )
        plan = result.scalars().first()
        if not plan:
            raise HTTPException(status_code=404, detail="行程未找到或无权访问")
        return plan

    async def create_or_update_plan(
        self,
        user_id: str,
        payload: TravelPlanSaveInput,
        plan_id: Optional[str] = None,
    ) -> TravelPlan:
        """Create a new plan or update an existing one."""

        if plan_id:
            plan = await self.get_plan(user_id, plan_id)
        else:
            plan = TravelPlan(user_id=user_id)
            self.db.add(plan)

        plan.title = payload.title
        plan.city = payload.city
        plan.days = payload.days
        plan.itinerary_data = [day.model_dump() for day in payload.itinerary]
        plan.checklist_data = [
            {"item": item, "checked": False}
            for item in payload.checklist
        ]
        plan.guide_data = payload.guide_data.model_dump()

        await self.db.commit()
        await self.db.refresh(plan)
        return plan

    async def update_plan(self, user_id: str, plan_id: str, payload: TravelPlanUpdate) -> TravelPlan:
        """Update editable fields on an existing plan."""

        plan = await self.get_plan(user_id, plan_id)

        if payload.title is not None:
            plan.title = payload.title
        if payload.status is not None:
            plan.status = payload.status
        if payload.itinerary_data is not None:
            plan.itinerary_data = [day.model_dump() for day in payload.itinerary_data]
        if payload.checklist_data is not None:
            plan.checklist_data = [item.model_dump() for item in payload.checklist_data]
        if payload.guide_data is not None:
            plan.guide_data = payload.guide_data.model_dump()

        await self.db.commit()
        await self.db.refresh(plan)
        return plan

    async def update_checklist(
        self,
        user_id: str,
        plan_id: str,
        payload: ChecklistUpdate,
    ) -> TravelPlan:
        """Update checklist state only."""

        plan = await self.get_plan(user_id, plan_id)
        plan.checklist_data = [item.model_dump() for item in payload.checklist]
        await self.db.commit()
        await self.db.refresh(plan)
        return plan

    @staticmethod
    def serialize_plan(plan: TravelPlan) -> dict:
        """Convert ORM model to API response payload."""

        checklist = [
            ChecklistItem.model_validate(item).model_dump()
            for item in (plan.checklist_data or [])
        ]

        return {
            "plan_id": plan.plan_id,
            "user_id": plan.user_id,
            "title": plan.title,
            "city": plan.city,
            "days": plan.days,
            "itinerary_data": plan.itinerary_data or [],
            "checklist_data": checklist,
            "guide_data": normalize_guide_data(plan.guide_data).model_dump(),
            "status": plan.status,
            "created_at": plan.created_at,
            "updated_at": plan.updated_at,
        }
