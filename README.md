# survivor-like

A Godot 4 2D survivor-like prototype focused on **three-character switching combat**.

当前核心体验：

- 走位普攻
- 切换角色入场
- 释放大招
- 通过构筑和演出拉开角色差异

## Current Status

这个项目已经具备可玩的主循环，当前已包含：

- 主菜单
- 存档位选择
- 主线准备界面
- 三角色切换战斗
- 普攻 / 进场技 / 退场技 / 大招
- 升级与 Build 菜单：主题式卡池、英雄特性训练、卡牌悬停详情
- 普通怪 / 精英 / Boss 基础框架
- HUD / 暂停菜单 / 主菜单设置 / 继续游戏 / BGM
- 开发者模式
- 本地成就系统与右上角成就提示
- 显示设置：窗口 / 全屏、16:9 固定比例窗口尺寸
- 通用 UI 组件：居中弹窗、卡牌列表、悬停详情、底部技能栏详情

## Core Roles

- `Swordsman`
  近身压制、斩击演出、生存收益

- `Gunner`
  远程 poke、弹幕覆盖、稳定点杀

- `Mage`
  范围轰炸、区域控制、AOE 压迫

## Controls

- `WASD`: 移动
- `Mouse`: 控制攻击方向
- `Q`: 切到上一位角色
- `E`: 切到下一位角色
- `R`: 释放大招
- `ESC`: 暂停菜单
- `TAB`: 切换攻击方式
- `C`: 角色面板

## Run

1. 用 Godot 4 打开项目目录
2. 运行主场景 `res://scenes/main_menu.tscn`

当前 `project.godot` 已将主运行场景设置为：

- `res://scenes/main_menu.tscn`

## Project Structure

- `assets/`
  背景图、音乐、角色测试贴图等

- `effects/`
  特效场景与特效贴图

- `scenes/`
  主场景、UI 场景、战斗单位场景

- `scripts/`
  核心逻辑脚本

- `shaders/`
  材质与 shader

- `docs/`
  项目说明文档

## Key Scripts

- `scripts/main.gd`
  战斗主控、刷怪、Boss、UI、继续游戏

- `scripts/player.gd`
  玩家战斗核心、三角色轮转、Build、英雄特性、特效、战斗状态

- `scripts/build/build_database.gd` / `scripts/build/build_system.gd`
  主题式 Build 卡池、卡牌详情、三英雄对应效果和主题解锁

- `scripts/enemy.gd`
  普通怪 / 精英 / Boss 行为

- `scripts/save_manager.gd`
  故事档、战斗存档、继续游戏

- `scripts/story_data.gd`
  主线关卡表、角色池、风格样式

- `scripts/ui/core/`、`scripts/ui/components/`、`scripts/ui/theme/`
  通用 UI 弹窗、卡牌列表、悬停详情和幸存者风格主题

## Documentation

完整文档入口：

- [docs/README_文档索引.md](docs/README_文档索引.md)

推荐优先阅读：

1. 项目定位与核心理念
2. 工程架构与代码入口
3. 战斗系统与角色机制
4. 构筑系统与文案交互规范
5. 当前实现状态与后续重点

## Checks

Run the local project health check with:

```bash
./scripts/check_project.sh
```

The script validates docs links, achievement data, key project settings, Godot script loading, a small achievement smoke test, and graphify update when available.

## Development Notes

当前项目仍处于持续迭代阶段。

现阶段优先级不是做最终成品包装，而是持续验证并打磨：

- 战斗节奏
- 角色差异
- 构筑深度
- 关卡与 Boss 压力
- 演出反馈

## Asset Notice

The current BGM files under `assets/` are non-commercial placeholder materials for development testing only. They are included so the project can run with the current audio setup, and will be replaced before any commercial release or public distribution build.

## Changelog

- [CHANGELOG.md](CHANGELOG.md)

## Project Governance

- 版本路线：见 [ROADMAP.md](ROADMAP.md)
- 已知问题：见 [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)
- 发布检查：见 [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)
- 第三方素材与插件：见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- 成就/Steam 适配：见 [docs/achievements/STEAM_ADAPTER.md](docs/achievements/STEAM_ADAPTER.md)
