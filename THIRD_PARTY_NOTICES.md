# Third-Party Notices and Asset Status

This file tracks bundled assets/plugins and their release readiness.

## Godot MCP addon

- Path: `addons/godot_mcp/`
- Purpose: editor/MCP tooling for local development.
- Release note: verify whether this addon should be included in exported builds. If not needed at runtime, disable/remove it for release builds.

## Retained, unused placeholder audio

Current files:

- `assets/game_bgm.mp3`
- `assets/game_bgm.ogg`
- `assets/menu_bgm.mp3`
- `assets/menu_bgm.ogg`

Status: no longer referenced by runtime scenes; explicitly excluded by `export_presets.cfg`. The four audio files and their `.import` files have been removed from the Git index for the current source tree, while the local files remain. Their original public `origin/main` history is unchanged and still contains the audio; no history rewrite has been performed. Retained source files still have no added license evidence.

Do not redistribute these retained files, including in a public source archive, without replacement or explicit license evidence. The new music does not retroactively license them.

## Prototype images/sketches

Current paths include:

- `assets/demo2.png`
- `assets/sketch/`
- `effects/`
- `enemies/`

Status: prototype material in the source tree. Its source and usage rights still need review before production or commercial distribution.

## Mechanic artwork (2026-10-13)

- Runtime paths: `assets/players/mechanic/`, the two mechanic portraits in `assets/UI/facility/`, and the eight active sequences listed in `docs/07_资源_美术_特效规范.md` under `effects/mechanic/`.
- Source: newly generated with the built-in `image_gen` tool, then registered and exported through Aseprite. Original outputs, prompts and the reproducible import instructions are in `design/mechanic-rework-20261013/`.
- Character reference requested by the user: Maria Custard from Rance, using [AliceSoft's official Rance IX character page](https://www.alicesoft.com/rance9/character/outlaw.html). The official reference image itself is not bundled in the runtime assets; the generated design remains visibly reference-derived and is not recorded as an independently cleared character design.

## Ruan Dog pixel sprite

- Path: `assets/camp/ruan_dog_husky.png`
- Source: [Husky Sprites](https://opengameart.org/content/husky-sprites) by Hellkipz, based on work by Shepardskin.
- License: CC0 1.0 Universal.
- Usage: the original PNG is bundled unchanged; `scenes/endless_camp.tscn` selects one sitting-idle frame with `AtlasTexture` for the camp sprite and dialogue portrait.

## Shared UI tones and export boundary (2026-10-23)

- `scripts/ui/ui_audio.gd` generates short sine tones in code; it introduces no sampled third-party audio. These are development feedback cues, not finished combat sound design.
- `export_presets.cfg` excludes development tools, tests, archives, docs and design artifacts, and explicitly includes runtime story/achievement JSON.
- `SurvivorsUITheme` still uses system-font fallback. Verify Chinese text on each target OS; no new font redistribution license is implied.
- A successful local PCK export does not clear retained placeholder files, prototype images/effects or reference-derived character artwork listed above. Other asset-rights review/replacement remains necessary for public distribution.

## Story communications camp (2026-10-25)

- Runtime path: `assets/story/communications_camp.png`.
- Source: original scene generated with the built-in ImageGen tool for this project. Full prompt and generation provenance are retained in `design/story-20261025/README.md`.
- The story UI uses crops of this same image; no Narcissu or To the Moon screenshots, dialogue, character art or soundtrack were copied into the runtime.

## Original game score (2026-10-25)

- At that date, 14 Ogg Vorbis files in `assets/music/`, comprising 12 loops and 2 non-looping result cues, replaced the previous runtime BGM. These files and their sources are retained; the 2026-10-30 chronicle score below is a separate production.
- Composition: original note-level themes and arrangements written by the primary coding assistant for this project. Bach-style independent voices and Touhou-style melodic battle energy are references to methods; no songs, recordings or MIDI from those works were imported. No dialogue voice or voice clone was produced.
- Authoring: REAPER 7.83 Linux with its bundled Synthy McSynthface (MDA piano), Major General MIDI (Sonivox EAS), and Zita-Rev1-port reverb. The Sonivox engine/bank is identified as Apache-2.0 in the bundled source; the JSFX ports identify GPLv3+ licensing. The repository contains rendered performances, scores and project settings, not redistributed plugin implementations or sound banks.
- Provenance, software sources, license context, exact reproduction steps and limitations: [soundtrack production record](design/music-20261025/README.md). Full source scores, MIDI, REAPER projects, 24-bit FLAC masters and per-file hashes are retained there.
- REAPER was used under its official 60-day evaluation; continued DAW use beyond that period requires the appropriate license. The exported game does not depend on REAPER or its trial period.
- Technical audio checks do not establish human artistic approval or clear unrelated visual assets.

## Chronicle score (2026-10-30)

- Runtime: 70 Ogg Vorbis mixes in `assets/music/chronicle/`, catalogued by `assets/data/audio/music_catalog.json`: 38 main compositions, 8 alternate arrangements and 24 short cues. The full subjective listening review remains outstanding.
- Source: project-authored scores rendered from pinned CC0 multisample libraries, with a generated additive pad and room effect. Exact libraries, revisions, hashes, instrument names and local mapping corrections are listed in [the music notices](design/music-20261030/THIRD_PARTY_NOTICES.md) and [instrument manifest](design/music-20261030/instrument-manifest.json).
- Original sample downloads are cached outside the repository. Local frozen stems, MIDI, REAPER projects and FLAC masters are Git-ignored; score sources, manifest and production tools can regenerate them as described in [the production README](design/music-20261030/README.md).
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
