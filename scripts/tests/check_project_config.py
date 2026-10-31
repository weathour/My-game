#!/usr/bin/env python3
"""Guard the current Chronicle entry scene and its shared window autoload."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project.godot"


def sections(text: str) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    current = ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        match = re.fullmatch(r"\[([^]]+)\]", line)
        if match:
            current = match.group(1)
            result.setdefault(current, {})
        elif "=" in line:
            key, value = line.split("=", 1)
            result.setdefault(current, {})[key.strip()] = value.strip()
    return result


def main() -> int:
    data = sections(PROJECT.read_text(encoding="utf-8-sig"))
    failures: list[str] = []
    expected = {
        ("application", "run/main_scene"): '"res://scenes/chronicle/chronicle_shell.tscn"',
        ("application", "run/max_fps"): "120",
        ("display", "window/size/viewport_width"): "1280",
        ("display", "window/size/viewport_height"): "720",
        ("display", "window/stretch/mode"): '"canvas_items"',
        ("display", "window/vsync/vsync_mode"): "0",
        ("rendering", "renderer/rendering_method"): '"mobile"',
    }
    for (section, key), value in expected.items():
        if data.get(section, {}).get(key) != value:
            failures.append(f"[{section}] {key}: expected {value}, got {data.get(section, {}).get(key)}")

    autoloads = data.get("autoload", {})
    expected_autoload = '"*res://scripts/shared/window_display_manager.gd"'
    if autoloads.get("WindowDisplayManager") != expected_autoload:
        failures.append(f"autoload WindowDisplayManager: expected {expected_autoload}, got {autoloads.get('WindowDisplayManager')}")
    if set(autoloads) != {"WindowDisplayManager"}:
        failures.append(f"unexpected autoloads: {sorted(set(autoloads) - {'WindowDisplayManager'})}")

    for rel in (
        "scenes/chronicle/chronicle_shell.tscn",
        "scripts/campaign/campaign_service.gd",
        "scripts/campaign/campaign_store.gd",
        "scripts/battle/battle_session.gd",
        "scripts/content/story_catalog.gd",
        "scripts/shared/settings.gd",
        "scripts/shared/window_display_manager.gd",
        "scripts/audio/music_catalog.gd",
        "scripts/audio/music_player.gd",
    ):
        if not (ROOT / rel).is_file():
            failures.append(f"required current Chronicle file missing: {rel}")

    if failures:
        print("PROJECT_CONFIG_CHECK_FAILED")
        print("\n".join(failures))
        return 1
    print("PROJECT_CONFIG_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
