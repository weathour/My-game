---
name: My Game
description: A tactical campaign archive for a survivors-like game, with deep green and wine panels, original gilded frames, and three active roles from a four-role roster.
colors:
  campaign-backdrop: "#000000B8"
  campaign-bg: "#111A15FA"
  campaign-bg-soft: "#1C2C24F5"
  campaign-card: "#24392EFA"
  campaign-card-alt: "#301C20FA"
  campaign-border: "#82704BE6"
  campaign-gold: "#CAA45B"
  text-primary: "#F5ECD6"
  text-muted: "#C6BEA8"
  text-gold: "#F2D699"
  state-good: "#A6D29C"
  state-danger: "#702D32F5"
typography:
  headline:
    fontFamily: "Noto Serif CJK SC, Source Han Serif SC, SimSun, serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "Noto Serif CJK SC, Source Han Serif SC, SimSun, serif"
    fontSize: "21px"
    fontWeight: 700
    lineHeight: 1.25
  body:
    fontFamily: "Noto Sans CJK SC, Microsoft YaHei, PingFang SC, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Noto Sans CJK SC, Microsoft YaHei, PingFang SC, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.3
rounded:
  control: "3px"
  card: "3px"
  modal: "3px"
spacing:
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  xl: "16px"
components:
  campaign-panel:
    backgroundColor: "{colors.campaign-bg}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.modal}"
    padding: "{spacing.xl}"
    frame: "original gilded carved nine-slice decoration"
  campaign-card:
    backgroundColor: "{colors.campaign-card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "{spacing.sm}"
  campaign-tab-selected:
    backgroundColor: "{colors.campaign-card-alt}"
    textColor: "{colors.text-gold}"
    rounded: "{rounded.control}"
    height: "42px"
---

# Design System: My Game

## Overview

**Creative North Star: "The Gilded Campaign Archive"**

The interface pairs deep forest-green and wine-red surfaces with warm ivory reading text, gold serif headings, and original carved gilded frames. The main menu uses the original `assets/ui/campaign/four_heroes_menu.png` illustration, reserving the left side for navigation and placing the full four-role lineup on the right. Panels, preparation/read/record views, character pages, save selection, camp summaries, HUD, pause, and reward surfaces share this campaign treatment while retaining their existing task-specific information hierarchy.

The visual reference is the presentation of [Rance 10's official system page](https://www.alicesoft.com/rance10/system/index.html): use it to guide framing, palette, type hierarchy, and the sense of an illustrated campaign archive. This project uses its own controls, writing, art, and game rules. The gilded frame is a real nine-slice Node2D decoration attached to controls, not a screenshot or flattened background; it takes no layout space and does not intercept input.

The system still rejects generic mobile-RPG clutter, flat blue SaaS dashboards, copied official materials or rules, unreadable ornament, and tiny card grids or raw debug-text lists. Standard tabs, lists, buttons, and scrolling should remain clear and usable.

**Key Characteristics:**
- Three stable information zones: team, role record, build record.
- Serif gold display headings paired with readable Chinese sans-serif body text and explicit empty and locked states.
- Selection is shown by border, surface, and text together.
- Supported desktop layouts start at 1280×720.

## Colors

The working palette follows `scripts/ui/theme/survivors_ui_theme.gd`: near-black forest green `#111A15`, soft green `#1C2C24`, deep green cards `#24392E`, wine-red cards `#301C20`, muted gold borders `#82704B`, gold accent `#CAA45B`, ivory text `#F5ECD6`, muted text `#C6BEA8`, pale-gold headings `#F2D699`, active green `#A6D29C`, and danger wine `#702D32`.

### Primary
- **Campaign Gold** (`#CAA45B`): primary borders and selected states; the carved frame asset supplies brighter highlights.
- **Text Gold** (`#F2D699`): headings and selected labels.

### Secondary
- **State Good** (`#A6D29C`): an effect, role, upgrade, or talent that is currently active.
- **State Danger** (`#702D32`): unavailable or harmful states that require attention.

### Neutral
- **Campaign Background** (`#111A15`): modal and deep workspace surfaces.
- **Campaign Soft Background** (`#1C2C24`): controls and secondary panels.
- **Campaign Card** (`#24392E`): list rows and information cards.
- **Wine Card** (`#301C20`): alternate panels and selected/action surfaces.
- **Campaign Border** (`#82704B`): inactive boundaries and dividers.
- **Primary Text** (`#F5ECD6`): names and values.
- **Muted Text** (`#C6BEA8`): explanations, hints, and unavailable content.

**The Scarce Gold Rule.** Gold marks current selection, completion, or the screen's structural frame; it is not filler decoration.

## Typography

**Display Font:** Noto Serif CJK SC, Source Han Serif SC, SimSun, then serif.
**Body and Label Font:** Noto Sans CJK SC, Microsoft YaHei, PingFang SC, then sans-serif.

**Character:** Serif headings carry the campaign tone; a familiar Chinese sans-serif keeps controls, body copy, and dense records readable. Hierarchy comes from size, weight, color, and spacing.

### Hierarchy
- **Headline** (600, 28px, 1.2): modal titles only.
- **Title** (600, 21px, 1.25): section headings.
- **Body** (400, 15px, 1.4): skill, blessing, stat, and equipment content.
- **Label** (400, 12px, 1.3): scope, shortcut, count, and secondary-state labels.

**The Baseline Rule.** Core build information must remain legible at 1280×720; do not solve density by shrinking body text below 12px.

## Elevation

Depth is structural: layered green/wine surfaces and the original gilded carved frame separate the screen, sections, and rows. Keep ordinary controls compact and mostly flat; hover and focus may lighten a surface, while selected panels can use a stronger gold frame.

### Shadow Vocabulary
- **Card Separation** (5–8px dark shadow): dense archive cards and sections.
- **Modal Separation** (14px dark shadow): the outer character-panel frame only.

**The Layer-Only Rule.** Shadows clarify nesting; they never decorate ordinary text or inactive controls.

## Components

The shared frame and the character sheet have distinct existing variants. Shared controls use compact 3px corners; the nine-slice gilded frame supplies the larger decorative silhouette. Reward cards keep their illustrated paper treatment. Reuse the corresponding component rather than mixing visual treatments within one screen.

### Main Menu and Music Room

The main menu uses `assets/ui/campaign/four_heroes_menu.png` (1672×941) with linear filtering and aspect-preserving cover. The image leaves the left side clear for actual menu controls and composes the four heroes on the right: the blond ponytailed swordsman with blue bow and white cape, the red-haired gunner, the silver-purple-haired mage, and the blue-haired mechanic with glasses, red headband, and khaki workwear. Their identities follow the three current `assets/players/` idle sprites and the mechanic master image at `design/mechanic-rework-20261013/source/character-master.png`; the asset provenance is documented in `assets/ui/campaign/README.md`. “音乐鉴赏” opens a dedicated catalogue containing all 14 existing original tracks with no unlock gate. Track selection, previous/next, play/pause, seeking, elapsed/remaining time, and current mute/volume status are visible controls. Track completion advances to the next catalogue entry. Opening the room pauses and records the menu track position; closing stops the preview and restores that menu track and position through the existing BGM volume/mute setting. Escape returns focus to the opener. These are interface affordances only; the music room does not alter progression or save data.

The frame and palette take visual direction from [the official Rance 10 system page](https://www.alicesoft.com/rance10/system/index.html). Keep this to presentation: original assets and controls, no imported official art/text, and no borrowed gameplay rules. `campaign_frame.gd` draws the authored nine-slice frame as a `Node2D` decoration on real controls, preserving their layout, hit targets, and input behavior.

### Shared Modal and Settings

- Shared modals use the existing Chinese sans-serif reading font. Title and hint values set before the node enters the tree must survive initialization; empty headers take no space.
- Settings has one title, a fixed category rail, a scrolling content area and a fixed close action. Category selection, keyboard focus and disabled controls remain visually distinct; the focus outline has a transparent fill.
- Keyboard focus follows scrolling, stays inside the visible modal and returns to the opener on close. While capturing a binding, Tab, Enter and Space are ordinary bindable keys; Esc cancels capture before it can close the modal.
- Audio controls include a labeled mute checkbox. Display controls include HUD layout and the temporary performance-recording switch. Persist existing setting IDs across presentation changes.

### Camp Preparation

Use the existing pixel terrain, buildings and hero art for the world, with functional zones and a nearest-interaction highlight. Keep a small top action bar and bottom status recap: bones, unlocked N, next team, carry count/summary and the latest clear or active run. Avoid permanent notification badges or new currencies.

The shop uses four filters (all, stones, equipment, owned), a scrolling item list and a separate effect inspector. Show cumulative current and next-copy values and distinct buy/refund actions; capacity and insufficient funds disable only buying. Keep save failures visible and preserve the prior inventory. Team preparation supports replacement and adjacent reordering, with base-stat/role previews and an explicit first slot.

All camp overlays use the shared modal, stop world movement and suppress world interaction. Restore focus on close. Role/N-tier details explain when edits apply: team changes affect the next new run; current permanent carried items apply on continue. Validate action bounds at 1280×720 and 960×540.

### Buttons
- **Shape:** compact rectilinear controls (3px corners in the shared theme), visually integrated with the carved frame.
- **Primary:** campaign green, wine, or dark-gold surface, gold border/text, at least 40px high.
- **Hover / Focus:** lighten the same surface; focus uses a visible gold outline.
- **Secondary:** campaign green card surface with muted gold border.

### Chips
- **Style:** compact inline tier tokens such as `I×3 · II×1`; separators keep the ledger scannable without adding another row of controls.
- **State:** owned blessing tiers are written explicitly; unavailable or locked information uses muted text plus an explicit label.

### Cards / Containers

- **Upgrade-card exception:** preserve the original four floating portrait paper cards, illustrated outlines, crystals, entrance animation and separate refresh controls. Their face reads owner/type, name, level transition, primary benefit and secondary changes. Show details below the row; do not replace the cards with dashboard tiles.
- **Reading type for choices and hover details:** Noto Sans CJK SC, Microsoft YaHei, PingFang SC, then sans-serif through Godot `SystemFont`. Paper uses dark ink; dark hover panels use warm ivory text. Skill titles and the primary benefit use a bold weight.
- **Choice state:** gold outline plus an explicit selected check, a visible selected/required count and one refresh count per card. The active flow shows the actual required count: one free wave blessing, one skill unlock, or the current talent-slot choice. Historical four-pick-two styling does not enable that retired route.
- **Corner Style:** 3px for shared controls, rows, cards, and modal surfaces; campaign frame artwork supplies the outer carved silhouette.
- **Background:** campaign card over campaign background.
- **Shadow Strategy:** structural only, following Elevation.
- **Border:** one pixel by default, two pixels for selected/current state.
- **Internal Padding:** 8–12px.

### Inputs / Fields
- **Style:** standard Godot controls on the campaign-soft surface.
- **Focus:** visible gold border with no decorative animation.
- **Error / Disabled:** explicit text and muted/danger color; never color alone.

### Navigation

The character sheet has four top tabs: 总览 / 技能 / 祝福 / 装备. Its left team rail and right inspector stay fixed across tabs. Open on overview with attack selected; preserve stat selection on role changes. Click or keyboard focus selects list records. `Ctrl+Tab` cycles tabs, `Ctrl+Shift+Tab` reverses, and the configured character key or `Esc` closes the sheet. Preserve reward-menu pause context.

### Character Overview

Show all fourteen primary stats at the 1280×720 logical baseline. Group output, survival, and mobility/cooldowns. Base attack speed belongs in the attack-speed detail; damage bonuses belong in attack sources. Do not duplicate already-applied multipliers. The inspector lists exact combat operands and explains conditional scope and nonlinear dodge/reduction. Keep pixel portraits compact, show shared run level, and distinguish viewed role from active role.

Character-sheet surfaces use `#112018` / `#172B20`, wine-red selected tabs, `#DFBD68` gold, `#F3EAD0` reading text, `#C5B99B` secondary text and `#B5D39A` values. Their content retains the team / role / inspector information hierarchy and scales with the supported minimum window; it does not hide primary stats in a small scroll box.

### Skill Record

Group innate abilities, five active skills and the ultimate; retain the gunner's extra hunt record. Show current effect and available runtime parameters before next-level changes and talent slots. Unowned actives point to acquisition cards, ultimates have no invented level progression, and saved `level_talents` get a separate read-only list. Explicitly label placeholder effects and missing growth descriptions.

Mechanic's 16 implemented skill talents show their names, full rules and explicit owned/pending status in the detail pane. Reward cards use a talent name plus two short effect lines; the hover panel carries lifecycle and combination rules. Other roles keep explicit placeholder labels until their effects are implemented.

### Blessing and Equipment Records

Show all owned tier counts and aggregate primary plus extra stats only where the formula supports it. Label per-copy effects in the fixed detail pane; do not call a highest-tier copy the total. Keep scope visible. Equipment separates shared stones from role-owned items and gives ordinary items a visible transfer action, retaining the existing cap and right-click shortcut.

## Do's and Don'ts

### Do:
- **Do** preserve the three-zone team / role / build layout.
- **Do** use explicit labels, borders, and symbols alongside state colors.
- **Do** teach from empty states, such as where a build or blessing will come from.
- **Do** keep core information visible without hover and preserve keyboard focus.

### Don't:
- **Don't** recreate generic mobile-RPG clutter with badges, bars, currencies, and repeated lock icons.
- **Don't** turn the interface into a blue SaaS dashboard that ignores the game's combat identity.
- **Don't** reuse official Rance 10 artwork, interface captures, text, or game rules.
- **Don't** let ornate framing or texture obscure controls, content, or retained scene art.
- **Don't** use tiny card grids or raw debug-text lists that force players to decode the build.
- **Don't** add star maps, cross-panel connector lines, or decorative motion for fixed talent choices.

## Story reading surfaces

Story preparation is titled “等一声回答”, with “第一章 · 恢复通讯” as the chapter label. Use the original night communications-camp image as the main field, with a short caption derived from existing quest/delivery/completion state. Keep the current-clue/NPC rail scrollable on the right and the three-stage route below the scene. Unknown stages stay unnamed; cleared stages offer practice replay. Only discovered objects expose record links; delivered objects become “已整理” and open intel. These links never change story progress.

The story palette is maintained in `scripts/ui/story/story_visuals.gd`: background `#101A13`, panel `#182B20`, warm text `#F3EAD0`, muted text `#C5B99B`, gold `#DFBD68` and line `#786138`. Scene art carries the atmosphere; leave room around the prose. Avoid repeating bordered cards for every paragraph or adding ambient motion that competes with reading.

Dialogue uses a full-screen image with a bottom reading band. `dialogue.location` supplies the small location label; `dialogue.scene` selects `radio` (full camp), `outpost` or `rift` (different crops of the same camp). These are visual motifs, not new playable locations. Display optional `node.narration` separately in muted text, followed by the speaker, spoken text and explicit choices. The current 29 nodes use 27–40-character lines and narration under 40 characters.

The reading band reuses the modal's focus/scroll behavior, while task/item/intel/history records keep the shared modal shell. `journal.open(profile, tab_name = "任务")` supports direct object-to-record links; history includes only seen narration and dialogue. Retain the existing team editor. Acceptance, delivery and postponement remain explicit; first confirmation reveals the line, and skip stops at a choice. Keep save errors visible at the unchanged node, restore opener focus on close and preserve the checkpoint on Esc. Use the reading font, optional 120% story text and instant reveal under reduced motion. Check 1280×720 and 960×540, including three choices and long labels.

The Narcissu reference informs this project's choice of quiet reading space; To the Moon informs gradual discovery through ordinary objects. These are design interpretations, not copied layouts or official mandates. No third-party text, art or music is reused. Source boundaries and verification are recorded in [the story presentation review](docs/design-reviews/2026-10-25_主线场景与叙事呈现.md).
