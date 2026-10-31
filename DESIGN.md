# Design direction

The active project is the White Gate campaign. Rules and actual scope are maintained in [design consensus](docs/00_当前设计共识.md) and [current status](docs/08_当前实现状态与后续重点.md).

## Visual language

Combine a desolate Three Kingdoms setting with readable character art, ghostly threats, humor and adult adventure. Use dark green, aged gold and wine red for the interface; the world and its locations may have distinct palettes. Combat ground is subdued and visually flat so the player can distinguish characters, danger warnings and pickups. Building scenery and obstacles are future work, not implied collision.

The route map displays authored node connections, branches and state; inspection does not advance progress. Character records show foreground abilities, background support and owned bonuses separately. Default combat HUD uses a triangular portrait arrangement, with a team-band alternative; show only actual members and make death, availability and selection recognizable without color alone.

## Interaction and feedback

Menus use keyboard navigation; battle supports movement, switching and manual key skills without mouse aiming. Combat presentation follows actual cast, hit, shield, death, pickup, level and elite-result events. Visual and sound aggregation protect readability without changing damage or rewards. Reduced flash, reduced motion, mute and pause retain their meaning.

Story presents scene backgrounds, transparent portraits and sequential dialogue. History shows only already revealed text. Completed story replay and read-only lore do not change progression, rewards or checkpoints. Optional character stories maintain separate reading checkpoints.

Layouts target 960×540, 1280×720 and 1920×1080. Technical screenshots and automated checks do not replace user review. Preserve source and license information for game art, audio and production inputs; never treat an external commercial reference image as a runtime asset.
