# Project Agent Instructions

This Godot project uses the repository root as the working directory.

## Required checks before architecture/codebase answers

- Read `graphify-out/GRAPH_REPORT.md` when available.
- Prefer `docs/README_文档索引.md` as the documentation entry point.
- Use `docs/00_当前设计共识.md` for the approved gameplay target and `docs/08_当前实现状态与后续重点.md` for execution status. Dated implementation/review records describe their recorded baseline, not current product requirements.

## After modifying code

Run:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

If this repository already has `graphify-out/graph.json`, update it:

```bash
graphify update .
```

Do not create a new index unless the user explicitly requests it.

If graphify reports no Godot code files, check `docs/GRAPHIFY.md`; this project relies on local GDScript support for graphify.

## Documentation sync rule

When changing controls, settings, achievements, save data, UI modes, or release assumptions, update the relevant docs under `docs/` and `CHANGELOG.md`.

## Character combat art

For new or reworked character combat art, follow [the production workflow](docs/art/角色战斗美术制作流程.md) for references, transparent assets, animation export, integration and review evidence.

## Historical code boundary

`archive/legacy/` is a read-only catalog of superseded implementations referenced from Git history. It is not part of the current game and must not be used as evidence for current behavior.

When inspecting or changing the game, read the current working tree under `scripts/`, `scenes/`, `enemies/`, `effects/`, `assets/`, and the current design documents first. Exclude `archive/legacy/` from ordinary searches. Superseded gameplay specifications have been removed from the current documentation tree. Only consult those historical specifications or the legacy code catalog when the user explicitly asks for a historical comparison, restoration, or migration.

Do not copy a historical implementation back into the runtime tree without explicit user approval. The Git commit referenced by `archive/legacy/README.md` is the last committed baseline; uncommitted working-tree changes are current work and are intentionally excluded from the archive index.
