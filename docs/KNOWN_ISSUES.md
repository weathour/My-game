# Known Issues

## Documentation

- `docs/13` and `docs/14` are historical three-stage/108-node specifications. Current player progression uses acquisition/skill-level cards and level-5/10 talent slots; `LEVEL_TALENT_DEFINITIONS` acquisition is disabled, and data or tests for old `TALENT_DEFINITIONS` do not prove player reachability.
- `graphify-out/` is the active generated code graph output when available.
- Generated graph freshness must be checked against the working tree. Current source and the status entry take precedence over graph summaries and dated reviews.

## Assets

- Runtime BGM now uses 14 original cues; the four old placeholder music files remain in the source tree but are excluded from exports. Human musical listening review and normal-speed full-game mix evaluation have not been performed. See [production evidence](../design/music-20261025/README.md).
- Some visual assets remain development placeholders.
- Commercial/public release requires asset replacement or explicit license clearance.

## Gameplay/System Risks

- 2026-10-26复核待修：在小Boss奖励菜单退出，续战加载后停在默认暂停页，再次退出，会丢失原先固定的奖励候选。`run_save_flow.gd` 先把快照放到 `saved_reward`，随后立即写回；`reward_flow.gd:get_save_data()` 此时只读取尚未恢复的实时上下文，磁盘奖励状态被覆盖为空。已在临时存档中复现；修复应保留未消费的奖励快照并覆盖暂停后二次退出/加载回归。按用户要求，本轮先提交已有修改，留待后续修复。
- The 2026-10-25 dense real-scene benchmark still exceeds a 16.7ms budget: final X11 mean 83.35ms, p95 213.86ms with roughly 48 enemies and 2000 hostile bullets. Save validation is faster, but hostile simulation and enemy updates remain substantial CPU work. This is a reproducible release-performance risk, not a 60 FPS acceptance pass; see [measurement boundaries](implementation/evidence/2026-10-25/architecture/runtime/performance-findings.md).
- `scripts/player.gd` and `scripts/enemy.gd` remain large hub scripts; future work should avoid adding unrelated responsibilities there.
- Save/load and continue-game behavior should be treated as high-risk when changing player, enemy, blessings, equipment, hero traits, or mode state.
- Elite reward design is not final.
- Blessing text, blessing values, character panel display, and actual combat effects must stay synchronized.
- Camp return now preserves permanent purchases, and Rusted Dagger critical damage is included in combat and stat sources. Items already erased by an older return flow cannot be reconstructed automatically because profiles have no purchase history; this update preserves the remaining data and does not invent refunds.
- Common-prosperity applies a multiplicative switch-cooldown factor through player attribute data; changing switch cooldown formulas needs regression testing.
- The retained role-talent offer builder can produce empty choices when its groups are exhausted. Ordinary level-ups no longer increment `pending_level_talent_choices`, so this is a reactivation/developer-injection risk, not a current every-three-level progression blocker. Define exhaustion behavior before restoring that route.
- `_1` / `_2` talent names are alternatives, not sequential tiers; current I/II titles can mislead players.
- Direct role-build skill unlock cards are the only formal player-reachable active-skill unlock route. Blessing-recipe unlock/evolution, binding, and material-lock code remains, but required legacy materials are excluded from ordinary, Boss-choice, and random formal blessing generators.
- Old 108-node definitions are isolated in `scripts/player/data/legacy_skill_talent_catalog.gd`; compatibility helpers and tests remain. `get_selected_talents()` / `has_talent()` are disabled and `skill_talents` is cleared, so restoring only a UI or developer entry would create a half-working second progression route.

## UI Risks

- All four roles now consume `player_skill_level_effect_flow.gd`; mechanic has eight growth lines, independent entry/active turret sources and 16 implemented skill-slot talents. Other roles' skill slots remain placeholders. Mechanic balance tuning is explicitly outside the current task; full-run density/performance remains unverified.
- Most ability hover descriptions still contain authored base values. Turret/cannon and fireball stat rows read current runtime getters; a complete effective-value presentation for every ability remains separate content work.
- Main-menu Settings must remain a full-screen `Control` hosting `SurvivorsModal`; using a plain `CenterContainer` can make the panel appear in a corner.
- Hover detail panels intentionally auto-size up to a max size. Very long future text can still require scrolling inside the detail panel.
- Only independent-cooldown skills should appear as separate bottom skill slots. Other passive/basic/ultimate changes should be folded into normal attack or ultimate hover descriptions.
- The character sheet now displays current stats/sources and saved `level_talents`. Some innate/ultimate parameters still come from authored descriptions. Mechanic current values read runtime getters, and its skill slots show real effects and ownership; other roles' slots still show placeholders.
- `refresh_limit=0` disables the old whole-offer refresh, not the live per-card buttons. Ordinary four-card offers and retained legacy level-talent detail cards track one refresh per card slot in `level_up_ui.gd`.

## Tooling

- The installed Graphify 0.9.50 lacks both GDScript registration and extraction. The update guard restores the previous graph when a candidate loses runtime coverage and marks it stale; the graph must not be treated as current implementation evidence. See [Graphify workflow](GRAPHIFY.md).
- Godot MCP is development tooling only. Current handoff should not rely on MCP being available; CLI Godot checks are the safer baseline.

## Known Design Quirks

### Blessing Skill Unlock Lock Sharing
- `player_blessing_skill_state.gd` uses a global `role_recipe_locks` dictionary to track consumed blessings per skill unlock.
- These locks are NOT per-role — a blessing consumed to unlock a swordsman skill (e.g., `formation_break` for Blade Storm) is also subtracted when checking mage skill requirements (e.g., Surging Wave).
- Result when legacy materials are injected or restored: two roles that both meet the same blessing requirements may not both unlock their skills, because the first unlock's lock is subtracted from all roles.
- This is dormant in a clean formal run because the required materials are not generated. If recipes are restored, decide whether the shared resource pool is intentional before changing it.

## System framework implementation, 2026-10-23

The four reproduced save/reward defects from the pre-implementation review are fixed and covered by `save_recovery_smoke.gd` and `reward_recovery_smoke.gd`. The story chapter now has task/dialogue/item state, migration, replay and failure recovery. See the [implementation record](implementation/2026-10-23_系统框架实施.md) for exact evidence.

Remaining boundaries:

- The 2026-10-23 baseline failures were reviewed and corrected against current gameplay contracts in the 2026-10-25 architecture work. The full gate now passes 174 regular smokes; earlier reports remain historical evidence. See the [current implementation record](implementation/2026-10-25_架构健全性整改.md) for the final source and performance status.
- Bone pickup receipts are scoped to the current run and removed at successful end/settlement; ordinary new pickups and deterministic legacy snapshot IDs prevent an older run snapshot from granting an already credited pickup again. They are not a complete historical income ledger or a way to reconstruct data lost before this update.
- Runtime validation now covers nested entities, directly consumed state types, vectors/colors and finite numbers, with explicit restore failure and primary/backup preservation. Optional legacy fields still use their existing normalizers; future ability payload fields must extend validation and round-trip coverage where they are consumed.
- UI/result sounds are generated development cues. Most combat sound design, target-platform checks and placeholder-media clearance remain open.
- Automatic story tests trigger existing stage victory events; they do not prove normal-speed combat pacing or a complete human 20-wave playthrough.
- A development PCK has been checked independently; standalone executable templates are absent locally. No public build or upload was performed.
