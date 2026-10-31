# Third-Party Notices and Asset Status

This file tracks bundled assets/plugins and their release readiness.

## Godot MCP addon

- Path: `addons/godot_mcp/`
- Purpose: editor/MCP tooling for local development.
- Release note: verify whether this addon should be included in exported builds. If not needed at runtime, disable/remove it for release builds.

## Asset review boundary

Current game art, effects and characters include prototype and reference-derived work. Source and usage rights must be reviewed for the actual assets and intended distribution; technical packaging or source cleanup does not establish rights clearance.

## Mechanic-derived style reference

The current Jia battle-art workflow retains a mechanical-character animation sheet solely as a pixel-style reference. It was generated with ImageGen using a character identity inspired by Maria Custard from Rance; the [reference and provenance](design/jia-combat-20261027/style-reference/README.md) preserve the source commit, original path, hash and prompt. This reference-derived status is not a clearance of character-design rights. Review any retained character visuals and intended distribution individually.

## Audio and export boundary

- Boss feedback includes synthesized cues from `scripts/ui/chronicle/boss_sound.gd`; the separate sampled combat cues are documented below.
- `export_presets.cfg` excludes development tools, tests, archives, docs and design artifacts, and explicitly includes runtime story/achievement JSON.
- `SurvivorsUITheme` still uses system-font fallback. Verify Chinese text on each target OS; no new font redistribution license is implied.
- A successful local PCK export does not clear prototype images/effects or reference-derived character artwork listed below. Other asset-rights review/replacement remains necessary for public distribution.

## Chronicle score (2026-10-30)

- Runtime: 70 Ogg Vorbis mixes in `assets/music/chronicle/`, catalogued by `assets/data/audio/music_catalog.json`: 38 main compositions, 8 alternate arrangements and 24 short cues. The full subjective listening review remains outstanding.
- Source: project-authored scores rendered from pinned CC0 multisample libraries, with a generated additive pad and room effect. Exact libraries, revisions, hashes, instrument names and local mapping corrections are listed in [the music notices](design/music-20261030/THIRD_PARTY_NOTICES.md) and [instrument manifest](design/music-20261030/instrument-manifest.json).
- Original sample downloads were cached outside the repository; cache completeness must be checked before rebuilding. The frozen stems, MIDI, REAPER projects and FLAC masters were Git-ignored local intermediates and are absent from the current project after the local archives were removed. The score sources, manifest and production tools remain; rebuilding audio requires the appropriate samples and tools, followed by actual verification as described in [the production README](design/music-20261030/README.md).
- REAPER 7.83 was used for isolated project verification under its existing evaluation or license status. The game and its exported validation PCK do not require REAPER. The PCK is a local engineering check, not a public release or clearance of other assets.

## Chronicle UI geographic data (2026-10-27)

`assets/data/chronicle/provinces.json` is converted from wonton1984/sanguo-map `data/donghan.js` under MIT; the original notice is retained in [sanguo-map-LICENSE.txt](assets/data/chronicle/sanguo-map-LICENSE.txt). Only the self-drawn province data was used, not its third-party portraits, modern basemap or novel text. `land.json` is Natural Earth 110m land, public domain. [Data provenance](assets/data/chronicle/README.md).

New map/portrait illustrations were generated with native image_gen; [manifest and prompts](design/ui-direction-20261027/manifest.json). Downloaded RTK/Rance screenshots under `design/**/reference/` are local research references, excluded from the current source tree and not used as runtime art; their source records and research documents are retained.

## Chronicle character-card atlases (2026-10-27)

- Runtime paths: `assets/ui/chronicle/cards/named-transparent.png`, `common-transparent.png` and `companions-transparent.png`; the original nontransparent atlases are retained alongside them. The three ImageGen-created atlases contain 26 portrait cells, mapped and reused for the 38-entry character directory; common troops also use color variants. Emma continues to use the existing `assets/ui/chronicle/emma.png`.
- Eight named Three Kingdoms cards use *The Ravages of Time* as a visual reference. These are provisional designs, not individually finalized reproductions, and their reference-derived status is not a clearance of character-design rights.
- [Generation manifest](design/ui-reflow-20261027/generated-manifest.json), [prompts](design/ui-reflow-20261027/prompts.json) and [reference sources](design/ui-reflow-20261027/reference/sources.json) record provenance. Two references are from the creator's official site; the Gao Shun reference is a secondary reproduction on Sina. The commercial reference images are research material and are not used as runtime textures. Review or replace reference-derived assets as appropriate before public or commercial distribution.

## Jia battle art (2026-10-27)

- Runtime path: `assets/players/jia/`. ImageGen source sheets use the user-approved [Jia standing art](design/jia-weisuo-20261027/jia-standing-v1.png) as the character identity reference; the previously generated mechanic animation sheet is a pixel-style and workflow reference only. See the mechanic notice above for its own reference history.
- The HUD portrait is generated separately and exported through Aseprite, rather than cropped from a character animation frame. Aseprite exports character and effect strips plus editable `.aseprite` files; source images, prompts, import command and the validation boundary are recorded in [Jia battle-art provenance](design/jia-combat-20261027/README.md).

## Chronicle combat audio and battlefield ground

- Combat feedback uses 22 short clips derived from CC0 sources. The source files, authors, links, license and processing are recorded in [the source manifest](assets/sfx/chronicle-feedback/source-license-manifest.json), with the applicable [CC0 text](assets/sfx/chronicle-feedback/CC0-LICENSE.txt). Their organizational labels do not establish subjective sound quality or clear unrelated assets.
- The six battlefield ground textures are original ImageGen outputs for this project; prompts and source hashes are recorded in [the ground manifest](assets/maps/baimen-feedback-20261030/generation.json).
- Current character and enemy production provenance is recorded alongside the relevant production sources, including [female character art](design/baimen-women-20261028/README.md), [enemy art](design/baimen-enemies-20261028/README.md) and [Boss forms](design/boss-forms-20261029/README.md). Generated or reference-derived work still needs review for the intended distribution context.
