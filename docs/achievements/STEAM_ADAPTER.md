# 成就系统与 Steam 适配约定

本项目的成就系统以本地 `AchievementService` 为权威来源，Steam 只是后续发布渠道的同步层。

## 本地文件

- 成就定义：`res://data/achievements.json`
- 成就服务 Autoload：`res://scripts/achievements/achievement_service.gd`
- 战斗事件桥接：`res://scripts/game/game_achievement_bridge.gd`
- 本地存档：`user://achievements.json`
- Steam 适配草稿：`res://scripts/achievements/steam_achievement_adapter.gd`

## 稳定约定

1. `id` 使用 Steamworks Achievement API Name 风格，例如 `ACH_FIRST_BLOOD`。
2. `steam_api_name` 默认应与 `id` 一致；除非 Steam 后台已经发布了不同名字，否则不要改。
3. 战斗场景不要直接调用 `AchievementService`；新增战斗成就先接入 `game_achievement_bridge.gd`，由桥接层转发到本地服务。
4. Steam、Epic、GOG 等平台只通过 adapter 监听 `achievement_unlocked` 信号。
5. 进度成就在本地累计，达到目标时再解锁平台成就。
6. `game_achievement_bridge.gd` 必须保持平台中立，不允许出现 Steam/GodotSteam 调用。

## 添加新成就

在 `data/achievements.json` 增加：

```json
{
  "id": "ACH_EXAMPLE",
  "title": "示例成就",
  "description": "完成某个目标。",
  "hidden": false,
  "goal": 1,
  "steam_api_name": "ACH_EXAMPLE"
}
```

然后按触发来源选择接入方式：

- 战斗内事件：优先在 `scripts/game/game_achievement_bridge.gd` 增加一个语义化方法，再由 `main.gd` 或具体 flow 调用桥接层。
- 非战斗全局事件：可以在对应服务中调用 `AchievementService`，但仍不得直接调用 GodotSteam。

```gdscript
GAME_ACHIEVEMENT_BRIDGE.record_example(self, current_value)
```

如果确实是成就服务内部逻辑，可以使用：

```gdscript
AchievementService.unlock("ACH_EXAMPLE")
AchievementService.set_progress("ACH_EXAMPLE", current_value)
```

## 后续接 Steam

1. 安装 GodotSteam / GodotSteam GDExtension。
2. 在 Steamworks 后台创建同名 Achievement API Name。
3. 发布 Steamworks 改动。
4. 将 `steam_achievement_adapter.gd` 作为 Autoload 或游戏启动节点加载，且顺序在 `AchievementService` 之后。
5. Steam adapter 会监听本地解锁信号并调用：

```gdscript
Steam.setAchievement(steam_api_name)
Steam.storeStats()
```

注意：Steam adapter 使用 `get_node_or_null("/root/AchievementService")` 读取本地服务，避免在没有 Autoload 的 headless/测试场景里因为全局符号解析失败。

## 架构交接说明

- `main.gd` 现在只知道 `GAME_ACHIEVEMENT_BRIDGE`，不再直接知道成就服务细节。
- `AchievementService` 是本地权威状态源；它负责定义、进度、解锁、信号。
- `AchievementNotifier` 只负责本地 UI 提示。
- `steam_achievement_adapter.gd` 只负责平台同步，不参与本地解锁判定。
- `scripts/tests/check_architecture_contract.py` 会阻止 `main.gd` 重新直接调用 `AchievementService`，也会阻止桥接层混入平台代码。

## 当前内置成就

- `ACH_FIRST_BLOOD`：击败第一个敌人
- `ACH_FIRST_ELITE`：击败第一个精英敌人
- `ACH_FIRST_BOSS`：击败第一个 Boss
- `ACH_SURVIVE_5_MIN`：单局生存 5 分钟
- `ACH_REACH_LEVEL_5`：单局达到 5 级
- `ACH_ENDLESS_BOSS_3`：通关无尽难度 N3

## 游戏内显示效果

`AchievementNotifier` 作为 Autoload 监听 `AchievementService.achievement_unlocked`，在右上角显示小型成就达成弹窗。

- 本地弹窗不依赖 Steam。
- 后续 Steam overlay 由 `Steam.setAchievement()` / `Steam.storeStats()` 触发。
- 如果 Steam 版本不希望重复显示本地弹窗，可以在发布构建中关闭或条件化 `AchievementNotifier`。
