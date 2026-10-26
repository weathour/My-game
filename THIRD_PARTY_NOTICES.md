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

Status: no longer referenced by runtime scenes; explicitly excluded by `export_presets.cfg`. Retained source files still have no added license evidence.

Do not redistribute these retained files, including in a public source archive, without replacement or explicit license evidence. The new music does not retroactively license them.

## Prototype images/sketches

Current paths include:

- `assets/demo2.png`
- `assets/sketch/`
- `effects/`
- `enemies/`

Status: prototype material. Verify source and usage rights before public/commercial distribution.

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

- Runtime: 14 Ogg Vorbis files in `assets/music/`; 12 loops and 2 non-looping result cues. This replaces the previous runtime BGM.
- Composition: original note-level themes and arrangements written by the primary coding assistant for this project. Bach-style independent voices and Touhou-style melodic battle energy are references to methods; no songs, recordings or MIDI from those works were imported. No dialogue voice or voice clone was produced.
- Authoring: REAPER 7.83 Linux with its bundled Synthy McSynthface (MDA piano), Major General MIDI (Sonivox EAS), and Zita-Rev1-port reverb. The Sonivox engine/bank is identified as Apache-2.0 in the bundled source; the JSFX ports identify GPLv3+ licensing. The repository contains rendered performances, scores and project settings, not redistributed plugin implementations or sound banks.
- Provenance, software sources, license context, exact reproduction steps and limitations: [soundtrack production record](design/music-20261025/README.md). Full source scores, MIDI, REAPER projects, 24-bit FLAC masters and per-file hashes are retained there.
- REAPER was used under its official 60-day evaluation; continued DAW use beyond that period requires the appropriate license. The exported game does not depend on REAPER or its trial period.
- Technical audio checks do not establish human artistic approval or clear unrelated visual assets.
