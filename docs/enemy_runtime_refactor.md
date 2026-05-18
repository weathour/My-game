# Enemy Runtime Refactor

Goal: keep `scripts/enemy.gd` as the runtime dispatcher and move feature logic into focused helper modules. This stage must not change gameplay values or behavior.

## Current Dispatcher Boundary

`scripts/enemy.gd` keeps:

- exported/runtime state fields that other modules already read and write;
- Godot lifecycle entry points: `_ready`, `_exit_tree`, `_physics_process`;
- compatibility wrappers used by existing modules;
- registration and pooling entry points.

Feature logic should live outside `enemy.gd`.

## Runtime Modules

- `scripts/enemies/enemy_body_separation.gd`
  - Owns body spacing / soft collision push logic.
  - Reads the current enemy profile collision radius and current scale.
- `scripts/enemies/enemy_motion_throttle.gd`
  - Owns movement refresh throttling under enemy pressure.
  - Keeps existing distance thresholds and pressure threshold unchanged.
- `scripts/enemies/enemy_status_visual_throttle.gd`
  - Owns status visual refresh cadence and pressure checks.
  - Keeps existing refresh intervals unchanged.
- `scripts/enemies/enemy_trait_flags.gd`
  - Owns cached trait booleans and trait lookup.
  - Keeps the old `has_trait()` behavior through the wrapper in `enemy.gd`.
- Existing modules still own their areas:
  - `enemy_movement.gd`: velocity calculation.
  - `enemy_trait_behavior.gd`: shooter, dash, glutton, turret, rebirth ticking.
  - `enemy_damage.gd`: damage application.
  - `enemy_drops.gd`: drops.
  - `enemy_visuals.gd`: profile-driven visuals.
  - `enemy_status_visuals.gd`: status visual nodes/effects.

## Rule For New Enemy Work

Do not add large behavior blocks or hardcoded monster data back into `enemy.gd`.

If the work is a new enemy type, add or update:

1. `data/enemies/*.tres`
2. `scripts/enemy/enemy_archetype_database.gd`
3. the smallest responsible runtime module

If the work is runtime behavior, add it to the matching `scripts/enemies/enemy_*.gd` module or create a new focused module.

## Verification

Run these after enemy refactor changes:

```powershell
& 'C:\Users\Aron\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\Aron\Documents\survivor-like' --check-only --script res://scripts/enemy.gd
& 'C:\Users\Aron\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\Aron\Documents\survivor-like' --script res://scripts/tests/enemy_profile_resource_smoke.gd
& 'C:\Users\Aron\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'C:\Users\Aron\Documents\survivor-like' --script res://scripts/tests/enemy_profile_snapshot_smoke.gd
```
