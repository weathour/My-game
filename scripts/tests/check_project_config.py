#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project.godot"
REQUIRED_AUTOLOADS = {
    "AchievementService": "res://scripts/achievements/achievement_service.gd",
    "AchievementNotifier": "res://scripts/achievements/achievement_notifier.gd",
    "WindowDisplayManager": "res://scripts/window_display_manager.gd",
}
REQUIRED_SETTINGS = {
    "run/main_scene": '"res://scenes/main_menu.tscn"',
    "run/max_fps": "120",
    "window/size/viewport_width": "1280",
    "window/size/viewport_height": "720",
    "window/size/resizable": "true",
    "window/stretch/mode": '"canvas_items"',
    "window/stretch/aspect": '"keep"',
    "window/vsync/vsync_mode": "0",
}
REQUIRED_FILES = [
    "scripts/game/game_map_flow.gd",
    "scripts/map/map_boundary_view.gd",
    "scripts/player/player_map_bounds_flow.gd",
    "scripts/tests/map_ui_smoke.gd",
]


def parse_sections(text: str) -> dict[str, dict[str, str]]:
    sections: dict[str, dict[str, str]] = {}
    current = ""
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        section_match = re.match(r"^\[([^\]]+)\]$", line)
        if section_match:
            current = section_match.group(1)
            sections.setdefault(current, {})
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            sections.setdefault(current, {})[key.strip()] = value.strip()
    return sections


def main() -> int:
    failures: list[str] = []
    text = PROJECT.read_text(encoding="utf-8-sig")
    sections = parse_sections(text)

    app = sections.get("application", {})
    display = sections.get("display", {})
    autoload = sections.get("autoload", {})

    for key, expected in REQUIRED_SETTINGS.items():
        section = app if key.startswith("run/") else display
        actual = section.get(key)
        if actual != expected:
            failures.append(f"{key}: expected {expected}, got {actual}")

    for name, path in REQUIRED_AUTOLOADS.items():
        raw = autoload.get(name)
        expected = f'"*{path}"'
        if raw != expected:
            failures.append(f"autoload {name}: expected {expected}, got {raw}")
        fs_path = ROOT / path.removeprefix("res://")
        if not fs_path.exists():
            failures.append(f"autoload {name}: missing script {path}")

    for path in REQUIRED_FILES:
        if not (ROOT / path).exists():
            failures.append(f"required file missing: {path}")

    if failures:
        print("PROJECT_CONFIG_CHECK_FAILED")
        print("\n".join(failures))
        return 1
    print("PROJECT_CONFIG_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
