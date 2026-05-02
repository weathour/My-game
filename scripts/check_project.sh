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

  echo "== Godot map UI smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/map_ui_smoke.gd 2>&1 | tee /tmp/my-game-map-ui-smoke.log
  if ! grep -q "MAP_UI_SMOKE_OK" /tmp/my-game-map-ui-smoke.log; then
    echo "MAP_UI_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot UI/build handoff smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/ui_build_handoff_smoke.gd 2>&1 | tee /tmp/my-game-ui-build-handoff-smoke.log
  if ! grep -q "UI_BUILD_HANDOFF_SMOKE_OK" /tmp/my-game-ui-build-handoff-smoke.log; then
    echo "UI_BUILD_HANDOFF_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot player level curve smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/player_level_curve_smoke.gd 2>&1 | tee /tmp/my-game-player-level-curve-smoke.log
  if ! grep -q "PLAYER_LEVEL_CURVE_SMOKE_OK" /tmp/my-game-player-level-curve-smoke.log; then
    echo "PLAYER_LEVEL_CURVE_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot first-batch build model smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/build_first_batch_model_smoke.gd 2>&1 | tee /tmp/my-game-build-first-batch-model-smoke.log
  if ! grep -q "BUILD_FIRST_BATCH_MODEL_SMOKE_OK" /tmp/my-game-build-first-batch-model-smoke.log; then
    echo "BUILD_FIRST_BATCH_MODEL_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot first-batch balance smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/build_first_batch_balance_smoke.gd 2>&1 | tee /tmp/my-game-build-first-batch-balance-smoke.log
  if ! grep -q "BUILD_FIRST_BATCH_BALANCE_SMOKE_OK" /tmp/my-game-build-first-batch-balance-smoke.log; then
    echo "BUILD_FIRST_BATCH_BALANCE_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot first-batch runtime smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/build_first_batch_runtime_smoke.gd 2>&1 | tee /tmp/my-game-build-first-batch-runtime-smoke.log
  if ! grep -q "BUILD_FIRST_BATCH_RUNTIME_SMOKE_OK" /tmp/my-game-build-first-batch-runtime-smoke.log; then
    echo "BUILD_FIRST_BATCH_RUNTIME_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot enemy pressure model smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/build_enemy_pressure_model_smoke.gd 2>&1 | tee /tmp/my-game-build-enemy-pressure-model-smoke.log
  if ! grep -q "BUILD_ENEMY_PRESSURE_MODEL_SMOKE_OK" /tmp/my-game-build-enemy-pressure-model-smoke.log; then
    echo "BUILD_ENEMY_PRESSURE_MODEL_SMOKE_FAILED"
    exit 1
  fi

  echo "== Godot difficulty profile smoke =="
  "$GODOT_BIN" --headless --path . --script scripts/tests/difficulty_profile_smoke.gd 2>&1 | tee /tmp/my-game-difficulty-profile-smoke.log
  if ! grep -q "DIFFICULTY_PROFILE_SMOKE_OK" /tmp/my-game-difficulty-profile-smoke.log; then
    echo "DIFFICULTY_PROFILE_SMOKE_FAILED"
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
