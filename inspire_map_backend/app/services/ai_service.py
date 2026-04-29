"""AI service orchestration for chat, planning, and RAG queries."""

from __future__ import annotations

import hashlib
import json
import re
import uuid
from typing import Any, AsyncGenerator, List, Optional

from sqlalchemy.ext.asyncio import AsyncSession

import app.core.config as config
from app.ai_core.llm_client import LLMClient
from app.ai_core.skill_loader import get_skill
from app.schemas.ai_schema import AIChatMessage, AIChatRequest, AIPlanRouteRequest, AIStreamChunk
from app.schemas.plan_schema import RouteDayInput, RouteStopInput, TravelGuideData, TravelPlanSaveInput
from app.services.map_service import MapService
from app.services.plan_service import PlanService


class AIService:
    """Coordinates LLM access, caching, SSE output, and structured plan persistence."""

    def __init__(self, db: AsyncSession, redis=None) -> None:
        self.db = db
        self.redis = redis
        self.llm = LLMClient()
        self.map_service = MapService(db)

    async def plan_route(
        self,
        request: AIPlanRouteRequest,
        stream: bool = True,
        user_id: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        """Generate a route plan with the travel-planner skill and auto-save it."""

        cache_key = self._generate_cache_key(request)
        full_response: Optional[str] = None

        if config.settings.ENABLE_AI_CACHE and self.redis:
            full_response = await self._get_cache(cache_key)

        if not full_response:
            messages = [
                AIChatMessage(role="system", content=self._build_route_plan_system_prompt()),
                AIChatMessage(role="user", content=self._build_route_plan_user_prompt(request)),
            ]
            full_response = await self._generate_json_plan(messages)
            if config.settings.ENABLE_AI_CACHE and self.redis and full_response:
                await self._set_cache(cache_key, full_response)

        if not full_response:
            error_chunk = AIStreamChunk(type="error", content="行程生成失败，请稍后重试", is_complete=True)
            yield f"data: {json.dumps(error_chunk.model_dump(), ensure_ascii=False)}\n\n"
            return

        if stream:
            for chunk in self._simulate_stream(full_response):
                yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"

        saved_payload = await self._save_route_plan_if_possible(
            request=request,
            full_response=full_response,
            user_id=user_id or "default_user_123",
        )
        if saved_payload:
            yield f"data: {json.dumps({'type': 'plan_saved', **saved_payload}, ensure_ascii=False)}\n\n"

        yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"

    async def query_poi_with_rag(
        self,
        poi_id: str,
        question: str,
        mbti_type: Optional[str] = None,
    ) -> str:
        """Answer POI questions with cached RAG context."""

        cache_key = f"poi_qa:{poi_id}:{hashlib.md5(question.encode()).hexdigest()}"
        if config.settings.ENABLE_AI_CACHE and self.redis:
            cached = await self._get_cache(cache_key)
            if cached:
                return cached

        from app.ai_core.prompts import PromptTemplates
        from app.ai_core.rag_engine import RAGEngine

        rag = RAGEngine()
        context = await rag.retrieve_poi_context(poi_id=poi_id, query=question, top_k=3)
        poi_detail = await self.map_service.get_poi_detail(poi_id, mbti_type)
        poi_info = f"地点: {poi_detail.name}\n分类: {poi_detail.category}"
        if poi_detail.ai_summary:
            poi_info += f"\n简介: {poi_detail.ai_summary}"

        prompt = PromptTemplates.get_poi_qa_prompt(
            poi_info=poi_info,
            user_question=question,
            community_context=context,
            mbti_type=mbti_type,
        )
        response = await self.llm.chat([AIChatMessage(role="user", content=prompt)])

        if config.settings.ENABLE_AI_CACHE and self.redis:
            await self._set_cache(cache_key, response)
        return response

    async def moderate_content(self, content: str) -> dict:
        """Run the moderation prompt and parse JSON output."""

        if not config.settings.CONTENT_AUDIT_ENABLED:
            return {"passed": True, "reason": "审核已禁用", "sensitivity_score": 0}

        from app.ai_core.prompts import PromptTemplates

        prompt = PromptTemplates.get_content_moderation_prompt(content)
        try:
            result = await self.llm.chat([AIChatMessage(role="user", content=prompt)])
            parsed = self._parse_json_object(result)
            if parsed:
                return parsed
            return {"passed": False, "reason": "审核结果格式异常", "sensitivity_score": 50}
        except Exception:
            return {"passed": False, "reason": "审核服务异常", "sensitivity_score": 100}

    async def chat(
        self,
        request: AIChatRequest,
        user_id: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        """Stream the main travel agent response and emit saved-plan metadata."""

        from app.ai_core.agent import TravelAgent

        should_use_cache = config.settings.ENABLE_AI_CACHE and self.redis and not self._looks_like_plan_request(request.message)
        cache_key = self._generate_chat_cache_key(request, request.current_poi_id or "")
        if should_use_cache:
            cached = await self._get_cache(cache_key)
            if cached:
                for chunk in self._simulate_stream(cached):
                    yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"
                yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"
                return

        current_poi_name = None
        if request.current_poi_id:
            try:
                poi = await self.map_service.get_poi_detail(request.current_poi_id, mbti_type=None)
                current_poi_name = poi.name if poi else None
            except Exception:
                current_poi_name = None

        if not request.conversation_id:
            request.conversation_id = str(uuid.uuid4())

        agent = TravelAgent(
            db=self.db,
            redis=self.redis,
            user_id=user_id or "default_user_123",
            auto_save_plan=False,
        )
        full_response = ""
        try:
            async for chunk in agent.chat_stream(
                message=request.message,
                conversation_id=request.conversation_id,
                mbti_type=request.mbti_type,
                current_poi_id=request.current_poi_id,
                current_poi_name=current_poi_name,
                conversation_history=request.history,
            ):
                full_response += chunk
                payload = AIStreamChunk(
                    type="chunk",
                    content=chunk,
                    is_complete=False,
                    conversation_id=request.conversation_id,
                )
                yield f"data: {json.dumps(payload.model_dump(exclude_none=True), ensure_ascii=False)}\n\n"
        except Exception as exc:
            error_chunk = AIStreamChunk(
                type="error",
                content=f"对话出错: {exc}",
                is_complete=True,
                conversation_id=request.conversation_id,
            )
            yield f"data: {json.dumps(error_chunk.model_dump(exclude_none=True), ensure_ascii=False)}\n\n"
            return

        if should_use_cache:
            await self._set_cache(cache_key, full_response)

        if isinstance(agent.last_saved_plan, dict) and agent.last_saved_plan.get("plan_id"):
            yield (
                "data: "
                + json.dumps(
                    {
                        "type": "plan_saved",
                        "conversation_id": request.conversation_id,
                        **agent.last_saved_plan,
                    },
                    ensure_ascii=False,
                )
                + "\n\n"
            )
        elif isinstance(agent.last_ready_plan, dict) and agent.last_ready_plan.get("plan_data"):
            yield (
                "data: "
                + json.dumps(
                    {
                        "type": "plan_ready",
                        "conversation_id": request.conversation_id,
                        **agent.last_ready_plan,
                    },
                    ensure_ascii=False,
                )
                + "\n\n"
            )

        yield f"data: {json.dumps({'type': 'complete', 'conversation_id': request.conversation_id}, ensure_ascii=False)}\n\n"

    async def confirm_plan_save(
        self,
        plan_data: dict[str, Any],
        user_id: Optional[str] = None,
        plan_id: Optional[str] = None,
    ) -> dict[str, Any]:
        """Persist a frontend-confirmed structured travel plan."""

        payload = TravelPlanSaveInput.model_validate(plan_data)
        plan = await PlanService(self.db).create_or_update_plan(
            user_id or "default_user_123",
            payload,
            plan_id=plan_id,
        )
        return {
            "saved": True,
            "plan_id": plan.plan_id,
            "title": plan.title,
            "city": plan.city,
            "days": plan.days,
        }

    def _build_route_plan_system_prompt(self) -> str:
        """Build a route-planning prompt from the root travel-planner skill."""

        skill = get_skill()
        parts: list[str] = []
        if skill.role_prompt:
            parts.append(f"# 角色\n{skill.role_prompt}")
        if skill.workflow:
            parts.append(f"# 工作流\n{skill.workflow}")
        if skill.vertical_scenes.get("_overview"):
            parts.append(f"# 垂直场景\n{skill.vertical_scenes['_overview']}")
        if skill.rag_rules:
            parts.append(f"# 经验融合\n{skill.rag_rules}")
        if skill.output_templates.get("full_itinerary"):
            parts.append(f"# 输出模板\n{skill.output_templates['full_itinerary']}")
        if skill.conversation_style:
            parts.append(f"# 风格\n{skill.conversation_style}")

        parts.append(
            """
# 当前任务
请生成一份可以直接保存到《灵感经纬》“我的行程”页面的结构化攻略。

# 硬性要求
- 只输出合法 JSON，不要输出解释、寒暄、Markdown 或代码块
- 内容必须便于前端拆成表格、清单、预算、住宿和行前准备
- 每天给出明确主题与时间节点，包含交通衔接
- 如果信息不足，用空字符串或空数组补齐字段

# JSON 结构
{
  "title": "",
  "city": "",
  "days": 0,
  "mbti_match": "",
  "summary": "",
  "travel_type": "",
  "scene": "",
  "style_tags": [""],
  "checklist": [""],
  "guide_data": {
    "summary": "",
    "travel_type": "",
    "scene": "",
    "style_tags": [""],
    "preparation": {
      "best_season": "",
      "long_distance_transport": [""],
      "city_transport": [""],
      "packing_list": [""],
      "documents": [""]
    },
    "accommodation": [
      {"tier": "", "name": "", "price_range": "", "highlights": [""]}
    ],
    "budget": [
      {"category": "", "amount_range": ""}
    ],
    "avoid_tips": [""],
    "notes": [""]
  },
  "routes": [
    {
      "day": 1,
      "theme": "",
      "summary": "",
      "stops": [
        {
          "time": "09:00",
          "poi_name": "",
          "duration": "",
          "activity": "",
          "tips": "",
          "transport_to_next": ""
        }
      ]
    }
  ],
  "budget_estimate": "",
  "packing_tips": [""]
}
""".strip()
        )
        return "\n\n---\n\n".join(parts)

    def _build_route_plan_user_prompt(self, request: AIPlanRouteRequest) -> str:
        """Build the route-planning user prompt."""

        payload = {
            "city": request.city,
            "days": request.days,
            "mbti_type": request.mbti_type or "",
            "preferences": request.preferences or [],
            "budget_level": request.budget_level or "",
            "avoid_crowds": request.avoid_crowds,
            "pace": request.pace or "适中",
        }
        return (
            "请基于以下用户需求生成结构化旅行攻略 JSON。"
            "内容要现实、可执行、节奏合理，并适合后续保存到我的行程。\n\n"
            f"用户需求: {json.dumps(payload, ensure_ascii=False)}"
        )

    async def _generate_json_plan(self, messages: list[AIChatMessage]) -> str:
        """Generate a JSON plan with response-format fallback."""

        message_dicts = [{"role": item.role, "content": item.content} for item in messages]
        try:
            response = await self.llm.client.chat.completions.create(
                model=self.llm._get_default_model(),
                messages=message_dicts,
                temperature=0.2,
                response_format={"type": "json_object"},
            )
            return response.choices[0].message.content or ""
        except Exception:
            return await self.llm.chat(messages, temperature=0.2, max_tokens=2600)

    async def _save_route_plan_if_possible(
        self,
        request: AIPlanRouteRequest,
        full_response: str,
        user_id: str,
    ) -> Optional[dict[str, Any]]:
        """Persist the route plan as a structured travel plan when possible."""

        data = self._parse_json_object(full_response)
        if not data:
            return None

        itinerary = self._build_itinerary_inputs(data.get("routes") or data.get("itinerary") or [])
        if not itinerary:
            return None

        checklist = self._build_checklist(data)
        guide_data = self._build_guide_data(data)
        payload = TravelPlanSaveInput(
            title=str(data.get("title") or f"{request.city}{request.days}天行程"),
            city=str(data.get("city") or request.city),
            days=int(data.get("days") or request.days),
            itinerary=itinerary,
            checklist=checklist,
            guide_data=TravelGuideData.model_validate(guide_data),
        )

        plan = await PlanService(self.db).create_or_update_plan(user_id, payload)
        return {
            "saved": True,
            "plan_id": plan.plan_id,
            "title": plan.title,
            "city": plan.city,
            "days": plan.days,
        }

    @staticmethod
    def _build_itinerary_inputs(raw_days: list[Any]) -> list[RouteDayInput]:
        """Convert response JSON into validated itinerary inputs."""

        itinerary: list[RouteDayInput] = []
        for index, raw_day in enumerate(raw_days, start=1):
            if not isinstance(raw_day, dict):
                continue

            raw_stops = raw_day.get("stops") if isinstance(raw_day.get("stops"), list) else []
            stops: list[RouteStopInput] = []
            for raw_stop in raw_stops:
                if not isinstance(raw_stop, dict):
                    continue
                stops.append(
                    RouteStopInput(
                        time=str(raw_stop.get("time") or ""),
                        poi_name=str(raw_stop.get("poi_name") or raw_stop.get("name") or ""),
                        activity=str(raw_stop.get("activity") or ""),
                        duration=str(raw_stop.get("duration") or "") or None,
                        tips=str(raw_stop.get("tips") or "") or None,
                        transport_to_next=str(raw_stop.get("transport_to_next") or "") or None,
                    )
                )

            itinerary.append(
                RouteDayInput(
                    day=int(raw_day.get("day") or index),
                    theme=str(raw_day.get("theme") or f"Day {index}"),
                    summary=str(raw_day.get("summary") or "") or None,
                    stops=stops,
                )
            )
        return itinerary

    @staticmethod
    def _build_checklist(data: dict[str, Any]) -> list[str]:
        """Build a user-editable checklist for the saved plan."""

        checklist = data.get("checklist")
        if isinstance(checklist, list):
            items = [str(item).strip() for item in checklist if str(item).strip()]
            if items:
                return items

        derived = [
            "确认往返交通",
            "确认首晚住宿",
            "整理证件与支付方式",
        ]
        packing_tips = data.get("packing_tips")
        if isinstance(packing_tips, list):
            for item in packing_tips[:4]:
                text = str(item).strip()
                if text:
                    derived.append(f"准备：{text}")
        return derived

    @staticmethod
    def _build_guide_data(data: dict[str, Any]) -> dict[str, Any]:
        """Build `guide_data` for persistence, with graceful fallbacks."""

        raw_guide = data.get("guide_data")
        if isinstance(raw_guide, dict) and raw_guide:
            guide = dict(raw_guide)
        else:
            guide = {}

        guide.setdefault("summary", data.get("summary") or data.get("mbti_match") or "")
        guide.setdefault("travel_type", data.get("travel_type") or "自由行")
        guide.setdefault("scene", data.get("scene") or "")
        guide.setdefault("style_tags", data.get("style_tags") or [])

        preparation = guide.get("preparation") if isinstance(guide.get("preparation"), dict) else {}
        preparation.setdefault("best_season", "")
        preparation.setdefault("long_distance_transport", [])
        preparation.setdefault("city_transport", [])
        preparation.setdefault("packing_list", data.get("packing_tips") if isinstance(data.get("packing_tips"), list) else [])
        preparation.setdefault("documents", [])
        guide["preparation"] = preparation

        guide.setdefault("accommodation", [])
        guide.setdefault("avoid_tips", data.get("avoid_tips") if isinstance(data.get("avoid_tips"), list) else [])
        guide.setdefault("notes", data.get("notes") if isinstance(data.get("notes"), list) else [])

        budget = guide.get("budget") if isinstance(guide.get("budget"), list) else []
        if not budget and data.get("budget_estimate"):
            budget = [{"category": "总预算", "amount_range": str(data.get("budget_estimate"))}]
        guide["budget"] = budget
        return guide

    def _generate_chat_cache_key(self, request: AIChatRequest, context: str) -> str:
        key_data = {
            "message": request.message,
            "current_poi_id": request.current_poi_id,
            "context": context,
        }
        key_str = json.dumps(key_data, sort_keys=True, ensure_ascii=False)
        return f"ai:chat:{hashlib.md5(key_str.encode()).hexdigest()}"

    @staticmethod
    def _looks_like_plan_request(message: str) -> bool:
        """Avoid returning stale cached content for planning conversations."""

        keywords = ("行程", "路线", "攻略", "规划", "几天", "旅行计划", " itinerary ")
        lowered = f" {message.lower()} "
        return any(keyword in lowered for keyword in keywords)

    def _generate_cache_key(self, request: AIPlanRouteRequest) -> str:
        key_data = {
            "city": request.city,
            "days": request.days,
            "mbti": request.mbti_type,
            "prefs": sorted(request.preferences) if request.preferences else [],
            "budget": request.budget_level,
            "avoid_crowds": request.avoid_crowds,
            "pace": request.pace,
        }
        key_str = json.dumps(key_data, sort_keys=True, ensure_ascii=False)
        return f"ai:route:{hashlib.md5(key_str.encode()).hexdigest()}"

    async def _get_cache(self, key: str) -> Optional[str]:
        if not self.redis:
            return None
        try:
            return await self.redis.get(key)
        except Exception:
            return None

    async def _set_cache(self, key: str, value: str) -> None:
        if not self.redis:
            return
        try:
            await self.redis.setex(key, config.settings.AI_CACHE_TTL, value)
        except Exception:
            return

    @staticmethod
    def _simulate_stream(content: str) -> List[dict]:
        if not re.search(r"[。！？\n]", content):
            return [
                {"type": "chunk", "content": content[index:index + 120], "is_complete": False}
                for index in range(0, len(content), 120)
            ]

        sentences = re.split(r'([。！？\n])', content)
        chunks: list[dict] = []
        current = ""
        for sentence in sentences:
            current += sentence
            if len(current) >= 20:
                chunks.append({"type": "chunk", "content": current, "is_complete": False})
                current = ""
        if current:
            chunks.append({"type": "chunk", "content": current, "is_complete": False})
        return chunks

    @staticmethod
    def _parse_json_object(text: str) -> dict:
        stripped = text.strip()
        if not stripped:
            return {}
        try:
            parsed = json.loads(stripped)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            match = re.search(r"\{[\s\S]*\}", stripped)
            if not match:
                return {}
            try:
                parsed = json.loads(match.group(0))
                return parsed if isinstance(parsed, dict) else {}
            except json.JSONDecodeError:
                return {}
