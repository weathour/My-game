# UI smoke test contracts

Godot 4.6.2 evidence for the three UI and catalogue smoke fixtures. Each recorded run reached its `_SMOKE_OK` marker; the current acceptance gate also rejects any `^ERROR` line. Logs were run with task-local XDG directories under `/tmp/my-game-test-contracts-xdg`.

| Test | Contract retained | Current evidence |
|---|---|---|
| `developer_catalog_smoke.gd` | The current developer catalogue exposes all 17 registered products, including poison. Poison can be granted and removed; unknown IDs are rejected. Heavy + brave use the current 0.2 attack interval, and light replacement is 1.0 while other selected build stages remain. | [log](developer_catalog_smoke.log); separate basic-build rule evidence is in the parent architecture evidence set. |
| `ruan_stone_ui_smoke.gd` | Ruan Stone data remains usable by the character panel; the test reads its details from the Equipment page. It does not require an always-visible combat HUD strip. | [log](ruan_stone_ui_smoke.log) |
| `skill_info_ui_smoke.gd` | Skill details stay hidden before the 1.5 s hover delay and appear afterward; combat cooldown text updates while detail data remains; team-band details show role and status; build-card detail, comparison rows, and talent content fit at 1280×720 and 960×540. | [headless verbose log](skill_info_ui_headless_verbose.log), [X11 log](skill_info_ui_x11.log), [screenshots](ui/) |

## Skill tooltip fixture cleanup

The fixture disables player attacks before adding the player, then stops the lifecycle-created fire timer immediately after entering the tree. On exit it frees the UI and world, then calls `PLAYER_AUTHORED_EFFECTS.clear_runtime_state()` to release detached pooled effects and cached static runtime state. This is fixture cleanup only; no shared runtime code was changed.

The verbose headless run ends with `SKILL_INFO_UI_SMOKE_OK` and has no `ERROR`, RID, leaked-instance, or “Resource still in use” lines. The X11 run uses `--audio-driver Dummy` to avoid an unavailable ALSA device while retaining the X11 display and renderer; it ends with `SKILL_INFO_UI_SMOKE_OK` and no `ERROR` lines. `combat-tooltip.png` was visually inspected after that X11 run.
