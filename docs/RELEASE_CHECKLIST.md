# Release Checklist

Use this before any public build, demo handoff, or store upload.

## Automated checks

- [x] Run local project checks: 2026-10-25 final architecture gate passed 174/174 regular smokes with no script errors or exit-leak warnings. Rerun after later code changes; see [evidence](implementation/evidence/2026-10-25/architecture/project-check-final/results.json).

```bash
./scripts/check_project.sh
```

- [ ] GitHub `Project Checks` passes with its pinned Godot `4.6.2` binary.

## Package sanity

- [ ] Open the project in Godot `4.6.2`.
- [ ] Main scene is `res://scenes/main_menu.tscn`.
- [x] Run headless parse: passed in the 2026-10-25 final gate.

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

- [ ] Manually launch main menu.
- [ ] Start story mode if enabled.
- [ ] Start endless mode.
- [ ] Test pause/resume/main-menu return.
- [ ] Test window/fullscreen switching and 16:9 window resize behavior.
- [ ] Test main-menu Settings opens centered after changing window size.
- [ ] Verify each role receives its own skill point on level-up, existing-skill plus buttons spend that role’s point, empty slots offer three unowned skills, and wave blessing selection is free.
- [ ] Reach skill Lv.5: verify the two-slot choice, one selected talent, correct owned/pending state and resume after save/load; at Lv.10 verify the other slot is granted.
- [ ] For mechanic, verify both effects of each skill line change their documented combat behavior; other roles must label unimplemented slots explicitly.
- [ ] Verify the live talent flow never opens the historical Lv.3/Lv.6/Lv.9 skill-build tree, writes old `skill_talents`, or queues every-three-player-level talent picks.
- [ ] Test hover details for role builds, blessings, rewards, bottom skill slots, normal attack, and ultimate energy.
- [ ] Open the character panel: verify all 14 overview stats and sources, skill levels/talents, blessing counts, shared carried items, equipment transfers, and the read-only saved `level_talents` list.
- [ ] Verify Q/E switching without full energy changes role but does not fire an entry skill; full **departing-role** energy is consumed and fires only the incoming entry skill. Exit-skill copy/tutorial must not claim an effect while `EXIT_SKILLS_ENABLED=false`.
- [ ] Verify all 20 active skills honor their auto/manual setting and the matching slot key, including the mechanic's five deployments. Gunner Infinite Reload retains its toggle behavior, and directional skills retain their aiming rules.
- [ ] In camp, verify all four roles including mechanic, avatar/team synchronization, role introductions, team replacement/reordering, and next-run semantics when a run already exists.
- [ ] At the dog and blacksmith, verify separate buy/refund actions, duplicate purchases, all 17 effect previews, capacity/poor/empty-owned states, and no inventory/bone changes after a failed save.
- [ ] Verify camp overview and departure loadout, nearest interact highlight, all-modal movement lock, focus restoration, and F not resetting an open tier selector. Check 1280×720 and 960×540 modal action bounds.
- [ ] Return after a clear, a defeat and an active end-run: keep permanent items/bones, clear only the run save, and show the latest run summary without paying a duplicate reward.
- [ ] Defeat the endless final Boss in wave 20: verify fixed/first-clear bones, N+1 unlock, run-save removal, and return to camp with no same-run skill reward or “continue deeper” choice.


## Performance sanity

- [ ] Endless mode keeps intended enemy density; low FPS must not silently reduce normal enemy count.
- [ ] Under high density, effective player projectiles still check each physics-step path, spawn warnings retain the full reaction window, and reused enemy nodes do not receive damage queued for an earlier activation.
- [ ] Run the isolated battle lifecycle benchmark; review whole-frame time, physics-step workload, save peaks and ten enter/exit snapshots. A passing microbenchmark is not a 60 FPS guarantee.
- [ ] Developer normal-enemy batch spawner can reproduce dense-combat scenes.
- [ ] Level-up, blessing binding, and skill-reward confirmation do not create obvious click-frame stalls.
- [ ] If a stall is reported, enable performance trace briefly and inspect `user://performance_trace_latest.jsonl` for slow-frame, SavePeak, pending spawn, and batch counters.
- [ ] Combat save still overwrites `run_save.json` and `run_save_backup.json` only; save file count must not grow with play time.

## Save/settings sanity

- [ ] New story profile can be created.
- [ ] Endless profile can be created.
- [ ] Continue game works after leaving a run.
- [ ] Keybind changes persist.
- [ ] Music settings persist.
- [ ] Display settings persist.
- [ ] Keybind editing in main-menu Settings still works after closing/reopening the panel.
- [ ] Role-build levels and role special state persist across continue-game save/load.
- [ ] `role_special_states[role_id].skill_levels` and `.skill_talent_slots` persist across continue-game save/load, and a skill reaching level 5 still shows its pending two-slot talent pick after reloading.
- [ ] `pending_level_talent_choices`, active talent context, `level_talents`, and `level_talent_group_locks` still round-trip for legacy saves; the player-level talent entry no longer queues new picks, and legacy `skill_talents` remains empty after normalization.
- [ ] Blessing levels, retained attribute-training state, skill blessing levels, and equipment persist across continue-game save/load.
- [ ] Achievement unlock state persists.

## Content/legal

- [x] Runtime placeholder BGM replaced with 14 original cues; four retained old music files excluded from the export preset. Source archive redistribution still requires excluding or clearing those retained files.
- [ ] Human listening, normal-speed gameplay mix and target-device speaker checks for the new score; technical audio QA does not close these gates.
- [ ] Review the implemented common UI/result tones and independent SFX volume; author and verify remaining combat/environment SFX if required for the release.
- [ ] Placeholder images/sketches replaced or license cleared.
- [ ] README, `docs/README_文档索引.md`, `docs/04`, `docs/06`, `docs/08`, `ROADMAP.md`, `KNOWN_ISSUES.md`, and this checklist describe the same shipped progression and settlement rules.
- [ ] `THIRD_PARTY_NOTICES.md` reviewed.
- [ ] `LICENSE.md` reviewed for intended distribution model.

## Steam-specific future checks

- [ ] GodotSteam installed only for Steam package lane.
- [ ] Steamworks Achievement API Names match local `data/achievements.json` IDs.
- [ ] Steamworks changes are published.
- [ ] `Steam.setAchievement()` and `Steam.storeStats()` verified in a Steam test app.

## Story and recovery acceptance added 2026-10-23

- [ ] Read the current [architecture implementation evidence](implementation/2026-10-25_架构健全性整改.md) and its final verification limits; the earlier [framework record](implementation/2026-10-23_系统框架实施.md) is provenance.
- [ ] Accept, clear and deliver all three quests through real controls; verify current objective, next NPC and chapter completion.
- [ ] Reopen a postponed dialogue, reveal text, skip to a choice, confirm delivery and inspect read-only history using keyboard and mouse.
- [ ] Verify 1280×720 / 960×540, large story text, reduced motion and steady spawn warnings; boss/skill effects retain their current separate visual behavior.
- [ ] Verify corrupted primary + valid backup, two damaged files, unsupported version, interrupted departure, failed settlement write and repeated submission without losing the raw files or paying twice.
- [ ] Verify nested damaged entity/ability state falls back safely; a failed runtime restore must not start a fresh battle or overwrite either file. A failed endless cleanup must remain retryable without paying a reward twice.
- [ ] Verify overlapping reward, pause and character-panel reasons cannot resume one another; third-stage story HUD shows elapsed Boss-hunt time past 300 seconds.
- [ ] Verify small-Boss reward before wave blessing on resume, and restored final settlement retry.
- [ ] Verify failure/abandon review, same-stage retry and a practice replay with no permanent story reward.

## Development package

The checked-in `Linux development` preset exports runtime story/achievement JSON and excludes editor tools, tests, docs and design artifacts. Generate a content pack with:

```bash
mkdir -p builds/linux
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --export-pack 'Linux development' builds/linux/survivor_like.pck
```

Run `scripts/tests/package_content_check.gd` from an empty temporary project directory with an isolated `XDG_DATA_HOME` and the absolute PCK path after `--`. This checks packaged resources and three-stage story transactions without falling back to source files. Also boot the pack with `--main-pack builds/linux/survivor_like.pck --quit`.

The 2026-10-25 architecture PCK passed both checks, including all 14 original music cues; [package evidence](implementation/evidence/2026-10-25/architecture/project-check-final/package-results.json) records its hash and isolation directory. This does not close the standalone executable, full-run performance or human acceptance items below.

- [ ] Install the matching Godot export templates and produce/run the independent Linux executable. A locally booted PCK alone is not this check.
- [ ] Test each intended target OS, font fallback, audio output and save-directory permissions.
- [ ] Clear asset rights in `THIRD_PARTY_NOTICES.md` before sharing any build outside authorized development.
