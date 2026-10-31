# Project Agent Instructions

This Godot project uses the repository root as the working directory.

## Current project

- Read `docs/README_文档索引.md` first; `docs/00_当前设计共识.md` owns approved gameplay rules and `docs/08_当前实现状态与后续重点.md` owns implementation status.
- Current source, data and tests are the authority for runtime behavior. Dated production records describe their own baseline, not an automatic task queue.
- Keep current campaign saves and settings compatible. Never delete player data as part of repository cleanup.
- Preserve licenses, third-party attribution and production inputs required by this game. Reusable visuals are not a reason to reinstate retired gameplay.

## After code changes

Run the Godot 4.6.2 headless startup using the configured binary, then the checks appropriate to the affected behavior and `scripts/check_project.sh` when completing an implementation. Do not create a Graphify index unless the user explicitly requests one; if an existing project-local index is present, follow the repository's current update instructions.

## Documentation and art

- Update relevant `docs/` and `CHANGELOG.md` when controls, settings, save data, UI modes or release assumptions change.
- For new or reworked character combat art, follow [the production workflow](docs/art/角色战斗美术制作流程.md).
