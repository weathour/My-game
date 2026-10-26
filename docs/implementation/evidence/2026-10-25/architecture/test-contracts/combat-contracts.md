# 战斗与成长测试合同整理 · 2026-10-25

本文件恢复原先由战斗/成长测试执行者写入README的15项合同对账与6项替代检查映射；共享README随后由主代理维护为总入口。本轮仅修改这15项测试，没有修改运行时数值、技能、保存业务或恢复旧玩法。依据当前`docs/08_当前实现状态与后续重点.md`、实际运行源码和现行专用build smoke；没有使用`archive/legacy/`或历史13/14文档作为当前行为依据。

## 当前边界

- 普通技能保持既有1—10级与5/10天赋位；已改为专用构筑的普攻、剑刃风暴、无限装填和波涛汹涌使用LV0—9、LV4/8/9分支。
- `player_skill_talent_system.has_talent()`正式返回false，旧108节点不再由普通玩家获得或启用。测试不得通过自定义`_has_skill_talent() = true`把停用路径伪装成现行玩法。本轮旧输入放入真实`role_special_states[role].skill_talents`字段，fixture调用生产查询，验证其不产生效果。
- `level_talents`是另一条已有保存/读取兼容链，和旧108个`skill_talents`不同。当前仍被运行时读取的已保存角色天赋断言保留；本轮没有恢复普通玩家授予入口。
- 专用build fixture显式带对应构筑key，避免遗漏key后被当成旧LV1存档并减一级。迁移本身仍由专用build检查验证。

## 逐项旧失败与处理

| 旧失败测试（`scripts/tests/`） | 当前合同与依据 | 本轮变更和保留保护 |
| --- | --- | --- |
| `gunner_basic_level_talents_smoke.gd` | `enemy_damage.gd`当前直接读取感电、风暴削甲等正式敌人状态；原精简BasicEnemy缺字段，不是伤害规则失败 | 改用真实`scenes/enemy.tscn`并关闭自动处理，固定护甲/减伤。保留已保存普攻角色天赋的子弹配置、三分裂、原目标去重及削甲先后顺序。 |
| `gunner_infinite_reload_manual_smoke.gd` | `player_gunner_infinite_reload_build.gd`及当前ability：火力调控来自LV9分支，最少开启1秒、无关闭冷却，不锁移动/其他技能；轻盈步伐提供30个百分点闪避。旧测试仍要求1.5秒、0.5秒关闭冷却和旧双束天赋 | 使用真实player及测量子类，只替换最终形状伤害/画面输出；经正式slot dispatch验证开关优先于全局自动设置、槽位隔离、1秒边界、聚能延后、单轨、600射程、闪避归属和立即重开。设置保留/恢复；双轨/瞄准/灵魂伤害由专用build测试覆盖。 |
| `gunner_skill_level_effect_smoke.gd` | 普攻和装填的现行专用build取代旧线性射程/弹速/里程碑分裂；`player_skill_level_effect_flow.gd`对应getter已转发或清零 | fixture显式LV0标记；验证旧分裂里程碑不重复添加、普攻LV6射程+75、装填LV3伤害+15个百分点、light_step射程+100/移速+10%，更新升级预览。保留瞬杀、猎杀、登场、散弹、爆破弹、榴弹、魔眼及升级卡检查。 |
| `gunner_skill_talents_smoke.gd` | 旧108节点停用；重做装填不再存在旧beam damage/queue、hit_during_cast和last_tick_data接口 | 旧节点存入正式字段后，生产查询下不改变普攻配置、散弹冷却/减速、登场冷却或执行层数；装填保持4秒/36秒。保留散弹目标空间分离、已保存角色天赋压缩节奏、枪手大招方向/伤害和登场天赋。已删除beam时序/快照实现由`gunner_infinite_reload_build_smoke.gd`的当前实现检查替代。 |
| `mage_arcane_charge_level_talents_smoke.gd` | `mage_tidal_surge_ability.gd:BASE_COOLDOWN`当前为26秒，原测试写死20秒 | 将冷却组合断言更新为26×0.96，仍独立验证4层1%缩减、充能概率、转移及大招伤害乘区，没有更改运行时冷却。 |
| `mage_basic_level_talents_smoke.gd` | `player_mage_basic_build.gd`现行LV0雷击倍率为200%，原测试按100% | 只更新两道雷的完整倍率预期为200%；保留已保存角色天赋的二次雷击调度、密集中心选择、击杀回能、冷却减少及来源隔离。 |
| `mage_skill_level_effect_smoke.gd` | 法师普攻/波涛汹涌已为LV0专用build；旧普攻自动多雷与旧波涛线性getter不再代表实际ability输出 | fixture显式构筑key；验证普攻LV5总倍率270%、无focus时范围不额外扩大、旧多雷里程碑为0，波涛LV4实际ability倍率390%/持续4秒及现行分支预览。保留领域护甲、充能、盈余、火球、契约、火焰之径和卡片检查。 |
| `mage_stage_two_three_talents_smoke.gd` | 旧trait/meta/ultimate节点停用；波涛当前分支通过`player_mage_surging_wave_talent_flow.gd`映射到施法快照。旧ProjectileStub已经不满足实际wave字段 | 移除依赖旧假授予和过期弹道stub的正向断言，改验原始旧输入不扩展转移/领域、不捕获旧大招节点。保留并加强现行波涛合同：只捕获已选flood/water_path/tidal，构筑随后变更不影响飞行中快照。未把这些检查宣称为波涛所有路径特效的完整验收。 |
| `mage_talent_smoke.gd` | 当前数量加成2产生3方向；旧`mage_surge_four`不再生成6方向；tidal现行为3道、相邻40° | 使用真实旧输入查询；保留几何helper检查，验证数量/低倍率连击方向隔离和当前tidal分支扇面，取消旧六方向预期。 |
| `skill_level_milestone_runtime_smoke.gd` | 剑士共享矩形damage query已有slow-source与knockback参数；当前命中框向近身延伸，和画面中心不同 | 更新fixture签名；仍验证LV6才安排额外斩击、延后0.25秒、当前角色位置跟随、每里程碑恰好一次。固定fixture下命中框中心为玩家右侧40，覆盖视觉/近身间隙，而非旧的右侧60。 |
| `swordsman_advanced_talents_smoke.gd` | 旧trait/crescent/ultimate节点正式不生效；旧storm recall私有方法已被新build替代 | 原始旧输入不激活治疗后buff、双月或大招快照；旧recall不授予新分支。保留普通攻击和连击均受随身风暴锁的两入口检查；旧recall正向移动由当前`blade_storm_build_smoke.gd`的台风/龙卷实际行为替代，不恢复旧方法。 |
| `swordsman_basic_attack_event_smoke.gd` | 当前query追加可选参数；旧back/cross不能授予多次攻击；既有已保存blood_surge计时状态仍按命中消费 | 更新签名，旧输入走生产查询后只出一刀；保留命中消费/挥空保留计时状态并新增每次攻击唯一`swordsman_basic:`事件身份，不把计时兼容断言当作恢复旧节点授予。 |
| `swordsman_skill_talents_smoke.gd` | 旧full_moon/return/stationary/last_guard不生效；当前月牙基础速度650，保留build_levels速度+30；新storm无`_get_storm_centers` | 验旧输入不替换基础速度、不使过期弹道返程、不选择新风暴分支、不触发强制救援/耗能。保留月牙弹道过期与旧build_levels兼容，清理测试自己的弹道池防泄漏；当前storm与普攻分支效果由专用build测试覆盖。 |
| `swordsman_trait_runtime_flow_smoke.gd` | 原角色天赋读取仍保留，但重做风暴不提供旧size helper，旧风暴II不能越过随身风暴普攻锁；当前普攻LV0倍率100% | 更新query签名，检查风暴基准半径150及随身期间禁普攻；普攻角色天赋的双刀/延后伤害以100/60计算。保留骑士荣耀、嗜血、冲锋、状态驱散、持续时间、救助治疗及月牙角色天赋。 |
| `player_skill_level_system_smoke.gd` | 无限装填解锁LV0，购买4级到LV4，选择结果存在`infinite_reload_build`；不使用普通技能5/10占位槽 | 更新解锁、normalize和分支保留断言，明确不授予generic slots；保留查询只读/不反射、锁技能门禁、升级池、大招排除、上限、陈旧选择拒绝、普通技能双槽及权重抽样。 |

## 替代覆盖实跑

本轮额外运行下列现有专用测试，均未修改其文件：

| 专用测试 | 替代/补充内容 |
| --- | --- |
| `gunner_basic_build_smoke.gd` | LV0—9升级与分支、真实连射、三分裂/原目标去重、弹速射程、其他终极分支与保存规范化 |
| `gunner_infinite_reload_build_smoke.gd` | 4秒/36秒与帧率无关跳数、LV4/8/9、双轨独立伤害、转向限速、灵魂伤害/保护、当前beam快照JSON往返 |
| `mage_basic_build_smoke.gd` | 普攻当前分支、攻速/能量组合、真实感电叠加和下一击引爆、眩晕及保存 |
| `mage_surging_wave_level_talents_smoke.gd` | 波涛LV0起点、LV4/8/9选择与LV9当前伤害倍率；不宣称覆盖全部路径效果 |
| `swordsman_basic_build_smoke.gd` | 现行重/轻剑、分裂/地裂、守势/勇猛及实际伤害、弹道和规范化 |
| `blade_storm_build_smoke.gd` | 现行风暴升级、移动龙卷、属性/风息继承、削甲与保存恢复 |

## 验证结果

[results.json](results.json)记录最终统一批次：15项所有权测试和6项替代测试共21/21通过。每项都要求退出码0、出现`_SMOKE_OK`，且没有`SCRIPT ERROR:`或`ERROR:`；不能只凭退出码判断。原`mage_stage_two_three_talents`和`swordsman_advanced_talents`曾在退出0时仍打印运行错误，这也是本轮要消除的假通过。

- `*.baseline.log`：运行时其他owner的临时编译状态恢复后、测试未修改时的旧失败证据。timeout表示断言或脚本错误使SceneTree未走到quit，不是性能基准。
- 对应21项`*.log`：最终当前合同测试输出，和`results.json`一一对应。目录还可包含其他执行者的日志，不在此21项结果内。
- 每项使用独立`XDG_DATA_HOME=/tmp/my-game-contracts-final-<test>`。Godot路径为`/home/weathour/.local/bin/godot-4.6.2`，命令为`--headless --path . --script scripts/tests/<test>_smoke.gd`。
- [project-startup.log](project-startup.log)：本轮15项测试修改后的Godot `--headless --path . --quit`检查，退出0。
- 未修改的`mage_surging_wave_level_talents_smoke.gd`仍有ObjectDB退出泄漏WARNING；它没有SCRIPT ERROR/ERROR，本轮未扩大修改其清理逻辑。
- 本轮未执行全仓gate或Graphify，由主代理统一收口；没有将上述测试通过解释为完整战斗、平衡、性能或玩家实玩验收。
