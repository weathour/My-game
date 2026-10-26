---
name: My Game
description: A tactical dark-gold build archive for a survivors-like game with three active roles from a four-role roster.
colors:
  archive-backdrop: "#000000B8"
  archive-bg: "#0B0D14FA"
  archive-bg-soft: "#131621F5"
  archive-card: "#1C202EFA"
  archive-card-alt: "#161A26FA"
  archive-border: "#5C6B94E6"
  archive-gold: "#FFC23D"
  text-primary: "#F2F7FFFF"
  text-muted: "#C7D4F0F0"
  text-gold: "#FFE070FF"
  state-good: "#6BFF94FF"
  state-danger: "#D62E2EF5"
typography:
  headline:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "28px"
    fontWeight: 600
    lineHeight: 1.2
  title:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "21px"
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Godot UI Default, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.3
rounded:
  compact: "8px"
  control: "10px"
  card: "12px"
  modal: "16px"
spacing:
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  xl: "16px"
components:
  archive-panel:
    backgroundColor: "{colors.archive-bg}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.modal}"
    padding: "{spacing.xl}"
  archive-card:
    backgroundColor: "{colors.archive-card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "{spacing.sm}"
  archive-tab-selected:
    backgroundColor: "{colors.archive-card-alt}"
    textColor: "{colors.text-gold}"
    rounded: "{rounded.control}"
    height: "42px"
---

# Design System: My Game

## Overview

**Creative North Star: "The Tactical Build Archive"**

The interface is a dependable combat tool presented as a dark-gold archive. Near-black navy surfaces keep dense build information calm; thin amber borders establish hierarchy; green is reserved for effects that are already active. Ornament supports the frame but never competes with the player's numbers, equipment, blessings, or skill build.

The system rejects generic mobile-RPG clutter, blue SaaS dashboards, fantasy parchment overload, and tiny card grids or raw debug-text lists. Standard tabs, lists, buttons, and scrolling should disappear into the task.

**Key Characteristics:**
- Three stable information zones: team, role record, build record.
- Compact, fixed typography with explicit empty and locked states.
- Selection is shown by border, surface, and text together.
- Supported desktop layouts start at 1280×720.

## Colors

The palette is restrained navy-black with a scarce amber-gold accent and semantic green/red states.

### Primary
- **Archive Gold** (`#FFC23D`): selected tabs, primary frame borders, and decisive values.
- **Text Gold** (`#FFE070`): section titles and selected labels.

### Secondary
- **State Good** (`#6BFF94`): an effect, role, upgrade, or talent that is currently active.
- **State Danger** (`#D62E2E`): unavailable or harmful states that require attention.

### Neutral
- **Archive Background** (`#0B0D14`): modal and deep workspace surfaces.
- **Archive Soft Background** (`#131621`): controls and secondary panels.
- **Archive Card** (`#1C202E`): list rows and information cards.
- **Archive Border** (`#5C6B94`): inactive boundaries and dividers.
- **Primary Text** (`#F2F7FF`): names and values.
- **Muted Text** (`#C7D4F0`): explanations, hints, and unavailable content.

**The Scarce Gold Rule.** Gold marks current selection, completion, or the screen's structural frame; it is not filler decoration.

## Typography

**Display Font:** Godot UI Default
**Body Font:** Noto Sans CJK SC, Microsoft YaHei, PingFang SC, then sans-serif in reading-heavy panels
**Label/Mono Font:** Godot UI Default

**Character:** One familiar sans-serif family carries the entire product surface. Hierarchy comes from size, weight, and spacing rather than decorative typefaces.

### Hierarchy
- **Headline** (600, 28px, 1.2): modal titles only.
- **Title** (600, 21px, 1.25): section headings.
- **Body** (400, 15px, 1.4): skill, blessing, stat, and equipment content.
- **Label** (400, 12px, 1.3): scope, shortcut, count, and secondary-state labels.

**The Baseline Rule.** Core build information must remain legible at 1280×720; do not solve density by shrinking body text below 12px.

## Elevation

Depth is structural: nested navy surfaces, thin borders, and modest dark shadows separate the archive, sections, and rows. Surfaces remain visually flat at rest; hover and focus may lighten the existing surface but do not float cards dramatically.

### Shadow Vocabulary
- **Card Separation** (5–8px dark shadow): dense archive cards and sections.
- **Modal Separation** (14px dark shadow): the outer character-panel frame only.

**The Layer-Only Rule.** Shadows clarify nesting; they never decorate ordinary text or inactive controls.

## Components

The shared modal shell and the character sheet have distinct existing variants. The colors and rounded corners above describe the shared shell; the Character Overview section defines the flatter, muted character-sheet variant. Reward cards keep their illustrated paper treatment. Reuse the corresponding component rather than mixing these values within one screen.

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
- **Shape:** restrained rounded rectangle (10–12px).
- **Primary:** archive-soft surface, gold border/text, at least 40px high.
- **Hover / Focus:** lighten the same surface; focus uses a visible gold outline.
- **Secondary:** navy card surface with neutral blue-gray border.

### Chips
- **Style:** compact inline tier tokens such as `I×3 · II×1`; separators keep the ledger scannable without adding another row of controls.
- **State:** owned blessing tiers are written explicitly; unavailable or locked information uses muted text plus an explicit label.

### Cards / Containers

- **Upgrade-card exception:** preserve the original four floating portrait paper cards, illustrated outlines, crystals, entrance animation and separate cyan refresh controls. Their face reads owner/type, name, level transition, primary benefit and secondary changes. Show details below the row; do not replace the cards with dashboard tiles.
- **Reading type for choices and hover details:** Noto Sans CJK SC, Microsoft YaHei, PingFang SC, then sans-serif through Godot `SystemFont`. Paper uses dark ink; dark hover panels always use the archive's light text. Skill titles and the primary benefit use a bold weight.
- **Choice state:** gold outline plus an explicit selected check, a visible selected/required count and one refresh count per card. The second selection still submits the original four-pick-two offer automatically.
- **Corner Style:** 12px for rows/cards; 16px for the main modal.
- **Background:** archive card over archive background.
- **Shadow Strategy:** structural only, following Elevation.
- **Border:** one pixel by default, two pixels for selected/current state.
- **Internal Padding:** 8–12px.

### Inputs / Fields
- **Style:** standard Godot controls on the archive-soft surface.
- **Focus:** visible gold border with no decorative animation.
- **Error / Disabled:** explicit text and muted/danger color; never color alone.

### Navigation

The character sheet has four top tabs: 总览 / 技能 / 祝福 / 装备. Its left team rail and right inspector stay fixed across tabs. Open on overview with attack selected; preserve stat selection on role changes. Click or keyboard focus selects list records. `Ctrl+Tab` cycles tabs, `Ctrl+Shift+Tab` reverses, and the configured character key or `Esc` closes the sheet. Preserve reward-menu pause context.

### Character Overview

Show all eleven primary stats at the 1280×720 logical baseline. Group output, survival, and mobility/cooldowns. Base attack speed belongs in the attack-speed detail; damage bonuses belong in attack sources. Do not duplicate already-applied multipliers. The inspector lists exact combat operands and explains conditional scope and nonlinear dodge/reduction. Keep pixel portraits compact, show shared run level, and distinguish viewed role from active role.

Character-sheet surfaces use `#111620` / `#181F2B`, sparse `#CBB581` gold, `#EDECE5` reading text, `#A5ADB9` secondary text and `#98C8B2` values. Use 16px body text, 25–26px titles and 30px selected values, with thin borders and 3–4px corners. The modal scales with the supported minimum window; it does not hide primary stats in a small scroll box.

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
- **Don't** add fantasy parchment overload, realistic book textures, or ornate metal framing.
- **Don't** use tiny card grids or raw debug-text lists that force players to decode the build.
- **Don't** add star maps, cross-panel connector lines, or decorative motion for fixed talent choices.

## Story reading surfaces

Story preparation is titled “等一声回答”, with “第一章 · 恢复通讯” as the chapter label. Use the original night communications-camp image as the main field, with a short caption derived from existing quest/delivery/completion state. Keep the current-clue/NPC rail scrollable on the right and the three-stage route below the scene. Unknown stages stay unnamed; cleared stages offer practice replay. Only discovered objects expose record links; delivered objects become “已整理” and open intel. These links never change story progress.

The story palette is maintained in `scripts/ui/story/story_visuals.gd`: background `#101923`, panel `#151f29`, warm text `#ece9de`, muted text `#b3bdc6`, gold `#d7bd86` and line `#3e4b56`. Scene art carries the atmosphere; leave room around the prose. Avoid repeating bordered cards for every paragraph or adding ambient motion that competes with reading.

Dialogue uses a full-screen image with a bottom reading band. `dialogue.location` supplies the small location label; `dialogue.scene` selects `radio` (full camp), `outpost` or `rift` (different crops of the same camp). These are visual motifs, not new playable locations. Display optional `node.narration` separately in muted text, followed by the speaker, spoken text and explicit choices. The current 29 nodes use 27–40-character lines and narration under 40 characters.

The reading band reuses the modal's focus/scroll behavior, while task/item/intel/history records keep the shared modal shell. `journal.open(profile, tab_name = "任务")` supports direct object-to-record links; history includes only seen narration and dialogue. Retain the existing team editor. Acceptance, delivery and postponement remain explicit; first confirmation reveals the line, and skip stops at a choice. Keep save errors visible at the unchanged node, restore opener focus on close and preserve the checkpoint on Esc. Use the reading font, optional 120% story text and instant reveal under reduced motion. Check 1280×720 and 960×540, including three choices and long labels.

The Narcissu reference informs this project's choice of quiet reading space; To the Moon informs gradual discovery through ordinary objects. These are design interpretations, not copied layouts or official mandates. No third-party text, art or music is reused. Source boundaries and verification are recorded in [the story presentation review](docs/design-reviews/2026-10-25_主线场景与叙事呈现.md).
