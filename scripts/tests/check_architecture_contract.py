#!/usr/bin/env python3
from __future__ import annotations

import io
import re
import tokenize
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def function_body(source: str, name: str) -> tuple[str, ...]:
    """Tokenize thin GDScript wrappers; indentation and comments are not contracts."""
    declaration = r"^(?:@|(?:static )?(?:func|var|const|signal|class_name|class|enum)\b)"
    match = re.search(rf"(?ms)^(?:static )?func {re.escape(name)}\b.*?(?={declaration}|\Z)", source)
    if match is None:
        return ()
    body = False
    tokens: list[str] = []
    for token in tokenize.generate_tokens(io.StringIO(match[0]).readline):
        if not body:
            body = token.type == tokenize.NEWLINE
        elif token.type not in {
            tokenize.INDENT, tokenize.DEDENT, tokenize.NEWLINE, tokenize.NL,
            tokenize.COMMENT, tokenize.ENDMARKER,
        }:
            tokens.append(token.string)
    return tuple(tokens)


def delegates(source: str, name: str, calls: str) -> bool:
    return function_body(source, name) == function_body("func expected():\n" + calls, "expected")


def main() -> int:
    failures: list[str] = []

    main_script = read("scripts/main.gd")
    bridge_script = read("scripts/game/game_achievement_bridge.gd")
    enemy_defeat_flow = read("scripts/game/enemy_defeat_flow.gd")
    scene_wiring = read("scripts/game/game_scene_wiring.gd")
    story_context_flow = read("scripts/game/game_story_context_flow.gd")
    hud_flow = read("scripts/game/game_hud_flow.gd")
    character_panel_flow = read("scripts/game/game_character_panel_flow.gd")
    map_flow = read("scripts/game/game_map_flow.gd")
    player_script = read("scripts/player.gd")
    player_map_bounds_flow = read("scripts/player/player_map_bounds_flow.gd")
    player_level_flow = read("scripts/player/player_level_flow.gd")
    player_blessing_system = read("scripts/player/player_blessing_system.gd")
    player_blessing_bridge = read("scripts/player/player_blessing_skill_bridge.gd")
    character_panel_script = read("scripts/ui/hud/character_panel.gd")
    developer_mode = read("scripts/developer_mode.gd")
    developer_panel = read("scripts/developer/developer_panel.gd")
    reward_flow = read("scripts/game/reward_flow.gd")
    game_main_flow = read("scripts/game/game_main_flow.gd")
    run_save_flow = read("scripts/game/run_save_flow.gd")
    level_up_ui = read("scripts/level_up_ui.gd")
    hud_script = read("scripts/hud.gd")
    steam_adapter = read("scripts/achievements/steam_achievement_adapter.gd")

    if "GAME_ACHIEVEMENT_BRIDGE" not in main_script:
        failures.append("scripts/main.gd must route achievement events through GAME_ACHIEVEMENT_BRIDGE")
    if "AchievementService." in main_script:
        failures.append("scripts/main.gd must not call AchievementService directly")
    if not delegates(main_script, "_on_enemy_defeated", "\tENEMY_DEFEAT_FLOW.handle_enemy_defeated(self, enemy_kind, enemy)\n"):
        failures.append("scripts/main.gd enemy defeat handler must delegate to ENEMY_DEFEAT_FLOW only")
    if "REWARD_FLOW.show_small_boss_reward" in main_script or "REWARD_FLOW.show_endless_boss_reward" in main_script:
        failures.append("scripts/main.gd must not handle enemy reward UI directly; use enemy_defeat_flow.gd")
    if not delegates(main_script, "_setup_ui", "\tGAME_SCENE_WIRING.setup_ui(self)\n"):
        failures.append("scripts/main.gd UI setup must delegate to GAME_SCENE_WIRING")
    if not delegates(main_script, "_connect_player_signals", "\tGAME_SCENE_WIRING.connect_player_signals(self)\n\t_refresh_hud()\n"):
        failures.append("scripts/main.gd player signal wiring must delegate to GAME_SCENE_WIRING")
    hud_wrappers = {
        "_refresh_hud": "GAME_HUD_FLOW.refresh_hud(self)",
        "_update_boss_hud": "GAME_HUD_FLOW.update_boss_hud(self)",
        "_update_performance_metrics": "GAME_HUD_FLOW.update_performance_metrics(self, delta)",
        "_on_player_stats_changed": "GAME_HUD_FLOW.on_player_stats_changed(self, summary)",
        "_on_player_mana_changed": "GAME_HUD_FLOW.on_player_mana_changed(self, current_mana, max_mana)",
    }
    for name, call in hud_wrappers.items():
        if call not in main_script:
            failures.append(f"scripts/main.gd HUD wrapper must delegate {name} to GAME_HUD_FLOW")
    forbidden_main_hud_tokens = [
        "hud.update_display",
        "hud.update_stats",
        "hud.update_health",
        "hud.update_mana",
        "hud.update_time",
        "hud.show_boss_ui",
        "hud.hide_boss_ui",
    ]
    for token in forbidden_main_hud_tokens:
        if token in main_script:
            failures.append(f"scripts/main.gd must not call HUD projection directly: {token}")
            break
    character_panel_wrappers = {
        "_toggle_character_panel": "GAME_CHARACTER_PANEL_FLOW.toggle_character_panel(self)",
        "_show_character_panel": "GAME_CHARACTER_PANEL_FLOW.show_character_panel(self)",
        "_hide_character_panel": "GAME_CHARACTER_PANEL_FLOW.hide_character_panel(self)",
    }
    for name, call in character_panel_wrappers.items():
        if call not in main_script:
            failures.append(f"scripts/main.gd character-panel wrapper must delegate {name} to GAME_CHARACTER_PANEL_FLOW")
    forbidden_panel_tokens = [
        "character_panel.show_for_player",
        "character_panel.hide_panel",
        "character_panel.visible:",
    ]
    for token in forbidden_panel_tokens:
        if token in main_script:
            failures.append(f"scripts/main.gd must not own character-panel visibility logic directly: {token}")
            break
    story_wrappers = {
        "load_story_stage_context": "GAME_STORY_CONTEXT_FLOW.load_story_stage_context(self)",
        "apply_story_loadout": "GAME_STORY_CONTEXT_FLOW.apply_story_loadout(self)",
        "get_effective_boss_spawn_time": "GAME_STORY_CONTEXT_FLOW.get_effective_boss_spawn_time(self)",
        "get_effective_stage_curve_time": "GAME_STORY_CONTEXT_FLOW.get_effective_stage_curve_time(self)",
        "get_story_spawn_interval_multiplier": "GAME_STORY_CONTEXT_FLOW.get_story_spawn_interval_multiplier(self)",
        "get_story_enemy_health_multiplier": "GAME_STORY_CONTEXT_FLOW.get_story_enemy_health_multiplier(self)",
        "get_story_enemy_speed_multiplier": "GAME_STORY_CONTEXT_FLOW.get_story_enemy_speed_multiplier(self)",
    }
    for name, call in story_wrappers.items():
        if call not in main_script:
            failures.append(f"scripts/main.gd story wrapper must delegate {name} to GAME_STORY_CONTEXT_FLOW")
    map_wrappers = {
        "setup_map_features": "GAME_MAP_FLOW.setup_map_features(self)",
        "update_minimap": "GAME_MAP_FLOW.update_minimap(self)",
    }
    for name, call in map_wrappers.items():
        if call not in main_script:
            failures.append(f"scripts/main.gd map wrapper must delegate {name} to GAME_MAP_FLOW")

    if "/root/AchievementService" not in bridge_script:
        failures.append("game_achievement_bridge.gd must resolve AchievementService through the scene tree")
    if "GAME_ACHIEVEMENT_BRIDGE.record_enemy_defeated" not in enemy_defeat_flow:
        failures.append("enemy_defeat_flow.gd must preserve enemy-defeat achievement recording")
    if "REWARD_FLOW.show_small_boss_reward" not in enemy_defeat_flow or "REWARD_FLOW.show_endless_boss_reward" not in enemy_defeat_flow:
        failures.append("enemy_defeat_flow.gd must own enemy reward routing")
    required_wiring_tokens = [
        "static func setup_ui",
        "static func connect_player_signals",
        '"developer_level_up_requested"',
        '"experience_changed"',
        '"died"',
    ]
    for token in required_wiring_tokens:
        if token not in scene_wiring:
            failures.append(f"game_scene_wiring.gd missing required wiring token: {token}")
    required_story_tokens = [
        "static func load_story_stage_context",
        "static func apply_story_loadout",
        "SAVE_MANAGER.get_current_story_stage",
        "SAVE_MANAGER.is_endless_mode_active",
        "ENEMY_DIRECTOR.get_effective_boss_spawn_time",
    ]
    for token in required_story_tokens:
        if token not in story_context_flow:
            failures.append(f"game_story_context_flow.gd missing required story context token: {token}")
    required_hud_tokens = [
        "static func refresh_hud",
        "static func update_boss_hud",
        "static func hide_boss_ui",
        "static func on_player_mana_changed",
        "PERFORMANCE_MONITOR.collect_metrics",
        "set_developer_boss_options",
    ]
    for token in required_hud_tokens:
        if token not in hud_flow:
            failures.append(f"game_hud_flow.gd missing required HUD token: {token}")
    required_panel_tokens = [
        "static func toggle_character_panel",
        "static func can_show_character_panel",
        "static func show_character_panel",
        "static func hide_character_panel",
        "show_for_player",
        "hide_panel",
    ]
    for token in required_panel_tokens:
        if token not in character_panel_flow:
            failures.append(f"game_character_panel_flow.gd missing required character-panel token: {token}")
    required_map_tokens = [
        "MAP_BOUNDARY_VIEW",
        "static func setup_map_features",
        "static func update_minimap",
        "configure_minimap",
        "update_minimap",
        "get_nodes_in_group(group_name)",
    ]
    for token in required_map_tokens:
        if token not in map_flow:
            failures.append(f"game_map_flow.gd missing required map token: {token}")
    if "PLAYER_MAP_BOUNDS_FLOW.clamp_to_active_map_bounds(self)" not in player_script:
        failures.append("scripts/player.gd must clamp movement through PLAYER_MAP_BOUNDS_FLOW")
    if "static func clamp_to_active_map_bounds" not in player_map_bounds_flow or "map_bounds" not in player_map_bounds_flow:
        failures.append("player_map_bounds_flow.gd must own player map-bound clamping")
    if "func configure_minimap" not in hud_script or "func update_minimap" not in hud_script or "func _draw_minimap" not in hud_script:
        failures.append("scripts/hud.gd must expose minimap configure/update/draw methods")
    forbidden_platform_calls = [
        'Engine.has_singleton("Steam")',
        'Engine.get_singleton("Steam")',
        ".setAchievement",
        "storeStats",
        "GodotSteam.",
    ]
    for token in forbidden_platform_calls:
        if token in bridge_script:
            failures.append(
                "game_achievement_bridge.gd must stay platform-neutral; Steam/GodotSteam calls belong in steam_achievement_adapter.gd"
            )
            break

    if "get_node_or_null(\"/root/AchievementService\")" not in steam_adapter:
        failures.append("steam_achievement_adapter.gd must not rely on a compile-time AchievementService global")

    retired_progression_entries = {
        "scripts/main.gd": (main_script, ("opening_trait_choice_completed",)),
        "scripts/game/game_main_flow.gd": (game_main_flow, ("opening_trait_choice_completed",)),
        "scripts/game/run_save_flow.gd": (run_save_flow, ("opening_trait_choice_completed",)),
        "scripts/game/reward_flow.gd": (
            reward_flow,
            ("show_opening_trait_choice", 'reward_context == "opening_trait_choice"'),
        ),
        "scripts/level_up_ui.gd": (level_up_ui, ("func show_opening_trait_choice",)),
        "scripts/player/player_level_flow.gd": (
            player_level_flow,
            ("BUILD_CHOICE_LEVELS", "ENDLESS_BUILD_CHOICE_", "should_offer_build_choice_for_level"),
        ),
        "scripts/player/player_blessing_system.gd": (
            player_blessing_system,
            (
                "static func _pick_options",
                "_ensure_forced_tier_four_blessing",
                "_build_offerable_options_for_tier",
                "MANUAL_COMPOSE_TIER_ONE_LEVEL",
                "can_compose_role_blessing",
                "can_compose_skill_blessing",
                "compose_role_blessing",
                "compose_skill_blessing",
                "_compose_blessing",
            ),
        ),
        "scripts/player/player_blessing_skill_bridge.gd": (
            player_blessing_bridge,
            (
                "can_compose_role_blessing",
                "can_compose_skill_blessing",
                "compose_role_blessing",
                "compose_skill_blessing",
            ),
        ),
        "scripts/player.gd": (
            player_script,
            (
                "can_compose_role_blessing",
                "can_compose_skill_blessing",
                "compose_role_blessing",
                "compose_skill_blessing",
            ),
        ),
        "scripts/ui/hud/character_panel.gd": (
            character_panel_script,
            (
                "blessing_popup",
                "pending_compose_",
                "右键合成",
                "I x3",
                "_show_blessing_compose_popup",
            ),
        ),
        "scripts/developer_mode.gd": (
            developer_mode,
            (
                "force_tier_four_blessing",
                "should_offer_all_blessings",
                "should_allow_unlimited_upgrade_refresh",
            ),
        ),
        "scripts/developer/developer_panel.gd": (
            developer_panel,
            ("force_tier_four_blessing", "必出四级祝福"),
        ),
    }
    for path, (source, retired_tokens) in retired_progression_entries.items():
        for token in retired_tokens:
            if token in source:
                failures.append(f"{path} still exposes retired progression entry: {token}")

    graphifyignore = ROOT / ".graphifyignore"
    if not graphifyignore.exists():
        failures.append(".graphifyignore is required so addon tooling does not dominate architecture graphs")
    else:
        ignore_text = graphifyignore.read_text(encoding="utf-8")
        if "addons/godot_mcp/" not in ignore_text:
            failures.append(".graphifyignore must exclude addons/godot_mcp/")

    if failures:
        print("ARCHITECTURE_CONTRACT_CHECK_FAILED")
        print("\n".join(failures))
        return 1

    print("ARCHITECTURE_CONTRACT_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
