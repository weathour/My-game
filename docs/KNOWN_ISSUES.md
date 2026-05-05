# Known Issues

## Documentation

- Some historical docs were rewritten after the old progression cleanup. If a spec conflicts with code, verify against the current scripts first.
- `graphify-out/` is the active generated code graph output when available.

## Assets

- Current BGM and some visual assets are development placeholders.
- Commercial/public release requires asset replacement or explicit license clearance.

## Gameplay/System Risks

- `scripts/player.gd` and `scripts/enemy.gd` remain large hub scripts; future work should avoid adding unrelated responsibilities there.
- Save/load and continue-game behavior should be treated as high-risk when changing player, enemy, blessings, equipment, hero traits, or mode state.
- Elite reward design is not final.
- Blessing text, blessing values, character panel display, and actual combat effects must stay synchronized.
- Common-prosperity applies a multiplicative switch-cooldown factor through player attribute data; changing switch cooldown formulas needs regression testing.

## UI Risks

- Main-menu Settings must remain a full-screen `Control` hosting `SurvivorsModal`; using a plain `CenterContainer` can make the panel appear in a corner.
- Hover detail panels intentionally auto-size up to a max size. Very long future text can still require scrolling inside the detail panel.
- Only independent-cooldown skills should appear as separate bottom skill slots. Other passive/basic/ultimate changes should be folded into normal attack or ultimate hover descriptions.

## Tooling

- Local graphify support for Godot/GDScript depends on local tooling availability.
- Godot MCP is development tooling only. Current handoff should not rely on MCP being available; CLI Godot checks are the safer baseline.
