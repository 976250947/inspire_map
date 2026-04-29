"""AI 相关 API。"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_deps import get_db, get_redis
from app.core.rate_limit import limiter
from app.core.security import get_optional_user_id
from app.schemas.ai_schema import AIPOIQueryRequest, AIChatRequest, AIConfirmPlanSaveRequest, AIPlanRouteRequest
from app.schemas.base import success_response
from app.services.ai_service import AIService

router = APIRouter()


@router.post("/plan-route")
@limiter.limit("10/minute")
async def plan_route(
    request: Request,
    payload: AIPlanRouteRequest,
    stream: bool = Query(True, description="是否流式输出"),
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """AI 规划行程 SSE 接口。"""

    redis = await get_redis()
    service = AIService(db, redis)

    if user_id and not payload.mbti_type:
        from app.services.user_service import UserService

        user = await UserService(db).get_user_by_id(user_id)
        if user:
            payload.mbti_type = user.mbti_type

    return StreamingResponse(
        service.plan_route(payload, stream=stream, user_id=user_id),
        media_type="text/event-stream",
    )


@router.post("/chat")
@limiter.limit("20/minute")
async def chat(
    request: Request,
    payload: AIChatRequest,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """智能体对话 SSE 接口。"""

    redis = await get_redis()
    service = AIService(db, redis)

    if user_id and not payload.mbti_type:
        from app.services.user_service import UserService

        user = await UserService(db).get_user_by_id(user_id)
        if user:
            payload.mbti_type = user.mbti_type

    return StreamingResponse(service.chat(payload, user_id=user_id), media_type="text/event-stream")


@router.post("/confirm-plan-save")
@limiter.limit("20/minute")
async def confirm_plan_save(
    request: Request,
    payload: AIConfirmPlanSaveRequest,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """确认将 AI 已生成的攻略保存到“我的行程”."""

    redis = await get_redis()
    service = AIService(db, redis)
    try:
        saved = await service.confirm_plan_save(
            plan_data=payload.plan_data,
            user_id=user_id,
            plan_id=payload.plan_id,
        )
    except Exception as exc:  # pragma: no cover - defensive branch
        raise HTTPException(status_code=400, detail=f"保存行程失败: {exc}") from exc
    return success_response(saved, message="saved")


@router.post("/poi-query")
@limiter.limit("30/minute")
async def query_poi(
    request: Request,
    payload: AIPOIQueryRequest,
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """基于 RAG 的 POI 问答。"""

    mbti_type = payload.mbti_type
    if user_id and not mbti_type:
        from app.services.user_service import UserService

        user = await UserService(db).get_user_by_id(user_id)
        if user:
            mbti_type = user.mbti_type

    redis = await get_redis()
    service = AIService(db, redis)
    answer = await service.query_poi_with_rag(payload.poi_id, payload.question, mbti_type=mbti_type)
    return success_response({"answer": answer, "poi_id": payload.poi_id, "sources": []})


@router.get("/suggest")
async def get_suggestions(
    city: str = Query(..., description="城市"),
    mbti_type: Optional[str] = Query(None, description="MBTI 类型"),
    user_id: Optional[str] = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取个性化推荐占位接口。"""

    if user_id and not mbti_type:
        from app.services.user_service import UserService

        user = await UserService(db).get_user_by_id(user_id)
        if user:
            mbti_type = user.mbti_type

    return success_response({"city": city, "mbti_type": mbti_type, "suggestions": []})
