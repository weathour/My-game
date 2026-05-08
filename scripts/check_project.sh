#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  elif [[ -x "/home/weathour/.local/bin/godot-4.6.2" ]]; then
    GODOT_BIN="/home/weathour/.local/bin/godot-4.6.2"
  else
    GODOT_BIN=""
  fi
fi

echo "== Python project checks =="
python3 scripts/tests/check_docs_links.py
python3 scripts/tests/check_achievements.py
python3 scripts/tests/check_project_config.py
python3 scripts/tests/check_architecture_contract.py

if [[ -n "$GODOT_BIN" ]]; then
  echo "== Godot headless parse =="
  "$GODOT_BIN" --headless --path . --quit --verbose 2>&1 | tee /tmp/my-game-godot-check.log >/dev/null
  if grep -E "SCRIPT ERROR|Parse Error|Invalid call|Failed to load script|Failed to instantiate" /tmp/my-game-godot-check.log; then
    echo "GODOT_PARSE_CHECK_FAILED"
    exit 1
  fi
  echo "GODOT_PARSE_CHECK_OK"

  echo "== Godot main scene smoke =="
  "$GODOT_BIN" --headless --path . res://scenes/main.tscn --quit --verbose 2>&1 | tee /tmp/my-game-main-scene-smoke.log >/dev/null
  if grep -E "SCRIPT ERROR|Parser Error|Invalid call|Failed to load script|Compilation failed" /tmp/my-game-main-scene-smoke.log; then
    echo "MAIN_SCENE_SMOKE_FAILED"
    exit 1
  fi
  echo "MAIN_SCENE_SMOKE_OK"

  echo "== Godot achievement smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/achievement_smoke.gd 2>&1 | tee /tmp/my-game-achievement-smoke.log
  if ! grep -q "ACHIEVEMENT_SMOKE_OK" /tmp/my-game-achievement-smoke.log; then
    echo "ACHIEVEMENT_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player blessing system smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_blessing_system_smoke.gd 2>&1 | tee /tmp/my-game-player-blessing-system-smoke.log
  if ! grep -q "PLAYER_BLESSING_SYSTEM_SMOKE_OK" /tmp/my-game-player-blessing-system-smoke.log; then
    echo "PLAYER_BLESSING_SYSTEM_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot map UI smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/map_ui_smoke.gd 2>&1 | tee /tmp/my-game-map-ui-smoke.log
  if ! grep -q "MAP_UI_SMOKE_OK" /tmp/my-game-map-ui-smoke.log; then
    echo "MAP_UI_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot level-up scroll reopen smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/level_up_scroll_reopen_smoke.gd 2>&1 | tee /tmp/my-game-level-up-scroll-reopen-smoke.log
  if ! grep -q "LEVEL_UP_SCROLL_REOPEN_SMOKE_OK" /tmp/my-game-level-up-scroll-reopen-smoke.log; then
    echo "LEVEL_UP_SCROLL_REOPEN_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player targeting smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_targeting_smoke.gd 2>&1 | tee /tmp/my-game-player-targeting-smoke.log
  if ! grep -q "PLAYER_TARGETING_SMOKE_OK" /tmp/my-game-player-targeting-smoke.log; then
    echo "PLAYER_TARGETING_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player damage resolver smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_damage_resolver_smoke.gd 2>&1 | tee /tmp/my-game-player-damage-resolver-smoke.log
  if ! grep -q "PLAYER_DAMAGE_RESOLVER_SMOKE_OK" /tmp/my-game-player-damage-resolver-smoke.log; then
    echo "PLAYER_DAMAGE_RESOLVER_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player timer flow smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_timer_flow_smoke.gd 2>&1 | tee /tmp/my-game-player-timer-flow-smoke.log
  if ! grep -q "PLAYER_TIMER_FLOW_SMOKE_OK" /tmp/my-game-player-timer-flow-smoke.log; then
    echo "PLAYER_TIMER_FLOW_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player effect bridge smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_effect_bridge_smoke.gd 2>&1 | tee /tmp/my-game-player-effect-bridge-smoke.log
  if ! grep -q "PLAYER_EFFECT_BRIDGE_SMOKE_OK" /tmp/my-game-player-effect-bridge-smoke.log; then
    echo "PLAYER_EFFECT_BRIDGE_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player save roundtrip smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_save_roundtrip_smoke.gd 2>&1 | tee /tmp/my-game-player-save-roundtrip-smoke.log
  if ! grep -q "PLAYER_SAVE_ROUNDTRIP_SMOKE_OK" /tmp/my-game-player-save-roundtrip-smoke.log; then
    echo "PLAYER_SAVE_ROUNDTRIP_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot runtime registry smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/runtime_registry_smoke.gd 2>&1 | tee /tmp/my-game-runtime-registry-smoke.log
  if ! grep -q "RUNTIME_REGISTRY_SMOKE_OK" /tmp/my-game-runtime-registry-smoke.log; then
    echo "RUNTIME_REGISTRY_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player projectile pool smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_projectile_pool_smoke.gd 2>&1 | tee /tmp/my-game-player-projectile-pool-smoke.log
  if ! grep -q "PLAYER_PROJECTILE_POOL_SMOKE_OK" /tmp/my-game-player-projectile-pool-smoke.log; then
    echo "PLAYER_PROJECTILE_POOL_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player level curve smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_level_curve_smoke.gd 2>&1 | tee /tmp/my-game-player-level-curve-smoke.log
  if ! grep -q "PLAYER_LEVEL_CURVE_SMOKE_OK" /tmp/my-game-player-level-curve-smoke.log; then
    echo "PLAYER_LEVEL_CURVE_SMOKE_FAILED"
    exit 1
  fi

else
  echo "== Godot checks skipped: set GODOT_BIN or install godot =="
fi

if command -v graphify >/dev/null 2>&1; then
  echo "== graphify update =="
  graphify update .
else
  echo "== graphify skipped: command not found =="
fi

echo "PROJECT_CHECK_OK"
