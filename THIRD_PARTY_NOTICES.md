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

## Character skill presentation and battle models (2026-11-05)

- New battle-model material for 22 characters has been produced using existing project identity references, built-in ImageGen and Aseprite. Each has 16 independently drawn body poses and an independently drawn portrait; the two hit frames reuse other poses. Character-specific source images, prompts, reference roles, extraction records, editable files, measurements, hashes and checks are retained in the [production directory](design/skill-presentation-20261105/characters/), with a [generation and prompt index](design/skill-presentation-20261105/generation-manifest.json) and [model and capture manifest](design/skill-presentation-20261105/art-preview/manifest.json); exported assets are under `assets/players/chronicle-cast/`.
- Existing reference-derived character art and the mechanical-sheet style-reference boundary above continue to apply. This production record does not expand rights in those references.

## Zhang Liao collaboration presentation (2026-11-06)

- The new Zhang Liao, Gao Shun and Chen Gong presentation frames and effects use built-in ImageGen and Aseprite with existing project character references. Source sheets, exact prompts, references and hashes are retained in the [production record](design/zhang-liao-summons-20261106/README.md).
- Official *Dynasty Warriors: Origins* and *Wo Long: Fallen Dynasty* imagery was consulted only for visual study and is not used as an identity-generation reference or runtime texture. Existing reference-derived asset boundaries remain in effect.

## Audio and export boundary

- Boss feedback includes synthesized cues from `scripts/ui/chronicle/boss_sound.gd`; the separate sampled combat cues are documented below.
- `export_presets.cfg` excludes development tools, tests, archives, docs and design artifacts, and explicitly includes runtime story/achievement JSON.
- `SurvivorsUITheme` still uses system-font fallback. Verify Chinese text on each target OS; no new font redistribution license is implied.
- A successful local PCK export does not clear prototype images/effects or reference-derived character artwork listed below. Other asset-rights review/replacement remains necessary for public distribution.

## Standalone MIDI rhythm tester (2026-11-04)

The independent Python Qt tester lives under `tools/rhythm_tester/`; `tools/*` is excluded from game exports. Its local environment uses the following components:

- [PySide6 and shiboken6 6.10.2](https://doc.qt.io/qtforpython-6/) package metadata states `LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only`; Qt component terms and notices are available from [Qt licensing](https://doc.qt.io/qt-6/licensing.html).
- [mido 1.3.3](https://github.com/mido/mido/blob/main/LICENSE) uses the MIT license. [NumPy 2.2.6](https://github.com/numpy/numpy/blob/main/LICENSE.txt) uses BSD 3-Clause; the installed wheel's `numpy-2.2.6.dist-info/LICENSE.txt` also records its bundled components and their terms.
- [packaging 25.0](https://github.com/pypa/packaging/blob/25.0/LICENSE) is available under either Apache 2.0 or BSD 2-Clause. System [FFmpeg](https://ffmpeg.org/legal.html) is invoked for decoding and is not bundled with the game.
- The locally unpacked Ubuntu `libxcb-cursor0` retains its [copyright and MIT/X license](tools/rhythm_tester/licenses/libxcb-cursor0-copyright.txt); the launcher adds its library path only for this tool.

## Chinese-instrument D2 game music (2026-11-04)

- The twelve D2 game tracks were exported from the delivered D2 mixes. Their Chinese-instrument sounds use **DSK Asian DreamZ** by DSK Music / Victor Castilla; the publisher describes the instrument as free for private and commercial use. The raw SF2 and exported raw samples remain in local cache and are not packaged with the game; the runtime uses rendered audio only. This is not a CC0 designation or a claim of permission to redistribute the original samples. See the [D2 source notices](design/music-20261104-chinese-12/THIRD_PARTY_NOTICES.md) for source details and the other instruments.
- These tracks derive from automatically transcribed third-party instrumental covers, not project-original compositions or original multitrack recordings. Instrument-sample terms are distinct from rights in the underlying musical works and source accompaniments; this integration does not expand the existing rights boundary.

## Frozen-MIDI game music test (2026-11-03)

- The twelve test tracks are rendered from MIDI automatically transcribed from third-party instrumental covers, rather than project-original compositions. Input paths and hashes are in [the experiment manifest](design/music-20261103-midi-test/experiment-manifest.json); source-music rights are distinct from the instrument-sample licenses below.
- The drum kit is **MuldjordKit** by Lars Muldjord, with the FreePats stereo SF2 version assembled by Roberto (version 2020-10-18), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). [Original source](https://freepats.zenvoid.org/Percussion/acoustic-drum-kit.html), [license text](design/music-20261103-midi-test/sources/muldjordkit/LICENSE.txt) and [upstream README](design/music-20261103-midi-test/sources/muldjordkit/README.txt). This project maps input GM drum roles to kit keys and processes the rendered sound; this attribution does not imply endorsement.
- The rendered guitar and bass use Karoryfer Emilyguitar and Fashionbass samples under CC0; auxiliary piano uses VSCO 2 CE samples under CC0. GeneralUser GS 2.0.3 by S. Christian Collins supplies the GM 54 tambourine absent from MuldjordKit in “Disposable Teens”; its [license](design/music-20261103-midi-test/sources/generaluser/GeneralUser-GS-LICENSE.txt) includes upstream remarks on historical sample provenance. Detailed revisions, hashes, processing and license links are in [the music notices](design/music-20261103-midi-test/THIRD_PARTY_NOTICES.md) and [instrument sources](design/music-20261103-midi-test/sources/instrument-sources.json).

## Chronicle score (2026-10-30)

- The 2026-10-30 runtime baseline comprised 70 Ogg Vorbis mixes: 38 main compositions, 8 alternate arrangements and 24 short cues. In the 2026-11-03 music replacement, 66 retired mixes have been removed and four warm/rest cues remain in `assets/music/chronicle/`. The local test package includes the applicable notices and license texts. The full subjective listening review remains outstanding.
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
- The 2026-11-03 skill-audio production generated 303 WAV variants from selected CC0 source sounds by **rubberduck**, combined with project processing and synthesized layers. The selected sources come from [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx), [40 CC0 water/splash/slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) and [100 CC0 SFX](https://opengameart.org/node/85570). Original listings, pinned mirror revision, selected-file hashes and retained CC0 texts are recorded in the [source-lock directory](design/skill-audio-20261103/audio/sources/). The Sonniss bundle researched during planning was not used.
- The six battlefield ground textures are original ImageGen outputs for this project; prompts and source hashes are recorded in [the ground manifest](assets/maps/baimen-feedback-20261030/generation.json).
- Current character and enemy production provenance is recorded alongside the relevant production sources, including [female character art](design/baimen-women-20261028/README.md), [enemy art](design/baimen-enemies-20261028/README.md) and [Boss forms](design/boss-forms-20261029/README.md). Generated or reference-derived work still needs review for the intended distribution context.
