# Build 首批卡牌与等级节奏设计

本文档在 [12_Build数学模型与发牌方案.md](12_Build数学模型与发牌方案.md) 的数学模型基础上，进一步落地首批新 Build 卡、队伍等级阶段节奏、能力包数据和协同连结。

本文先做设计数据，不直接替换当前实装主题树。后续实现时应先做纯模型模拟，再逐步接入战斗效果。

当前实现状态：完整首批版已从纯模型推进到局内首批版。数据与生成器位于 `scripts/build/build_first_batch_database.gd`、`scripts/build/build_first_batch_model.gd`，运行时发牌位于 `scripts/build/build_first_batch_runtime.gd`，卡牌应用位于 `scripts/player/player_first_batch_card_applier.gd`，队伍等级里程碑位于 `scripts/player/player_first_batch_milestone_flow.gd`。普通升级和开发者模式均已接入首批 Build；旧主题树仍保留为兼容/历史链路。

---

## 1. 等级节奏定义

这里的 6 / 12 / 18 / 25 指 **队伍等级阶段**，不是三个英雄各自独立升级，也不是三个英雄分别刷经验。

核心原则：

```text
team_level：队伍共享等级，决定局内阶段、解锁层级和升级节奏。
role_investment[role]：某英雄本局被投入了多少构筑资源。
package_depth[package]：某个能力包被投入了多少构筑资源。
edge_level[a->b]：两个英雄或两个能力包之间的接力强度。
```

普通升级仍然是队伍升级触发三选一。选择不同卡时增加“投入”，而不是增加独立英雄等级：

```text
英雄专属卡：对应 role_investment +1，对应 package_depth +1。
双人共鸣卡：两名英雄 role_investment 各 +0.5，edge +1。
三人共鸣卡：三名英雄 role_investment 各 +0.35，cycle_edge +1。
Boss 突破：对应 package_depth +2，对应 role_investment +1，或对应 edge +2。
通用卡：默认不加英雄投入，少数通用轮转卡可三英雄各 +0.15。
```

因此，本文中的“6 级质变 / 12 级质变 / 18 级质变 / 25 级成型”表示：

```text
队伍到达该等级后，系统允许对应层级的卡、共鸣或突破进入候选池；
真正出现哪条线，仍取决于玩家此前的 role_investment / package_depth / edge_level。
```

不应把它理解成：

```text
剑士 6 级、枪手 6 级、术师 6 级分别独立解锁。
```

---

## 2. 四段队伍等级质变目标

队伍等级按 6 / 12 / 18 / 25 做阶段质变。每个阶段不是给所有英雄自动解锁同样内容，而是扩大“当前已投入方向”的可选层级。

| 队伍等级 | 设计目标 | 发牌变化 | 玩家感受 |
| --- | --- | --- | --- |
| 6 | 第一次质变：入口机制从数值变成可见状态 | 解锁 engine 卡 | “这个英雄开始有自己的玩法了” |
| 12 | 第二次质变：机制形成自循环 | 解锁 payoff 卡和第一批强共鸣 | “我能围绕它打套路了” |
| 18 | 第三次质变：跨机制或跨英雄成型 | 解锁 capstone 候选 | “这条线有大招级表现了” |
| 25 | 基本完全成型 | 降低同线延续权重，提高桥接/第二线权重 | “这条线毕业，可以扩其他线了” |

队伍 25 级不是终局强制停止，而是允许“当前主线毕业”：

```text
team_level >= 25 且某 package_depth 达到毕业阈值后：
- 同 package 继续出现的概率下降。
- 与该 package 相邻的 bridge_edge 卡权重提高。
- Boss 奖励更倾向给共鸣突破或第二能力包入口。
```

当前局内第一版的强制可感知规则：

```text
队伍达到 Lv.6：
- 立刻触发一次“第一质变”提示、环形特效和轻震屏。
- 底部技能栏新增当前英雄的 Build质变冷却槽。
- 剑士命中周期触发“破阵牵引”：范围斩击、牵引、易伤、短减速、回蓝。
- 枪手命中周期触发“火线标记”：锁定目标、易伤、爆点和小范围溅射。
- 术师命中周期触发“符印领域”：展开领域，多段伤害并减速。

队伍达到 Lv.12 / Lv.18 / Lv.25：
- 目前已有队伍属性、资源循环、切人/大招/后台倾向和可视提示。
- 后续需要继续补齐对应阶段的专属 ability 和更强演出。
```

---

## 3. 三名英雄的特性定位

### 3.1 剑士特性：破阵血潮

当前已实装特性基础：

```text
最大生命 / 生命自动恢复
剑士普攻伤害
入场破阵伤害 / 突进距离 / 无敌
离场传承吸血
```

新模型表达：

```text
核心语法：突进、斩击、近身风险、吸血、护盾、反击。
主能力包：swd_break_blood，破阵血潮。
高亲和门派：entry_burst / lifesteal_grind / guard_counter。
中亲和门派：healing_push / summon_swarm。
主要状态：armor_break / guard / vulnerable。
```

### 3.2 枪手特性：过载火线

当前已实装特性基础：

```text
移动速度 / 闪避率
枪手普攻伤害
入场弹幕伤害 / 弹速 / 波数
离场过载攻速 / 移速 / 持续
```

新模型表达：

```text
核心语法：弹道、装填、穿透、标记、火力窗口、压制。
主能力包：gun_overload_fireline，过载火线。
高亲和门派：projectile_storm / mark_execute。
中亲和门派：summon_swarm / ultimate_cycle / control_lock。
主要状态：marked / overdrive / vulnerable。
```

### 3.3 术师特性：星灾符印

当前已实装特性基础：

```text
大招能量自动恢复 / 吸取范围
术师普攻伤害
入场轰炸伤害 / 范围 / 落点数
离场回能 / 减速符印
```

新模型表达：

```text
核心语法：领域、元素、轰炸、延迟爆发、控制、回能。
主能力包：mag_starfall_field，星灾符印。
高亲和门派：domain_blast / control_lock / summon_swarm / ultimate_cycle。
中亲和门派：healing_push / guard_counter。
主要状态：field / slowed / charge。
```

---

### 3.4 多定位但不允许同质化

首批版把“英雄能承担什么职责”和“英雄用什么语法承担职责”拆开：

```text
position_weights：输出 / 控制 / 生存 / 支援 / 召唤 / 资源 / 机动。
identity_weights：破阵、弹道、领域、标记、过载、护盾、回能等英雄语法。
upgrade_axes：进场、离场、核心输出、终式、独立冷却被动。
```

这样允许三个英雄都能走输出，也允许三个英雄都偏支援，但不会变成同一套模板：

| 英雄 | 招牌定位 | 可扩展副定位 | 不同质化约束 |
| --- | --- | --- | --- |
| 剑士 | 生存型破阵前锋 | 近身爆发、吸血护盾、牵引控制、剑影嘲讽召唤 | 输出靠入场斩击、破甲和风险换血；支援也表现为护盾、吸血传承、嘲讽。 |
| 枪手 | 远程火线输出 | 标记支援、装填资源、无人机辅助、压制控制 | 输出靠弹道、标记和过载窗口；支援也表现为标记高价值目标、装填和火线覆盖。 |
| 术师 | 领域控制 | 回能支援、领域爆发、守护傀儡、召唤/治疗桥接 | 输出靠领域、符印和持续空间；支援也表现为回能、减速、傀儡护场。 |

因此，“多定位”不是每个英雄复制一套输出/坦克/治疗按钮，而是：

```text
同一职责，不同实现语法。
剑士的支援 = 护盾/吸血/嘲讽。
枪手的支援 = 标记/装填/火线窗口。
术师的支援 = 回能/领域/傀儡。
```

首批纯模型中，`build_first_batch_database.gd` 已显式记录每张英雄卡的 `position_weights`、`upgrade_axes`，并给三名英雄配置不同的 `ROLE_IDENTITY_PROFILES`。`build_first_batch_model.gd` 会把玩家选择累积到 `position_points`，使发牌不仅追踪英雄投入和门派深度，也追踪本局队伍实际职责倾向。

### 3.5 独立冷却被动技能覆盖

每名英雄首批先保留 **1 张独立冷却被动技能牌**，避免底部技能栏和战斗反馈缺口：

| 英雄 | 卡牌 | 冷却 | 触发语法 | 定位差异 |
| --- | --- | ---: | --- | --- |
| 剑士 | `swd_blade_shadow` 剑影留形 | 9.0s | 入场后/周期性留下剑影 | 召唤物承担重复斩击与短嘲讽，是近身风险的残影。 |
| 枪手 | `gun_spotter_drone` 侦察无人机 | 10.0s | 自动标记高价值目标 | 召唤物承担索敌、标记和轻支援，是火线指挥节点。 |
| 术师 | `mag_guardian_puppet` 守护傀儡 | 12.0s | 领域或高压时召唤守护物 | 召唤物承担嘲讽、护盾和领域守护，是法阵空间的一部分。 |

注意：三者都可以归入“召唤/支援”，但功能语法不同：

```text
剑影 = 近身斩击残留 + 嘲讽。
无人机 = 远程标记 + 火线索敌。
傀儡 = 领域守护 + 吸引火力。
```

这保证了后续可以做召唤流，但不会让三名英雄的召唤物都只是“自动攻击小宠物”。

---

## 4. 队伍等级阶段下的英雄里程碑

以下里程碑的读取方式是：

```text
队伍等级达到阶段门槛 + 对应英雄/能力包有足够投入 => 相关卡进入候选池。
```

例如“队伍 12 级 + 剑士破阵血潮投入足够”才会出现血潮循环类卡；不是队伍 12 级时三个英雄自动获得所有 12 级效果。

### 4.1 剑士里程碑

| 队伍等级门槛 | 投入要求 | 质变 | 具体变化 |
| --- | --- | --- | --- |
| 6 | 剑士投入或破阵包 >=2 | 破阵成形 | 剑士入场命中敌人附加 `armor_break`；离场吸血祝福可传给下一名英雄。 |
| 12 | 剑士投入或破阵包 >=4 | 血潮循环 | 剑士造成的治疗可形成 `guard`；过量治疗会产生短距离推波。 |
| 18 | 剑士投入或破阵包 >=6，或剑士相关 edge >=3 | 剑影出鞘 | 剑士入场或离场可留下剑影，剑影重复斩击或短暂嘲讽。 |
| 25 | 破阵包 >=8 或剑士主线突破已选 | 断潮毕业 | 剑士完成破阵血潮主线；同线卡降权，剑影、奶推、守护反击桥接卡升权。 |

### 4.2 枪手里程碑

| 队伍等级门槛 | 投入要求 | 质变 | 具体变化 |
| --- | --- | --- | --- |
| 6 | 枪手投入或火线包 >=2 | 火线成形 | 枪手入场弹幕附加 `marked`；离场过载成为明确的下一人火力窗口。 |
| 12 | 枪手投入或火线包 >=4 | 装填循环 | 标记击杀 / 多次命中可返还装填或延长过载；火线开始自循环。 |
| 18 | 枪手投入或火线包 >=6，或枪手相关 edge >=3 | 支援展开 | 枪手可部署侦察无人机 / 压制炮台，提供标记、治疗或火力支援。 |
| 25 | 火线包 >=8 或枪手主线突破已选 | 无限火线 | 枪手完成过载火线主线；同线卡降权，标记处决、无人机、回能桥接卡升权。 |

### 4.3 术师里程碑

| 队伍等级门槛 | 投入要求 | 质变 | 具体变化 |
| --- | --- | --- | --- |
| 6 | 术师投入或星灾包 >=2 | 符印成形 | 术师入场轰炸留下 `field`；离场减速符印可被下一名英雄继承。 |
| 12 | 术师投入或星灾包 >=4 | 法阵循环 | 领域持续时间、回能和状态消耗形成闭环；轰炸不只是瞬时伤害。 |
| 18 | 术师投入或星灾包 >=6，或术师相关 edge >=3 | 造物显现 | 术师可召唤元素傀儡，承担嘲讽、治疗、爆炸或控场之一。 |
| 25 | 星灾包 >=8 或术师主线突破已选 | 星穹毕业 | 术师完成星灾符印主线；同线卡降权，傀儡、治疗领域、大招循环桥接卡升权。 |

---

## 5. 首批英雄专属卡数据

数值是第一版设计值，目标是建模与测试，不是最终平衡。

### 5.1 剑士：破阵血潮包 `swd_break_blood`

| ID | 名称 | 队伍等级门槛 | Max | 主要标签 | 核心效果 | 状态 / 边 |
| --- | --- | ---: | ---: | --- | --- | --- |
| `swd_break_step` | 破阵步 | 0 | 3 | entry_burst / direct_hit / burst | 入场突进距离 +6%/级，入场斩击伤害 +8%/级。 | 产生 `armor_break`；`swordsman->gunner` +0.2 |
| `swd_blood_echo` | 血刃回响 | 0 | 3 | lifesteal_grind / heal / survival | 攻击破甲敌人回复最大生命 0.4%/级；离场吸血祝福 +1.2%/级。 | 产生 `guard` 少量；`swordsman->mage` +0.2 |
| `swd_tide_pull` | 断潮聚锋 | 6 | 3 | entry_burst / control / push | 入场终点牵引 90+15/级 范围敌人；对减速敌人牵引增强。 | 消耗 `slowed/field`；`mage->swordsman` +0.5 |
| `swd_overheal_guard` | 血潮护身 | 6 | 3 | healing_push / overheal / shield | 过量治疗 35%/级 转护盾；护盾破裂释放推波。 | 产生 `guard/push`；桥接 healing_push |
| `swd_blade_shadow` | 剑影留形 | 12 | 3 | summon_swarm / direct_hit / taunt | 入场后留下剑影 4+1/级 秒；剑影重复 40/55/70% 入场斩击，可短暂嘲讽。 | 产生 `summon_unit/guard`；`swordsman->mage` +0.3 |
| `swd_break_execute` | 裂甲处决 | 12 | 3 | mark_execute / execute / burst | 破甲敌人低于 8/11/14% 生命时被处决；精英改为额外伤害。 | 消耗 `armor_break/vulnerable`；`gunner->swordsman` +0.4 |
| `swd_tide_unbound` | 断潮无双 | 18 | 1 | entry_burst / lifesteal_grind / capstone | 每完成一次三英雄轮转，剑士下一次入场变为二段破阵；离场吸血祝福附带护盾。 | capstone；`cycle->swordsman` +1 |
| `swd_break_mastery` | 破阵血潮·成型 | 25 | 1 | mastery / bridge | 破阵血潮毕业：剑士同线卡降权；剑影、奶推、守护反击桥接卡升权。 | 打开 bridge 权重 |

#### 代表卡数据：`swd_overheal_guard`

```gdscript
{
  "id": "swd_overheal_guard",
  "title": "血潮护身",
  "owner_role": "swordsman",
  "package_id": "swd_break_blood",
  "team_level_min": 6,
  "investment_requirements": {"swordsman": 2, "swd_break_blood": 2},
  "max_level": 3,
  "trait_gain": {"swordsman": 1.0},
  "package_gain": {"swd_break_blood": 1.0},
  "role_weights": {"swordsman": 1.0},
  "timing_weights": {"active": 0.5, "exit": 0.5},
  "function_weights": {"survival": 0.7, "control": 0.3, "burst": 0.2},
  "mechanic_weights": {"heal": 0.5, "overheal": 0.8, "push": 0.4},
  "archetype_weights": {"healing_push": 0.7, "guard_counter": 0.4, "lifesteal_grind": 0.4},
  "produce_weights": {"guard": 0.8},
  "consume_weights": {},
  "bridge_weights": {"lifesteal_grind->healing_push": 0.8, "healing_push->guard_counter": 0.4},
  "package_edges": [
    {"to": "swd_blade_shadow", "type": "bridge_edge", "cost": 2.0},
    {"to": "mag_guardian_puppet", "type": "relay_edge", "cost": 1.0}
  ]
}
```

### 5.2 枪手：过载火线包 `gun_overload_fireline`

| ID | 名称 | 队伍等级门槛 | Max | 主要标签 | 核心效果 | 状态 / 边 |
| --- | --- | ---: | ---: | --- | --- | --- |
| `gun_entry_barrage` | 弹幕开局 | 0 | 3 | projectile_storm / entry / burst | 入场弹幕伤害 +6%/级；第 3 级额外 +1 波。 | 产生 `marked`；`gunner->mage` +0.2 |
| `gun_overload_mag` | 过载弹匣 | 0 | 3 | overdrive / exit / pass_next | 离场过载持续 +0.4s/级；下一名英雄攻速 +4%/级。 | 产生 `overdrive`；`gunner->swordsman` +0.3 |
| `gun_fireline_mark` | 火线标记 | 6 | 3 | mark_execute / projectile / mark | 同一敌人被枪手命中 3 次后标记；攻击破甲敌人立即标记。 | 消耗 `armor_break`，产生 `marked`；`swordsman->gunner` +0.6 |
| `gun_tactical_reload` | 战术装填 | 6 | 3 | resource_loop / overdrive | 击杀标记敌人返还 0.25s 装填/过载；每级 +0.15s。 | 消耗 `marked`；`gunner->gunner` engine |
| `gun_spotter_drone` | 侦察无人机 | 12 | 3 | summon_swarm / mark / support | 召唤无人机标记最近精英或血量最高敌人；第 3 级可治疗少量护盾。 | 产生 `marked`；桥接 summon_swarm/healing_push |
| `gun_suppression_grid` | 压制火网 | 12 | 3 | control_lock / projectile / push | 过载期间子弹附带轻击退；对减速/领域内敌人变为穿透。 | 消耗 `slowed/field`；`mage->gunner` +0.5 |
| `gun_infinite_fireline` | 无限火线 | 18 | 1 | projectile_storm / capstone | 三英雄轮转后，枪手下一次入场进入短暂无限弹幕窗口。 | capstone；`cycle->gunner` +1 |
| `gun_fireline_mastery` | 过载火线·成型 | 25 | 1 | mastery / bridge | 过载火线毕业：同线卡降权；标记处决、无人机、回能桥接卡升权。 | 打开 bridge 权重 |

#### 代表卡数据：`gun_spotter_drone`

```gdscript
{
  "id": "gun_spotter_drone",
  "title": "侦察无人机",
  "owner_role": "gunner",
  "package_id": "gun_overload_fireline",
  "team_level_min": 12,
  "investment_requirements": {"gunner": 4, "gun_overload_fireline": 4},
  "max_level": 3,
  "trait_gain": {"gunner": 1.0},
  "package_gain": {"gun_overload_fireline": 1.0},
  "role_weights": {"gunner": 1.0},
  "timing_weights": {"active": 0.7, "exit": 0.3},
  "function_weights": {"mark": 0.8, "sustain": 0.3, "survival": 0.2},
  "mechanic_weights": {"summon_unit": 0.7, "command_summon": 0.6},
  "archetype_weights": {"summon_swarm": 0.5, "mark_execute": 0.6, "projectile_storm": 0.3},
  "produce_weights": {"marked": 0.9},
  "bridge_weights": {"projectile_storm->summon_swarm": 0.5, "mark_execute->summon_swarm": 0.6},
  "package_edges": [
    {"to": "mag_guardian_puppet", "type": "mirror_edge", "cost": 1.5},
    {"to": "swd_break_execute", "type": "relay_edge", "cost": 1.0}
  ]
}
```

### 5.3 术师：星灾符印包 `mag_starfall_field`

| ID | 名称 | 队伍等级门槛 | Max | 主要标签 | 核心效果 | 状态 / 边 |
| --- | --- | ---: | ---: | --- | --- | --- |
| `mag_starfall_seed` | 星陨落点 | 0 | 3 | domain_blast / entry / burst | 入场轰炸半径 +5%/级；第 3 级额外 +1 落点。 | 产生 `field`；`mage->swordsman` +0.2 |
| `mag_mana_tide` | 法力回潮 | 0 | 3 | ultimate_cycle / energy | 离场给下一名英雄 +2/3/4 能量；术师回能 +0.12/s/级。 | 产生 `charge`；`mage->gunner` +0.2 |
| `mag_frost_seal` | 冰封符印 | 6 | 3 | control_lock / field / slow | 离场领域持续 +0.7s/级；领域内敌人减速增强。 | 产生 `slowed/field`；`mage->swordsman` +0.5 |
| `mag_field_convergence` | 法阵聚流 | 6 | 3 | domain_blast / control | 两个领域重叠时合并并造成 60%+20%/级 术师伤害。 | 消耗 `field`；`mage->mage` engine |
| `mag_guardian_puppet` | 守护傀儡 | 12 | 3 | summon_swarm / taunt / survival | 召唤元素傀儡吸引敌人 3+1/级 秒；领域内傀儡获得护盾。 | 产生 `summon_unit/guard`；桥接 summon/healing |
| `mag_orbital_script` | 星轨咒文 | 12 | 3 | mark_execute / domain / burst | 领域会锁定标记敌人追加星轨；每级 +1 次锁定上限。 | 消耗 `marked`；`gunner->mage` +0.6 |
| `mag_sky_dome` | 星穹降临 | 18 | 1 | domain_blast / capstone | 三英雄轮转后，术师下一次入场生成持续星穹领域。 | capstone；`cycle->mage` +1 |
| `mag_starfield_mastery` | 星灾符印·成型 | 25 | 1 | mastery / bridge | 星灾符印毕业：同线卡降权；傀儡、治疗领域、大招循环桥接卡升权。 | 打开 bridge 权重 |

#### 代表卡数据：`mag_guardian_puppet`

```gdscript
{
  "id": "mag_guardian_puppet",
  "title": "守护傀儡",
  "owner_role": "mage",
  "package_id": "mag_starfall_field",
  "team_level_min": 12,
  "investment_requirements": {"mage": 4, "mag_starfall_field": 4},
  "max_level": 3,
  "trait_gain": {"mage": 1.0},
  "package_gain": {"mag_starfall_field": 1.0},
  "role_weights": {"mage": 1.0},
  "timing_weights": {"exit": 0.4, "active": 0.6},
  "function_weights": {"control": 0.5, "survival": 0.7, "domain": 0.4},
  "mechanic_weights": {"summon_unit": 0.8, "command_summon": 0.4, "field_tick": 0.3},
  "archetype_weights": {"summon_swarm": 0.8, "control_lock": 0.4, "guard_counter": 0.3},
  "produce_weights": {"guard": 0.6, "field": 0.3},
  "bridge_weights": {"domain_blast->summon_swarm": 0.8, "summon_swarm->healing_push": 0.3},
  "package_edges": [
    {"to": "gun_spotter_drone", "type": "mirror_edge", "cost": 1.5},
    {"to": "swd_overheal_guard", "type": "relay_edge", "cost": 1.0}
  ]
}
```

---

## 6. 双人协同卡

双人协同卡不要求固定主副定位，只要求双方有可解释的状态传递。

### 6.1 剑士 + 枪手：开路火线

| ID | 解锁条件 | Max | 效果 | 关系 |
| --- | --- | ---: | --- | --- |
| `res_swd_gun_open_fire` | `armor_break` 生产 >=1，`projectile/marked` >=1，或剑枪 edge >=1.5 | 2 | 剑士入场破甲敌人会被枪手优先标记；枪手攻击破甲敌人额外穿透。 | `swordsman->gunner` +1 |
| `res_gun_swd_cover_dash` | 枪手过载 >=2，剑士入场 >=2 | 2 | 枪手离场过载期间，剑士下一次突进附带弹幕护航。 | `gunner->swordsman` +1 |

质变：

```text
Lv.1：状态能接上，出现明确的双人接力反馈。
Lv.2：接力时追加可见弹幕/剑气，并返还少量切换冷却。
```

### 6.2 枪手 + 术师：星轨锁定

| ID | 解锁条件 | Max | 效果 | 关系 |
| --- | --- | ---: | --- | --- |
| `res_gun_mag_orbital_lock` | `marked` >=2，`field` >=1 | 2 | 术师领域优先轰炸标记敌人；枪手攻击领域内敌人时子弹更易穿透。 | `gunner->mage` +1，`mage->gunner` +0.5 |
| `res_mag_gun_arcane_reload` | `charge` >=1，过载 >=1 | 2 | 术师离场回能同时给枪手装填；枪手过载命中为术师回能。 | energy loop |

### 6.3 术师 + 剑士：星灾破阵

| ID | 解锁条件 | Max | 效果 | 关系 |
| --- | --- | ---: | --- | --- |
| `res_mag_swd_star_cleave` | `field/slowed` >=2，剑士入场 >=1 | 2 | 剑士在术师领域内入场时，突进终点追加星灾斩。 | `mage->swordsman` +1 |
| `res_swd_mag_blood_ward` | 剑士过量治疗或 guard >=1，术师领域 >=1 | 2 | 剑士护盾破裂时在术师领域内释放守护爆波；术师傀儡获得护盾。 | healing_push / summon bridge |

---

## 7. 三人协同卡

### 7.1 三段轮转：三相接力

| ID | 解锁条件 | Max | 效果 |
| --- | --- | ---: | --- |
| `res_tri_three_step_cycle` | 三名英雄投入都 >=2，或三条双人 edge 总和 >=4 | 2 | 在短时间内依次切入三名不同英雄后，触发一次队伍终结打击。 |

等级：

```text
Lv.1：触发终结打击，伤害取三英雄最近一次核心伤害的平均值。
Lv.2：终结打击继承 armor_break / marked / field 中的一个最高状态，并返还部分切换冷却。
```

### 7.2 三输出轮转：火力合奏

| ID | 解锁条件 | Max | 效果 |
| --- | --- | ---: | --- |
| `res_tri_all_damage_concert` | 三名英雄 `burst/sustain/domain/projectile` 输出标签合计 >=8 | 2 | 三名英雄都在 8 秒内造成核心伤害后，全队获得短暂伤害增幅。 |

这张卡保证“三个英雄都是输出”也是合法构筑，而不是被系统强行改成一主二辅。

### 7.3 三功能轮转：守势合环

| ID | 解锁条件 | Max | 效果 |
| --- | --- | ---: | --- |
| `res_tri_guard_loop` | `guard + field + overdrive` 三类状态都出现 | 2 | 过载、领域、护盾三者依次出现时，生成一次团队保护环。 |

这张卡服务非纯输出构筑，例如奶推、守护、召唤嘲讽。

---

## 8. 能力包连结图

### 8.1 首批 package 节点

```text
swd_break_blood
  -> swd_blade_shadow_branch       bridge_edge, 2.0
  -> swd_healing_push_branch       bridge_edge, 2.0
  -> gun_overload_fireline         relay_edge, 1.0
  -> mag_starfall_field            relay_edge, 1.0

 gun_overload_fireline
  -> gun_mark_execute_branch       bridge_edge, 2.0
  -> gun_drone_support_branch      bridge_edge, 2.0
  -> swd_break_blood               relay_edge, 1.0
  -> mag_starfall_field            relay_edge, 1.0

mag_starfall_field
  -> mag_puppet_branch             bridge_edge, 2.0
  -> mag_healing_field_branch      bridge_edge, 2.0
  -> swd_break_blood               relay_edge, 1.0
  -> gun_overload_fireline         relay_edge, 1.0
```

### 8.2 状态传递

```text
剑士 produces armor_break
枪手 consumes armor_break -> produces marked / overdrive
术师 consumes marked -> produces field / slowed / charge
剑士 consumes slowed / field -> stronger entry pull / healing_push
```

这是第一版核心闭环：

```text
armor_break -> marked -> field/slowed -> enhanced entry/healing
```

---

## 9. 发牌与队伍等级阶段关系

### 9.1 队伍 1-5：入口阶段

目标：让玩家选择一个英雄或一个行为偏好。

可出现：

```text
剑士：破阵步 / 血刃回响
枪手：弹幕开局 / 过载弹匣
术师：星陨落点 / 法力回潮
少量通用卡
```

不出现：

```text
守护傀儡、侦察无人机、断潮无双等高阶卡。
```

### 9.2 队伍 6-11：第一次质变后

目标：入口卡变成 engine。

新增：

```text
剑士：断潮聚锋 / 血潮护身
枪手：火线标记 / 战术装填
术师：冰封符印 / 法阵聚流
第一批双人协同卡
```

### 9.3 队伍 12-17：第二次质变后

目标：机制出现 payoff 和跨机制桥接。

新增：

```text
剑士：剑影留形 / 裂甲处决
枪手：侦察无人机 / 压制火网
术师：守护傀儡 / 星轨咒文
更强双人协同卡
```

### 9.4 队伍 18-24：第三次质变后

目标：capstone 候选和三人轮转。

新增：

```text
剑士：断潮无双
枪手：无限火线
术师：星穹降临
三人协同卡
Boss 突破
```

### 9.5 队伍 25+：主线毕业

目标：开始其他线路增加，而不是继续无限堆同线。

规则：

```text
已达到毕业投入的当前 package 延续权重 ×0.45。
相邻 bridge_edge 权重 ×1.6。
双人/三人共鸣权重 ×1.3。
第二能力包 seed 权重 ×1.5。
```

---

## 9.6 发牌刷新机制

首批纯模型采用：

```text
每次队伍升级：三槽三选一 + 1 次免费刷新。
```

三槽仍然固定为：

| 槽位 | 作用 | 刷新后是否保留 |
| --- | --- | --- |
| Continue | 延续当前投入，避免断供 | 保留 |
| Link | 给出英雄接力、双人/三人共鸣 | 保留 |
| Pivot | 转向、补缺、通用稳定 | 保留 |

刷新不是“心愿”。玩家不能指定想要剑士、枪手、术师或某张卡，只能拒绝当前这一组。

### 9.6.1 刷新流程

```text
1. build_upgrade_offer(state) 生成第一次 offer。
2. offer_context.refresh_remaining = 1。
3. 玩家如果刷新：
   - 当前 offer 的 card_id 写入 rejected_offer_ids。
   - refresh_remaining 变 0。
   - 使用同一 state 重新生成三槽 offer。
4. 玩家选择任意卡：
   - apply_card_pick(state, card_id)。
   - 本次升级结束。
```

刷新不会修改构筑状态：

```text
role_investment
package_depth
edge_level
tag_points
position_points
```

刷新只修改本次发牌上下文：

```text
refresh_index
refresh_remaining
rejected_offer_ids
refresh_repair_used
```

### 9.6.2 为什么只给一次刷新

一次刷新解决的是“这组三张都不舒服”的体验问题。

如果给多次刷新，会变成：

```text
玩家用刷新刷目标路线
=> 实际上变成软心愿
=> 最优解更稳定
=> 中期转向和发牌生态被压缩
```

因此首批版只给一次。后续如果要增加刷新次数，必须引入成本，例如金币、Boss 奖励或遗物，而不是基础规则。

### 9.6.3 刷新后的质量要求

刷新后的 offer 应满足：

```text
- 仍然是 3 张。
- 仍然保留 continue / link / pivot 三个 offer_slot。
- 尽量不重复刷新前 3 张。
- 不突破 team_level、investment_requirements、max_level。
- 如果候选不足导致重复，标记 refresh_repair_used = true。
```

### 9.6.4 UI 表达建议

升级界面显示一个按钮：

```text
刷新 1/1
```

刷新后变为：

```text
刷新 0/1
```

每张卡仍可显示轻量来源：

```text
延续当前投入
形成英雄接力或共鸣
补缺、转向或通用稳定
```

这些文案来自 `offer_reason`，不需要把底层分数暴露给玩家。

---

## 9.7 纯模型平衡分析器

首批版现在增加了一个不进入战斗场景的平衡分析器，并接入敌人压力模型：

```text
scripts/build/build_first_batch_balance_analyzer.gd
scripts/build/build_enemy_pressure_model.gd
scripts/tests/build_first_batch_balance_smoke.gd
scripts/tests/build_enemy_pressure_model_smoke.gd
```

它的目标不是证明最终战斗数值完全平衡，而是先回答构筑层面的三个问题：

```text
1. 各路线在 6 / 12 / 18 / 25 阶段大致强弱曲线是否合理。
2. 是否允许前期强、后期强、转向强、共鸣强等不同节奏并存。
3. 是否出现明显唯一最优解，导致大多数理性选择都被同一路线碾压。
```

当前分析器内置策略包括：

| 策略 | 预期节奏 | 合理性目标 |
| --- | --- | --- |
| 剑士主轴 | 前中期稳定，后期靠破阵终式补强 | 允许前期竞争力强，但不能后期碾压。 |
| 枪手主轴 | 前期输出清晰，中后期标记/过载成型 | 应与剑士主轴处在同一大致强度带。 |
| 术师主轴 | 前期略慢，中后期领域和终式抬升 | 允许后期强，但不能成为唯一答案。 |
| 三人均衡 | 前期平滑，中后期靠 edge 和共鸣 | 应始终可玩，不要求最高。 |
| 共鸣猎手 | 依赖双人/三人联动 | 中后期应有回报。 |
| 召唤支援 | 前期较慢，中后期随独立被动和召唤卡抬升 | 允许后期强。 |
| 大招循环 | 前期慢，18/25 后价值提高 | 应体现后期路线。 |
| 中期转向 | 12 级后换主轴 | 应不明显低于纯主轴。 |
| 低协同散选 | 明显不合理 | 可以弱，而且应该弱。 |

分析器会输出每个策略在四个里程碑的模型分数，并检查：

```text
- top / runner-up aggregate gap 不能过大。
- 至少有多个策略接近最优，不能只有一个明显答案。
- 低协同散选的最终分数应明显低于合理策略中位数。
- 召唤和大招循环应体现中后期成长曲线。
- 三个英雄主轴最终分数保持在同一大致强度带。
```

一轮通过示例：

```text
summon_support aggregate ≈ 68.66
mage_main aggregate ≈ 67.06
pivot_sword_to_gunner aggregate ≈ 66.65
swordsman_main / gunner_main aggregate ≈ 65.54
bad_scattered aggregate ≈ 51.54

Top gap ≈ 1.024，close policies = 10，无明显唯一最优解。
```

解释方式：召唤支援和术师后期略强是允许的；剑士、枪手和转向路线仍在接近区间；低协同散选明显弱，说明模型不会把乱选也抬到同等强度。

### 9.7.1 敌人压力接入

平衡报告现在不只输出强度，也输出风险：

```text
L6=19.26/risk0.62
L12=41.56/risk0.61
L18=70.82/risk0.64
L25=104.12/risk0.57
```

其中 `risk` 来自敌人压力模型，表示该构筑在当前阶段还有多少敌人压力没有被覆盖。敌人压力包括：

```text
density / durability / contact / ranged / burst / mobility / control / boss
```

这些压力由当前实装敌人资料和波次曲线计算：

```text
scripts/enemy/enemy_archetype_database.gd
scripts/enemy/enemy_director.gd
```

因此后续判断强弱时不只看分数：

```text
高强度 + 低风险 + 稳定成型 = 需要警惕的最优解候选。
高强度 + 高风险 = 可以接受的偏科强路线。
低强度 + 高风险 = 明显不合理路线，可以弱。
```

当前示例中，召唤支援后期强且风险较低，但 aggregate 只领先约 2.4%，因此暂时不构成“明显唯一最优解”。后续如果加入更多召唤卡，需要重点观察它是否同时获得最高强度、最低风险和最高成型稳定性。

### 9.7.2 完整场景时间线评估（后续升级方向）

现阶段平衡器是里程碑评估：用 `6 / 12 / 18 / 25` 级代表前期、中期、后期和成型点。下一阶段需要升级为完整场景时间线评估：

```text
0s -> Boss 出场 -> Boss 战结束
每 15s/30s 采样一次：
- 当前预期队伍等级
- 当前已选卡牌和路线动量
- 当前敌人压力
- 当前 Build 覆盖
- 清怪余量 / 生存余量 / 未覆盖风险
```

这样难度不再只靠“敌人血量乘以多少”，而是能看到：

```text
哪一分钟密度压力过高
哪一分钟远程或冲刺压力过高
某路线在第 12 级前是否断档
中期转向路线是否有追赶窗口
Boss 前是否有足够成型空间
```

该方向用于后续设置简单、普通、困难、地狱四档难度的目标风险带。

首批难度落地已加入 `scripts/game/difficulty_profile.gd` 和 `scripts/tests/difficulty_profile_smoke.gd`：先让四档难度真实影响无尽模式，再用完整时间线评估继续细调每个压力窗口。

---

## 10. 首批实现建议

### 10.1 第一批先实现的数据

最小实现包：

```text
剑士 4 张：破阵步、血刃回响、断潮聚锋、血潮护身。
枪手 4 张：弹幕开局、过载弹匣、火线标记、战术装填。
术师 4 张：星陨落点、法力回潮、冰封符印、法阵聚流。
双人协同 3 张：开路火线、星轨锁定、星灾破阵。
三人协同 1 张：三相接力。
```

这批能验证 0-12 级节奏。

### 10.2 第二批再补

```text
剑士：剑影留形、裂甲处决、断潮无双。
枪手：侦察无人机、压制火网、无限火线。
术师：守护傀儡、星轨咒文、星穹降临。
三人协同：火力合奏、守势合环。
```

这批验证 12-25 和毕业转线。

### 10.3 实现前置调整

```text
1. 保留队伍共享等级作为阶段门槛；不要新增三个英雄独立等级。
2. 新增 role_investment / package_depth / edge_level / milestone_flags。
3. 新增卡牌数据字段：package_id、team_level_min、investment_requirements、trait_gain、package_gain、edge_gain。
4. 先做纯发牌模拟，不直接写战斗效果。
5. 模拟通过后，再逐张接入战斗实现。
```

---

## 11. 验收标准

### 11.1 单英雄主线

```text
连续投资剑士时：
队伍 6 级前能感到入场破阵变强。
队伍 6 级后，若剑士投入足够，出现破甲/牵引/吸血传承。
队伍 12 级后，若剑士投入足够，出现血潮循环、剑影或处决等玩法改变。
队伍 18 级后，若剑士线已成型，出现断潮无双候选。
队伍 25 级后，若剑士主线毕业，系统开始推荐剑影/奶推/共鸣等第二线路。
```

枪手和术师同理。

### 11.2 中期转向

```text
前期队伍等级推进中，剑士投入 8，枪手投入 2。
中期连续选择枪手 2-3 次。
接下来 2 次升级内至少 1 次出现枪手延续或剑枪共鸣。
```

### 11.3 三输出合法

```text
剑士破阵 + 枪手过载 + 术师星灾 都有投入时，
系统应给出火力合奏 / 三相接力，
而不是强迫其中一人转辅助。
```

### 11.4 非输出召唤合法

```text
术师守护傀儡、枪手侦察无人机、剑士剑影可以承担不同功能：
嘲讽 / 标记 / 斩击 / 治疗 / 护盾。
系统不得把 summon_swarm 默认等同于输出。
```


---

## 12. 首批卡量与卡内等级原则

### 12.1 两档首批范围

不要一开始把所有设计卡全部实装。首批应分两档：

```text
模型验证版：18-20 张唯一卡。
完整首批版：30-35 张唯一卡。
```

模型验证版用于确认发牌、转向和 0-12 级节奏：

```text
英雄专属普通卡：12 张
  - 每名英雄 4 张：2 张入口 + 2 张 6 级 engine。
双人协同：3 张
三人协同：1 张
通用卡：2-4 张
```

完整首批版用于覆盖 25 级前后的完整体验：

```text
英雄专属普通卡：18 张
  - 每名英雄 6 张：2 张入口 + 2 张 6 级 engine + 2 张 12 级 payoff/bridge。
英雄终式卡：3 张
  - 每名英雄 1 张，队伍 18 级后出现。
双人协同卡：6 张
  - 每对英雄 2 张。
三人协同卡：3 张
通用卡：3-5 张
成型节点：3 个系统节点，不算普通卡。
```

因此完整首批推荐约：

```text
18 + 3 + 6 + 3 + 3~5 = 33~35 张唯一卡
```

其中 33~35 是“总定义数”，不是每次升级会从 33~35 张里随机抽。实际发牌仍由延续槽、协同槽、转向槽控制。

### 12.2 卡自身需要等级，但不需要独立阶段

卡自身建议有 `max_level`，但不要再给每张卡设计复杂“阶段”。阶段属于队伍等级门槛：

```text
队伍等级 6 / 12 / 18 / 25 = 局内阶段。
卡牌 level 1 / 2 / 3 = 这张卡被重复选择后的深化。
```

也就是说，卡牌只需要：

```text
team_level_min
investment_requirements
max_level
level_effects
```

不建议每张卡再写：

```text
卡牌一阶段 / 二阶段 / 三阶段
```

否则会形成“双重阶段系统”，玩家和设计都会很难维护。

### 12.3 不同类型卡的 max_level

| 类型 | 推荐 Max | 原因 |
| --- | ---: | --- |
| 英雄入口卡 | 3 | 允许前期稳定深化，Lv.3 给第一次小质变。 |
| 英雄 engine 卡 | 3 | 负责 6-12 级玩法成形，需要可重复投资。 |
| 英雄 payoff/bridge 卡 | 3 | 负责 12 级后变体和转向，需要一定深度。 |
| 双人协同卡 | 2 | Lv.1 接上状态，Lv.2 给明显追加反馈；避免协同吞太多升级。 |
| 三人协同卡 | 2 | 三人卡本身门槛高，不宜再吃 3-4 次选择。 |
| 英雄终式卡 | 1 | 应该是强质变，而不是反复堆数值。 |
| 成型节点 | 0/系统节点 | 不进普通升级池，只改变后续发牌权重。 |
| 通用卡 | 2-3 | 生存/拾取/移速可重复，但不能抢主构筑。 |

### 12.4 普通卡等级结构

普通 3 级卡建议这样写：

```text
Lv.1：解锁机制。
Lv.2：提高稳定性、范围、持续或触发频率。
Lv.3：给一个小质变，最好有可见表现变化。
```

例如 `破阵步`：

```text
Lv.1：入场突进伤害提高，命中敌人产生轻破甲。
Lv.2：突进距离和破甲持续提高。
Lv.3：突进终点追加横斩，破甲敌人更容易被枪手标记。
```

这样卡等级不是单纯 `+5%`，而是：

```text
机制 -> 稳定 -> 小质变
```

### 12.5 为什么不让终式卡多级

终式卡如果做成 4 级，会抢走太多队伍等级选择，导致玩家到 25 级还在补同一张终式，而没有空间转向第二线路。

所以第一版建议：

```text
终式卡 Max 1。
```

如果以后需要更长局，可以扩成：

```text
终式卡 Max 2：
Lv.1 获得终式。
Lv.2 终式和另一条能力包产生桥接。
```

但第一版先不要做 Max 4。

### 12.6 成型节点不是普通卡

`破阵血潮·成型`、`过载火线·成型`、`星灾符印·成型` 更适合作为系统节点，而不是普通卡。

触发条件：

```text
team_level >= 25
package_depth >= 8
或已选择对应英雄终式 / Boss 突破
```

触发后：

```text
当前 package 延续权重下降。
相邻 bridge_edge 权重上升。
双人/三人共鸣权重上升。
第二能力包 seed 权重上升。
```

它可以在 UI 上显示为“已成型”，但不应该消耗一次普通升级选择。

## 13. 当前实装接入状态：首批 Build 进入升级局内循环

本阶段已经不再只停留在纯模型层。普通升级现在走首批 Build 发牌链路：

```text
Player.try_request_level_up
-> player_level_flow.build_upgrade_options
-> build_first_batch_runtime.build_offer_for_owner
-> build_first_batch_model.build_upgrade_offer
-> level_up_ui.show_options(options, trait_options, offer_context)
```

### 13.1 UI 三槽映射

纯模型的三类发牌槽保持不变，但普通升级 UI 不再把三张待选 Build 卡拆成三个分区。玩家看到的是统一的“Build 技能三选一”，每张卡在摘要和详情里说明它属于哪类推荐：

| 模型槽 | UI 分区 | 玩家含义 |
| --- | --- | --- |
| `continue` | 卡面说明：主轴延续 | 沿当前投入最深的英雄/能力包继续深化。 |
| `link` | 卡面说明：联动共鸣 | 给双人/三人接力、状态消费、队伍共鸣。 |
| `pivot` | 卡面说明：转向补强 | 给低投入英雄、通用补强、第二路线入口。 |

升级界面仍然保持“英雄特性训练 + 1 张 Build 卡”的双选择，但 Build 卡池已经由首批模型生成。

### 13.2 一次刷新

每次升级生成一个 `offer_context`，默认 `refresh_limit = 1`。玩家可以在本次升级界面点击一次“刷新发牌”：

```text
level_up_ui.upgrade_refresh_requested
-> reward_flow.handle_upgrade_refresh_requested
-> player.refresh_upgrade_options
-> build_first_batch_runtime.refresh_offer_for_owner
```

刷新会把本次已展示的卡记录进 `rejected_offer_ids`，然后重新按当前 state 选出 `continue/link/pivot` 三槽。刷新后 `refresh_remaining = 0`，按钮禁用。刷新不会修改玩家已经获得的卡，只影响本次候选。

### 13.3 战斗效果承载方式

首批卡当前通过 `player_first_batch_card_applier.gd` 接入实战：

1. 每张首批卡按 `card_pick_levels[card_id]` 记录等级，遵守卡自身 `max_level`。
2. 根据卡的 `position_weights` 转换为基础战斗收益：输出、生存、控制、支援、召唤/造物、资源、机动。
3. 根据 `owner_role` 和定位，把收益分配到该英雄现有 special key，例如剑士破阵/血刃/守势，枪手弹幕/锁定/装填，术师星陨/冰封/回流。
4. 双人/三人共鸣卡以队伍增益和多英雄 special 同步提升承载，避免只强化单个角色。
5. 三张 12 级英雄专属已拆成独立 ability，不再借用旧主题进化触发器：
   - `swd_blade_shadow` → `swordsman_blade_shadow_ability.gd`：9s 独立冷却，剑影重复斩击；Lv.2 增加牵引/短嘲讽感，Lv.3 增加交叉剑影。
   - `gun_spotter_drone` → `gunner_spotter_drone_ability.gd`：10s 独立冷却，锁定关键目标并追加无人机火力；Lv.2 溅射，Lv.3 命中后提供少量回复/护盾感。
   - `mag_guardian_puppet` → `mage_guardian_puppet_ability.gd`：12s 独立冷却，在敌群中心生成傀儡领域；Lv.2 给护卫减伤，Lv.3 脉冲后回复。

Boss 掉落的 Build 奖励改为“Boss Build 三选一”：三张选项固定分别对应剑士、枪手、术师专属进阶，优先把对应专属卡提升到 Lv.3；若该专属已经满级，则改为同英雄伤害、冷却、范围、skill_bonus 与 special key 的溢出补强。这样 Boss 奖励不再随机从庞大池里抽，而是让玩家在三个英雄方向之间做一次明确的中期/后期轴向选择。

### 13.4 验收护栏

新增 `scripts/tests/build_first_batch_runtime_smoke.gd`，检查：

- 首批模型选项能被 runtime 格式化为 UI 可识别的 `body/combat/skill` 三分区。
- 从 `card_pick_levels` 重建 state 后，6 级剑士投入能够解锁对应 engine 卡。
- 刷新后的候选仍然保持 UI 兼容格式。

`./scripts/check_project.sh` 已加入该 smoke，并继续跑纯模型、平衡模型、敌人压力模型和难度 profile 检查。
