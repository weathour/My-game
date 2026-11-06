# Contributing

Use Godot 4.6.2 and open `project.godot` at the repository root. The default scene is `scenes/chronicle/chronicle_shell.tscn`.

Read `docs/00_当前设计共识.md` for approved rules and `docs/08_当前实现状态与后续重点.md` for implemented scope. Preserve existing campaign saves and settings, and keep source and license records for runtime and production assets.

After code changes, run the headless Godot startup, relevant focused checks and `./scripts/check_project.sh`. Set `GODOT_BIN` when necessary. The complete check uses Python 3 with Pillow and needs either a graphical display or `xvfb-run` for its rendering tests. For documentation changes, run `python3 scripts/tests/check_docs_links.py` and `git diff --check`. Automated results do not substitute for playtesting or audio review.

Use reviewable changes and record meaningful checks and limitations. Do not create a Graphify index unless explicitly requested.
