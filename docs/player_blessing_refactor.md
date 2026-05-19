# Player Blessing Refactor

Goal: split blessing and blessing-skill state logic into focused modules without changing gameplay values, recipes, unlock rules, or UI-facing behavior.

## Current Boundary

`scripts/player/player_blessing_skill_state.gd` is still the compatibility facade for existing callers. Keep public static function names stable unless all callers are migrated in the same patch.

## Extracted Modules

- `scripts/player/player_blessing_skill_store.gd`
  - Owns `blessing_skill_state` structure creation and normalization.
  - Does not know recipes, roles, UI, or combat behavior.
  - Receives known skill ids from the facade so it can reject stale save data.

## Remaining Split Targets

- Skill catalog / recipes
  - Skill ids, titles, tags, role ids, unlock recipes, evolve recipes.
  - This should become a data-only module or Resource later.
- Recipe resolver
  - Unlock/evolve candidate finding, material locking, tier equivalent counting.
- Skill modifier reader
  - Duration, combo, quantity, basic attack range, projectile speed.
- Graph / tooltip presenter
  - Skill graph entries, requirement text, blessing usage text.

## Verification

Run these after blessing-state refactor changes:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --check-only --script scripts/player/player_blessing_skill_state.gd
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script scripts/tests/player_blessing_system_smoke.gd
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script scripts/tests/player_save_roundtrip_smoke.gd
```
