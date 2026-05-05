# survivor-like

Godot 4 2D survivor-like prototype focused on three-character switching combat.

## Current Status

The project currently includes:

- Main menu, save selection, endless mode, pause menu, HUD, BGM, and developer mode.
- Three playable roles: swordsman, gunner, and mage.
- Role switching, normal attacks, ultimate skills, skill cooldown HUD, and character panel.
- Level-up rewards based on the current blessing system.
- Small boss equipment rewards and final boss core rewards.
- Map-bounded wave spawning, spawn warnings, elite/small boss/boss flow, and difficulty profiles.
- Local achievements and project health checks.

## Controls

- `WASD`: move
- `Mouse`: attack direction when mouse-follow mode is active
- `TAB`: switch attack mode between auto target and mouse-follow
- `Q` / `E`: switch role
- `R`: ultimate
- `C`: character panel
- `ESC`: pause

## Project Structure

- `assets/`: placeholder art/audio assets.
- `effects/`: combat effect scenes.
- `scenes/`: Godot scenes for menus, player, enemy, HUD, pickups, and combat.
- `scripts/`: gameplay, UI, save, enemy, player, and system logic.
- `scripts/player/`: player-side modules for blessings, roles, attacks, cooldowns, stats, save data, and rewards.
- `scripts/game/`: combat scene flows such as HUD wiring, rewards, spawning, map bounds, and session state.
- `scripts/ui/`: shared UI components and HUD panels.
- `docs/`: current design and architecture notes.

## Current Progression Model

Level-up progression centers on blessings:

- Each level-up offers three blessing options.
- Role-bound blessings are shared by all three roles.
- Skill-bound blessings are stored separately for skill unlocks and future skill scaling.
- Character panel displays owned blessings and supports blessing composition.
- Skill unlocks are handled by blessing requirements.

## Run

Open the project with Godot 4.6 and run:

```text
res://scenes/main_menu.tscn
```

## Checks

Run the local project health check with:

```bash
./scripts/check_project.sh
```

## Asset Notice

The current BGM files under `assets/` are non-commercial placeholder materials for development testing only. They are included so the project can run with the current audio setup, and will be replaced before any commercial release or public distribution build.

## Documentation

- [docs/README_文档索引.md](docs/README_文档索引.md)
- [CHANGELOG.md](CHANGELOG.md)
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)
- [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)
