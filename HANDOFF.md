# 交接说明（写给下一个对话）

2026-10-26：按用户确认的九组整理并提交现有主线、界面、战斗修复、配乐、性能、验证工具和音乐制作源档；本轮保持运行代码与资源内容，未推送或发布。后续修复从这批提交继续：已隔离复现“小Boss奖励读档后停在默认暂停页、未继续便再次退出，会把待恢复候选覆盖为空”的问题，位置在 `run_save_flow.gd` 的读档后写回与 `reward_flow.gd` 的奖励序列化；本轮按用户要求暂不修复。原有174/174检查所附1395项源码/资源摘要与整理前工作区一致；拆分提交另做阶段解析和相关专项检查。当前状态仍以状态文档和已知问题为入口，下列日期记录保留作来源。

2026-10-25：当前执行状态以[状态文档](docs/08_当前实现状态与后续重点.md)和[架构整改记录](docs/implementation/2026-10-25_架构健全性整改.md)为准。主线场景与14首原创配乐已接入；本轮架构整改、174/174项常规smoke、完整项目检查及隔离PCK验证已完成，无脚本错误或对象退出警告。相同载荷保存校验中位243.2→108.0ms，两后端各10次入退节点/资源稳定；高密度整帧仍超60FPS预算，详见性能证据，不得宣称整局达标。工作区包含多轮未提交改动，不得回滚，未提交/推送/发布。Graphify缺少GDScript提取器，残缺候选已回滚并保留旧图过期标记。使用根AGENTS规定的Linux Godot路径，下文Windows环境和旧任务仅作历史来源。

2026-10-23：当前接手入口为[状态文档](docs/08_当前实现状态与后续重点.md)和[系统框架实施记录](docs/implementation/2026-10-23_系统框架实施.md)。工作区已同步到 `9c1472e` 并进行了本轮实装，尚未提交或推送。下文是 `370c424` 时点的旧交接，保留作来源，**不作为当前任务队列或环境指令**；执行规则以根目录 `AGENTS.md` 为准。

## 0. 一句话现状

Godot 4.6.2 的幸存者-like 项目，仓库根就是工作目录。刚落地一套**技能等级系统**（已提交，是当前主线玩法）；工作区里另有一套由其他工具完成的**防御模型重构**（护甲 + 减伤率 + 闪避率），代码自洽、测试全绿，但**尚未提交、文档尚未同步**。下一个对话的第一优先级应该是：把防御模型重构验收、补文档、提交。

## 1. 最高优先级规则（先读这一节）

### 1.1 工作流硬性要求

改完代码必须依次执行（`AGENTS.md` 的强制要求）：

```powershell
# 1) headless 解析检查，必须 EXIT=0
& "C:\Users\Aron\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit

# 2) 重建知识图谱
graphify update .
```

> `AGENTS.md` 里写的是 Linux 路径 `/home/weathour/.local/bin/godot-4.6.2`，那是历史环境；**Windows 上必须用上面这条桌面路径**，Godot 不在 PATH 里。

改动涉及控制、设置、成就、存档、UI 模式、发布假设时，**必须同步** `docs/` 下相关文档与 `CHANGELOG.md`（新条目加在 `## Unreleased` 对应分区的最上面，中文条目为主，仓库历史提交也是中文消息）。

### 1.2 代码架构规则（不要破坏）

- `scripts/player.gd`、`scripts/main.gd` 只做**桥接**。新玩法写进 `scripts/player/*`、`scripts/game/*`、`scripts/ui/*`、`scripts/combat/*`。
- 技能脚本一律 `extends RefCounted` + `static func xxx(owner, ...)` 的 **flow 模式**（`scripts/abilities/*.gd` 是能力状态机，`scripts/player/player_*_flow.gd` 是纯逻辑）。
- **伤害只有一个出口**：`scripts/player/player_damage_resolver.gd` 的 `deal_damage_to_enemy` / `_damage_enemies_in_radius` / `_damage_enemies_in_line` / `_damage_enemies_in_oriented_rect*`。新增伤害来源前缀必须**同时**在 `player_damage_resolver.gd` 与 `player_damage_job_queue.gd` 注册白名单，否则伤害会被丢弃。
- **所有 “+X% 伤害” 类加成按线性/加算**结算（ratio 直接相加），不要写成乘法连乘。
- 全局设置（键位、技能自动释放状态、技能槽顺序、BGM）写 `user://settings.cfg`，**不进运行存档**；局内成长写运行存档。
- 玩家可见文本一律中文，**不要**把实现注释、括号说明写进卡面/技能描述。
- 角色基础数值集中在 `scripts/player/roles/role_database.gd`，不要在别处硬编码角色差异。

### 1.3 与用户协作的方式

- 所有思考过程、汇报用**中文**。
- 有歧义、需求不明确时**先问再动手**，不要猜着做。
- 改完要说明：改了哪些文件、怎么验证的、还剩什么没做。
- 用户会同时用别的工具改这个工作区（见第 6 节），**编辑前先重读文件**，不要相信记忆里的内容。

## 2. 当前主线：技能等级系统（已提交）

相关提交：`72457d0`（快捷键/阮石，前一阶段）、`9711c5c`（技能等级系统主体）、`e5a5753`（追加弹道可见性 + 审判之誓修复）、`fae8b1c`（追加弹道间隔）。

### 2.1 玩法规则

- 每条技能线 **1~10 级**，获得技能即为 1 级，满 10 级后不再出升级卡。
- 角色槽卡池 = 未解锁技能的**获得技能卡 60%** + 已解锁技能的**技能升级卡 40%**；某一类没候选时全部走另一类。通用祝福卡与「4 张选 2 张」规则不变。
- 升级池 = 角色特性、登场技、普通攻击 + 所有**已解锁**主动技能；**大招不参与**。
- 技能到 **5 级**弹出该技能的天赋位二选一（2 张卡、单选，走 `skill_talent_offer` 通道）；到 **10 级**自动补齐另一个天赋位。**两个天赋位目前是占位条目，没有任何战斗效果，等用户重新设计。**
- 玩家等级 3 倍数的“角色天赋”入口已**停用**：`pending_level_talent_choices` 不再累积，`player_skill_talent_system.gd` 的 `LEVEL_TALENT_DEFINITIONS`（70 条 / 35 互斥组）与全部 `has_level_talent()` 运行时读取代码**保留**，开发者面板仍可授予，等新触发入口设计。
- 旧的 63 项数值强化卡（属性卡）**不再发牌**，但定义、数值 getter、测试通路都还在。

### 2.2 关键文件

| 文件 | 职责 |
| --- | --- |
| `scripts/player/player_skill_level_system.gd` | 等级读写、上限、5/10 级天赋位、存档规范化。`ROLE_PROGRESS_ORDER` / `PROGRESS_TITLES` / `UNLOCKABLE_PROGRESS` 的唯一来源 |
| `scripts/player/player_skill_level_effect_flow.gd` | **所有“每级 +X”数值的唯一出口**，三角色全部 getter 与升级卡预览文案 |
| `scripts/player/player_build_system.gd` | 卡池：`_build_role_options` / `_pick_weighted_role_option`（60/40）/ `_make_skill_upgrade_option` / `_apply_skill_upgrade_option` |
| `scripts/player/player_skill_talent_system.gd` | 角色天赋定义与规范化分发层（入口停用中），并转发 `get_skill_progress_level` 到等级系统 |
| `scripts/game/reward_flow.gd` | 升级结算 → 祝福绑定 → 技能天赋位二选一的串行调度 |
| `scripts/level_up_ui.gd` | 升级卡 UI。技能天赋位复用 `show_options(options, [], context)`，context 里 `level_talent_offer=false` 时走单选分支 |
| `scripts/ui/hud/character_panel.gd` | 角色面板技能页：`技能 Lv.x / 10` + 天赋位状态 |

### 2.3 技能线清单（`ROLE_PROGRESS_ORDER`）

- 剑士 9 条：`swordsman_trait / entry / basic / blade_storm / crescent_wave / knight_thrust / king_blade / judgement_sword / ultimate`
- 枪手 **10** 条：`gunner_trait`（显示名「瞬杀」）`/ gunner_hunt`（显示名「猎杀」，为本次新拆出的独立线）`/ entry / basic / shrapnel / infinite_reload / explosive_round / magic_grenade / magic_eye / ultimate`
- 法师 9 条：`mage_trait / entry / basic / meta_field / surging_wave / flame_path / dark_contract / fireball / ultimate`
- 机械师 9 条：与之一一对应，**目前没有任何升级数值**（见第 7 节）

### 2.4 已经实现的追加弹道（表现层注意）

- 剑士普攻 2/4/6/8 级各追加一道 60% 伤害斩击，**依次发射、间隔 0.15s**（同帧同方向会完全重叠看不见）。
- 月牙剑气 2/4/6/8 级各追加一道 75% 伤害剑气，间隔 0.35s。
- 骑士突 3/6/9 级追加连击突刺（间隔 0.5s，60% 伤害，同一次技能共享命中登记，只有没被命中过的敌人才给临时血量）。
- 审判之誓 3/6/9 级追加冲击波，巨剑留场 = 冲击波道数 × 2s，视觉时长跟随留场时间。
- 枪手分裂弹 3/6/9 级各一枚（±20°/+40°）、散弹多圈、爆破弹 0.2s 连发、魔法榴弹多发、法师 2/4/6/8/10 级追加雷击。

## 3. 未提交的大改动：防御模型重构（重点）

**状态：代码已完成、`--headless --path . --quit` EXIT=0、相关 smoke 全绿，但未提交、文档未同步。**
涉及 46 个文件（33 个已跟踪文件 +307/−242，加上新文件）。

### 3.1 新模型

1. **护甲**：新增 `scripts/combat/armor_rules.gd`
   - `get_damage_multiplier(armor)`：`armor >= 0` 时 `100/(100+armor)`；`armor < 0` 时 `2 - 100/(100-armor)`（负护甲放大伤害）
   - 敌人在 `scripts/enemies/enemy_damage.gd` 的 `apply_damage` 里**先过护甲**，再过旧的 `damage_reduction_value` 与易伤。
2. **角色护甲**：`role_database.gd` 每个角色新增 `armor` —— 剑士 `10`、枪手 `-15`、法师 `0`、机械师 `0`；原 `base_damage_reduction_value`（剑士 20 / 枪手 −40）改为 `base_damage_reduction_rate = 0`。
3. **减伤改为乘算率**：`player_combat_modifiers.gd` 的 `get_role_damage_reduction_rate` 现在把各来源收集成 `rates` 数组后 `multiplier *= (1 - rate)`，来源包括：角色基础减伤率、祝福（`PLAYER_BLESSING_SYSTEM.get_damage_reduction_rates`）、装备、阮石、旧值兼容、低血装备。
4. **闪避改为概率**：取消“闪避值 → 概率”的曲线换算（`DODGE_VALUE_CURVE_SCALE` 等已删），直接用 `dodge_chance`。
5. **敌人**：`enemy.gd` 新增 `@export var armor`，`enemy_profile.gd`、`enemy_profile_applier.gd`、`enemy_save_data.gd`（存/读 `armor`）、`enemy_pool_lifecycle.gd`（复用时清零）全部同步。

### 3.2 数值改动清单（改数据看这里）

| 对象 | 改动 | 位置 |
| --- | --- | --- |
| 角色护甲 | 剑士 10 / 枪手 −15 / 法师 0 / 机械师 0 | `role_database.gd` `ROLE_DATA[].armor` |
| 祝福「不屈」 | 减伤值 10/18/26/34 → **减伤率 5%/10%/15%/20%** | `player_blessing_system.gd` `DEFINITIONS.unyielding` |
| 祝福「乘风」 | 闪避 +6/+12 → **闪避率 +12%/+24%** | 同上 `DEFINITIONS.tailwind` |
| 装备「大地之子」 | 38% 血 / 95 减伤值 → **50% 血 / 25% 减伤** | `player_equipment_flow.gd` `EQUIPMENT_DEFINITIONS` |
| 阮石「残破披风」 | 闪避值 +20 → **闪避率 +10%（每件独立相乘）** | `ruan_stone_system.gd` `get_effect_values`，读取在 `player_ruan_stone_stat_flow.gd` |
| 阮石「地上的树枝」「残破胸甲」 | 减伤值 +20 → **减伤 +7%** | 同上 |
| 梅塔领域 | 减伤/固定减伤值 → **护甲：基础 25 + 每级 2.5** | `mage_meta_field_ability.gd` `BASE_ARMOR_BONUS` + `player_skill_level_effect_flow.gd` `META_FIELD_ARMOR_PER_LEVEL` |
| 瞬杀每层 | 4 闪避值 → **1.5% 闪避率**；技能等级每级 +0.35% | `player.gd` `GUNNER_FLASH_DODGE_CHANCE_PER_STACK` + `FLASH_DODGE_CHANCE_PER_STACK_PER_LEVEL` |
| 存档兼容 | `equipment_low_health_damage_reduction_rate`（旧键 `_value` 仍读） | `player_run_save_state.gd` / `player_save_codec.gd` |
| 教程/卡面文案 | 闪避率、减伤率、护甲描述同步 | `movement_tutorial.gd`、`level_up_ui.gd` `TRAIT_*_DESCRIPTIONS`、`role_attribute_rules.gd` 描述 |

### 3.3 新测试（已全绿）

`scripts/tests/armor_rules_smoke.gd`、`dodge_probability_smoke.gd`、`role_base_defense_smoke.gd`、`ruan_cloak_dodge_smoke.gd`、`tailwind_dodge_smoke.gd`。

### 3.4 本次顺手修的过期断言

- `player_save_roundtrip_smoke.gd`：roundtrip 键名 `equipment_low_health_damage_reduction_value` → `..._rate`
- `player_blessing_system_smoke.gd`：乘风 III/IV 期望文案改成“角色闪避率+12％/+24％”

## 4. 想改什么数据，去哪个文件

| 想改 | 去哪 |
| --- | --- |
| 角色基础属性（血量/伤害/射程/移速/闪避/护甲） | `scripts/player/roles/role_database.gd` `ROLE_DATA` |
| 角色普攻行为 | `scripts/player/roles/<role>_role.gd` |
| 单个主动技能行为与基础倍率 | `scripts/abilities/<skill>_ability.gd`（常量 + `try_trigger`/`update`） |
| 技能线每级成长 | `scripts/player/player_skill_level_effect_flow.gd`（改常量即可，grep `_PER_LEVEL`） |
| 技能等级上限 / 天赋位触发等级 | `scripts/player/player_skill_level_system.gd`（`MAX_SKILL_LEVEL` / `TALENT_PICK_LEVEL` / `TALENT_AUTO_LEVEL`） |
| 升级卡出现概率 / 卡池构成 | `scripts/player/player_build_system.gd`（`UNLOCK_OPTION_WEIGHT` / `SKILL_UPGRADE_OPTION_WEIGHT` / `_build_role_options`） |
| 通用祝福数值与文案 | `scripts/player/player_blessing_system.gd` `DEFINITIONS` |
| 减伤/护甲/闪避结算 | `scripts/player/player_combat_modifiers.gd`、`scripts/combat/armor_rules.gd` |
| 装备（小 Boss 掉落） | `scripts/player/player_equipment_flow.gd` `EQUIPMENT_DEFINITIONS` |
| 阮石商店物品 | `scripts/player/ruan_stone_system.gd` `DEFINITIONS` + `get_effect_values`，UI 在 `scripts/camp/endless_camp.gd` |
| 敌人基础数值与护甲 | `enemies/` 下的资源（`EnemyProfile`）+ `scripts/enemy/enemy_profile.gd`；运行时字段在 `scripts/enemy.gd` |
| 无尽层数难度曲线 | `scripts/game/difficulty_profile.gd` |
| 存档字段 | 写：`scripts/player/player_run_save_state.gd` `get_save_data`；读：`apply_save_data` / `_apply_stat_save_data`；角色合并：`player_save_codec.gd` |

## 5. 怎么验证

```powershell
$godot = "C:\Users\Aron\Desktop\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"

# 解析检查（必须 EXIT=0）
& $godot --headless --path . --quit

# 跑单个 smoke（成功会打印 *_OK，失败一般 exit=1 并往 stderr 打 ERROR）
& $godot --headless --path . --script scripts/tests/<name>.gd
```

常用回归集（共 102 个 smoke）：

- 技能等级：`player_skill_level_system_smoke`、`skill_level_milestone_runtime_smoke`、`swordsman_skill_level_effect_smoke`、`gunner_skill_level_effect_smoke`、`mage_skill_level_effect_smoke`
- 防御模型：`armor_rules_smoke`、`dodge_probability_smoke`、`role_base_defense_smoke`、`ruan_cloak_dodge_smoke`、`tailwind_dodge_smoke`
- 存档：`player_save_roundtrip_smoke`、`ability_talent_snapshot_save_smoke`、`reward_flow_talent_smoke`
- UI/构筑：`player_blessing_system_smoke`、`character_panel_ui_smoke`、`level_up_scroll_reopen_smoke`、`combat_skill_bar_talent_projection_smoke`
- 阮石/营地：`ruan_stone_profile_smoke`、`ruan_stone_combat_smoke`、`ruan_stone_ui_smoke`、`endless_camp_smoke`、`developer_ruan_stone_smoke`

**测试挂住不动**通常意味着 `assert` 失败导致 `_init` 中断、SceneTree 空转。用下面方式抓 stderr：

```powershell
$p = Start-Process -FilePath $godot -ArgumentList "--headless","--path",".","--script","scripts/tests/<name>.gd" -NoNewWindow -PassThru -RedirectStandardOutput out.txt -RedirectStandardError err.txt
if (-not $p.WaitForExit(150000)) { $p.Kill(); "TIMEOUT" } else { Get-Content err.txt -Tail 10 }
```

## 6. 坑与注意事项

1. **工作区被并发编辑**：用户会用别的工具（另一个 agent / codex / 豆包）同时改同一份工作区。**每次编辑前重读文件**，`git status` 经常出现你没改过的文件；提交时先看清哪些是自己的改动。
2. **文件是 CRLF**，`git diff` 会提示 “CRLF will be replaced by LF”，属正常，不要批量转换编码。
3. 陷阱文件：根目录有个 0 字节杂散文件 `=ro`（历史误操作产物），可安全删除。
4. **`scripts/graphify-out/` 与根 `graphify-out/`**：后者是图谱产物，已在 `.gitignore`；不要当源码改。
5. 角色面板**不展示** `level_talents`（角色天赋账本），这是已知信息缺口。
6. 开发者面板可以授予等级天赋、清空天赋、改阮石等级/骨头，用来复现问题很方便（`scripts/developer/*`）。
7. 技能天赋位目前只写 `role_special_states[role_id].skill_talent_slots`，**没有任何运行时读取点**，所以“选了没效果”是预期，不是 bug。

## 7. 待办（按优先级）

1. **验收并提交防御模型重构**（第 3 节），同步 `docs/02`、`docs/03`、`docs/06`、`docs/08`、`CHANGELOG.md` —— 目前文档里还写着“减伤值/闪避值”旧模型。
2. **机械师的技能升级数值**：用户明确说“暂时没有”。现在机械师入队后会正常发升级卡（能升到 10 级、5 级也能选占位天赋位）但**没有任何数值收益**。数值到位后往 `player_skill_level_effect_flow.gd` 加一组 `get_mechanic_*` getter，并在对应 ability 接入。
3. **天赋位内容设计**：5/10 级天赋位目前是占位条目（`player_skill_level_system.gd` `_make_talent_option`），等用户给设计。
4. **角色天赋（`LEVEL_TALENT_DEFINITIONS`）的重新启用方式**：70 条定义与全部 `has_level_talent()` 消费代码都已实现，只缺触发入口。
5. 旧 63 项数值强化卡的最终去向（保留 / 迁移进技能等级 / 删除）。
