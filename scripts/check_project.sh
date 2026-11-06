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

# Recovery is explicit and fails closed if any shared source/resource or the
# original evidence changed. The default full check path remains unchanged.
if [[ -n "${PROJECT_CHECK_REUSE_MANIFEST:-}" ]]; then
  python3 scripts/tests/check_project_reuse.py check --manifest "$PROJECT_CHECK_REUSE_MANIFEST" --godot "$GODOT_BIN"
  python3 scripts/tests/check_project_reuse.py self-test
fi

echo "== Python project checks =="
python3 scripts/tests/check_docs_links.py
python3 scripts/tests/check_project_config.py
python3 scripts/tests/check_graph_update_self_test.py
python3 scripts/tests/check_smoke_log_self_test.py
python3 scripts/tests/check_architecture_contract.py
python3 scripts/tests/check_story_content.py
python3 scripts/tests/check_chronicle_cast_art.py
python3 scripts/tests/check_jia_campaign_art.py
python3 scripts/tests/check_zhang_liao_summon_art.py
python3 scripts/tools/build_battle_sprite_bounds.py --check

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

  echo "== Godot Chronicle entry scene smoke =="
  "$GODOT_BIN" --headless --path . res://scenes/chronicle/chronicle_shell.tscn --quit --verbose 2>&1 | tee "$CHECK_LOG_DIR/chronicle-entry-scene-smoke.log" >/dev/null
  if grep -E "$GODOT_ERROR_PATTERN" "$CHECK_LOG_DIR/chronicle-entry-scene-smoke.log"; then
    echo "CHRONICLE_ENTRY_SCENE_SMOKE_FAILED"
    exit 1
  fi
  echo "CHRONICLE_ENTRY_SCENE_SMOKE_OK"

  run_smoke() {
    local script="$1"
    local name
    local log
    local display_args=(--headless)
    local runner=()
    local limit=90
    # Dense encounters and two continuous, resource-carrying routes exercise many
    # more production ticks than short UI fixtures. Keep their wall budget bounded.
    if [[ "$script" == *chronicle_enemy_campaign_smoke.gd ]]; then limit=480; fi
    if [[ "$script" == *chronicle_enemy_sessions_smoke.gd ]]; then limit=300; fi
    name="$(basename "${script%.gd}")"
    # This finite 17-case/3230-frame GL check exceeds 90s on two-CPU llvmpipe.
    if [[ "$name" == "zhang_liao_summon_render_smoke" && "${LIBGL_ALWAYS_SOFTWARE:-}" == "1" ]]; then limit=300; fi
    log="$CHECK_LOG_DIR/${name}.log"
    if [[ -n "${PROJECT_CHECK_REUSE_MANIFEST:-}" ]]; then
      local reuse_status=0
      python3 scripts/tests/check_project_reuse.py reuse --manifest "$PROJECT_CHECK_REUSE_MANIFEST" \
        --godot "$GODOT_BIN" --script "$script" --output-log "$log" || reuse_status=$?
      if [[ "$reuse_status" == 0 ]]; then return; fi
      if [[ "$reuse_status" != 3 ]]; then exit "$reuse_status"; fi
    fi
    # Pixel assertions and actual music playback need a real display; CI
    # supplies Xvfb. Dummy still decodes/mixes audio without a hardware device.
    if [[ "$name" == *_render_smoke || "$name" == "chronicle_music_smoke" || "$name" == "chronicle_music_playback_smoke" || "$name" == "chronicle_skill_audio_smoke" || "$name" == "chronicle_combat_feedback_smoke" || "$name" == "chronicle_party_drag_smoke" ]]; then
      display_args=(--rendering-method gl_compatibility --audio-driver Dummy)
      if command -v xvfb-run >/dev/null 2>&1; then
        runner=(xvfb-run --auto-servernum)
      elif [[ -z "${DISPLAY:-}" ]]; then
        echo "${name^^}_NEEDS_XVFB_OR_DISPLAY"
        exit 1
      fi
    fi
    echo "== Godot ${name//_/ } =="
    if ! XDG_DATA_HOME="$CHECK_DATA_DIR/$name/data" XDG_CONFIG_HOME="$CHECK_DATA_DIR/$name/config" \
        timeout "${limit}s" "${runner[@]}" "$GODOT_BIN" "${display_args[@]}" --path . --script "$script" 2>&1 | tee "$log"; then
      echo "${name^^}_FAILED"
      exit 1
    fi
    if ! python3 scripts/tests/check_smoke_log.py "$script" "$log"; then
      exit 1
    fi
  }

  run_pack_smokes() {
    local pack_dir="$CHECK_DATA_DIR/pack-smokes"
    local empty_dir="$pack_dir/empty-cwd"
    local pack="$pack_dir/game.pck"
    local export_log="$CHECK_LOG_DIR/chronicle-pack-export.log"
    local name external_script log
    mkdir -p "$empty_dir"

    echo "== Godot Linux development pack export for isolated pack smokes =="
    if ! XDG_DATA_HOME="$pack_dir/export-data" XDG_CONFIG_HOME="$pack_dir/export-config" \
        timeout 300s "$GODOT_BIN" --headless --path "$ROOT" --export-pack "Linux development" "$pack" \
        >"$export_log" 2>&1; then
      tail -n 80 "$export_log"
      echo "CHRONICLE_PACK_EXPORT_FAILED"
      exit 1
    fi
    if grep -E "$GODOT_ERROR_PATTERN" "$export_log"; then
      echo "CHRONICLE_PACK_EXPORT_DIAGNOSTIC_FAILED"
      exit 1
    fi
    if [[ ! -s "$pack" ]]; then
      echo "CHRONICLE_PACK_MISSING"
      exit 1
    fi
    local pack_bytes
    pack_bytes="$(stat -c '%s' "$pack")"
    echo "CHRONICLE_PACK path=$pack bytes=$pack_bytes"
    if [[ -e "$empty_dir/project.godot" || -d "$empty_dir/scripts" || -d "$empty_dir/assets" ]]; then
      echo "CHRONICLE_PACK_EMPTY_CWD_CONTAMINATED"
      exit 1
    fi

    for name in chronicle_enemy_pack_smoke chronicle_music_pack_smoke chronicle_story_pack_smoke chronicle_combat_feedback_pack_smoke; do
      external_script="$pack_dir/$name.gd"
      log="$CHECK_LOG_DIR/$name.log"
      cp "scripts/tests/$name.gd" "$external_script"
      echo "== Godot $name against isolated main pack from empty cwd =="
      if ! (
        cd "$empty_dir"
        XDG_DATA_HOME="$pack_dir/$name/data" XDG_CONFIG_HOME="$pack_dir/$name/config" \
          timeout 120s "$GODOT_BIN" --headless --path "$empty_dir" --main-pack "$pack" --script "$external_script"
      ) 2>&1 | tee "$log"; then
        echo "${name^^}_FAILED"
        exit 1
      fi
      if ! python3 scripts/tests/check_smoke_log.py "$external_script" "$log"; then
        exit 1
      fi
    done
  }

  # These tests are excluded from the PCK and must run externally against one
  # shared export, with no source project available to satisfy res:// loads.
  run_pack_smokes

  for smoke in scripts/tests/*_smoke.gd; do
    [[ "$(basename "$smoke")" == "chronicle_enemy_pack_smoke.gd" ]] && continue
    [[ "$(basename "$smoke")" == "chronicle_music_pack_smoke.gd" ]] && continue
    [[ "$(basename "$smoke")" == "chronicle_story_pack_smoke.gd" ]] && continue
    [[ "$(basename "$smoke")" == "chronicle_combat_feedback_pack_smoke.gd" ]] && continue
    run_smoke "$smoke"
  done

fi

if [[ -n "${PROJECT_CHECK_REUSE_MANIFEST:-}" ]]; then
  python3 scripts/tests/check_project_reuse.py check --manifest "$PROJECT_CHECK_REUSE_MANIFEST" --godot "$GODOT_BIN"
fi

if [[ -f graphify-out/graph.json ]] && command -v graphify >/dev/null 2>&1; then
  echo "== graphify update =="
  python3 scripts/tools/update_existing_graph.py
else
  echo "== graphify skipped: no existing index or command not found =="
fi

echo "PROJECT_CHECK_OK"
