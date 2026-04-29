"""行程规划 API。"""

from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_deps import get_db
from app.core.security import get_optional_user_id
from app.schemas.base import success_response
from app.schemas.plan_schema import ChecklistUpdate, TravelPlanUpdate
from app.services.plan_service import PlanService

router = APIRouter()


@router.get("", response_model=dict)
async def list_plans(
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取当前用户的行程列表。"""

    uid = user_id or "default_user_123"
    service = PlanService(db)
    items = await service.list_plans(uid)
    return success_response({"total": len(items), "items": items})


@router.get("/{plan_id}", response_model=dict)
async def get_plan(
    plan_id: str,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取单个行程详情。"""

    uid = user_id or "default_user_123"
    service = PlanService(db)
    plan = await service.get_plan(uid, plan_id)
    return success_response(service.serialize_plan(plan))


@router.put("/{plan_id}", response_model=dict)
async def update_plan(
    plan_id: str,
    payload: TravelPlanUpdate,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """更新行程详情。"""

    uid = user_id or "default_user_123"
    service = PlanService(db)
    plan = await service.update_plan(uid, plan_id, payload)
    return success_response(service.serialize_plan(plan), message="updated")


@router.put("/{plan_id}/checklist", response_model=dict)
async def update_checklist(
    plan_id: str,
    payload: ChecklistUpdate,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """更新清单勾选状态。"""

    uid = user_id or "default_user_123"
    service = PlanService(db)
    plan = await service.update_checklist(uid, plan_id, payload)
    return success_response(service.serialize_plan(plan), message="updated")
