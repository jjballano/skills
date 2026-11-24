#!/usr/bin/env python3
"""Checks every skill in plugins/*/skills/*/SKILL.md.

- Frontmatter has name and description, and only keys claude.ai also accepts.
- name is kebab-case, at most 64 chars, and equals its folder name.
- description is at most 1024 chars.
- Relative links in SKILL.md point to files that exist inside the skill.
- No absolute home paths (/Users/..., /home/..., ~/) in any skill file.

Exit code 1 if anything fails. Standard library only.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALLOWED_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK_RE = re.compile(r"\]\(([^)#\s]+)\)")
HOME_PATH_RE = re.compile(r"(/Users/[A-Za-z]|/home/[A-Za-z]|~/\.)")


def frontmatter(text: str) -> dict[str, str] | None:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end == -1:
        return None
    fields: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if line and not line[0].isspace() and ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


def check_skill(skill_md: Path) -> list[str]:
    errors: list[str] = []
    skill_dir = skill_md.parent
    text = skill_md.read_text(encoding="utf-8")
    fields = frontmatter(text)
    if fields is None:
        return [f"{skill_md}: missing frontmatter"]

    extra = set(fields) - ALLOWED_KEYS
    if extra:
        errors.append(f"{skill_md}: keys not accepted by claude.ai: {sorted(extra)}")
    name = fields.get("name", "")
    if not NAME_RE.match(name) or len(name) > 64:
        errors.append(f"{skill_md}: invalid name {name!r}")
    if name != skill_dir.name:
        errors.append(f"{skill_md}: name {name!r} != folder {skill_dir.name!r}")
    description = fields.get("description", "")
    if not description:
        errors.append(f"{skill_md}: missing description")
    elif len(description) > 1024:
        errors.append(f"{skill_md}: description is {len(description)} chars (max 1024)")

    for target in LINK_RE.findall(text):
        if "://" in target or target.startswith("mailto:"):
            continue
        resolved = (skill_dir / target).resolve()
        if not resolved.exists():
            errors.append(f"{skill_md}: broken link {target}")
        elif skill_dir.resolve() not in resolved.parents:
            errors.append(f"{skill_md}: link leaves the skill folder: {target}")

    for path in skill_dir.rglob("*"):
        if path.is_file():
            content = path.read_text(encoding="utf-8", errors="ignore")
            if HOME_PATH_RE.search(content):
                errors.append(f"{path}: contains a machine-specific home path")
    return errors


def main() -> int:
    skills = sorted(ROOT.glob("plugins/*/skills/*/SKILL.md"))
    if not skills:
        print("no skills found", file=sys.stderr)
        return 1
    errors = [e for s in skills for e in check_skill(s)]
    for error in errors:
        print(error, file=sys.stderr)
    print(f"{len(skills)} skills checked, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
