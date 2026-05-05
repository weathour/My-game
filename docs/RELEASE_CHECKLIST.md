# Release Checklist

Use this before any public build, demo handoff, or store upload.

## Automated checks

- [ ] Run local project checks:

```bash
./scripts/check_project.sh
```

## Package sanity

- [ ] Open the project in Godot `4.6.2`.
- [ ] Main scene is `res://scenes/main_menu.tscn`.
- [ ] Run headless parse:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

- [ ] Manually launch main menu.
- [ ] Start story mode if enabled.
- [ ] Start endless mode.
- [ ] Test pause/resume/main-menu return.
- [ ] Test window/fullscreen switching and 16:9 window resize behavior.
- [ ] Test main-menu Settings opens centered after changing window size.
- [ ] Test level-up blessing list scroll bar is visible and draggable.
- [ ] Test hover details for blessings, rewards, bottom skill slots, normal attack, and ultimate energy.

## Save/settings sanity

- [ ] New story profile can be created.
- [ ] Endless profile can be created.
- [ ] Continue game works after leaving a run.
- [ ] Keybind changes persist.
- [ ] Music settings persist.
- [ ] Display settings persist.
- [ ] Keybind editing in main-menu Settings still works after closing/reopening the panel.
- [ ] Hero-trait training and common-prosperity count persist across continue-game save/load.
- [ ] Blessing levels, skill blessing levels, and equipment persist across continue-game save/load.
- [ ] Achievement unlock state persists.

## Content/legal

- [ ] Placeholder BGM replaced or license cleared.
- [ ] Placeholder images/sketches replaced or license cleared.
- [ ] `THIRD_PARTY_NOTICES.md` reviewed.
- [ ] `LICENSE.md` reviewed for intended distribution model.

## Steam-specific future checks

- [ ] GodotSteam installed only for Steam package lane.
- [ ] Steamworks Achievement API Names match local `data/achievements.json` IDs.
- [ ] Steamworks changes are published.
- [ ] `Steam.setAchievement()` and `Steam.storeStats()` verified in a Steam test app.
