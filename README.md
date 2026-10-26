# survivor-like

Godot 4 2D survivor-like prototype focused on three-character switching combat.

## Current Status

A desktop prototype with a playable three-stage story, endless combat, camp preparation, save/continue, a character sheet, settings, achievements, and developer tools. Combat uses three selected characters from the swordsman, gunner, mage, and mechanic roster. The home screen features the four-hero illustration and a music room with all 14 original tracks. Challenge mode remains disabled.

The maintained implementation status and priorities live in [docs/08_当前实现状态与后续重点.md](docs/08_当前实现状态与后续重点.md). Read that entry before treating older design reviews as current requirements.

## Controls

- `WASD`: move
- `Mouse`: attack direction when mouse-follow mode is active
- `TAB`: switch attack mode between auto target and mouse-follow
- `Q` / `E`: switch role
- `R`: ultimate
- `1`–`6`: cast the matching active skill when it is in manual mode
- `Ctrl` + skill hotkey, or right-click a skill slot: switch auto/manual casting
- Drag between two skill slots of the same role: swap their order
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

- Each level-up offers three role cards from the current team plus one general-blessing card; choose two, with one refresh per card.
- Role cards unlock an active skill or raise an eligible skill line from level 1 to 10. At skill level 5, choose one of two talent slots; level 10 grants the other. Mechanic's 16 slot effects are implemented; other roles still use explicit placeholders.
- Swordsman, gunner, mage, and mechanic skill-level effects are read by the combat modules and shown in upgrade previews. Mechanic entry and active turrets keep independent skill levels across saves.
- The every-three-player-level talent acquisition flow is disabled. Saved `level_talents` remain readable and appear in the character sheet. The older 108-node `skill_talents` route is also disabled.
- Direct acquisition cards are the formal active-skill unlock route; legacy recipe materials are not offered in normal rewards.

Camp now includes all four resident roles, team replacement/reordering and a departure loadout check. Its 17-item shop has separate per-copy buy/refund actions and cumulative previews. Permanent purchases survive return to camp; failed saves preserve the previous inventory.

See [current build rules](docs/04_构筑系统与文案交互规范.md) for the complete contract.

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

Runtime music uses the 14 original cues under `assets/music/`, covering preparation, stages, elites, Boss phases and results. Editable REAPER projects, MIDI, lossless masters and production notes are in [the soundtrack package](design/music-20261025/README.md). The four old `game_bgm`/`menu_bgm` MP3/Ogg placeholders are retained locally but excluded from the export preset. Other prototype artwork still requires the review described in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Documentation

- [docs/README_文档索引.md](docs/README_文档索引.md)
- [CHANGELOG.md](CHANGELOG.md)
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)
- [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)

## Historical code archive

Superseded implementations are cataloged under [`archive/legacy/`](archive/legacy/). The directory is ignored by Godot and contains references to Git history rather than runtime scripts. It is kept for explicit historical comparison or migration work; current gameplay analysis uses the active working tree only.
