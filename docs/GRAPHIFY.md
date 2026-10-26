# Graphify Workflow

Active graph location:

- `graphify-out/GRAPH_REPORT.md`
- `graphify-out/graph.json`

Legacy documentation-only snapshot:

- `docs/graphify/` was an older graph generated from design docs only. Do not treat it as the active code graph.

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
- `docs/13_*` and `docs/14_*` (retired design specifications)

Without this ignore file, editor MCP tooling can dominate the graph with utility nodes such as `_success()`, `_error()`, and `_find_node_by_path()`, making architecture review less useful.

2026-10-25 verification: the required update was run again after the story presentation change. It still excludes `.gd`; `story_visuals.gd` and `dialogue_panel.gd` received zero nodes. The partial 5402-node output was rejected and the prior 5094-node graph/report/HTML restored, with a current stale marker. See the [story presentation review](design-reviews/2026-10-25_主线场景与叙事呈现.md) and [update log](design-reviews/evidence/2026-10-25/graphify-update.log).

2026-10-25 music integration verification: `graphify update .` was run after the original-score/runtime changes. The 5478-node candidate still omitted the new `music_catalog.gd` and `music_context_smoke.gd`; it was rejected and the prior 5094-node graph restored with a refreshed stale marker. Evidence: [update log](design-reviews/evidence/2026-10-25/music/graphify-update.log), [coverage and restore](design-reviews/evidence/2026-10-25/music/graphify-coverage.json). Do not treat this graph as verification of the new music runtime.
