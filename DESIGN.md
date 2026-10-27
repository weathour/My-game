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

Updated 2026-10-27. The direction is **Romance of the Three Kingdoms art + Rance 10 UI organization**. The user chose [probe D](design/ui-direction-20261027/probes/d-rtk-rance-restrained.png) for the map and overall composition after rejecting A/B's excessive browser-game styling; C was superseded. The later request specifically calls for Rance 10-style framed controls, updating the earlier surface and border treatment. The current reflow has been implemented and tested; the user has not yet accepted its visuals. [History](docs/design-reviews/2026-10-27_操作界面风格与制作方向.md) · [implementation](docs/implementation/2026-10-27_人物卡与主线界面重排.md).

## Composition and materials

Keep the map's desolate Three Kingdoms landscape and let terrain and character art lead. Use dark green surfaces with fine aged-gold borders and selective corner ornaments; primary buttons use wine red. Olive marks selection and brick-red lines mark routes. Chinese serif headings pair with legible Chinese body text.

The earlier blanket ban on metal frames and carved ornament no longer applies. The default combat HUD restores the triangular portrait arrangement: the controlled character is raised in the center, with switch targets lower on the sides and a short transition when switching. The earlier simple HUD used a horizontal arrangement and did not reproduce that geometry. Show only actual party members; fallen auxiliaries remain identifiable but are skipped by switching. Keep the HUD over the battlefield and retain the three-row team band as an option. Reuse does not restore legacy combat rules.

The reusable new theme is `scripts/ui/chronicle/chronicle_theme.gd`. Generated assets under `assets/ui/chronicle/` contain no live UI labels. Runtime controls, choices, route edges and status values remain editable Godot elements.

## Two map levels

- World: continental relief, selectable geographical modules, regional information and available campaigns. The current 13-state data is an illustrative scaffold, not a final historical-boundary decision.
- Campaign: local terrain, current choices and progression toward the final boss. Six segment tabs are the current implementation, not a required permanent navigation bar. Segment browsing does not add another geographical layer or permit replaying cleared branches.

A companion, central route and contextual actions retain the approved layout's main ingredients. Do not force a fixed sidebar, global navigation and full party band onto every page. The opening remains a solo protagonist with empty auxiliary slots.

## Information hierarchy

Character records distinguish foreground abilities, configured-auxiliary support and owned numeric passives; present their concise comparison together. Full stats, growth tables and eligibility belong in on-demand details. Dispel, revival and interception require a configured auxiliary and explicit character conditions. Owned numeric bonuses do not silently grant those functions.

The party page places the protagonist and two auxiliary slots together on the left, with actual party bonuses, configured support and shared equipment effects on the right. Count every owned character's numerical passive, including fallen characters, while stopping a fallen auxiliary's background support. Keep effects and their scope distinct, update after party/equipment changes, and do not present rehearsal-fixture numbers as real combat values. At 1280 pixels and wider, the summary places bonus sources beside support and equipment; at 960 pixels it scrolls vertically. The revision passed the three-size layout and party-summary checks.

Equipment has three shared slots: weapon, armor, accessory. Weapon form changes the protagonist; normal equipment stats apply to the current party; enchantment defaults to the controlled actor's direct attacks; armor effects follow the actual damage recipient.

Reward cards show acquisition/duplicate-leveling results and an owned-bonus summary, with keyboard-accessible ability details. Ordinary 5/2, elite 5/3, chapter 7/3 and chapter elite 7/4 share one layout. Chapter candidates contain at least two important cards, without forcing their selection.

Card backgrounds use three explicit rarity tiers: blue common, purple rare and gold-orange legendary; the protagonist has a separate vermilion hero treatment. Rarity is independent of character `kind`, eligible pools and reward guarantees. Character art stays transparent and separate from the rarity background, frame and labels. Mapping and implementation are documented in the [current revision](docs/implementation/2026-10-27_人物稀有度与编队加成.md).

## Input and adaptation

Desktop targets are 1280×720 and 1920×1080; the minimum target window is 960×540. Adapt card and detail layouts to smaller windows, retain focus-following scroll for lists, and show selection, unavailability and death through text or shape as well as color. The three-size layout fixture passed; it is not a substitute for visual acceptance.

Menus use Tab/arrows, Enter and Escape. The playable battle uses WASD/arrows, Q/E, J/K and Escape. New battle key remapping remains pending; legacy bindings are unchanged. Switching keeps each member's HP/MP and cooldowns. A maximum of two manual skill keys follows the controlled member.

## Implementation boundary

The default entry is now `scenes/chronicle/chronicle_shell.tscn`. Six battle nodes and twelve characters, XP, equipment, rewards and isolated formal saves are implemented; a single route includes four battles or five with the optional elite. Existing actor/enemy visual scenes, battle maps, portraits, effects and HUD widgets are reused through presentation adapters. Combat now uses a shared 3200×1800 world, a follow-camera with a 1280×720 baseline view, and visible body and foot alignment; fields, bounds and the overview use the same geometry. Spawns stay near the engagement. Automated checks passed, while encounter pacing and visual acceptance require play and user review; see [battle proportion and HUD record](docs/implementation/2026-10-27_战场比例与三角头像HUD.md). Complete chapter content and the protagonist's battle sprite remain unfinished.

Reuse the 14 original music tracks through a matching music page. Keep original catalog names; do not relabel old story music as a finished new score. Use project art and appropriately licensed data, not commercial-game screenshots as runtime assets.

## Latest UI research

The [Rance 10 screen study](docs/design-reviews/2026-10-27_兰斯10界面结构与信息减法研究.md) records the reference and page-specific decisions. Portrait, card, party and reward components have been added; equipment, maps and menu have been reorganized. Three transparent atlases provide 26 portrait cells for the 38-entry directory through mapping and reuse; Emma's existing portrait is retained and the protagonist's approved early-campaign art is used for the card and detail page. The eight named Three Kingdoms cards reference *The Ravages of Time* as provisional designs, not final character likenesses. [Asset provenance](assets/ui/chronicle/cards/README.md). The simple HUD and optional team band observe one battle session.
