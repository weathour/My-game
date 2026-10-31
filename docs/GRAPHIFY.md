# Graphify Workflow

Active graph location:

- `graphify-out/GRAPH_REPORT.md`
- `graphify-out/graph.json`

The graph is currently stale and does not describe the new design or cleaned documentation tree. Read [the design consensus](00_当前设计共识.md) and [current status](08_当前实现状态与后续重点.md) first. Documentation-only changes do not require a rebuild; do not recreate deleted specifications from graph nodes.

2026-10-30 latency and readability fix: the protected update again rejected its candidate because Godot extraction was unavailable and 211 runtime GDScript files lacked coverage; the prior graph remains STALE. See the [check log](../design/combat-feedback-20261030/latency-readability-fix/full-check-console.log) and [implementation record](implementation/2026-10-30_打击时序与首关可读性修正.md). The game checks passed independently.

2026-10-30 combat feedback and ground: the protected updater ran after the last runtime change, but Godot extraction remained unavailable and 211 runtime GDScript files lacked coverage. The candidate was rejected and the existing graph retained as STALE. See the [project-check log](../design/combat-feedback-20261030/runtime-evidence/full-check-console.log) and [implementation record](implementation/2026-10-30_战斗反馈与战场环境改进.md); this index limitation is separate from the passing game checks.

## Update command

After code changes, run:

```bash
graphify update .
```

This should rebuild the AST/code graph without API cost.

The project check now invokes that command through `python3 scripts/tools/update_existing_graph.py`. The wrapper backs up the existing graph/report/manifest, checks candidate coverage of current runtime `.gd` files, and restores the prior output with an explicit `STALE` marker when coverage is missing. Its rollback has a self-check in `scripts/tests/check_graph_update_self_test.py`. This prevents a successful Python-only update from silently replacing the retained game graph; it does not supply a missing Godot extractor.

## Godot/GDScript note

This project relies on local Godot support in Graphify (`.gd`, `.tscn`, `.tres`, `.godot`). The local extractor lets `graphify update .` classify and lightly extract GDScript/Godot text assets; package upgrades must preserve that support.

2026-10-23 verification: the installed 0.9.50 package does **not** classify `.gd` as code. The required update command completed, but the new `story_progress.gd` and `story_state.gd` both had zero nodes; only the Python content checker was added. That partial output was rejected. The prior JSON/report based on `91fd75c9` was retained, its HTML regenerated from that same JSON, and `.needs_update` plus the report header mark it stale. Use current source and the [implementation record](implementation/2026-10-23_系统框架实施.md) for this change. Restore the local Godot extractor before trusting the next update; no new index was created.

If a future reinstall or upgrade makes graphify print:

```text
No code files found - nothing to rebuild.
```

check whether `.gd` is present in `graphify.detect.CODE_EXTENSIONS` and whether `graphify.extract` has a GDScript extractor/dispatch. A successful update can still process only Python/shell files when Godot support is missing: also confirm that the changed `.gd` source files have nodes in `graphify-out/graph.json`. Do not use a successful CLI exit alone as evidence of GDScript coverage.

## Noise control

The project root maintains `.graphifyignore` to keep the graph focused on gameplay/runtime code:

- `.godot/`
- `graphify-out/`
- `addons/godot_mcp/`
- `archive/legacy/`
- Legacy `docs/13_*` and `docs/14_*` patterns may remain in the ignore configuration; those retired specifications have been deleted.

Without this ignore file, editor MCP tooling can dominate the graph with utility nodes such as `_success()`, `_error()`, and `_find_node_by_path()`, making architecture review less useful.

2026-10-25 verification: the required update was run again after the story presentation change. It still excludes `.gd`; `story_visuals.gd` and `dialogue_panel.gd` received zero nodes. The partial 5402-node output was rejected and the prior 5094-node graph/report/HTML restored, with a current stale marker. See the [story presentation review](design-reviews/2026-10-25_主线场景与叙事呈现.md) and [update log](design-reviews/evidence/2026-10-25/graphify-update.log).

2026-10-25 music integration verification: `graphify update .` was run after the original-score/runtime changes. The 5478-node candidate still omitted the new `music_catalog.gd` and `music_context_smoke.gd`; it was rejected and the prior 5094-node graph restored with a refreshed stale marker. Evidence: [update log](design-reviews/evidence/2026-10-25/music/graphify-update.log), [coverage and restore](design-reviews/evidence/2026-10-25/music/graphify-coverage.json). Do not treat this graph as verification of the new music runtime.

2026-10-27 UI framework: the protected updater invoked `graphify update .`; exit was 0 but the Godot extractor remained unavailable, with 149 runtime GDScript sources missing. The candidate was rejected and the original graph restored with a refreshed stale marker. [Update log](design-reviews/evidence/2026-10-27/chronicle/graphify-update.log).

2026-10-27 real combat: the protected updater again invoked `graphify update .`; exit was 0, but Godot extraction was unavailable and 166 runtime scripts lacked coverage. The candidate was rejected and the previous graph retained. New battle/campaign code must be read directly. [Update log](design-reviews/evidence/2026-10-27/combat/graphify-update.log).

2026-10-27 battle presentation reuse: protected update completed with exit 0, but GDScript extraction is still unavailable and 167 runtime scripts are uncovered. Incomplete candidate rejected; prior graph retained. [Reuse update log](design-reviews/evidence/2026-10-27/combat-reuse/graphify-update.log).

2026-10-29 White Gate enemies: the protected updater ran `graphify update .` and returned exit 0, but the Godot extractor was unavailable and 197 runtime GDScript files were missing. The 7847-node / 16783-edge candidate was rejected; the previous graph was restored and marked stale. This is a graph coverage limitation, not a game startup failure; no new index was created. [Update log](../design/baimen-enemies-20261028/final-evidence/logs/graphify-update.log).

2026-10-29 codex and map navigation: the protected updater ran `graphify update .` with exit 0, but the Godot extractor was unavailable and 197 runtime GDScript files were missing. The 7863-node / 16803-edge candidate was rejected; the prior graph was restored and remains stale. This is an index coverage limitation, not a failure of the verified game startup. [Update log](design-reviews/evidence/2026-10-29/ui-simplification/graphify-update.log).

2026-10-29 Rance-style main-screen rearrangement: the protected updater ran `graphify update .` with exit 0, but the Godot extractor remained unavailable and 199 runtime GDScript files were missing. The incomplete candidate was rejected and the prior graph retained as stale. This is an index coverage limitation; the required Godot startup succeeded. [Update log](design-reviews/evidence/2026-10-29/rance-main-ui/validation/graph-update.log).

2026-10-29 party formation and character inspection: the protected updater ran `graphify update .` with exit 0, but the Godot extractor remained unavailable and 202 runtime GDScript files were missing. The incomplete candidate was rejected; the previous graph was retained and marked stale. No new index was created. [Update log](design-reviews/evidence/2026-10-29/party-inspection/validation/graphify-update.log).

2026-10-29 Boss depth: the protected updater invoked `graphify update .` with exit 0; the Godot extractor remained unavailable and 206 runtime GDScript files were missing. The incomplete candidate with 8388 nodes and 17368 edges was rejected; the previous graph and report were restored and marked STALE. No new index was created. Use current source and [current status](08_当前实现状态与后续重点.md) for this work. [Update log](implementation/evidence/2026-10-29/boss-depth/integration/graphify-update.log).

2026-10-30 chronicle music: the protected updater ran the required update, but the candidate lacked coverage for 207 runtime GDScript files. It was rejected and the previous graph retained as STALE. Read the current source directly; this index limitation does not invalidate the separate Godot checks. [Update log](implementation/evidence/2026-10-30/music/runtime/graphify-update.log).

2026-10-30 White Gate story and journal: the protected updater completed successfully, but the Godot extractor remained unavailable and 209 runtime GDScript files lacked coverage. The incomplete candidate was rejected and the previous graph restored as STALE. This is an index coverage limitation, not a game-test failure; use current source and [current status](08_当前实现状态与后续重点.md). [Update log](story/baimen-20261030/runtime-evidence/graph-update.log).
