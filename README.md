# survivor-like

Godot 4 2D survivor-like prototype focused on three-character switching combat.

## Current Status

The project currently includes:

- Main menu, save selection, endless mode, pause menu, HUD, BGM, and developer mode.
- Three playable roles: swordsman, gunner, and mage.
- Role switching, normal attacks, ultimate skills, skill cooldown HUD, and character panel.
- Four-card/select-two level-up rewards, blessings, and player-level talent choices every three levels.
- Small-boss equipment rewards and mode-specific final-Boss settlement. Endless final-Boss victories settle the tier and return to camp; legacy final-core applicators remain in code but are not currently offered by the reward menu.
- Map-bounded wave spawning, spawn warnings, elite/small boss/boss flow, and difficulty profiles.
- Local achievements and project health checks.

## Controls

- `WASD`: move
- `Mouse`: attack direction when mouse-follow mode is active
- `TAB`: switch attack mode between auto target and mouse-follow
- `Q` / `E`: switch role
- `R`: ultimate
- `1`–`6`: route to the matching active-skill slot; the current player-facing manual action is Gunner's talent-enabled Infinite Reload toggle
- `C`: character panel
- `F`: interact in camp/tutorial scenes
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

Level-up progression currently uses a four-card build offer:

- Each level-up shows one role-build card for each of the three team slots plus one general-blessing card.
- The player selects two of the four cards, and each displayed card can be refreshed once for that offer.
- Role-build cards cover role traits, basic attacks, entry skills, ultimates, direct skill unlocks, and upgrades for unlocked skills.
- At player levels 3, 6, 9, and every later multiple of three, one additional talent choice is queued after the ordinary reward flow. The player first chooses a role, then one of up to three eligible talents for that role; each displayed talent card can be refreshed once.
- Current player-facing talents come from 42 active definitions arranged as 21 mutually exclusive pairs. A picked `_1`/`_2` talent locks its sibling for the current scope; these suffixes are alternatives, not sequential tiers.
- The formal general-blessing pool currently contains seven entries: Divine Grace, Support, Greed, Tailwind, Blazing Sun, Burst, and Unyielding. They remain shared progression with independent tiers; blessing composition has been removed.
- Character panel displays ordinary skill-build stacks, owned blessings, stats, and equipment. It does not currently display the active player-level talent ledger.
- Direct role-build cards are the formal player route for unlocking active skills. Blessing-recipe unlock/evolution code and legacy material definitions remain in source, but those materials are excluded from the formal reward generators, so a clean formal run cannot currently use that path.
- The older 18-tree/108-node Lv.3/Lv.6/Lv.9 skill-build design remains in source and historical specifications, but its player reward/apply/save path is disabled and legacy `skill_talents` are cleared during normalization.

## Run

Open the project with Godot 4.6.2 and run:

```text
res://scenes/main_menu.tscn
```

## Checks

Run the local project health check with:

```bash
./scripts/check_project.sh
```

This runs the Python contracts, Godot asset import and parse checks, real main-menu and battle-scene launch checks, and every ordinary `scripts/tests/*_smoke.gd` test. The timed dense-combat benchmark remains a separate performance evidence command.

## Asset Notice

The current BGM files under `assets/` are non-commercial placeholder materials for development testing only. They are included so the project can run with the current audio setup, and will be replaced before any commercial release or public distribution build.

## Documentation

- [docs/README_文档索引.md](docs/README_文档索引.md)
- [CHANGELOG.md](CHANGELOG.md)
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)
- [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)

## Historical code archive

Superseded implementations are cataloged under [`archive/legacy/`](archive/legacy/). The directory is ignored by Godot and contains references to Git history rather than runtime scripts. It is kept for explicit historical comparison or migration work; current gameplay analysis uses the active working tree only.
