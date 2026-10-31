#!/usr/bin/env python3
"""Check a few high-value boundaries in the current Chronicle architecture."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main() -> int:
    failures: list[str] = []
    shell = read("scripts/ui/chronicle/chronicle_shell.gd")
    battle_view = read("scripts/ui/chronicle/battle_view.gd")
    music_player = read("scripts/audio/music_player.gd")
    catalog = read("scripts/audio/music_catalog.gd")
    campaign = read("scripts/campaign/campaign_service.gd")
    store = read("scripts/campaign/campaign_store.gd")
    settings = read("scripts/shared/settings.gd")
    enemy_art = read("scripts/ui/chronicle/battle_art.gd")
    enemy_placeholder = read("scripts/ui/chronicle/enemy_placeholder.gd")

    required = {
        "chronicle_shell.gd": (shell, ("SESSION := preload(\"res://scripts/campaign/campaign_service.gd\")", "MUSIC_CONTEXT", "_on_battle_music_context", "_sync_page_music")),
        "battle_view.gd": (battle_view, ("signal music_context_changed", "music_context_changed.emit", "battle_session.gd", "battle_canvas.gd")),
        "music_player.gd": (music_player, ("same_phase_family", "play_stinger", "capture_snapshot", "restore_snapshot")),
        "music_catalog.gd": (catalog, ("chapter_cues", "is_one_shot", "same_phase_family", "static func path(")),
        "chronicle_music.gd": (read("scripts/audio/chronicle_music.gd"), ("static func battle_cue", "static func page_cue", "static func story_cue")),
        "campaign_service.gd": (campaign, ("user://chronicle_campaign_v1", "SCHEMA := 1", "const STORE", "complete_battle", "save_story_checkpoint")),
        "campaign_store.gd": (store, ("static func write", "static func read", "path + \".bak\"", "validator.call")),
        "settings.gd": (settings, ("COMFORT_DEFAULTS", "audio", "hud_layout", "load_keycode", "ACTION_INTERACT")),
        "battle_art.gd": (enemy_art, ("ENEMY_PLACEHOLDER", "create_enemy", "fit_enemy_instance", "battle_environments.json", "missing_enemy_art")),
        "enemy_placeholder.gd": (enemy_placeholder, ("func body_profile", "Vector2(64, 0)", "extends Node2D")),
    }
    for label, (source, tokens) in required.items():
        for token in tokens:
            if token not in source:
                failures.append(f"{label} missing Chronicle contract token: {token}")

    if "MUSIC_CONTEXT.battle_cue(id, form_index)" not in shell or "music_context_changed.connect(_on_battle_music_context)" not in shell:
        failures.append("Chronicle battle music must route the production battle signal through ChronicleMusic")
    if "chronicle_session.gd" in shell or "chronicle_battle.gd" in shell:
        failures.append("chronicle_shell.gd must use the production campaign/battle modules")
    for retired in ("scenes/main_menu.tscn", "scenes/endless_save_select.tscn", "scripts/achievements/achievement_service.gd"):
        if (ROOT / retired).exists():
            failures.append(f"retired legacy entry still exists in active tree: {retired}")
    for path in ROOT.joinpath("scripts").rglob("*.gd"):
        text = path.read_text(encoding="utf-8-sig")
        if "res://scripts/game/" in text or "res://scripts/player.gd" in text:
            failures.append(f"active script keeps a retired legacy gameplay reference: {path.relative_to(ROOT)}")

    if failures:
        print("ARCHITECTURE_CONTRACT_CHECK_FAILED")
        print("\n".join(failures))
        return 1
    print("ARCHITECTURE_CONTRACT_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
