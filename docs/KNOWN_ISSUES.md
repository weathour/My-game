# Known Issues

## Documentation

- `docs/13` and `docs/14` are historical three-stage/108-node specifications. Current player progression uses `LEVEL_TALENT_DEFINITIONS`; data or tests for old `TALENT_DEFINITIONS` do not prove player reachability.
- `graphify-out/` is the active generated code graph output when available.
- The checked-in graph report was built from an older commit; use current source for changed progression behavior until `graphify update .` is run after a code change.

## Assets

- Current BGM and some visual assets are development placeholders.
- Commercial/public release requires asset replacement or explicit license clearance.

## Gameplay/System Risks

- `scripts/player.gd` and `scripts/enemy.gd` remain large hub scripts; future work should avoid adding unrelated responsibilities there.
- Save/load and continue-game behavior should be treated as high-risk when changing player, enemy, blessings, equipment, hero traits, or mode state.
- Elite reward design is not final.
- Blessing text, blessing values, character panel display, and actual combat effects must stay synchronized.
- Common-prosperity applies a multiplicative switch-cooldown factor through player attribute data; changing switch cooldown formulas needs regression testing.
- Current talent definitions contain 70 player-facing options in 35 mutually exclusive `_1` / `_2` groups, while a choice is queued every three player levels. The three role-entry cards now derive from the current team, so a single run only reaches its own team's groups (default team swordsman/gunner/mage: 28 groups; mechanic's 7 groups appear only while she is on the team). Exhaustion is reproducible: the offer still exposes three role-entry cards whose nested candidate arrays are empty, so the paused reward flow cannot complete. With active-skill groups unavailable this can occur after 16 picks (next trigger Lv.51); full exhaustion of the default team's 28 groups reaches the same state at Lv.87.
- `_1` / `_2` talent names are alternatives, not sequential tiers; current I/II titles can mislead players.
- Current documentation uses the canonical player-facing role name `法师`, but two live Mage talent summaries in `LEVEL_TALENT_DEFINITIONS` and the camp's placeholder Mage interaction still say `术师`; synchronize that source copy before claiming player-facing labels are fully unified.
- Direct role-build skill unlock cards are the only formal player-reachable active-skill unlock route. Blessing-recipe unlock/evolution, binding, and material-lock code remains, but required legacy materials are excluded from ordinary, Boss-choice, and random formal blessing generators.
- `EXIT_SKILLS_ENABLED=false` disables exit skills, but the movement tutorial still says a full-energy switch triggers both exit and entry skills.
- `difficulty_profile.gd` still describes the goal as defeating the final Boss “within 12 minutes”, while the Boss only spawns at `12:00`; current rules treat `12:00` as arrival and settlement as post-kill.
- Old 108-node runtime helpers and tests remain beside the current system. `get_selected_talents()` / `has_talent()` are disabled and `skill_talents` is cleared, so restoring only a UI or developer entry would create a half-working second progression route.

## UI Risks

- Main-menu Settings must remain a full-screen `Control` hosting `SurvivorsModal`; using a plain `CenterContainer` can make the panel appear in a corner.
- Hover detail panels intentionally auto-size up to a max size. Very long future text can still require scrolling inside the detail panel.
- Only independent-cooldown skills should appear as separate bottom skill slots. Other passive/basic/ultimate changes should be folded into normal attack or ultimate hover descriptions.
- Character panel shows ordinary skill-build stacks but not the current `level_talents` ledger; its footer still says “查看天赋树” after the old tree was removed.
- `refresh_limit=0` disables the old whole-offer refresh, not the live per-card buttons. Ordinary four-card offers and level-talent detail cards track one refresh per card slot in `level_up_ui.gd`.

## Tooling

- Local graphify support for Godot/GDScript depends on local tooling availability.
- Godot MCP is development tooling only. Current handoff should not rely on MCP being available; CLI Godot checks are the safer baseline.

## Known Design Quirks

### Blessing Skill Unlock Lock Sharing
- `player_blessing_skill_state.gd` uses a global `role_recipe_locks` dictionary to track consumed blessings per skill unlock.
- These locks are NOT per-role — a blessing consumed to unlock a swordsman skill (e.g., `formation_break` for Blade Storm) is also subtracted when checking mage skill requirements (e.g., Surging Wave).
- Result when legacy materials are injected or restored: two roles that both meet the same blessing requirements may not both unlock their skills, because the first unlock's lock is subtracted from all roles.
- This is dormant in a clean formal run because the required materials are not generated. If recipes are restored, decide whether the shared resource pool is intentional before changing it.
