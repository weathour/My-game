# Project Agent Instructions

This Godot project uses the repository root as the working directory.

## Required checks before architecture/codebase answers

- Read `graphify-out/GRAPH_REPORT.md` when available.
- Prefer `docs/README_文档索引.md` as the documentation entry point.

## After modifying code

Run:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

Then run:

```bash
graphify update .
```

If graphify reports no Godot code files, check `docs/GRAPHIFY.md`; this project relies on local GDScript support for graphify.

## Documentation sync rule

When changing controls, settings, achievements, save data, UI modes, or release assumptions, update the relevant docs under `docs/` and `CHANGELOG.md`.

## Historical code boundary

`archive/legacy/` is a read-only catalog of superseded implementations referenced from Git history. It is not part of the current game and must not be used as evidence for current behavior.

When inspecting or changing the game, read the current working tree under `scripts/`, `scenes/`, `enemies/`, `effects/`, `assets/`, and the current design documents first. Exclude `archive/legacy/`, `docs/13_*`, and `docs/14_*` from ordinary searches. Only inspect those historical sources when the user explicitly asks for a historical comparison, restoration, or migration.

Do not copy a historical implementation back into the runtime tree without explicit user approval. The Git commit referenced by `archive/legacy/README.md` is the last committed baseline; uncommitted working-tree changes are current work and are intentionally excluded from the archive index.
