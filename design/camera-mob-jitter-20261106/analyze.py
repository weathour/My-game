"""Analyze diagnostic transforms; origin delta alone is not screen displacement."""
import hashlib
import json
import math
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
HERE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else BASE
ROOT = BASE.parents[1]


def distance(a, b):
    return math.dist(a, b)


def project(row, point):
    return [row["origin"][i] + point[i] * row["scale"] for i in (0, 1)]


def percentile(values, q):
    values = sorted(values)
    return values[round((len(values) - 1) * q)] if values else 0


summaries = []
for path in sorted(HERE.glob("E*.jsonl")):
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    if len(rows) != 1200:
        raise ValueError(f"Incomplete case {path}")
    steps, landmark_steps, flips, largest = [], [], [], []
    fixed = [320, 300] if "edge" in path.stem else [1600, 900]
    fixed_projection = [project(row, fixed) for row in rows]
    for before, row in zip(rows, rows[1:]):
        # Hold the world point fixed at the previous player's foot position:
        # neither the input's own displacement nor zoom-origin coupling is mislabeled.
        step = distance(project(before, before["player"]), project(row, before["player"]))
        landmark = [before["player"][0] + 300, before["player"][1]]
        edge_step = distance(project(before, landmark), project(row, landmark))
        steps.append(step)
        landmark_steps.append(edge_step)
        if row["route_flipped"]:
            flips.append({"frame": row["frame"], "danger_set_changed": row["danger_set_changed"],
                          "focus_changed": distance(row["focus"], before["focus"]) > .01,
                          "screen_step_at_previous_player_px": step})
        if step > 3 or edge_step > 10:
            largest.append({"frame": row["frame"], "time": row["time"],
                            "screen_step_at_previous_player_px": step,
                            "screen_step_300_world_right_px": edge_step,
                            "scale_before": before["scale"], "scale_after": row["scale"],
                            "danger_set_changed": row["danger_set_changed"],
                            "route_flipped": row["route_flipped"],
                            "post_smoothing_correction_world": row["post_smoothing_correction_world"],
                            "trauma": row["trauma"]})
    largest.sort(key=lambda value: value["screen_step_at_previous_player_px"], reverse=True)
    summaries.append({"case": path.stem, "frames": len(rows),
                      "trauma_max": max(row["trauma"] for row in rows),
                      "scale_min": min(row["scale"] for row in rows),
                      "scale_max": max(row["scale"] for row in rows),
                      "screen_step_at_previous_player_max_px": max(steps),
                      "screen_step_at_previous_player_p95_px": percentile(steps, .95),
                      "screen_step_300_world_right_max_px": max(landmark_steps),
                      "fixed_world_marker_screen_span_px": [max(v[i] for v in fixed_projection)-min(v[i] for v in fixed_projection) for i in (0, 1)],
                      "route_flips": len(flips), "route_flips_without_focus_change": sum(not item["focus_changed"] for item in flips),
                      "route_flip_samples": flips[:8], "largest": largest[:8]})

sources = ["scripts/ui/chronicle/boss_camera.gd", "scripts/ui/chronicle/battle_canvas.gd",
           "scripts/battle/enemy_system.gd", "scripts/battle/enemy_geometry.gd",
           "scripts/content/enemy_catalog.gd", "scripts/content/stage_catalog.gd"]
payload = {"method": "headless transforms from real EnemySystem rules, not a full fight or native image measurement",
           "scope_limits": ["No user recording/stage is available; these cases establish possible mechanisms, not unique attribution.",
                            "No-Boss camera with unmodified stage config stated in sibling results JSON; player offense/health and reinforcement director omitted.",
                            "No production actions, geometry, timings, numerical stats or camera code are modified.",
                            "No real HUD silhouette obstacles in diagnostic; safe top72/bottom188 reflects simpleHUD168+20 at1280x720.",
                            "Route angular flips do not necessarily change focus; origin delta alone overstates visible camera motion.",
                            "Large post-smoothing correction near map edge can keep origin fixed, so is not itself a screen-jump measurement."],
           "source_sha256": {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sources},
           "cases": summaries}
(HERE/"screen-analysis.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2)+"\n")
for item in summaries:
    print(item["case"], "screen_max/p95", *(round(item[key], 3) for key in ["screen_step_at_previous_player_max_px", "screen_step_at_previous_player_p95_px"]),
          "landmark_max", round(item["screen_step_300_world_right_max_px"], 3), "scale", round(item["scale_min"], 3),
          "flips/focus_unchanged", item["route_flips"], item["route_flips_without_focus_change"])
