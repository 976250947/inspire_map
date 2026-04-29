"""Skill-driven travel agent for InspireMap."""

from __future__ import annotations

import asyncio
import json
import logging
import re
import uuid
from typing import Any, AsyncGenerator, Dict, List, Optional

from app.ai_core.intent_classifier import IntentClassifier, TravelIntent
from app.ai_core.llm_client import LLMClient
from app.ai_core.memory import AgentState, ConversationMemory, WorkflowPhase
from app.ai_core.skill_loader import get_skill
from app.ai_core.tools import ALL_TOOLS, get_all_tools_openai_format, get_tools_by_names
from app.schemas.ai_schema import AIChatMessage
from app.schemas.plan_schema import TravelGuideData, TravelPlanSaveInput
from app.services.plan_service import PlanService

logger = logging.getLogger(__name__)
MAX_TOOL_ROUNDS = 2


class ToolExecutor:
    """Executes tool calls selected by the agent."""

    def __init__(self, db=None, redis=None, user_id: str = "default_user_123") -> None:
        self.db = db
        self.redis = redis
        self.user_id = user_id

    async def execute(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """Dispatch a tool call by name."""

        try:
            if tool_name == "search_community":
                return await self._search_community(arguments.get("query", ""), arguments.get("poi_id"))
            if tool_name == "get_poi_detail":
                return await self._get_poi_detail(arguments.get("poi_name", ""))
            if tool_name == "plan_route":
                return await self._plan_route(
                    city=arguments.get("city", ""),
                    days=int(arguments.get("days", 2)),
                    preferences=arguments.get("preferences"),
                )
            if tool_name == "search_nearby":
                return await self._search_nearby(arguments.get("location", ""), arguments.get("category"))
            if tool_name == "get_transport_info":
                return await self._get_transport_info(arguments.get("destination", ""), arguments.get("origin"))
            if tool_name == "get_food_recommendation":
                return await self._get_food_recommendation(arguments.get("location", ""), arguments.get("food_type"))
            if tool_name == "get_accommodation_info":
                return await self._get_accommodation_info(arguments.get("location", ""), arguments.get("style"))
            if tool_name == "get_user_profile":
                return await self._get_user_profile()
            if tool_name == "save_travel_plan":
                return await self._save_travel_plan(
                    title=arguments.get("title", "未命名行程"),
                    city=arguments.get("city", ""),
                    days=int(arguments.get("days", 0)),
                    itinerary=arguments.get("itinerary", []),
                    checklist=arguments.get("checklist", []),
                    guide_data=arguments.get("guide_data", {}),
                    plan_id=arguments.get("plan_id"),
                )
            return f"未知工具: {tool_name}"
        except Exception as exc:  # pragma: no cover - defensive branch
            logger.exception("Tool execution failed: %s", tool_name)
            return f"工具执行出错: {exc}"

    async def _search_community(self, query: str, poi_id: Optional[str] = None) -> str:
        """Search community/RAG context."""

        from app.ai_core.rag_engine import RAGEngine

        rag = RAGEngine()
        if poi_id:
            result = await rag.retrieve_poi_context(poi_id=poi_id, query=query, top_k=5)
        else:
            result = await rag.retrieve_general_context(query=query, top_k=5)
        return result or "暂未找到相关社区经验。"

    async def _get_poi_detail(self, poi_name: str) -> str:
        """Lookup POI details from the database."""

        if not self.db:
            return "数据库连接不可用。"

        from sqlalchemy import select

        from app.models.content import POIBase

        result = await self.db.execute(
            select(POIBase).where(POIBase.name.ilike(f"%{poi_name}%")).limit(3)
        )
        pois = result.scalars().all()
        if not pois:
            return f"未找到与 {poi_name} 相关的地点信息。"

        details: list[str] = []
        for poi in pois:
            tips = []
            if isinstance(poi.tips, list):
                tips = poi.tips[:3]
            elif poi.tips:
                tips = [str(poi.tips)]
            detail = [
                f"地点: {poi.name}",
                f"分类: {poi.category}",
                f"地址: {poi.address or '暂无'}",
                f"评分: {poi.rating}",
            ]
            if poi.ai_summary_static:
                detail.append(f"简介: {poi.ai_summary_static}")
            if poi.best_visit_time:
                detail.append(f"最佳时间: {poi.best_visit_time}")
            if tips:
                detail.append(f"提示: {'；'.join(tips)}")
            details.append("\n".join(detail))
        return "\n---\n".join(details)

    async def _plan_route(self, city: str, days: int, preferences: Optional[str] = None) -> str:
        """Generate a concise route sketch."""

        llm = LLMClient()
        prompt = (
            f"请为 {city} 规划 {days} 天旅行草案。"
            f"偏好: {preferences or '无特别偏好'}。"
            "直接输出分天安排，每天包含时间、地点、活动和交通提示，不要使用 JSON。"
        )
        messages = [
            AIChatMessage(role="system", content="你是旅行规划助手，回答简洁直接，不要寒暄。"),
            AIChatMessage(role="user", content=prompt),
        ]
        try:
            return await asyncio.wait_for(llm.chat(messages), timeout=30)
        except asyncio.TimeoutError:
            return f"正在为 {city} 规划 {days} 天行程，请稍后再试。"

    async def _search_nearby(self, location: str, category: Optional[str] = None) -> str:
        """Search nearby POIs."""

        if not self.db:
            return "数据库连接不可用。"

        from sqlalchemy import or_, select

        from app.models.content import POIBase

        query = select(POIBase).where(
            or_(
                POIBase.name.ilike(f"%{location}%"),
                POIBase.address.ilike(f"%{location}%"),
            )
        )
        if category:
            query = query.where(POIBase.category == category)
        result = await self.db.execute(query.limit(5))
        pois = result.scalars().all()
        if not pois:
            return f"暂未收录 {location} 附近的地点。"
        return "\n".join(
            f"- {poi.name}（{poi.category}，评分 {poi.rating}）{(poi.ai_summary_static or '')[:80]}"
            for poi in pois
        )

    async def _get_transport_info(self, destination: str, origin: Optional[str] = None) -> str:
        """Search transport suggestions from RAG."""

        from app.ai_core.rag_engine import RAGEngine

        rag = RAGEngine()
        query = f"{destination} 交通攻略"
        if origin:
            query = f"从 {origin} 到 {destination} 怎么去"
        result = await rag.retrieve_general_context(query=query, top_k=3)
        return result or f"暂时没有 {destination} 的交通建议。"

    async def _get_food_recommendation(self, location: str, food_type: Optional[str] = None) -> str:
        """Search food suggestions from RAG."""

        from app.ai_core.rag_engine import RAGEngine

        rag = RAGEngine()
        query = f"{location} 美食推荐 {food_type or ''}".strip()
        result = await rag.retrieve_general_context(query=query, top_k=5)
        return result or f"暂时没有 {location} 的美食推荐。"

    async def _get_accommodation_info(self, location: str, style: Optional[str] = None) -> str:
        """Search accommodation suggestions from RAG."""

        from app.ai_core.rag_engine import RAGEngine

        rag = RAGEngine()
        query = f"{location} 住宿推荐 {style or ''}".strip()
        result = await rag.retrieve_general_context(query=query, top_k=3)
        return result or f"暂时没有 {location} 的住宿建议。"

    async def _get_user_profile(self) -> str:
        """Return a lightweight placeholder profile summary."""

        return "当前用户偏好多为深度体验、低废话、希望攻略可以直接落到行程页。"

    async def _save_travel_plan(
        self,
        title: str,
        city: str,
        days: int,
        itinerary: list,
        checklist: list,
        guide_data: Optional[dict] = None,
        plan_id: Optional[str] = None,
    ) -> str:
        """Persist a structured travel plan."""

        if not self.db:
            return json.dumps({"saved": False, "reason": "数据库连接不可用"}, ensure_ascii=False)

        payload = TravelPlanSaveInput(
            title=title,
            city=city,
            days=days,
            itinerary=itinerary,
            checklist=[str(item) for item in checklist],
            guide_data=TravelGuideData.model_validate(guide_data or {}),
        )
        service = PlanService(self.db)
        plan = await service.create_or_update_plan(self.user_id, payload, plan_id=plan_id)
        return json.dumps(
            {
                "saved": True,
                "plan_id": plan.plan_id,
                "title": plan.title,
                "city": plan.city,
                "days": plan.days,
            },
            ensure_ascii=False,
        )


class TravelAgent:
    """Skill-driven travel planning agent."""

    def __init__(
        self,
        db=None,
        redis=None,
        user_id: str = "default_user_123",
        auto_save_plan: bool = True,
    ) -> None:
        self.llm = LLMClient()
        self.tool_executor = ToolExecutor(db=db, redis=redis, user_id=user_id)
        self.skill = get_skill()
        self.classifier = IntentClassifier(self.llm)
        self.memory = ConversationMemory(redis=redis)
        self.user_id = user_id
        self.auto_save_plan = auto_save_plan
        self.tools_schema = self._build_tools_schema()
        self.last_saved_plan: Optional[dict[str, Any]] = None
        self.last_ready_plan: Optional[dict[str, Any]] = None

    async def chat(
        self,
        message: str,
        conversation_id: Optional[str] = None,
        mbti_type: Optional[str] = None,
        current_poi_id: Optional[str] = None,
        current_poi_name: Optional[str] = None,
        conversation_history: Optional[List[AIChatMessage]] = None,
    ) -> str:
        """Non-streaming facade around ``chat_stream``."""

        chunks: list[str] = []
        async for chunk in self.chat_stream(
            message=message,
            conversation_id=conversation_id,
            mbti_type=mbti_type,
            current_poi_id=current_poi_id,
            current_poi_name=current_poi_name,
            conversation_history=conversation_history,
        ):
            chunks.append(chunk)
        return "".join(chunks)

    async def chat_stream(
        self,
        message: str,
        conversation_id: Optional[str] = None,
        mbti_type: Optional[str] = None,
        current_poi_id: Optional[str] = None,
        current_poi_name: Optional[str] = None,
        conversation_history: Optional[List[AIChatMessage]] = None,
    ) -> AsyncGenerator[str, None]:
        """Main streaming entrypoint."""

        self.last_saved_plan = None
        self.last_ready_plan = None
        state = await self.memory.get_state(conversation_id or "")
        state.message_count += 1
        state = await self._update_agent_state(message, state)
        state.add_message("user", message)
        await self.memory.save_state(state)

        messages = self._build_messages(
            message,
            state,
            mbti_type,
            current_poi_id,
            current_poi_name,
            conversation_history,
        )

        if state.workflow_phase == WorkflowPhase.CHATTING and self._is_simple_chat(message, state.intent):
            full_response = ""
            async for chunk in self._stream_llm(messages):
                full_response += chunk
                yield chunk
            state.add_message("assistant", full_response)
            await self.memory.save_state(state)
            return

        relevant_tools = self._select_relevant_tools(message, state.intent)
        if not self.auto_save_plan:
            relevant_tools = [
                tool for tool in relevant_tools
                if getattr(tool, "name", "") != "save_travel_plan"
            ]
        tool_used = False

        for _ in range(MAX_TOOL_ROUNDS):
            response = await self._call_llm_with_tools(messages, relevant_tools)
            if not response.get("tool_calls"):
                break

            tool_used = True
            messages.append(
                {
                    "role": "assistant",
                    "content": response.get("content", ""),
                    "tool_calls": response["tool_calls"],
                }
            )

            parsed_calls: list[tuple[dict, str, dict[str, Any]]] = []
            for tool_call in response["tool_calls"]:
                name = tool_call["function"]["name"]
                try:
                    args = json.loads(tool_call["function"]["arguments"])
                except json.JSONDecodeError:
                    args = {}
                parsed_calls.append((tool_call, name, args))

            results = await asyncio.gather(
                *[self.tool_executor.execute(name, args) for _, name, args in parsed_calls],
                return_exceptions=True,
            )

            for (tool_call, name, _), result in zip(parsed_calls, results):
                content = str(result) if not isinstance(result, Exception) else f"错误: {result}"
                if name == "save_travel_plan":
                    saved_payload = self._parse_json_object(content)
                    if saved_payload.get("saved"):
                        self.last_saved_plan = saved_payload
                        state.collected_info["saved_plan_id"] = saved_payload.get("plan_id")
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tool_call["id"],
                        "content": content[:3000],
                    }
                )

        if tool_used:
            messages.append(
                {
                    "role": "user",
                    "content": "请基于以上检索结果直接给出完整攻略，不要寒暄，保持结构清晰。",
                }
            )

        full_response = ""
        async for chunk in self._stream_llm(messages):
            full_response += chunk
            yield chunk

        state.add_message("assistant", full_response)
        if full_response:
            state.generated_plan = full_response[:3000]

        if state.workflow_phase in {WorkflowPhase.PLANNING, WorkflowPhase.ITERATING} and full_response:
            if self.auto_save_plan:
                saved = await self._ensure_plan_saved(state, full_response)
                if saved:
                    self.last_saved_plan = saved
                    state.collected_info["saved_plan_id"] = saved.get("plan_id")
            else:
                ready = await self._prepare_plan_for_confirmation(full_response, state)
                if ready:
                    self.last_ready_plan = ready

        await self.memory.save_state(state)

    async def _ensure_plan_saved(self, state: AgentState, full_response: str) -> Optional[dict[str, Any]]:
        """Build and persist a structured plan after a planning response."""

        if not self.tool_executor.db:
            return None

        if self.last_saved_plan and self.last_saved_plan.get("saved"):
            return self.last_saved_plan

        payload = await self._build_structured_plan_payload(state, full_response)
        if not payload or not payload.itinerary:
            return None

        service = PlanService(self.tool_executor.db)
        existing_plan_id = state.collected_info.get("saved_plan_id")
        plan = await service.create_or_update_plan(
            self.user_id,
            payload,
            plan_id=existing_plan_id if isinstance(existing_plan_id, str) else None,
        )
        return {
            "saved": True,
            "plan_id": plan.plan_id,
            "title": plan.title,
            "city": plan.city,
            "days": plan.days,
        }

    async def _build_structured_plan_payload(
        self,
        state: AgentState,
        full_response: str,
    ) -> Optional[TravelPlanSaveInput]:
        """Use the model to transform free-text攻略 into strict JSON."""

        user_context = json.dumps(state.collected_info, ensure_ascii=False)
        system_prompt = """
你是《灵感经纬》的攻略结构化引擎。
请把输入的旅行攻略整理成严格合法 JSON，禁止输出任何解释、寒暄或 Markdown。
输出格式必须满足：
{
  "title": "",
  "city": "",
  "days": 0,
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
  "itinerary": [
    {
      "day": 1,
      "theme": "",
      "summary": "",
      "stops": [
        {
          "time": "09:00",
          "poi_name": "",
          "activity": "",
          "duration": "",
          "tips": "",
          "transport_to_next": ""
        }
      ]
    }
  ]
}
如果原文缺少字段，请使用空字符串或空数组。
""".strip()
        user_prompt = (
            f"用户偏好上下文: {user_context}\n"
            f"识别场景: {state.scene or ''}\n"
            f"原始攻略:\n{full_response}"
        )

        response_text = ""
        try:
            response = await self.llm.client.chat.completions.create(
                model=self.llm._get_default_model(),
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=0.0,
                response_format={"type": "json_object"},
            )
            response_text = response.choices[0].message.content or ""
        except Exception:
            response_text = await self.llm.chat(
                [
                    AIChatMessage(role="system", content=system_prompt),
                    AIChatMessage(role="user", content=user_prompt),
                ],
                temperature=0.0,
                max_tokens=2400,
            )

        data = self._parse_json_object(response_text)
        if not data:
            return None

        try:
            return TravelPlanSaveInput.model_validate(data)
        except Exception:
            logger.exception("Failed to validate structured plan payload")
            return None

    async def _prepare_plan_for_confirmation(
        self,
        full_response: str,
        state: AgentState,
    ) -> Optional[dict[str, Any]]:
        """Build a pending plan payload for frontend confirmation without saving it."""

        if self.last_saved_plan and self.last_saved_plan.get("saved"):
            return None

        payload = await self._build_structured_plan_payload(state, full_response)
        if not payload or not payload.itinerary:
            return None

        data = payload.model_dump()
        return {
            "title": payload.title,
            "city": payload.city,
            "days": payload.days,
            "plan_data": data,
        }

    async def _update_agent_state(self, message: str, state: AgentState) -> AgentState:
        """Update workflow state for the current conversation."""

        if state.message_count == 1 or not state.intent:
            classification = await self.classifier.classify(message)
            state.intent = classification.get("intent")
            state.scene = classification.get("scene")

        planning_intents = {
            TravelIntent.PLAN_ROUTE.value,
            TravelIntent.FAMILY_TRIP.value,
            TravelIntent.COUPLE_TRIP.value,
            TravelIntent.SOLO_TRIP.value,
            TravelIntent.BUSINESS_TRIP.value,
            TravelIntent.ELDERLY_TRIP.value,
            TravelIntent.GENERAL_TRIP.value,
        }
        chatting_intents = {
            TravelIntent.SIMPLE_CHAT.value,
            TravelIntent.POI_QUERY.value,
            TravelIntent.FOOD_QUERY.value,
            TravelIntent.REALTIME_QUERY.value,
            TravelIntent.TRANSPORT_QUERY.value,
            TravelIntent.ACCOMMODATION_QUERY.value,
        }

        if state.intent in chatting_intents:
            state.workflow_phase = WorkflowPhase.CHATTING
            return state

        if state.intent in planning_intents:
            extracted = await self._extract_info_from_message(message, state)
            if extracted:
                state.collected_info.update(extracted)

            if state.workflow_phase == WorkflowPhase.COLLECTING and state.is_info_sufficient():
                state.workflow_phase = WorkflowPhase.PLANNING
            elif state.workflow_phase == WorkflowPhase.PLANNING and state.generated_plan:
                state.workflow_phase = WorkflowPhase.ITERATING

            if any(keyword in message.lower() for keyword in ["保存", "导出", "修改", "调整", "表格"]):
                state.workflow_phase = WorkflowPhase.ITERATING

        return state

    async def _extract_info_from_message(self, message: str, state: AgentState) -> Dict[str, Any]:
        """Extract destination/days/companions from user input."""

        prompt = f"""
请分析用户的旅行需求，并提取下列字段。
只返回 JSON，不要额外文本。
已知信息: {json.dumps(state.collected_info, ensure_ascii=False)}
用户消息: {message}

{{
  "destination": "",
  "days": "",
  "companions": ""
}}
""".strip()
        try:
            response = await self.llm.chat(
                [AIChatMessage(role="user", content=prompt)],
                temperature=0.0,
                max_tokens=80,
            )
            data = self._parse_json_object(response)
            return {key: value for key, value in data.items() if value}
        except Exception:  # pragma: no cover - defensive branch
            return {}

    def _select_template(self, state: AgentState) -> str:
        """Pick the output template based on intent."""

        if state.intent == TravelIntent.REALTIME_QUERY.value:
            return "realtime_query"
        if state.intent == TravelIntent.JOURNAL_ASSIST.value:
            return "journal_assist"
        return "full_itinerary"

    def _build_messages(
        self,
        message: str,
        state: AgentState,
        mbti_type: Optional[str],
        current_poi_id: Optional[str],
        current_poi_name: Optional[str],
        conversation_history: Optional[List[AIChatMessage]],
    ) -> List[dict]:
        """Build the LLM message list with memory and skill prompt."""

        system_prompt = self._build_system_prompt(state, mbti_type, current_poi_id, current_poi_name)
        messages: List[dict] = [{"role": "system", "content": system_prompt}]

        if state.conversation_messages:
            for item in state.conversation_messages[:-1]:
                messages.append({"role": item["role"], "content": item["content"]})
        elif conversation_history:
            for item in conversation_history[-10:]:
                messages.append({"role": item.role, "content": item.content})

        messages.append({"role": "user", "content": message})
        return messages

    def _build_system_prompt(
        self,
        state: AgentState,
        mbti_type: Optional[str],
        current_poi_id: Optional[str],
        current_poi_name: Optional[str],
    ) -> str:
        """Assemble the system prompt from the loaded skill."""

        parts: list[str] = []
        if self.skill.role_prompt:
            parts.append(f"# 角色\n{self.skill.role_prompt}")
        if self.skill.workflow:
            parts.append(f"# 工作流\n{self.skill.workflow}")

        if state.workflow_phase == WorkflowPhase.COLLECTING:
            parts.append("# 当前阶段\n优先补齐目的地、天数、出行人群，每次最多追问 2 个问题。")
            if self.skill.preference_collection:
                parts.append(self.skill.preference_collection)
        elif state.workflow_phase == WorkflowPhase.PLANNING:
            parts.append("# 当前阶段\n请输出完整旅行攻略，结构清晰，避免寒暄，并尽量覆盖行前准备、日程、预算、住宿与避坑。")
        elif state.workflow_phase == WorkflowPhase.ITERATING:
            parts.append("# 当前阶段\n请基于已有攻略做定向修改，只改用户关心的部分。")
            if self.skill.iteration_guide:
                parts.append(self.skill.iteration_guide)
        else:
            parts.append("# 当前阶段\n回答当前问题即可，必要时使用工具检索真实经验。")

        if self.skill.vertical_scenes.get("_overview"):
            parts.append(f"# 垂直场景\n{self.skill.vertical_scenes['_overview']}")
        if state.scene and state.scene in self.skill.vertical_scenes:
            parts.append(self.skill.vertical_scenes[state.scene])
        if self.skill.rag_rules:
            parts.append(f"# RAG 融合规则\n{self.skill.rag_rules}")
        if self.skill.output_templates.get(self._select_template(state)):
            parts.append(self.skill.output_templates[self._select_template(state)])
        if self.skill.conversation_style:
            parts.append(f"# 风格\n{self.skill.conversation_style}")

        context_lines: list[str] = []
        if mbti_type:
            context_lines.append(f"- MBTI: {mbti_type}")
        if current_poi_name:
            context_lines.append(f"- 当前 POI: {current_poi_name} ({current_poi_id or ''})")
        if state.collected_info:
            context_lines.append(f"- 已收集偏好: {json.dumps(state.collected_info, ensure_ascii=False)}")
        if context_lines:
            parts.append("# 用户上下文\n" + "\n".join(context_lines))

        parts.append("# 额外要求\n如果已经形成完整攻略，系统会在用户确认后将其结构化保存到‘我的行程’，所以你的输出要便于拆分成表格与清单。")
        return "\n\n---\n\n".join(parts)

    async def _call_llm_with_tools(self, messages: List[dict], tools_schema: Optional[list] = None) -> dict:
        """Call the model with function calling enabled."""

        active_tools_schema = tools_schema or self.tools_schema
        try:
            response = await self.llm.client.chat.completions.create(
                model=self.llm._get_default_model(),
                messages=messages,
                tools=active_tools_schema,
                tool_choice="auto",
                temperature=0.7,
            )
            message = response.choices[0].message
            result = {"content": message.content or "", "tool_calls": None}
            if message.tool_calls:
                result["tool_calls"] = [
                    {
                        "id": call.id,
                        "type": "function",
                        "function": {
                            "name": call.function.name,
                            "arguments": call.function.arguments,
                        },
                    }
                    for call in message.tool_calls
                ]
            return result
        except Exception as exc:
            return await self._fallback_tool_selection(messages, str(exc), active_tools_schema)

    async def _fallback_tool_selection(
        self,
        messages: List[dict],
        error: str,
        tools_schema: Optional[list] = None,
    ) -> dict:
        """Fallback when native tool-calling is unavailable."""

        allowed_names = {
            item.get("function", {}).get("name")
            for item in (tools_schema or self.tools_schema)
        }
        tool_descriptions = "\n".join(
            f"- {tool.name}: {tool.description}"
            for tool in ALL_TOOLS
            if tool.name in allowed_names
        )
        fallback_prompt = (
            "你可以使用下列工具。若需要调用，请只输出 "
            '{"tool": "工具名", "args": {}}；否则直接回答。\n'
            f"{tool_descriptions}\n错误信息: {error}"
        )
        augmented = list(messages) + [{"role": "system", "content": fallback_prompt}]
        sanitized = self._sanitize_messages(augmented)

        try:
            response = await self.llm.client.chat.completions.create(
                model=self.llm._get_default_model(),
                messages=sanitized,
                temperature=0.2,
            )
            text = response.choices[0].message.content or ""
            match = re.search(r'\{"tool"\s*:\s*"([^"]+)".*?"args"\s*:\s*(\{.*\})\}', text, re.DOTALL)
            if not match:
                return {"content": text, "tool_calls": None}
            try:
                args = json.loads(match.group(2))
            except json.JSONDecodeError:
                args = {}
            return {
                "content": "",
                "tool_calls": [
                    {
                        "id": f"fallback_{uuid.uuid4().hex[:8]}",
                        "type": "function",
                        "function": {"name": match.group(1), "arguments": json.dumps(args, ensure_ascii=False)},
                    }
                ],
            }
        except Exception:
            return {"content": "抱歉，服务暂时不可用。", "tool_calls": None}

    def _sanitize_messages(self, messages: List[dict]) -> List[dict]:
        """Convert tool messages into plain assistant-readable context."""

        clean: List[dict] = []
        for message in messages:
            role = message["role"]
            content = message.get("content", "")
            if role == "tool":
                clean.append({"role": "assistant", "content": f"[工具返回结果] {content}"})
            elif role == "assistant" and message.get("tool_calls"):
                names = ", ".join(call["function"]["name"] for call in message["tool_calls"])
                clean.append({"role": "assistant", "content": content or f"(准备调用工具: {names})"})
            elif content:
                clean.append({"role": role, "content": content})
        return clean

    async def _call_llm_simple(self, messages: List[dict]) -> str:
        """Plain model call without tools."""

        sanitized = self._sanitize_messages(messages)
        return await self.llm.chat([AIChatMessage(role=item["role"], content=item["content"]) for item in sanitized])

    async def _stream_llm(self, messages: List[dict]) -> AsyncGenerator[str, None]:
        """Stream the final answer from the model."""

        sanitized = self._sanitize_messages(messages)
        chat_messages = [AIChatMessage(role=item["role"], content=item["content"]) for item in sanitized]
        async for chunk in self.llm.chat_stream(chat_messages):
            yield chunk

    @staticmethod
    def _parse_json_object(text: str) -> dict[str, Any]:
        """Extract the first JSON object from model output."""

        stripped = text.strip()
        if not stripped:
            return {}
        try:
            parsed = json.loads(stripped)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            pass

        match = re.search(r"\{[\s\S]*\}", stripped)
        if not match:
            return {}
        try:
            parsed = json.loads(match.group(0))
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}

    @staticmethod
    def _is_simple_chat(message: str, intent: Optional[str] = None) -> bool:
        """Heuristic guard for lightweight casual chat."""

        if intent and intent != TravelIntent.SIMPLE_CHAT.value:
            return False

        travel_keywords = [
            "行程",
            "规划",
            "路线",
            "攻略",
            "怎么去",
            "怎么玩",
            "交通",
            "吃",
            "美食",
            "餐厅",
            "住",
            "景点",
            "门票",
            "周边",
            "哪里",
            "天",
        ]
        return not any(keyword in message.lower() for keyword in travel_keywords)

    @staticmethod
    def _select_relevant_tools(message: str, intent: Optional[str]) -> list:
        """Select a minimal tool subset for the current request."""

        msg = message.lower()
        selected: set[str] = set()

        if intent in {TravelIntent.PLAN_ROUTE.value, TravelIntent.FAMILY_TRIP.value, TravelIntent.COUPLE_TRIP.value}:
            selected.update({"plan_route", "search_community", "get_poi_detail"})

        if any(keyword in msg for keyword in ["攻略", "评价", "避坑", "社区"]):
            selected.add("search_community")
        if any(keyword in msg for keyword in ["景点", "门票", "详情"]):
            selected.add("get_poi_detail")
        if any(keyword in msg for keyword in ["行程", "规划", "几天", "计划"]):
            selected.add("plan_route")
        if any(keyword in msg for keyword in ["附近", "周边", "去哪"]):
            selected.add("search_nearby")
        if any(keyword in msg for keyword in ["交通", "地铁", "高铁", "飞机"]):
            selected.add("get_transport_info")
        if any(keyword in msg for keyword in ["吃", "美食", "小吃"]):
            selected.add("get_food_recommendation")
        if any(keyword in msg for keyword in ["住", "酒店", "民宿"]):
            selected.add("get_accommodation_info")
        if any(keyword in msg for keyword in ["保存", "加入", "写入", "记录"]):
            selected.add("save_travel_plan")

        if not selected:
            selected.update({"search_community", "get_poi_detail"})

        return get_tools_by_names(list(selected))

    def _build_tools_schema(self) -> list:
        """Build the callable tool schema for the current agent mode."""

        tools_schema = get_all_tools_openai_format()
        if self.auto_save_plan:
            return tools_schema
        return [
            tool_schema
            for tool_schema in tools_schema
            if tool_schema.get("function", {}).get("name") != "save_travel_plan"
        ]
