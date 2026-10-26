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

if [[ -z "$GODOT_BIN" || ! -x "$GODOT_BIN" ]]; then
  echo "PROJECT_CHECK_FAILED: set GODOT_BIN to an executable Godot 4.6.2 binary"
  exit 1
fi

CHECK_DATA_DIR="$(mktemp -d /tmp/my-game-check.XXXXXX)"
export XDG_DATA_HOME="$CHECK_DATA_DIR/data"
export XDG_CONFIG_HOME="$CHECK_DATA_DIR/config"
export PYTHONDONTWRITEBYTECODE=1
CHECK_LOG_DIR="${PROJECT_CHECK_LOG_DIR:-$CHECK_DATA_DIR/logs}"
mkdir -p "$CHECK_LOG_DIR"
echo "Check logs: $CHECK_LOG_DIR"

GODOT_ERROR_PATTERN="SCRIPT ERROR|Parser Error|Parse Error|Invalid call|Failed to load script|Failed to instantiate|Compilation failed|^ERROR:"

echo "== Python project checks =="
python3 scripts/tests/check_docs_links.py
python3 scripts/tests/check_achievements.py
python3 scripts/tests/check_project_config.py
python3 scripts/tests/check_architecture_contract_self_test.py
python3 scripts/tests/check_graph_update_self_test.py
python3 scripts/tests/check_architecture_contract.py
python3 scripts/tests/check_story_content.py

if [[ -n "$GODOT_BIN" ]]; then
  echo "== Godot asset import =="
  "$GODOT_BIN" --headless --path . --import 2>&1 | tee "$CHECK_LOG_DIR/godot-import.log" >/dev/null
  if grep -E "$GODOT_ERROR_PATTERN" "$CHECK_LOG_DIR/godot-import.log"; then
    echo "GODOT_ASSET_IMPORT_FAILED"
    exit 1
  fi
  echo "GODOT_ASSET_IMPORT_OK"

  echo "== Godot headless parse =="
  "$GODOT_BIN" --headless --path . --quit --verbose 2>&1 | tee "$CHECK_LOG_DIR/godot-check.log" >/dev/null
  if grep -E "$GODOT_ERROR_PATTERN" "$CHECK_LOG_DIR/godot-check.log"; then
    echo "GODOT_PARSE_CHECK_FAILED"
    exit 1
  fi
  echo "GODOT_PARSE_CHECK_OK"

  echo "== Godot main menu scene smoke =="
  "$GODOT_BIN" --headless --path . res://scenes/main_menu.tscn --quit --verbose 2>&1 | tee "$CHECK_LOG_DIR/main-menu-scene-smoke.log" >/dev/null
  if grep -E "$GODOT_ERROR_PATTERN" "$CHECK_LOG_DIR/main-menu-scene-smoke.log"; then
    echo "MAIN_MENU_SCENE_SMOKE_FAILED"
    exit 1
  fi
  echo "MAIN_MENU_SCENE_SMOKE_OK"

  echo "== Godot endless save select scene smoke =="
  "$GODOT_BIN" --headless --path . res://scenes/endless_save_select.tscn --quit --verbose 2>&1 | tee "$CHECK_LOG_DIR/endless-save-select-scene-smoke.log" >/dev/null
  if grep -E "$GODOT_ERROR_PATTERN" "$CHECK_LOG_DIR/endless-save-select-scene-smoke.log"; then
    echo "ENDLESS_SAVE_SELECT_SCENE_SMOKE_FAILED"
    exit 1
  fi
  echo "ENDLESS_SAVE_SELECT_SCENE_SMOKE_OK"

  echo "== Godot battle scene smoke =="
  "$GODOT_BIN" --headless --path . res://scenes/main.tscn --quit --verbose 2>&1 | tee "$CHECK_LOG_DIR/main-scene-smoke.log" >/dev/null
  if grep -E "$GODOT_ERROR_PATTERN" "$CHECK_LOG_DIR/main-scene-smoke.log"; then
    echo "BATTLE_SCENE_SMOKE_FAILED"
    exit 1
  fi
  echo "BATTLE_SCENE_SMOKE_OK"

  run_smoke() {
    local script="$1"
    local name
    local log
    local display_args=(--headless)
    local limit=90
    name="$(basename "${script%.gd}")"
    [[ "$name" == "boss_danmaku_stress_smoke" ]] && limit=240
    log="$CHECK_LOG_DIR/${name}.log"
    # Pixel assertions need a real renderer; CI supplies a virtual X display.
    if [[ "$name" == *_render_smoke ]]; then
      display_args=(--rendering-method gl_compatibility --audio-driver Dummy)
    fi
    echo "== Godot ${name//_/ } =="
    if ! XDG_DATA_HOME="$CHECK_DATA_DIR/$name/data" XDG_CONFIG_HOME="$CHECK_DATA_DIR/$name/config" \
        timeout "${limit}s" "$GODOT_BIN" "${display_args[@]}" --path . --script "$script" 2>&1 | tee "$log"; then
      echo "${name^^}_FAILED"
      exit 1
    fi
    if grep -E "$GODOT_ERROR_PATTERN" "$log"; then
      echo "${name^^}_FAILED"
      exit 1
    fi
    if ! grep -Eq "(_OK|: (OK|PASS))$" "$log"; then
      echo "${name^^}_MISSING_SUCCESS_MARKER"
      exit 1
    fi
  }

  for smoke in scripts/tests/*_smoke.gd; do
    # The dense benchmark is deliberately separate because it compares two
    # timed cases and writes result artifacts.
    [[ "$(basename "$smoke")" == "dense_combat_benchmark_smoke.gd" ]] && continue
    run_smoke "$smoke"
  done

fi

if [[ -f graphify-out/graph.json ]] && command -v graphify >/dev/null 2>&1; then
  echo "== graphify update =="
  python3 scripts/tools/update_existing_graph.py
else
  echo "== graphify skipped: no existing index or command not found =="
fi

echo "PROJECT_CHECK_OK"
