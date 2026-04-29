"""Load and parse the root `travel-planner` skill into structured prompt blocks."""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional

logger = logging.getLogger(__name__)


@dataclass
class Skill:
    """Structured prompt fragments parsed from the skill markdown."""

    name: str = ""
    description: str = ""
    role_prompt: str = ""
    workflow: str = ""
    preference_collection: str = ""
    vertical_scenes: Dict[str, str] = field(default_factory=dict)
    rag_rules: str = ""
    output_templates: Dict[str, str] = field(default_factory=dict)
    conversation_style: str = ""
    iteration_guide: str = ""


def _extract_frontmatter(content: str) -> tuple[Dict[str, str], str]:
    """Extract YAML-like frontmatter from markdown content."""

    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not match:
        return {}, content

    frontmatter: Dict[str, str] = {}
    for line in match.group(1).strip().splitlines():
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        frontmatter[key.strip()] = value.strip()
    return frontmatter, content[match.end():]


def _split_sections(content: str) -> Dict[str, str]:
    """Split markdown content by level-2 headings."""

    sections: Dict[str, str] = {}
    current_title = ""
    current_lines: list[str] = []

    for line in content.splitlines():
        heading_match = re.match(r"^##\s+(.+)", line)
        if heading_match:
            if current_title:
                sections[current_title] = "\n".join(current_lines).strip()
            current_title = heading_match.group(1).strip()
            current_lines = []
            continue
        current_lines.append(line)

    if current_title:
        sections[current_title] = "\n".join(current_lines).strip()
    return sections


def _parse_vertical_scenes(content: str) -> Dict[str, str]:
    """Parse `vertical-scenes.md` into scene-keyed fragments."""

    scene_key_map = {
        "亲子": "family_trip",
        "家庭": "family_trip",
        "情侣": "couple_trip",
        "蜜月": "couple_trip",
        "独自": "solo_trip",
        "背包": "solo_trip",
        "商务": "business_trip",
        "银发": "elderly_trip",
        "老年": "elderly_trip",
    }

    scenes: Dict[str, str] = {}
    for title, body in _split_sections(content).items():
        for keyword, scene_key in scene_key_map.items():
            if keyword in title:
                scenes[scene_key] = f"## {title}\n{body}"
                break
    return scenes


def _parse_output_templates(content: str) -> Dict[str, str]:
    """Parse `output-templates.md` into named template fragments."""

    template_key_map = {
        "完整行程": "full_itinerary",
        "出发前规划": "full_itinerary",
        "即时查询": "realtime_query",
        "旅途中": "realtime_query",
        "游记整理": "journal_assist",
        "回来后": "journal_assist",
    }

    templates: Dict[str, str] = {}
    for title, body in _split_sections(content).items():
        for keyword, template_key in template_key_map.items():
            if keyword in title:
                templates[template_key] = f"## {title}\n{body}"
                break
    return templates


def _parse_skill_md(content: str) -> Skill:
    """Parse `SKILL.md` into a `Skill` object."""

    frontmatter, body = _extract_frontmatter(content)
    sections = _split_sections(body)
    skill = Skill(
        name=frontmatter.get("name", "travel-planner"),
        description=frontmatter.get("description", ""),
    )

    skill.role_prompt = sections.get("角色定位", "")
    skill.workflow = sections.get("工作流程总览", "")

    preference_key = next((key for key in sections if "偏好采集" in key), None)
    if preference_key:
        skill.preference_collection = sections[preference_key]

    scene_key = next((key for key in sections if "垂直场景" in key), None)
    if scene_key:
        skill.vertical_scenes["_overview"] = sections[scene_key]

    rag_key = next((key for key in sections if "RAG" in key), None)
    if rag_key:
        skill.rag_rules = sections[rag_key]

    output_key = next((key for key in sections if "攻略生成" in key), None)
    if output_key:
        skill.output_templates["_overview"] = sections[output_key]

    style_key = next((key for key in sections if "对话风格" in key), None)
    if style_key:
        skill.conversation_style = sections[style_key]

    iteration_key = next((key for key in sections if "迭代优化" in key), None)
    if iteration_key:
        skill.iteration_guide = sections[iteration_key]

    return skill


_DEFAULT_SKILL_DIR = Path(__file__).resolve().parent.parent.parent.parent / "travel-planner"
_cached_skill: Optional[Skill] = None


def load_skill(skill_dir: Optional[str] = None) -> Skill:
    """Load the root skill and cache it in memory."""

    global _cached_skill

    skill_path = Path(skill_dir) if skill_dir else _DEFAULT_SKILL_DIR
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        logger.warning("SKILL.md 未找到：%s，智能体将退回通用旅行助手模式", skill_md)
        _cached_skill = Skill(name="fallback", description="通用旅行助手")
        return _cached_skill

    logger.info("正在加载 travel-planner skill: %s", skill_md)
    with open(skill_md, "r", encoding="utf-8") as file:
        skill = _parse_skill_md(file.read())

    refs_dir = skill_path / "references"
    if refs_dir.exists():
        vertical_scenes = refs_dir / "vertical-scenes.md"
        if vertical_scenes.exists():
            with open(vertical_scenes, "r", encoding="utf-8") as file:
                scenes = _parse_vertical_scenes(file.read())
                skill.vertical_scenes.update(scenes)
                logger.info("已加载 %s 个垂直场景规则", len(scenes))

        output_templates = refs_dir / "output-templates.md"
        if output_templates.exists():
            with open(output_templates, "r", encoding="utf-8") as file:
                templates = _parse_output_templates(file.read())
                skill.output_templates.update(templates)
                logger.info("已加载 %s 个输出模板", len(templates))

    _cached_skill = skill
    logger.info(
        "Skill '%s' 加载完成 (场景=%s, 模板=%s)",
        skill.name,
        len(skill.vertical_scenes),
        len(skill.output_templates),
    )
    return skill


def get_skill() -> Skill:
    """Return the cached skill, loading it on first access."""

    global _cached_skill
    if _cached_skill is None:
        return load_skill()
    return _cached_skill


def reload_skill(skill_dir: Optional[str] = None) -> Skill:
    """Force a skill reload, mainly for development/debugging."""

    global _cached_skill
    _cached_skill = None
    return load_skill(skill_dir)
