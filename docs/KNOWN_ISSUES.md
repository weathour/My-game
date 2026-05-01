# Known Issues

## Documentation and governance

- Some older design docs still use “当前” heavily; verify against code before relying on them as specs.
- `docs/graphify/` is a legacy documentation-only graph snapshot; the active code graph is `graphify-out/`.

## Assets

- Current BGM and some visual assets are development placeholders.
- Commercial/public release requires asset replacement or explicit license clearance.

## Gameplay/system risks

- `scripts/player.gd` and `scripts/enemy.gd` remain large hub scripts; future feature work should avoid adding more unrelated responsibilities there.
- Save/load and continue-game behavior should be treated as high-risk when changing player, enemy, build, hero-trait, theme unlock, or mode state.
- Elite reward design is not final.
- Current theme/card detail tables are hardcoded for swordsman / gunner / mage. If future runs allow choosing any 3 heroes from a larger roster, Build detail generation must become team-driven rather than fixed-three-role-driven.
- Common-prosperity currently applies a multiplicative switch-cooldown factor through player attribute data; changing switch cooldown formulas needs a regression smoke for repeated picks.

## UI risks

- Main-menu Settings must remain a full-screen `Control` hosting `SurvivorsModal`; using a plain `CenterContainer` can make the panel appear in a corner.
- Hover detail panels intentionally auto-size up to a max size. Very long future card text can still require scrolling inside the detail panel.
- Only independent-cooldown passive cards should appear as separate bottom skill slots. Other passive/basic/ultimate upgrades should be folded into normal attack or ultimate hover descriptions.

## Tooling

- Local graphify support for Godot/GDScript currently depends on a local patch to installed `graphifyy`; reinstalling/upgrading graphify may remove that support.
- Godot MCP is development tooling only. Current handoff should not rely on MCP being available; prior session observed `godot-mcp` startup/handshake failure, while CLI Godot checks still pass.
