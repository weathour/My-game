---
name: My Game
description: Restrained Three Kingdoms strategy art with Rance-style campaign navigation.
colors:
  backdrop: '#111e19'
  paper: '#1d3229'
  ink: '#eee5ce'
  muted: '#bcbba7'
  selected: '#40513a'
  route: '#9c4d3e'
  mana: '#527b89'
  border: '#8d774e'
  accent: '#dfc187'
  primary: '#592e28'
---

# Design System: My Game

Updated 2026-10-29. The direction retains **Romance of the Three Kingdoms art + Rance 10 UI organization**, with a quieter enemy codex informed by the visual structure of Black Myth: Wukong's journal. The user chose [probe D](design/ui-direction-20261027/probes/d-rtk-rance-restrained.png) for the map and overall composition; subsequent framing and page changes retain project-owned artwork. The previous navigation and codex revision passed its checks, but the user found the main map too simple. The main screen has since been rearranged based on [the module-by-module review](docs/design-reviews/2026-10-29_兰斯10主页面逐模块复核与重排.md), with three-size and interaction checks; those checks do not imply user visual approval.

## Composition and materials

Keep the map's desolate Three Kingdoms landscape and let terrain and character art lead. Use dark green surfaces with fine aged-gold borders and selective corner ornaments; primary buttons use wine red. Olive marks selection and brick-red lines mark routes. Chinese serif headings pair with legible Chinese body text.

The earlier blanket ban on metal frames and carved ornament no longer applies. The default combat HUD restores the triangular portrait arrangement: the controlled character is raised in the center, with switch targets lower on the sides and a short transition when switching. The earlier simple HUD used a horizontal arrangement and did not reproduce that geometry. Show only actual party members; fallen auxiliaries remain identifiable but are skipped by switching. Keep the HUD over the battlefield and retain the three-row team band as an option. Reuse does not restore legacy combat rules.

The reusable new theme is `scripts/ui/chronicle/chronicle_theme.gd`. Generated assets under `assets/ui/chronicle/` contain no live UI labels. Runtime controls, choices, route edges and status values remain editable Godot elements.

## Two map levels

- World: continental relief, selectable geographical modules, regional information and available campaigns. The current 13-state data is an illustrative scaffold, not a final historical-boundary decision.
- Campaign: local terrain with 36 nodes arranged as one continuous horizontal route. Draw the actual authored connections, spreading branches vertically and merging them at their real convergence points. Keep segment names within the map; the current redesign removes the duplicate segment directory. Showing a node does not by itself change its state or make it reachable.

Allow dragging and wheel navigation, hover information, keyboard selection and a local control to locate the current node. Keep campaign position distinct from the inspected node. The current layout places chapter and march context at the top, a configured living female companion or the protagonist on the left, the map in the center, task or branch choices on the right, selected information at lower left and actual party/equipment along the bottom. Menu and preparation sit in the lower corners; the legend, duplicate from/to lists and persistent operation instructions are removed. Original vector icons distinguish battle, elite, fountain, story and finale independently of status frames. Inspection never advances the campaign; completed authored story nodes retain read-only replay when no reward is pending. This layout's checks are recorded in [the module review](docs/design-reviews/2026-10-29_兰斯10主页面逐模块复核与重排.md).

## Information hierarchy

Character records distinguish foreground abilities, configured-auxiliary support and owned numeric passives; present their concise comparison together. Full stats, growth tables and eligibility belong in on-demand details. Dispel, revival and interception require a configured auxiliary and explicit character conditions. Owned numeric bonuses do not silently grant those functions.

The preparation page places the fixed protagonist and two auxiliary slots above the character-card library. Drag a card to deploy or replace, exchange the two slots, or drag a deployed card back to the library; keyboard pickup, target selection, placement and cancellation provide an equivalent path. The compact preview has one “详情” entry beside the name. Open the in-context sheet to read abilities, attributes and growth, or the character profile without losing the preparation or map context. Count every owned character's numerical passive, including fallen characters, while stopping a fallen auxiliary's background support. Keep effects and their scope distinct, update after party/equipment changes, and do not present rehearsal-fixture numbers as real combat values. The [formation and inspection record](docs/design-reviews/2026-10-29_整备拖卡与人物原位检视.md) covers three-size, drag and party-summary checks.

The current navigation revision groups party and equipment as tabs within preparation, retaining the return context from the world, route or menu and the battle-preparation flow. Battle, elite and final-boss nodes provide local enemy information; the menu opens the full 43-entry enemy codex. The codex places the category list, text and large portrait in three regions; portrait and animation share one display area, with combat details shown on demand. Do not expose internal IDs, sprite dimensions, collision radii or raw timing fields in the main reading view. The original dark ink backdrop, not a reference-game screenshot, provides the visual surface. Its implementation and checks are recorded in the redesign record.

Equipment has three shared slots: weapon, armor, accessory. Weapon form changes the protagonist; normal equipment stats apply to the current party; enchantment defaults to the controlled actor's direct attacks; armor effects follow the actual damage recipient.

Reward cards show acquisition/duplicate-leveling results and an owned-bonus summary, with keyboard-accessible ability details. Ordinary 5/2, elite 5/3, chapter 7/3 and chapter elite 7/4 share one layout. Chapter candidates contain at least two important cards, without forcing their selection.

For the opening stage, settle experience and complete the ordinary five-card/two-pick reward first, or three picks if the card elite was defeated. Emma's introduction follows, and she joins and enters the pool only after that story ends; she does not occupy a pick or appear among candidates newly generated under this sequence. Previously generated candidates in old saves are retained.

The approved story presentation layers transparent character portraits over a scene background, with a dialogue box at the bottom. Advance one line at a time, show the speaker's name, and emphasize the speaking portrait; narration has no invented speaker name. Expressions and poses may follow the scene, with transitions and music. The opening uses available neutral portraits; implementation and visual acceptance are tracked in [the current status](docs/08_当前实现状态与后续重点.md).

Completed event and fountain nodes with authored story scripts can be replayed from the route details or journal using the current save's progress. Mark replay clearly, begin at the first line, and offer an explicit way to finish or return. Use the current story presentation without repeating recruitment, unlocks, recovery, rewards or result messages; leave campaign state and the normal story checkpoint untouched. Whole-scene replay remains separate from current-scene dialogue history; neither provides a cross-save gallery.

During both first reading and replay, scrolling up opens a read-only history of the current scene over a dimmed version of the stage. Show prior lines and only the part of the current line already revealed, with speaker names or narration; do not expose later lines. Pause typewriter progress while the history is open and return to the same line and reveal position when it closes. Support wheel browsing, an explicit return button, keyboard navigation and closing without advancing. Resizing preserves the open history, scroll position and current reveal progress; no campaign checkpoint or result is written.

Card backgrounds use three explicit rarity tiers: blue common, purple rare and gold-orange legendary; the protagonist has a separate vermilion hero treatment. Rarity is independent of character `kind`, eligible pools and reward guarantees. Character art stays transparent and separate from the rarity background, frame and labels. Mapping and implementation are documented in the [current revision](docs/implementation/2026-10-27_人物稀有度与编队加成.md).

## Input and adaptation

Desktop targets are 1280×720 and 1920×1080; the minimum target window is 960×540. Adapt card and detail layouts to smaller windows, retain focus-following scroll for lists, and show selection, unavailability and death through text or shape as well as color. The three-size layout fixture passed; it is not a substitute for visual acceptance.

Menus use Tab/arrows, Enter and Escape. The playable battle uses WASD/arrows, Q/E, J/K and Escape. New battle key remapping remains pending; legacy bindings are unchanged. Switching keeps each member's HP/MP and cooldowns. A maximum of two manual skill keys follows the controlled member.

## Implementation boundary

The default entry is `scenes/chronicle/chronicle_shell.tscn`. The chapter has 18 configured battle nodes, 38 initial character definitions and 43 enemy/object definitions; two continuous automated routes and enemy visual integration have been checked. Combat uses a 3200×1800 world and a follow-camera with a 1280×720 baseline. Balance and art remain subject to play and user review; the main-screen rearrangement has passed its recorded navigation and rendering checks. See [current status](docs/08_当前实现状态与后续重点.md) and the [enemy production record](docs/implementation/2026-10-28_白门楼敌人完整制作.md).

Reuse the 14 original music tracks through a matching music page. Keep original catalog names; do not relabel old story music as a finished new score. Use project art and appropriately licensed data, not commercial-game screenshots as runtime assets.

## Latest UI research

The [Rance 10 screen study](docs/design-reviews/2026-10-27_兰斯10界面结构与信息减法研究.md) records the reference and page-specific decisions. Portrait, card, party and reward components have been added; equipment, maps and menu have been reorganized. Three transparent atlases provide 26 portrait cells for the 38-entry directory through mapping and reuse; Emma's existing portrait is retained and the protagonist's approved early-campaign art is used for the card and detail page. The eight named Three Kingdoms cards reference *The Ravages of Time* as provisional designs, not final character likenesses. [Asset provenance](assets/ui/chronicle/cards/README.md). The simple HUD and optional team band observe one battle session.
