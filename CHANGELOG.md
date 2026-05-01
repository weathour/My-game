# Changelog

## Unreleased

### Added

- 主题式 Build 卡池：默认三相荡阵，并按配比解锁万向锋路、血盾回路、三相终式。
- 三英雄特性训练与“共同致富”：共同致富每次三名英雄特性各 +0.35，并让切换英雄冷却乘算 ×90%。
- Build 技能卡详情支持三英雄对应效果/数值展示，角色同卡不同名。
- 底部技能栏悬停详情：普攻折叠普攻/被动强化，大招能量球显示当前英雄大招与大招强化，独立冷却被动单独显示。
- 通用幸存者风格 UI 组件：`SurvivorsModal`、`SurvivorsCardList`、`SurvivorsHoverDetail`、`SurvivorsTheme`。
- UI/Build 交接 smoke：`scripts/tests/ui_build_handoff_smoke.gd`。
- 本地成就系统、成就定义表和右上角成就提示。
- Steam 成就适配文档与 adapter 草稿。
- 显示设置：窗口 / 全屏、预设窗口尺寸和 16:9 窗口比例校正。
- 项目治理文档：路线图、已知问题、发布检查、贡献说明、第三方素材说明。
- graphify Godot/GDScript 本地支持说明。
- 本地一键检查脚本、轻量项目校验和最小 GitHub Actions 工作流。

### Changed

- 升级界面改为“英雄特性训练 + Build 卡”双选择，卡片本体显示短摘要，悬停显示完整详情。
- 主菜单设置面板改为全屏 overlay + 居中 `SurvivorsModal`，修复点击设置后显示在角落的问题。
- 主菜单背景资源切换为 `assets/demo2.png`。
- 技能栏标题显示技能/普攻/大招名称，不再用冷却时间覆盖标题。
- 文档索引改为仓库相对路径。
- README 同步当前成就、显示设置和治理文档入口。


## v0.1.0 - Current Prototype Baseline

首个可公开整理的原型基线版本。

### Added

- 主菜单与设置入口
- 存档位选择
- 主线准备界面基础框架
- 三角色切换战斗
- 剑士 / 枪手 / 术师基础定位
- 升级与 Build 菜单
- 普通怪 / 精英 / Boss 基础框架
- HUD、暂停菜单、继续游戏、BGM
- 开发者模式
- 项目说明文档 `docs/`

### Improved

- 主菜单仓库展示说明
- GitHub 可读文档结构
- 项目整体设计与工程信息归档

### Notes

- 当前版本仍以“可玩、可测、可继续迭代”为目标
- 重点仍在角色差异、构筑深度、Boss 演出和关卡节奏
