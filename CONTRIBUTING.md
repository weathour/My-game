# Contributing

This project is currently a private/early prototype. Contributions should prioritize small, reviewable, reversible changes.

## Development baseline

- Engine: Godot `4.6.2`
- Main scene: `res://scenes/main_menu.tscn`
- Project file: `project.godot`

## Local checks

For code or runtime-resource changes, run the one-command project check before reporting completion or opening a pull request:

```bash
./scripts/check_project.sh
```

This runs Markdown links, achievement JSON, project config and architecture checks, Godot import and scene checks, all smoke tests except the separate dense-combat benchmark, and the existing Graphify index update when available. Pixel checks (`*_render_smoke.gd`) use OpenGL and require a display; other smoke tests run headless. On a Linux server, install Xvfb and Mesa and run `xvfb-run --auto-servernum ./scripts/check_project.sh`, as CI does.

Godot is required: a missing binary or an import-time script error fails the check. Each smoke has its own player-data/settings directory, so earlier tests cannot change later inputs. Set `PROJECT_CHECK_LOG_DIR` to retain logs at a chosen path. A smoke must exit successfully, print its success marker and contain no script/engine errors. Do not treat an `OK` line followed by errors as passing.

The graph update is navigation tooling, separate from the runtime gate. `scripts/tools/update_existing_graph.py` runs `graphify update .` only for an existing index, and rejects/rolls back candidates missing runtime GDScript coverage. `GRAPHIFY_UPDATE_REJECTED` means the retained graph is stale; consult current source and `docs/08_当前实现状态与后续重点.md`. Restoring Graphify's missing Godot extractor is separate tooling work.

For documentation-only changes, run `python3 scripts/tests/check_docs_links.py` and `git diff --check`, and review changed requirements against `docs/00_当前设计共识.md`. No engine run or graph rebuild is required for prose-only edits.

## Change rules

1. Follow the approved target in `docs/00_当前设计共识.md` and execution scope in `docs/08_当前实现状态与后续重点.md`. Old behavior is a baseline, not a requirement to preserve a superseded system. Change runtime behavior only within the task scope.
2. Update docs when changing player-facing systems, save data, settings, achievements, or controls.
3. Do not add new dependencies without a clear reason.
4. Keep generated/cache files out of commits unless the repository already tracks them intentionally.
5. After code changes, run at least:

```bash
godot --headless --path . --quit
```

Use the local binary when needed:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

## Commit style

Use intent-first commit messages. Include useful trailers where appropriate:

```text
Clarify why the change exists

Short context and tradeoffs.

Tested: Godot headless parse
Not-tested: Manual gameplay pass
```
