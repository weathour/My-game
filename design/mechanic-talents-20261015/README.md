# 机械师专属天赋的界面验证

2026-10-15，`91fd75c` 加当前工作区；Godot 4.6.2、OpenGL Compatibility、NVIDIA RTX 5080。截图来自实际运行的 UI，不是设计稿。

- [重型炮台的两张天赋卡与高爆详情](cannon-talents.png)：1280×720，真实名称、两行核心效果、满级补齐说明。
- [磁滞力场的小窗口天赋卡](field-talents-960.png)：960×540，强磁共振/随行维保，两张卡和完整详情均能显示。
- [人物页的天赋详情](owned-talent-details.png)：1280×720，已生效的双联供弹、待获得的超频枪架与独立作用域。

运行 `scripts/tests/skill_info_ui_smoke.gd -- --screenshots=<输出目录>` 和 `scripts/tests/character_panel_ui_smoke.gd -- --capture=<输出目录>` 可重建全部截图；使用实际显示器和 `--rendering-method gl_compatibility --audio-driver Dummy`，隔离 `XDG_DATA_HOME` 以保护个人存档。

本目录保留2026-10-15的旧技能天赋素材与截图。对应玩法规格已随新设计撤下，原评审可从Git历史查阅；新目标见[当前设计共识](../../docs/00_当前设计共识.md)，旧运行差距见[运行基线](../../docs/implementation/2026-10-26_重构前运行基线.md)。以下验证指当时版本：完整 `scripts/check_project.sh` 已通过 141 项独立 smoke、3 个场景、4 项 Python 检查，零脚本错误与泄漏报告。截图不能代替整局体验或长期压力证据。
