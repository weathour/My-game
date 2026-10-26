# Roadmap

This roadmap tracks direction, not release dates. For implemented behavior and current handoff, start with [the status entry](docs/08_当前实现状态与后续重点.md).

## Now: finish the current progression

- Keep the playable route explicit: independent role skill points upgrade existing icons or open a three-option unlock; wave blessings are free; skill level 5 queues a two-slot choice and level 10 grants the other slot.
- Validate the implemented growth of all four roles in full runs. Mechanic now has eight growth lines, numeric previews and independent entry/active turret sources; keep its summon density and high-tier balance under review.
- Design actual skill-slot effects for swordsman, gunner and mage. Mechanic's 16 effects are implemented, including their selection UI and save regression; balance tuning was explicitly excluded from that task.
- Keep player-level talent acquisition disabled until redesigned. Preserve saved `level_talents`, their effects and the character sheet's read-only list.
- Decide the fate of the retired 108-node catalog and 63 dormant stat-build definitions. Their presence in data or tests does not make them formal progression.
- Keep direct role-build cards as the formal active-skill unlock route. Restoring recipes requires a complete decision about material supply, binding, locks and evolution.

## Now: stabilize architecture and interaction

- Keep `main.gd` and `player.gd` as coordination points; put new behavior in the existing game/player/ability modules.
- Keep definitions separate from runtime state. Skill-level and build queries must stay read-only; writes and save loading own initialization and normalization.
- Preserve independent HUD widgets and their visibility-driven animation lifecycle. Keep layout rebuilds from retaining stale interaction objects.
- Preserve settings scrolling, keyboard focus, rebinding and shared modal initialization with regression checks.
- Continue consolidating UI where a concrete defect or feature needs it. Keep the character-sheet, shared modal and illustrated reward-card variants explicit in `DESIGN.md`.
- Replace remaining static tutorial parameters and shortcut hints through current value/keybinding providers.
- Protect save/load and reward pause ownership with roundtrip and flow checks. Do not change serialized IDs for a presentation refactor.

## Next: validate balance and performance

- Identify the Boss referenced by the meeting before adjusting its difficulty or blessing timing.
- Validate N1/N3/N6/N11 runs: survival, completion, reached level, build completion, bone income and shop usage.
- Balance the implemented meta loop: each carried Ruan Gou item copy costs 5 bones, duplicate effects stack, and capacity follows the highest unlocked N tier.
- Keep dense-combat and autosave optimization evidence-driven through existing benchmarks, evaluators, traces and feature flags. A getter microbenchmark is not an overall frame-rate claim.
- Clarify elite and Boss reward identity through existing reward modules before adding reward types.

## Story framework delivered; release follow-up

- The first chapter now has saved dialogue, tasks, delivery, records and practice replays on the fixed three-stage route. Follow the current [implementation record](docs/implementation/2026-10-23_系统框架实施.md) for acceptance and remaining work.
- Keep the implemented camp loop coherent: permanent items survive return, separate per-copy buy/refund actions, four-role residents, ordered team preparation and loadout confirmation. The blacksmith reuses the equipment filter of the existing shop. Defer elaborate facilities, crafting trees and new camp currencies.
- Replace placeholder or non-commercial media, finalize licensing, verify standalone exports and create the remaining combat SFX. Development PCK checks and common UI/result tones are implemented.
- Keep achievements local until platform integration; use the existing `AchievementService` boundary for Steam.
- Do not restore retired three-in-one blessings, all-team role traits, pre-equipped skill loadouts, the seven-second switch cooldown or the old talent tree as incidental cleanup.
